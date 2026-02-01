import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user_model.dart';

// ============================================================================
// INTERFACE DO SERVIÇO DE AUTENTICAÇÃO
// ============================================================================

/// Interface abstrata que define o contrato para serviços de autenticação.
///
/// Esta interface permite a implementação de diferentes estratégias de
/// autenticação (mock, real API, etc.) e facilita testes unitários através
/// de dependency injection.
///
/// **Responsabilidades:**
/// - Definir métodos de login, registro e logout
/// - Garantir consistência entre diferentes implementações
/// - Facilitar mocking para testes
abstract class IAuthService {
  /// Autentica um usuário existente no sistema.
  ///
  /// **Parâmetros:**
  /// - [email]: E-mail do usuário (obrigatório, formato válido)
  /// - [password]: Senha do usuário (obrigatório, mínimo 8 caracteres)
  ///
  /// **Retorna:**
  /// - [UserModel] com token JWT e dados do usuário em caso de sucesso
  ///
  /// **Exceções:**
  /// - [Exception] com mensagem descritiva em caso de falha
  Future<UserModel> login(String email, String password);

  /// Registra um novo usuário no sistema.
  ///
  /// **Parâmetros:**
  /// - [name]: Nome completo do usuário (obrigatório)
  /// - [email]: E-mail único do usuário (obrigatório, formato válido)
  /// - [password]: Senha forte (obrigatório, mínimo 8 caracteres)
  ///
  /// **Retorna:**
  /// - [UserModel] com dados do usuário recém-criado
  ///
  /// **Exceções:**
  /// - [Exception] com mensagem descritiva em caso de falha
  Future<UserModel> register(String name, String email, String password);

  /// Encerra a sessão do usuário atual.
  ///
  /// Remove o token de autenticação do armazenamento seguro do dispositivo.
  /// Esta operação é local e não requer comunicação com o backend.
  ///
  /// **Retorna:**
  /// - [Future<void>] quando o logout for concluído
  Future<void> logout();
}

// ============================================================================
// IMPLEMENTAÇÃO DO SERVIÇO DE AUTENTICAÇÃO COM API REST
// ============================================================================

/// Implementação concreta do serviço de autenticação que se comunica
/// com uma API REST backend.
///
/// **Características:**
/// - Comunicação via HTTP com backend Node.js/Express
/// - Armazenamento seguro de tokens JWT usando FlutterSecureStorage
/// - Tratamento robusto de erros e timeouts
/// - Suporte a dependency injection para testes
/// - Validações de entrada antes de enviar requisições
///
/// **Segurança:**
/// - Tokens armazenados de forma criptografada no dispositivo
/// - Timeout de 15 segundos para evitar travamentos
/// - Validação de status HTTP para tratamento correto de erros
class AuthService implements IAuthService {
  // ==========================================================================
  // DEPENDÊNCIAS E CONFIGURAÇÕES
  // ==========================================================================

  /// Cliente HTTP para fazer requisições à API.
  /// Injetável para permitir mocking em testes.
  final http.Client _client;

  /// Armazenamento seguro para tokens JWT.
  /// Usa criptografia nativa do sistema operacional (Keychain no iOS, KeyStore no Android).
  final FlutterSecureStorage? _storage;

  /// Armazenamento para web usando SharedPreferences
  SharedPreferences? _prefs;

  /// URL base da API de autenticação.
  ///
  /// **Detecta automaticamente o ambiente:**
  /// - Web (Chrome/Edge): `http://localhost:3333/auth`
  /// - Emulador Android: `http://10.0.2.2:3333/auth`
  /// - Simulador iOS: `http://localhost:3333/auth`
  ///
  /// **Nota sobre portas:**
  /// - 10.0.2.2 é o IP especial que o emulador Android usa para acessar localhost do host
  /// - A porta 3333 corresponde à porta configurada no backend
  String get _baseUrl {
    if (kIsWeb) {
      // Web (Chrome, Edge, Firefox)
      return 'http://localhost:3333/auth';
    } else {
      // Mobile (Android/iOS)
      return 'http://10.0.2.2:3333/auth';
    }
  }

  // ==========================================================================
  // CONSTRUTOR COM DEPENDENCY INJECTION
  // ==========================================================================

  /// Cria uma instância do serviço de autenticação.
  ///
  /// **Parâmetros opcionais (para testes):**
  /// - [client]: Cliente HTTP customizado (útil para mocking)
  /// - [storage]: Armazenamento customizado (útil para mocking)
  ///
  /// **Exemplo de uso em produção:**
  /// ```dart
  /// final authService = AuthService();
  /// ```
  ///
  /// **Exemplo de uso em testes:**
  /// ```dart
  /// final mockClient = MockClient();
  /// final mockStorage = MockSecureStorage();
  /// final authService = AuthService(client: mockClient, storage: mockStorage);
  /// ```
  AuthService({http.Client? client, FlutterSecureStorage? storage})
      : _client = client ?? http.Client(),
        _storage = storage;

  /// Inicializa o armazenamento apropriado (Web ou Mobile)
  Future<void> _initStorage() async {
    if (kIsWeb && _prefs == null) {
      _prefs = await SharedPreferences.getInstance();
    }
  }

  /// Salva o token no armazenamento apropriado
  Future<void> _saveToken(String token) async {
    if (kIsWeb) {
      await _initStorage();
      await _prefs!.setString('auth_token', token);
    } else {
      final storage = _storage ?? const FlutterSecureStorage();
      await storage.write(key: 'auth_token', value: token);
    }
  }

