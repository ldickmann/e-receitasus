import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/professional_type.dart';
import '../services/auth_service.dart';

/// Provider responsável pelo gerenciamento de estado de autenticação.
///
/// Refatorado para a Etapa 2: A persistência de sessão agora é delegada
/// integralmente ao SDK do Supabase, eliminando o uso de SecureStorage manual.
class AuthProvider with ChangeNotifier {
  // ========== DEPENDÊNCIAS E ESTADO ==========

  final IAuthService _authService;

  /// Usuário atualmente autenticado na sessão ativa
  UserModel? _user;

  bool _isLoading = false;
  String? _errorMessage;

  // ========== CONSTRUTOR ==========

  AuthProvider(this._authService);

  // ========== GETTERS PÚBLICOS ==========

  UserModel? get user => _user;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  /// Verifica se há um usuário autenticado.
  /// O Supabase garante a validade do token em background.
  bool get isAuthenticated => _user != null;

  // ========== INICIALIZAÇÃO DA SESSÃO ==========

  /// Verifica se existe uma sessão ativa salva pelo Supabase ao abrir o app.
  /// Substitui a leitura manual de JSON do SharedPreferences.
  Future<void> initAuth() async {
    _setLoading(true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      if (session != null && user != null) {
        // Reconstrói o modelo a partir dos metadados da nuvem
        _user = UserModel(
          id: user.id,
          name: user.userMetadata?['name'] ?? 'Usuário SUS',
          email: user.email!,
          token: session.accessToken,
        );
      }
    } catch (e) {
      _errorMessage = 'Erro ao recuperar sessão: ${e.toString()}';
      debugPrint('Erro initAuth: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ========== AÇÕES DE AUTENTICAÇÃO ==========

  /// Realiza o login utilizando o novo AuthService (Cloud-Native)
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.login(email, password);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  /// Registra novo usuário profissional ou paciente
  Future<bool> registerWithProfessionalInfo({
    required String name,
    required String email,
    required String password,
    required ProfessionalType professionalType,
    String? professionalId,
    String? professionalState,
    String? specialty,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.registerWithProfessionalInfo(
        name: name,
        email: email,
        password: password,
        professionalType: professionalType,
        professionalId: professionalId,
        professionalState: professionalState,
        specialty: specialty,
      );

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  /// Realiza logout e limpa o estado interno
  Future<void> logout() async {
    try {
      await _authService.logout();
      _user = null;
      _clearError();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro no logout: $e');
    }
  }

  // ========== MÉTODOS AUXILIARES (ESTADO) ==========

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Traduz erros técnicos em mensagens amigáveis para o cidadão/profissional
  String _parseErrorMessage(Object error) {
    final e = error.toString();
    if (e.contains('Invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (e.contains('User already registered')) {
      return 'Este e-mail já está em uso.';
    }
    if (e.contains('network')) {
      return 'Erro de conexão. Verifique sua internet.';
    }
    return 'Ocorreu um erro. Tente novamente em instantes.';
  }
}
