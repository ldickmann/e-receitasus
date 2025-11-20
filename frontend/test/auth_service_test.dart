import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:e_receitasus/services/auth_service.dart';

// O arquivo de mocks que será gerado pelo comando build_runner
import 'auth_service_test.mocks.dart';

// Anotação procurada pelo build_runner para gerar os mocks
@GenerateMocks([http.Client, FlutterSecureStorage])
void main() {
  late MockClient mockClient;
  late MockFlutterSecureStorage mockStorage;
  late AuthService authService;

  setUp(() {
    mockClient = MockClient();
    mockStorage = MockFlutterSecureStorage();

    // Injeção de dependência dos mocks no serviço
    authService = AuthService(client: mockClient, storage: mockStorage);
  });

  group('AuthService Tests', () {
    // TESTE 1: Login com Sucesso
    test(
        'Deve retornar token e salvar no storage quando a API responder 200 OK',
        () async {
      // 1. Arrange (Preparação)
      // Simula resposta 200 OK com um token JSON
      when(mockClient.post(
        any,
        headers: anyNamed('headers'),
        body: anyNamed('body'),
      )).thenAnswer((_) async =>
          http.Response('{"token": "token_jwt_simulado_123"}', 200));

      // Simula que a gravação no storage funciona
      when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
          .thenAnswer((_) async => {});

      // 2. Act (Ação)
      // Chama o método real usando os mocks
      final result = await authService.login('teste@sus.gov.br', 'senha123');

      // 3. Assert (Verificação)
      // Verifica se o token foi salvo com a chave correta 'auth_token'
      verify(mockStorage.write(
              key: 'auth_token', value: 'token_jwt_simulado_123'))
          .called(1);

      // Verifica se o resultado (token) retornou corretamente
      expect(result, 'token_jwt_simulado_123');
    });

    // TESTE 2: Login Falhou (Senha incorreta)
    test('Deve lançar exceção quando a API responder 401 Unauthorized',
        () async {
      // 1. Arrange
      when(mockClient.post(any, headers: any, body: any)).thenAnswer(
          (_) async => http.Response('{"error": "Unauthorized"}', 401));

      // 2. Act & Assert
      // Espera que a chamada de login falhe com erro
      expect(
        () => authService.login('email@errado.com', 'senha_errada'),
        throwsException,
      );

      // Garante que NADA foi salvo no storage
      verifyNever(
          mockStorage.write(key: anyNamed('key'), value: anyNamed('value')));
    });

    // TESTE 3: Logout
    test('Deve limpar o token do storage ao fazer logout', () async {
      // 1. Arrange
      when(mockStorage.delete(key: anyNamed('key')))
          .thenAnswer((_) async => {});

      // 2. Act
      await authService.logout();

      // 3. Assert
      verify(mockStorage.delete(key: 'auth_token')).called(1);
    });
  });
}
