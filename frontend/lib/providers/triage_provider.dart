import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/renewal_request_model.dart';
import '../models/user_model.dart';
import '../services/renewal_service.dart';

// ---------------------------------------------------------------------------
// TriageProvider — estado global de triagem de pedidos (perfil enfermeiro)
// ---------------------------------------------------------------------------

/// Provider responsável pelo estado de triagem de pedidos de renovação de
/// prescrição, destinado ao perfil enfermeiro.
///
/// Gerencia as operações:
/// - Streaming em tempo real dos pedidos aguardando triagem ([streamPendingTriage]).
/// - Aprovação de um pedido de triagem, designando um médico ([approveTriage]).
/// - Rejeição de um pedido de triagem com motivo obrigatório ([rejectTriage]).
/// - Busca de médicos disponíveis para seleção na triagem ([fetchDoctors]).
///
/// Segue o padrão do projeto: injeção de [IRenewalService] via construtor
/// para permitir substituição por mock durante testes (TDD com Mockito).
///
/// Nunca acessa [SupabaseClient] diretamente — toda comunicação ocorre via
/// [IRenewalService], garantindo a separação de camadas (provider → service).
class TriageProvider with ChangeNotifier {
  /// Serviço de acesso a dados de renovação.
  /// Injetado via construtor para facilitar mocks em testes.
  final IRenewalService _service;

  /// Indica que uma operação de escrita está em andamento (approve/reject).
  /// Exibido como loading nos botões de triagem.
  bool _isLoading = false;

  /// Mensagem de erro humanizada para exibição via SnackBar/AlertDialog.
  /// Nula quando não há erro ativo. Limpar após exibir com [clearError].
  String? _errorMessage;

  // ── Construtor ──────────────────────────────────────────────────────────

  /// Cria o provider com [service] injetado.
  ///
  /// Em produção, use [RenewalService]; em testes, injete um mock gerado
  /// pelo `@GenerateMocks([IRenewalService])` via Mockito.
  TriageProvider(this._service);

  // ── Getters públicos ────────────────────────────────────────────────────

  /// Verdadeiro enquanto uma operação de triagem aguarda resposta do Supabase.
  bool get isLoading => _isLoading;

  /// Mensagem de erro pronta para exibição ou nula se não houver erro.
  String? get errorMessage => _errorMessage;

  // ── Métodos públicos ────────────────────────────────────────────────────

  /// Retorna um stream em tempo real dos pedidos aguardando triagem.
  ///
  /// Delega diretamente ao [IRenewalService.streamPendingTriage]. O RLS do
  /// Supabase (enfermeiro_ve_pendentes) garante que apenas enfermeiros
  /// autenticados recebem os dados; outros perfis obtêm stream vazio.
  ///
  /// Ordenados por data de criação crescente (FIFO — mais antigo primeiro),
  /// seguindo a política de atendimento por ordem de chegada.
  ///
  /// Este método não altera o estado do provider — apenas expõe o stream
  /// para que a tela possa reagir via [StreamBuilder].
  Stream<List<RenewalRequestModel>> streamPendingTriage() {
    return _service.streamPendingTriage();
  }

