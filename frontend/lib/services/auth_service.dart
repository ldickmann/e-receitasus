import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';

abstract class IAuthService {
  /// Retorna o UserModel com token JWT em caso de sucesso
  Future<UserModel> login(String email, String password);

  /// Retorna o UserModel criado em caso de sucesso
  Future<UserModel> register(String name, String email, String password);

  /// Encerra a sessão do usuário
  Future<void> logout();
}


// 2. Implementação do Serviço RESTful
class AuthService implements IAuthService {
  final http.Client _client;
  final FlutterSecureStorage _storage;

  // Usaremos o IP 10.0.2.2 para emuladores Android (se a API estiver rodando no host)
  final String _baseUrl = 'http://10.0.2.2:3000/api/v1/auth';

  // CONSTRUTOR ATUALIZADO:
  // Aceita dependências opcionais. Se não forem passadas, usa as padrão.
  // Isso permite que o arquivo de teste injete os Mocks.
  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      // Validação de entrada
      if (email.isEmpty || password.isEmpty) {
        throw Exception('E-mail e senha são obrigatórios');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Salva o token com segurança
        await _storage.write(key: 'auth_token', value: token);

        // RETORNA UserModel ao invés de String
        return UserModel(
          id: data['user']['id'] ?? '',
          name: data['user']['name'] ?? '',
          email: data['user']['email'] ?? '',
          crm: data['user']['crm'],
          specialty: data['user']['specialty'],
          token: token,
          tokenExpiry: DateTime.now().add(const Duration(hours: 24)),
        );
      } else if (response.statusCode == 401) {
        throw Exception('Credenciais inválidas');
      } else if (response.statusCode == 429) {
        throw Exception('Muitas tentativas. Tente novamente mais tarde.');
      } else {
        throw Exception('Erro ao fazer login: ${response.statusCode}');
      }
    } on http.ClientException {
      throw Exception('Erro de conexão. Verifique sua internet.');
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<UserModel> register(String name, String email, String password) async {
    try {
      // Validações de entrada
      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('Todos os campos são obrigatórios');
      }

      if (password.length < 8) {
        throw Exception('A senha deve ter pelo menos 8 caracteres');
      }

      final response = await _client.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];

        // Salva o token com segurança
        await _storage.write(key: 'auth_token', value: token);

        // RETORNA UserModel ao invés de bool
        return UserModel(
          id: data['user']['id'] ?? '',
          name: data['user']['name'] ?? '',
          email: data['user']['email'] ?? '',
          crm: data['user']['crm'],
          specialty: data['user']['specialty'],
          token: token,
          tokenExpiry: DateTime.now().add(const Duration(hours: 24)),
        );
      } else if (response.statusCode == 409) {
        throw Exception('E-mail já cadastrado');
      } else {
        throw Exception('Erro ao registrar: ${response.statusCode}');
      }
    } on http.ClientException {
      throw Exception('Erro de conexão. Verifique sua internet.');
    } catch (e) {
      rethrow;
    }
  }

  /// Implementa o Logout limpando o token do dispositivo.
  @override
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }
}
