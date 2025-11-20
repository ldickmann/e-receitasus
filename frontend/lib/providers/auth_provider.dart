import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  // Inicializamos o storage seguro (Requisito de Segurança)
  final _storage = const FlutterSecureStorage();
  final IAuthService _authService;
  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  // Injeção do serviço de autenticação
  AuthProvider(this._authService);

  UserModel? get user => _user;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------
  // Lógica de Autenticação
  // ---------------------------------------------------

  Future<void> login(String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final token = await _authService.login(email, password);

      // Assumindo que a API retorna dados completos em outro endpoint após o login
      // Para fins de MVP, criamos um modelo básico com o token
      _user = UserModel(
        id: '1', // Assumindo ID fixo ou obtido do token
        name: email, // Usando email como nome no MVP
        email: email,
        token: token,
      );

      // Armazenamento seguro do token
      await _storage.write(key: 'jwt_token', value: token);

      notifyListeners(); // Avisa a UI que o estado mudou
    } catch (e) {
      _user = null;
      _errorMessage = e.toString().contains('401')
          ? 'Credenciais inválidas.'
          : 'Erro ao tentar fazer login.';
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------
  // Lógica de Registro (Implementação rápida)
  // ---------------------------------------------------

  Future<void> register(String name, String email, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final success = await _authService.register(name, email, password);
      if (success) {
        // Se o registro for bem-sucedido, tente fazer login automaticamente
        await login(email, password);
      }
    } catch (e) {
      _user = null;
      _errorMessage = e.toString().contains('409')
          ? 'Usuário já existe.'
          : 'Falha ao registrar.';
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------
  // Utilitários e Logout
  // ---------------------------------------------------

  Future<void> logout() async {
    _user = null;
    await _storage.delete(key: 'jwt_token');
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
