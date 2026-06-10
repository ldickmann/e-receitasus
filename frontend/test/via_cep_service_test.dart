/// Testes unitários do [ViaCepService] — consulta de endereço por CEP.
///
/// Diferente de `prescription_form_viacep_test.dart` (que é um *widget test*
/// usando um fake), aqui exercitamos a IMPLEMENTAÇÃO REAL do service injetando
/// um [MockClient] do pacote `http`. Isso valida o parsing do JSON, o
/// tratamento de UTF-8 e o mapeamento de falhas para [ViaCepServiceException]
/// sem abrir sockets reais.
///
/// Cobre os dois cenários síncronos exigidos:
///   1. Sucesso (HTTP 200 com JSON válido) → preenche logradouro/bairro/localidade.
///   2. Falha de rede/exceção → vira [ViaCepServiceException] amigável (sem
///      vazar stack trace), garantindo que a UI não quebre.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:e_receitasus/services/via_cep_service.dart';

void main() {
  // Payload representativo do ViaCEP para um CEP de Navegantes/SC (MVP).
  const validBody = {
    'cep': '88370-000',
    'logradouro': 'Rua Tijucas',
    'complemento': '',
    'bairro': 'Centro',
    'localidade': 'Navegantes',
    'uf': 'sc',
  };

  group('ViaCepService — sucesso (HTTP 200)', () {
    test('preenche logradouro, bairro e localidade a partir do JSON', () async {
      final client = MockClient((request) async {
        // Confere que o service normaliza o CEP e monta a URL correta.
        expect(request.url.host, 'viacep.com.br');
        expect(request.url.path, '/ws/88370000/json/');
        return http.Response(jsonEncode(validBody), 200);
      });

      final service = ViaCepService(client: client);
      final address = await service.fetch('88370-000');

      expect(address.logradouro, 'Rua Tijucas');
      expect(address.bairro, 'Centro');
      expect(address.localidade, 'Navegantes');
      // UF é normalizada para maiúsculas (casa com os dropdowns de UF).
      expect(address.uf, 'SC');
    });

    test('aceita CEP sem máscara e decodifica acentos via UTF-8', () async {
      final acented = {
        'cep': '01310-100',
        'logradouro': 'Avenida Paulista',
        'bairro': 'Bela Vista',
        'localidade': 'São Paulo',
        'uf': 'SP',
      };
      // Codifica explicitamente em UTF-8 (bytes) para validar utf8.decode.
      final client = MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(jsonEncode(acented)),
          200,
        ),
      );

      final service = ViaCepService(client: client);
      final address = await service.fetch('01310100');

      expect(address.localidade, 'São Paulo');
      expect(address.uf, 'SP');
    });
  });

  group('ViaCepService — validação de entrada', () {
    test('rejeita CEP com número de dígitos inválido sem chamar a rede',
        () async {
      var requested = false;
      final client = MockClient((_) async {
        requested = true;
        return http.Response('{}', 200);
      });

      final service = ViaCepService(client: client);

      await expectLater(
        service.fetch('123'),
        throwsA(isA<ViaCepServiceException>()),
      );
      // CEP inválido falha na borda — nenhuma requisição é disparada.
      expect(requested, isFalse);
    });
  });

  group('ViaCepService — falhas de rede/serviço (UI não pode quebrar)', () {
    test('CEP inexistente ({"erro": true}) vira exceção amigável', () async {
      final client = MockClient(
        (_) async => http.Response(jsonEncode({'erro': true}), 200),
      );

      final service = ViaCepService(client: client);

      await expectLater(
        service.fetch('00000000'),
        throwsA(
          isA<ViaCepServiceException>().having(
            (e) => e.message,
            'message',
            contains('não encontrado'),
          ),
        ),
      );
    });

    test('status HTTP != 200 vira ViaCepServiceException com statusCode',
        () async {
      final client = MockClient((_) async => http.Response('erro', 500));

      final service = ViaCepService(client: client);

      await expectLater(
        service.fetch('88370000'),
        throwsA(
          isA<ViaCepServiceException>()
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('exceção de rede é encapsulada (sem vazar stack trace)', () async {
      final client = MockClient((_) async {
        // Simula falha de socket/DNS lançada pelo cliente HTTP.
        throw const _FakeSocketException();
      });

      final service = ViaCepService(client: client);

      await expectLater(
        service.fetch('88370000'),
        throwsA(
          isA<ViaCepServiceException>().having(
            (e) => e.message,
            'message',
            contains('Não foi possível consultar o CEP'),
          ),
        ),
      );
    });

    test('JSON malformado também resulta em mensagem amigável', () async {
      final client = MockClient(
        (_) async => http.Response('isto não é json', 200),
      );

      final service = ViaCepService(client: client);

      await expectLater(
        service.fetch('88370000'),
        throwsA(isA<ViaCepServiceException>()),
      );
    });
  });
}

/// Exceção sintética para simular falha de rede de baixo nível.
///
/// Implementa [Exception] para que o `catch (_)` genérico do service a
/// converta na mensagem amigável padrão, sem depender de `dart:io`
/// (indisponível no alvo de teste Flutter Web).
class _FakeSocketException implements Exception {
  const _FakeSocketException();

  @override
  String toString() => 'SocketException: connection failed';
}
