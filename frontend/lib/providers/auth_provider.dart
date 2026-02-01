import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

/// Provider responsável pelo gerenciamento de estado de autenticação
///
/// Implementa ChangeNotifier para notificar widgets dependentes sobre
/// mudanças no estado de autenticação. Segue o padrão Provider do Flutter.
class AuthProvider with ChangeNotifier {
  // ========== DEPENDÊNCIAS E ESTADO ==========

  /// Armazenamento seguro para dados sensíveis (tokens) - apenas mobile
  final FlutterSecureStorage? _secureStorage;

  /// SharedPreferences para web (inicializado sob demanda)
  SharedPreferences? _prefsForToken;

  /// Serviço de autenticação injetado
  final IAuthService _authService;

  /// Usuário atualmente autenticado (null se não autenticado)
  UserModel? _user;

  /// Indica se uma operação assíncrona está em andamento
  bool _isLoading = false;

  /// Mensagem de erro da última operação
  String? _errorMessage;

  // ========== CONSTRUTOR ==========

  /// Construtor com injeção de dependência do serviço de autenticação
  ///
  /// [_authService] - Implementação do serviço de autenticação
  AuthProvider(this._authService)
      : _secureStorage = kIsWeb ? null : const FlutterSecureStorage();

  // ========== GETTERS PÚBLICOS ==========

  /// Retorna o usuário autenticado ou null
  UserModel? get user => _user;

  /// Indica se há uma operação em andamento (loading state)
  bool get isLoading => _isLoading;

  /// Retorna a mensagem de erro da última operação
  String? get errorMessage => _errorMessage;

  /// Verifica se há um usuário autenticado com token válido
  bool get isAuthenticated => _user != null && _user!.isTokenValid;

  // ========== INICIALIZAÇÃO ==========

  /// Inicializa o provider verificando sessão existente
  ///
  /// Chamado na inicialização do app para verificar se há
  /// um usuário com sessão ativa salva localmente.
  Future<void> initAuth() async {
    _setLoading(true);

    try {
      // Busca dados do usuário salvos
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');

      if (userData != null) {
        // Reconstrói o modelo de usuário
        final userMap = json.decode(userData) as Map<String, dynamic>;
        _user = UserModel.fromJson(userMap);

        // Verifica validade do token
        if (!_user!.isTokenValid) {
          // Token expirado - realiza logout
          await logout();
        }
      }
    } catch (e) {
      _errorMessage = 'Erro ao carregar sessão: ${e.toString()}';
      debugPrint('Erro ao inicializar auth: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ========== AUTENTICAÇÃO ==========

  /// Realiza login do usuário no sistema
  ///
  /// [email] - E-mail cadastrado do usuário
  /// [password] - Senha do usuário
  ///
  /// Retorna `true` se login bem-sucedido, `false` caso contrário
  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Chama serviço de autenticação
      _user = await _authService.login(email, password);

      // Salva dados localmente
      await _saveUserData();
      await _saveTokenSecurely(_user!.token!);

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  /// Registra novo usuário no sistema
  ///
  /// [name] - Nome completo do profissional
  /// [email] - E-mail para cadastro
  /// [password] - Senha (mínimo 8 caracteres)
  ///
  /// Retorna `true` se registro bem-sucedido, `false` caso contrário
  ///
  /// **IMPORTANTE:** O backend não retorna token no registro.
  /// O usuário deve fazer login após o cadastro.
  Future<bool> register(String name, String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      // Chama serviço de registro
      _user = await _authService.register(name, email, password);

      // ⚠️ NÃO salva token porque o backend não retorna token no registro
      // Apenas salva os dados do usuário temporariamente
      await _saveUserData();

      // Limpa o usuário porque ele ainda não está autenticado
      _user = null;

      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  /// Realiza logout do usuário
  ///
  /// Remove todos os dados salvos localmente e limpa o estado
  Future<void> logout() async {
    try {
      // Remove dados não-sensíveis
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_data');

      // Remove token do armazenamento seguro
      await _deleteTokenSecurely();

      // Limpa estado
      _user = null;
      _clearError();

      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao fazer logout: $e');
    }
  }

  // ========== MÉTODOS PRIVADOS ==========

  /// Salva dados do usuário no SharedPreferences
  ///
  /// Persiste dados não-sensíveis para restauração de sessão
  Future<void> _saveUserData() async {
    if (_user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', json.encode(_user!.toJson()));
      } catch (e) {
        debugPrint('Erro ao salvar dados do usuário: $e');
      }
    }
  }

  /// Salva token JWT no armazenamento seguro
  ///
  /// [token] - Token JWT a ser armazenado de forma segura
  Future<void> _saveTokenSecurely(String token) async {
    try {
      if (kIsWeb) {
        // Web: usa SharedPreferences
        _prefsForToken ??= await SharedPreferences.getInstance();
        await _prefsForToken!.setString('jwt_token', token);
      } else {
        // Mobile: usa FlutterSecureStorage
        await _secureStorage!.write(key: 'jwt_token', value: token);
      }
    } catch (e) {
      debugPrint('Erro ao salvar token: $e');
    }
  }

  /// Remove token JWT do armazenamento seguro
  Future<void> _deleteTokenSecurely() async {
    try {
      if (kIsWeb) {
        // Web: usa SharedPreferences
        _prefsForToken ??= await SharedPreferences.getInstance();
        await _prefsForToken!.remove('jwt_token');
      } else {
        // Mobile: usa FlutterSecureStorage
        await _secureStorage!.delete(key: 'jwt_token');
      }
    } catch (e) {
      debugPrint('Erro ao remover token: $e');
    }
  }

  /// Atualiza estado de loading e notifica listeners
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Limpa mensagem de erro
  void _clearError() {
    _errorMessage = null;
  }

  /// Formata mensagens de erro para exibição ao usuário
  ///
  /// [error] - Exceção capturada
  /// Retorna mensagem amigável ao usuário
  String _parseErrorMessage(Object error) {
    final errorString = error.toString();

    if (errorString.contains('Credenciais inválidas')) {
      return 'E-mail ou senha incorretos';
    } else if (errorString.contains('E-mail já cadastrado')) {
      return 'Este e-mail já está cadastrado';
    } else if (errorString.contains('conexão')) {
      return 'Sem conexão com a internet';
    } else if (errorString.contains('timeout')) {
      return 'Tempo de conexão esgotado';
    } else {
      return 'Ocorreu um erro. Tente novamente.';
    }
  }

  /// Limpa mensagem de erro manualmente
  ///
  /// Útil para limpar erros após exibição ao usuário
  void clearError() {
    _clearError();
    notifyListeners();
  }
}