  /// Remove o token do armazenamento apropriado
  Future<void> _deleteToken() async {
    if (kIsWeb) {
      await _initStorage();
      await _prefs!.remove('auth_token');
    } else {
      final storage = _storage ?? const FlutterSecureStorage();
      await storage.delete(key: 'auth_token');
    }
  }

  // ==========================================================================
  // MÉTODO DE LOGIN
  // ==========================================================================

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      // -----------------------------------------------------------------------
      // 1. VALIDAÇÃO DE ENTRADA
      // -----------------------------------------------------------------------

      if (email.isEmpty || password.isEmpty) {
        throw Exception('E-mail e senha são obrigatórios');
      }

      // Log de debug (remover em produção)
      print('🔵 [LOGIN] Enviando requisição para: $_baseUrl/login');

      // -----------------------------------------------------------------------
      // 2. REQUISIÇÃO HTTP
      // -----------------------------------------------------------------------

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Timeout: A requisição demorou muito'),
          );

      // Log de debug
      print('✅ [LOGIN] Status: ${response.statusCode}');
      print('📦 [LOGIN] Resposta: ${response.body}');

      // -----------------------------------------------------------------------
      // 3. TRATAMENTO DA RESPOSTA
      // -----------------------------------------------------------------------

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;

        // Salva o token com segurança no dispositivo
        await _saveToken(token);

        print('💾 [LOGIN] Token salvo com sucesso');

        // Retorna modelo do usuário autenticado
        return UserModel(
          id: data['user']?['id'] ?? '',
          name: data['user']?['name'] ?? '',
          email: data['user']?['email'] ?? '',
          crm: data['user']?['crm'],
          specialty: data['user']?['specialty'],
          token: token,
          tokenExpiry: DateTime.now().add(const Duration(days: 7)),
        );
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        // Credenciais inválidas
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'E-mail ou senha incorretos');
      } else if (response.statusCode == 429) {
        // Rate limiting
        throw Exception(
            'Muitas tentativas. Tente novamente em alguns minutos.');
      } else {
        // Outros erros do servidor
        throw Exception('Erro no servidor: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      // Erro de conexão (sem internet, servidor offline, etc.)
      print('❌ [LOGIN] Erro de conexão: $e');
      throw Exception('Sem conexão com a internet. Verifique sua conexão.');
    } catch (e) {
      // Propaga outros erros (validação, timeout, parsing, etc.)
      print('❌ [LOGIN] Erro: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // MÉTODO DE REGISTRO
  // ==========================================================================

  @override
  Future<UserModel> register(String name, String email, String password) async {
    try {
      // -----------------------------------------------------------------------
      // 1. VALIDAÇÃO DE ENTRADA
      // -----------------------------------------------------------------------

      if (name.isEmpty || email.isEmpty || password.isEmpty) {
        throw Exception('Todos os campos são obrigatórios');
      }

      if (password.length < 8) {
        throw Exception('A senha deve ter pelo menos 8 caracteres');
      }

      // Validação básica de formato de e-mail
      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!emailRegex.hasMatch(email)) {
        throw Exception('E-mail inválido');
      }

      // Log de debug
      print('🔵 [REGISTER] Enviando requisição para: $_baseUrl/register');

      // -----------------------------------------------------------------------
      // 2. REQUISIÇÃO HTTP
      // -----------------------------------------------------------------------

      final response = await _client
          .post(
            Uri.parse('$_baseUrl/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
            }),
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw Exception('Timeout: A requisição demorou muito'),
          );

      // Log de debug
      print('✅ [REGISTER] Status: ${response.statusCode}');
      print('📦 [REGISTER] Resposta: ${response.body}');

      // -----------------------------------------------------------------------
      // 3. TRATAMENTO DA RESPOSTA
      // -----------------------------------------------------------------------

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ⚠️ IMPORTANTE: O backend NÃO retorna token no registro,
        // apenas os dados do usuário criado. O usuário precisa fazer login após.
        return UserModel(
          id: data['id'] ?? '',
          name: data['name'] ?? '',
          email: data['email'] ?? '',
          crm: data['crm'],
          specialty: data['specialty'],
          // Não há token no registro
        );
      } else if (response.statusCode == 409 || response.statusCode == 400) {
        // E-mail duplicado ou validação falhou
        final data = jsonDecode(response.body);
        throw Exception(data['message'] ?? 'Este e-mail já está cadastrado');
      } else {
        // Outros erros do servidor
        throw Exception('Erro no servidor: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      // Erro de conexão
      print('❌ [REGISTER] Erro de conexão: $e');
      throw Exception('Sem conexão com a internet. Verifique sua conexão.');
    } catch (e) {
      // Propaga outros erros
      print('❌ [REGISTER] Erro: $e');
      rethrow;
    }
  }

  // ==========================================================================
  // MÉTODO DE LOGOUT
  // ==========================================================================

  /// Implementa o logout removendo o token JWT do armazenamento local.
  ///
  /// **Fluxo:**
  /// 1. Remove token do FlutterSecureStorage
  /// 2. Não requer comunicação com backend (stateless JWT)
  /// 3. Usuário precisará fazer login novamente para acessar recursos protegidos
  ///
  /// **Nota de segurança:**
  /// - Em sistemas stateful (com blacklist de tokens), seria necessário
  ///   notificar o backend para invalidar o token
  /// - Com JWT stateless, a invalidação ocorre apenas localmente
  @override
  Future<void> logout() async {
    try {
      await _deleteToken();
      print('✅ [LOGOUT] Token removido com sucesso');
    } catch (e) {
      print('❌ [LOGOUT] Erro ao remover token: $e');
      // Não lança exceção pois logout deve sempre funcionar
      // mesmo se houver erro ao deletar o token
    }
  }
}