  /// Aprova a triagem de um pedido e designa o médico responsável.
  ///
  /// [id] é o identificador do pedido de renovação a ser aprovado.
  /// [nurseNotes] são observações opcionais do enfermeiro.
  /// [doctorUserId] é o ID do médico que irá emitir a nova prescrição.
  ///
  /// Retorna `true` em sucesso e `false` em falha, sempre com [errorMessage]
  /// preenchido na falha para que a tela exiba o feedback adequado.
  ///
  /// Validação de domínio (antes de chamar o service):
  /// - [doctorUserId] não pode ser vazio — sem médico designado, não é
  ///   possível completar a triagem de forma segura.
  ///
  /// Tratamento de erros do Supabase:
  /// - [PostgrestException]: RLS bloqueou ou estado inválido → mensagem genérica
  ///   sem vazar detalhes internos (LGPD).
  /// - [StateError]: sessão expirada → solicita relogin.
  /// - Outros erros: mensagem genérica de falha de conexão.
  Future<bool> approveTriage({
    required String id,
    String? nurseNotes,
    required String doctorUserId,
  }) async {
    // Validação de domínio: médico é obrigatório para aprovar a triagem
    if (doctorUserId.trim().isEmpty) {
      _errorMessage = 'Selecione um médico responsável antes de aprovar.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await _service.approveTriage(
        id,
        nurseNotes: nurseNotes,
        doctorUserId: doctorUserId,
      );
      _setLoading(false);
      return true;
    } on PostgrestException catch (e) {
      // Mensagem genérica — não vazar detalhes de constraint ou estrutura de
      // tabela ao usuário (LGPD e boas práticas de segurança)
      _errorMessage =
          'Não foi possível aprovar o pedido de triagem. Tente novamente.';
      // Loga apenas o código do erro — sem dados sensíveis do paciente (LGPD)
      debugPrint('TriageProvider.approveTriage: PostgrestException ${e.code}');
      _setLoading(false);
      return false;
    } on StateError catch (_) {
      // Sessão expirada durante a operação — solicitar relogin
      _errorMessage = 'Usuário não autenticado. Faça login novamente.';
      _setLoading(false);
      return false;
    } catch (_) {
      // Captura exceções inesperadas sem expor detalhes internos ao usuário
      _errorMessage =
          'Ocorreu um erro inesperado. Verifique sua conexão e tente novamente.';
      _setLoading(false);
      return false;
    }
  }

  /// Rejeita um pedido de renovação durante a triagem.
  ///
  /// [id] é o identificador do pedido de renovação a ser rejeitado.
  /// [nurseNotes] é o motivo da rejeição — campo **obrigatório** por exigência
  /// de auditoria (LGPD, registro de dados de saúde).
  ///
  /// Retorna `true` em sucesso e `false` em falha, sempre com [errorMessage]
  /// preenchido na falha para que a tela exiba o feedback adequado.
  ///
  /// Validação de domínio (antes de chamar o service):
  /// - [nurseNotes] não pode ser vazio — o motivo da rejeição é exigência
  ///   de auditoria para dados de saúde (LGPD, art. 11).
  ///
  /// Tratamento de erros do Supabase: idêntico ao [approveTriage].
  Future<bool> rejectTriage({
    required String id,
    required String nurseNotes,
  }) async {
    // Validação de domínio: motivo é obrigatório para rejeição auditável
    if (nurseNotes.trim().isEmpty) {
      _errorMessage = 'Informe o motivo da rejeição antes de confirmar.';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _clearError();

    try {
      await _service.rejectTriage(id, nurseNotes: nurseNotes);
      _setLoading(false);
      return true;
    } on PostgrestException catch (e) {
      _errorMessage =
          'Não foi possível rejeitar o pedido de triagem. Tente novamente.';
      // Loga apenas o código do erro — sem dados sensíveis do paciente (LGPD)
      debugPrint('TriageProvider.rejectTriage: PostgrestException ${e.code}');
      _setLoading(false);
      return false;
    } on StateError catch (_) {
      _errorMessage = 'Usuário não autenticado. Faça login novamente.';
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage =
          'Ocorreu um erro inesperado. Verifique sua conexão e tente novamente.';
      _setLoading(false);
      return false;
    }
  }

  /// Busca a lista de médicos disponíveis para seleção na triagem.
  ///
  /// Retorna a lista via [IRenewalService.fetchDoctors]. Em caso de erro,
  /// preenche [errorMessage] e retorna lista vazia para não quebrar a UI.
  ///
  /// Não usa loading separado — a tela deve usar [FutureBuilder] e tratar
  /// os estados de carregamento e erro diretamente.
  Future<List<UserModel>> fetchDoctors() async {
    try {
      return await _service.fetchDoctors();
    } on PostgrestException catch (e) {
      _errorMessage =
          'Não foi possível carregar a lista de médicos. Tente novamente.';
      debugPrint('TriageProvider.fetchDoctors: PostgrestException ${e.code}');
      notifyListeners();
      return [];
    } catch (_) {
      _errorMessage =
          'Ocorreu um erro inesperado ao carregar os médicos. Tente novamente.';
      notifyListeners();
      return [];
    }
  }

  /// Limpa a mensagem de erro atual.
  ///
  /// Deve ser chamado pela tela após exibir o SnackBar/AlertDialog para que
  /// o estado não persista ao reabrir a tela ou navegar de volta.
  void clearError() {
    if (_errorMessage != null) {
      _clearError();
      notifyListeners();
    }
  }

  // ── Helpers privados ────────────────────────────────────────────────────

  /// Atualiza [_isLoading] e notifica ouvintes para refletir na UI.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Limpa o erro sem notificar ouvintes (uso interno antes de operações).
  void _clearError() {
    _errorMessage = null;
  }
}
