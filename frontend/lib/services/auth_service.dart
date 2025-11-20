import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 1. Definição do Contrato (Interface Abstrata)
abstract class IAuthService {
  // Retorna o Token JWT em caso de sucesso
  Future<String> login(String email, String password);

  // Retorna true em caso de sucesso no registro
  Future<bool> register(String name, String email, String password);

  // Adicionado para permitir encerrar a sessão
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

  /// Implementa a autenticação do usuário, comunicando com a API.
  @override
  Future<String> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final token = data['token'];

      // AGORA SALVAMOS O TOKEN COM SEGURANÇA
      await _storage.write(key: 'auth_token', value: token);

      return token;
    } else if (response.statusCode == 401) {
      throw Exception('Credenciais inválidas. Verifique e-mail e senha.');
    } else {
      throw Exception(
          'Falha ao conectar ou erro no servidor: ${response.statusCode}');
    }
  }

  /// Implementa o registro de um novo usuário.
  @override
  Future<bool> register(String name, String email, String password) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      // 201 Created é o código esperado para sucesso no registro
      return true;
    } else if (response.statusCode == 409) {
      throw Exception('Usuário já cadastrado.');
    } else {
      throw Exception('Falha ao registrar usuário.');
    }
  }

  /// Implementa o Logout limpando o token do dispositivo.
  @override
  Future<void> logout() async {
    await _storage.delete(key: 'auth_token');
  }
}
