import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/renewal_request_model.dart';
import '../services/renewal_service.dart';

// ---------------------------------------------------------------------------
// RenewalProvider — estado global de renovação de prescrição (perfil paciente)
// ---------------------------------------------------------------------------

/// Provider responsável pelo estado de renovação de prescrição do paciente
/// autenticado.
///
/// Gerencia as operações:
/// - Streaming em tempo real das renovações do paciente ([streamMyRenewals]).
/// - Solicitação de uma nova renovação ([requestRenewal]).
///
/// Segue o padrão do projeto: injeção de [IRenewalService] via construtor
/// para permitir substituição por mock durante testes (TDD com Mockito).
///
/// Nunca acessa [SupabaseClient] diretamente — toda comunicação ocorre via
/// [IRenewalService], garantindo a separação de camadas (provider → service).
class RenewalProvider with ChangeNotifier {
  /// Serviço de acesso a dados de renovação.
  /// Injetado via construtor para facilitar mocks em testes.
  final IRenewalService _service;

  /// Indica que uma operação de escrita está em andamento (requestRenewal).
  /// Exibido como loading no botão de solicitação na tela do paciente.
  bool _isSubmitting = false;

  /// Mensagem de erro humanizada para exibição via SnackBar/AlertDialog.
  /// Nula quando não há erro ativo. Limpar após exibir com [clearError].
  String? _errorMessage;

  // ── Construtor ──────────────────────────────────────────────────────────

  /// Cria o provider com [service] injetado.
  ///
  /// Em produção, use [RenewalService]; em testes, injete um mock gerado
  /// pelo `@GenerateMocks([IRenewalService])` via Mockito.
  RenewalProvider(this._service);

  // ── Getters públicos ────────────────────────────────────────────────────

  /// Verdadeiro enquanto [requestRenewal] aguarda resposta do Supabase.
  bool get isSubmitting => _isSubmitting;

  /// Mensagem de erro pronta para exibição ou nula se não houver erro.
  String? get errorMessage => _errorMessage;

  // ── Métodos públicos ────────────────────────────────────────────────────

  /// Retorna um stream em tempo real das renovações do paciente autenticado.
  ///
  /// Delega diretamente ao [IRenewalService.streamMyRenewals]. O RLS do
  /// Supabase garante que apenas os registros do próprio paciente são
  /// retornados, sem necessidade de filtro adicional no provider.
  ///
  /// Este método não altera o estado do provider — apenas expõe o stream
  /// para que a tela possa reagir via [StreamBuilder].
  Stream<List<RenewalRequestModel>> streamMyRenewals() {
    return _service.streamMyRenewals();
  }

  /// Solicita a renovação de uma prescrição expirada.
  ///
  /// [prescriptionId] é o ID da prescrição que o paciente deseja renovar.
  /// [notes] são observações opcionais (ex.: "preciso com urgência").
  ///
  /// Retorna `true` em sucesso e `false` em falha, sempre com [errorMessage]
  /// preenchido na falha para que a tela exiba o feedback adequado.
  ///
  /// Tratamento de erros do Supabase:
  /// - Código `23505` (unique_violation): paciente já tem pedido ativo para
  ///   esta prescrição → mensagem humanizada específica.
  /// - [StateError] (usuário não autenticado): redirecionar ao login.
  /// - Outros erros: mensagem genérica sem vazar detalhes internos (LGPD).
  Future<bool> requestRenewal({
    required String prescriptionId,
    String? notes,
  }) async {
    _setSubmitting(true);
    _clearError();

    try {
      await _service.requestRenewal(prescriptionId, notes: notes);
      _setSubmitting(false);
      return true;
    } on PostgrestException catch (e) {
      // Trata violação de unicidade — pedido duplicado para a mesma prescrição
      if (e.code == '23505') {
        _errorMessage =
            'Você já possui um pedido de renovação ativo para esta prescrição.';
      } else {
        // Mensagem genérica para outros erros do banco de dados (não vazar
        // detalhes internos como estrutura de tabela ou constraint names)
        _errorMessage =
            'Não foi possível enviar o pedido de renovação. Tente novamente.';
      }
      // Loga apenas o código do erro — sem dados sensíveis do paciente (LGPD)
      debugPrint(
          'RenewalProvider.requestRenewal: PostgrestException ${e.code}');
      _setSubmitting(false);
      return false;
    } on StateError catch (_) {
      // Usuário perdeu a sessão durante a operação — solicitar relogin
      _errorMessage = 'Usuário não autenticado. Faça login novamente.';
      _setSubmitting(false);
      return false;
    } catch (_) {
      // Captura exceções inesperadas sem expor detalhes internos ao usuário
      _errorMessage =
          'Ocorreu um erro inesperado. Verifique sua conexão e tente novamente.';
      _setSubmitting(false);
      return false;
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

  /// Atualiza [_isSubmitting] e notifica ouvintes para refletir na UI.
  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  /// Limpa o erro sem notificar ouvintes (uso interno antes de operações).
  void _clearError() {
    _errorMessage = null;
  }
}
