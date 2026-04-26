import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:e_receitasus/models/health_unit_model.dart';
import 'package:e_receitasus/services/health_unit_service.dart';

// =============================================================================
// Testes do HealthUnitService — TASK #214 / PBI #198
//
// Estratégia: usamos `MockClient` de `package:http/testing.dart` (in-memory) e
// injetamos um `tokenProvider` síncrono. Isso evita acoplamento ao SDK do
// Supabase em testes unitários — exatamente por isso `HealthUnitService` foi
// desenhado com construtor parametrizado (regra TDD do projeto).
// =============================================================================

const String _testBaseUrl = 'http://test.local';

/// Helper que monta um `HealthUnitService` apontando para um cliente HTTP
/// determinístico, retornando o token informado.
HealthUnitService buildService(
  http.Client client, {
  String? token = 'jwt-fake',
}) {
  return HealthUnitService(
    client: client,
    tokenProvider: () async => token,
    baseUrl: _testBaseUrl,
  );
}

void main() {
  group('HealthUnitService.listByCity — sucesso', () {
    test('parseia lista de UBS de resposta 200 e envia headers corretos',
        () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((http.Request req) async {
        capturedRequest = req;
        return http.Response(
          jsonEncode([
            {
              'id': 'u1',
              'name': 'UBS Central',
              'district': 'Centro',
              'city': 'Navegantes',
              'state': 'SC',
            },
            {
              'id': 'u2',
              'name': 'UBS Bairro',
              'district': 'Aurora',
              'city': 'Navegantes',
              'state': 'SC',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = buildService(mockClient);
      final result = await service.listByCity('  Navegantes  ', state: 'sc');

      expect(result, hasLength(2));
      expect(result.first, isA<HealthUnitModel>());
      expect(result.first.name, 'UBS Central');
      expect(result.first.district, 'Centro');

      // Trim + uppercase aplicados antes de virar query param.
      expect(capturedRequest.url.queryParameters['city'], 'Navegantes');
      expect(capturedRequest.url.queryParameters['state'], 'SC');
      expect(capturedRequest.url.path, '/health-units');

      // Header de autenticação obrigatório.
      expect(capturedRequest.headers['Authorization'], 'Bearer jwt-fake');
      expect(capturedRequest.headers['Accept'], 'application/json');
    });

    test('retorna lista vazia quando backend responde []', () async {
      final mockClient = MockClient((_) async => http.Response('[]', 200));
      final service = buildService(mockClient);

      final result = await service.listByCity('Navegantes');

      expect(result, isEmpty);
    });

    test('omite query param `state` quando não informado', () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((http.Request req) async {
        capturedRequest = req;
        return http.Response('[]', 200);
      });
      final service = buildService(mockClient);

      await service.listByCity('Navegantes');

      expect(capturedRequest.url.queryParameters.containsKey('state'), isFalse);
    });
  });

  group('HealthUnitService.listByCity — falhas', () {
    test('lança HealthUnitServiceException quando city é vazio (após trim)',
        () async {
      final service = buildService(MockClient((_) async {
        fail('Não deveria fazer requisição quando city é vazio');
      }));

      expect(
        () => service.listByCity('   '),
        throwsA(isA<HealthUnitServiceException>()),
      );
    });

    test('lança 401 amigável quando token é null', () async {
      final mockClient = MockClient((_) async {
        fail('Não deveria chamar HTTP sem token');
      });
      final service = buildService(mockClient, token: null);

      try {
        await service.listByCity('Navegantes');
        fail('Esperava HealthUnitServiceException');
      } on HealthUnitServiceException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, contains('Sessão expirada'));
      }
    });

    test('mapeia 401 do backend para mensagem de sessão expirada', () async {
      final mockClient =
          MockClient((_) async => http.Response('Unauthorized', 401));
      final service = buildService(mockClient);

      try {
        await service.listByCity('Navegantes');
        fail('Esperava HealthUnitServiceException');
      } on HealthUnitServiceException catch (e) {
        expect(e.statusCode, 401);
        expect(e.message, contains('Sessão expirada'));
      }
    });

    test('mapeia 400 para mensagem de parâmetros inválidos', () async {
      final mockClient = MockClient((_) async => http.Response('{}', 400));
      final service = buildService(mockClient);

      try {
        await service.listByCity('Navegantes');
        fail('Esperava HealthUnitServiceException');
      } on HealthUnitServiceException catch (e) {
        expect(e.statusCode, 400);
        expect(e.message, contains('Parâmetros inválidos'));
      }
    });

    test('mapeia 5xx para mensagem de serviço indisponível', () async {
      final mockClient = MockClient((_) async => http.Response('boom', 503));
      final service = buildService(mockClient);

      try {
        await service.listByCity('Navegantes');
        fail('Esperava HealthUnitServiceException');
      } on HealthUnitServiceException catch (e) {
        expect(e.statusCode, 503);
        expect(e.message, contains('Serviço indisponível'));
      }
    });

    test('lança erro humanizado quando body 200 não é JSON válido', () async {
      final mockClient =
          MockClient((_) async => http.Response('not-json', 200));
      final service = buildService(mockClient);

      try {
        await service.listByCity('Navegantes');
        fail('Esperava HealthUnitServiceException');
      } on HealthUnitServiceException catch (e) {
        expect(e.message, contains('Resposta inválida'));
      }
    });

    test('NUNCA propaga corpo cru do servidor (LGPD)', () async {
      const sensitiveBody = 'stack trace interna: /var/app/secret.ts:42';
      final mockClient =
          MockClient((_) async => http.Response(sensitiveBody, 500));
      final service = buildService(mockClient);

      try {
        await service.listByCity('Navegantes');
        fail('Esperava HealthUnitServiceException');
      } on HealthUnitServiceException catch (e) {
        expect(e.message, isNot(contains('stack trace')));
        expect(e.message, isNot(contains('secret.ts')));
      }
    });
  });
}
