import 'package:flutter/foundation.dart';

import '../models/prescription_model.dart';
import '../services/prescription_service.dart';

// ---------------------------------------------------------------------------
// PrescriptionProvider — estado global de histórico de prescrições (paciente)
// ---------------------------------------------------------------------------

/// Provider responsável por expor o histórico de prescrições do paciente
/// autenticado para a [HistoryScreen].
///
/// Segue o mesmo padrão adotado pelos demais providers do projeto:
/// injeção de [IPrescriptionService] via construtor para permitir substituição
/// por mock durante testes (TDD com Mockito).
///
/// Nunca acessa [SupabaseClient] diretamente — toda comunicação ocorre via
/// [IPrescriptionService], preservando a separação de camadas
/// (provider → service → Supabase).
class PrescriptionProvider with ChangeNotifier {
  /// Serviço de acesso a dados de prescrições.
  /// Injetado via construtor para facilitar mocks em testes.
  final IPrescriptionService _service;

  /// Indica que [fetchPatientHistory] está aguardando resposta do Supabase.
  bool _isLoading = false;

  /// Mensagem de erro humanizada para exibição na UI.
  /// Nula quando não há erro ativo.
  String? _errorMessage;

  /// Cache local do histórico carregado. Nunca expõe referência mutável.
  List<PrescriptionModel> _history = const [];

  // ── Construtor ──────────────────────────────────────────────────────────

  /// Cria o provider com [service] injetado.
  ///
  /// Em produção, injete [PrescriptionService()]; em testes, injete um mock
  /// gerado pelo `@GenerateMocks([IPrescriptionService])` via Mockito.
  PrescriptionProvider(this._service);

  // ── Getters públicos ────────────────────────────────────────────────────

  /// Verdadeiro enquanto [fetchPatientHistory] aguarda resposta do Supabase.
  bool get isLoading => _isLoading;

  /// Mensagem de erro pronta para exibição ou nula se não houver erro.
  String? get errorMessage => _errorMessage;

  /// Cópia não-mutável do histórico carregado.
  List<PrescriptionModel> get history => List.unmodifiable(_history);

  // ── Métodos públicos ────────────────────────────────────────────────────

  /// Busca e armazena o histórico de prescrições do paciente autenticado.
  ///
  /// Delega para [IPrescriptionService.fetchPatientHistory], que usa
  /// `auth.currentUser?.id` internamente — nenhum `patientId` é aceito
  /// externamente para evitar falsificação de identidade (LGPD).
  ///
  /// Retorna a lista carregada em sucesso e lista vazia em falha, sempre
  /// com [errorMessage] preenchido em caso de erro para que a UI exiba
  /// o feedback adequado sem vazar detalhes internos.
  Future<List<PrescriptionModel>> fetchPatientHistory() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _history = await _service.fetchPatientHistory();
      _isLoading = false;
      notifyListeners();
      return _history;
    } catch (_) {
      // Captura qualquer exceção (rede, RLS, desconhecido) sem expor
      // detalhes internos — OWASP A05/LGPD.
      _isLoading = false;
      _errorMessage = 'Não foi possível carregar o histórico de receitas.';
      notifyListeners();
      return const [];
    }
  }

  /// Limpa a mensagem de erro atual.
  ///
  /// Deve ser chamado pela UI após exibir o feedback ao usuário para
  /// evitar que o estado de erro persista entre navegações.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
