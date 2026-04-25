import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:e_receitasus/models/patient_search_result.dart';
import 'package:e_receitasus/services/prescription_service.dart';

/// Subclasse de teste que sobrescreve o seam `invokeSearchPatientsRpc`.
///
/// Evita mockar a cadeia `SupabaseClient.rpc → PostgrestFilterBuilder → Future`
/// (API fluente do supabase_flutter difícil de simular com Mockito puro) e
/// permite injetar payloads controlados ou simular falhas determinísticas.
class _FakePrescriptionService extends PrescriptionService {
  /// Payload bruto que a RPC retornaria (List<dynamic>) ou outro tipo para
  /// testar o caminho defensivo de "tipo inesperado".
  final Object? rpcResponse;

  /// Erro que será lançado em vez de retornar `rpcResponse`.
  /// Quando definido, prevalece sobre `rpcResponse`.
  final Object? rpcError;

  /// Conta quantas vezes a RPC foi efetivamente chamada — usado para garantir
  /// que queries muito curtas NÃO acionem o backend (princípio de minimização
  /// de requisições + LGPD: não consultar dados de pacientes sem necessidade).
  int rpcCallCount = 0;

  _FakePrescriptionService({this.rpcResponse, this.rpcError})
      // Passa um `SupabaseClient` "qualquer" não-nulo só para evitar inicializar
      // o singleton — todo o caminho usado nos testes é interceptado pelo override.
      : super(supabaseClient: _NoopSupabaseClient());

  @override
  Future<dynamic> invokeSearchPatientsRpc(String nameQuery) async {
    rpcCallCount++;
    if (rpcError != null) {
      throw rpcError!;
    }
    return rpcResponse;
  }
}

/// `SupabaseClient` mínimo apenas para satisfazer o construtor — nenhum método
/// é invocado nos testes (todo acesso é interceptado pelo override do seam).
class _NoopSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PrescriptionService.searchPatients', () {
    test('retorna lista vazia sem chamar a RPC quando query tem < 2 caracteres',
        () async {
      // Arrange: serviço configurado para falhar caso a RPC fosse chamada
      // (garante que o curto-circuito acontece ANTES de qualquer I/O).
      final service = _FakePrescriptionService(
        rpcError: StateError('RPC nunca deveria ter sido chamada'),
      );

      // Act
      final resultEmpty = await service.searchPatients('');
      final resultOneChar = await service.searchPatients('a');
      final resultOnlySpaces = await service.searchPatients('   ');

      // Assert: sem requisições e listas vazias.
      expect(resultEmpty, isEmpty);
      expect(resultOneChar, isEmpty);
      expect(resultOnlySpaces, isEmpty);
      expect(service.rpcCallCount, 0);
    });

    test('mapeia corretamente o payload da RPC para PatientSearchResult',
        () async {
      // Arrange: payload reproduz o contrato da RPC `search_patients_for_prescription`
      // (snake_case nos campos `full_name`, `age_text`).
      final fakePayload = <Map<String, dynamic>>[
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'full_name': 'João da Silva',
          'cpf': '123.456.789-00',
          'address': 'Rua A, 100',
          'city': 'Itajaí',
          'age_text': '34 anos',
        },
        {
          'id': '22222222-2222-2222-2222-222222222222',
          'full_name': 'Maria Souza',
          'cpf': null,
          'address': null,
          'city': null,
          'age_text': null,
        },
      ];
      final service = _FakePrescriptionService(rpcResponse: fakePayload);

      // Act
      final results = await service.searchPatients('Jo');

      // Assert: ordem preservada + mapeamento snake → camelCase.
      expect(service.rpcCallCount, 1);
      expect(results, hasLength(2));
      expect(results[0], isA<PatientSearchResult>());
      expect(results[0].id, '11111111-1111-1111-1111-111111111111');
      expect(results[0].fullName, 'João da Silva'); // full_name → fullName
      expect(results[0].cpf, '123.456.789-00');
      expect(results[0].city, 'Itajaí');
      expect(results[0].ageText, '34 anos');
      // Segundo registro com campos opcionais nulos deve ser tolerado.
      expect(results[1].fullName, 'Maria Souza');
      expect(results[1].cpf, isNull);
      expect(results[1].address, isNull);
    });

    test('retorna lista vazia quando a RPC devolve lista vazia', () async {
      final service = _FakePrescriptionService(rpcResponse: <dynamic>[]);

      final results = await service.searchPatients('Zzz');

      expect(results, isEmpty);
      expect(service.rpcCallCount, 1);
    });

    test(
        'lança PatientSearchException com mensagem genérica em PostgrestException',
        () async {
      // Arrange: simula falha de RLS / GRANT ausente (code 42501) — diferente
      // do P0001 (acesso negado por falta de UBS), que tem mensagem própria.
      final service = _FakePrescriptionService(
        rpcError: const PostgrestException(
          message:
              'permission denied for function search_patients_for_prescription',
          code: '42501',
        ),
      );

      // Act + Assert: a UI recebe mensagem segura, sem detalhes do Postgrest.
      await expectLater(
        service.searchPatients('Jo'),
        throwsA(
          isA<PatientSearchException>().having(
            (e) => e.message,
            'message',
            'Você não tem permissão para buscar pacientes. '
                'Contate o administrador.',
          ),
        ),
      );
    });

    test(
        'mapeia P0001 (RAISE EXCEPTION da RPC) para mensagem orientando vínculo com UBS',
        () async {
      // Arrange: a RPC `search_patients_for_prescription` faz
      // `RAISE EXCEPTION 'Acesso negado: ...'` quando o profissional autenticado
      // não tem `healthUnitId` — esse RAISE retorna code SQLSTATE = P0001.
      // Esse é exatamente o cenário do BUG do PBI #197.
      final service = _FakePrescriptionService(
        rpcError: const PostgrestException(
          message:
              'Acesso negado: apenas profissionais vinculados a uma UBS podem buscar pacientes.',
          code: 'P0001',
        ),
      );

      // Act + Assert: mensagem amigável aponta a causa-raiz acionável pelo médico
      // (verificar vínculo com UBS), sem repassar a frase técnica do plpgsql.
      await expectLater(
        service.searchPatients('Jo'),
        throwsA(
          isA<PatientSearchException>().having(
            (e) => e.message,
            'message',
            'Não foi possível buscar pacientes. Verifique se você está '
                'vinculado a uma UBS no seu cadastro.',
          ),
        ),
      );
    });

    test(
        'lança PatientSearchException com mensagem de conexão em erros genéricos',
        () async {
      // Arrange: erro de rede / desconhecido.
      final service = _FakePrescriptionService(
        rpcError: Exception('SocketException: timeout'),
      );

      await expectLater(
        service.searchPatients('Jo'),
        throwsA(
          isA<PatientSearchException>().having(
            (e) => e.message,
            'message',
            'Erro ao consultar pacientes. Verifique sua conexão e tente novamente.',
          ),
        ),
      );
    });

    test(
        'lança PatientSearchException quando a RPC devolve tipo inesperado (não-List)',
        () async {
      // Arrange: defesa contra mudança de contrato na RPC.
      final service = _FakePrescriptionService(
        rpcResponse: <String, dynamic>{'unexpected': 'object'},
      );

      await expectLater(
        service.searchPatients('Jo'),
        throwsA(
          isA<PatientSearchException>().having(
            (e) => e.message,
            'message',
            'Resposta inesperada do servidor ao buscar pacientes.',
          ),
        ),
      );
    });

    test(
        'lança PatientSearchException quando o payload tem schema inválido (campo obrigatório ausente)',
        () async {
      // Arrange: faltando `full_name` (obrigatório no `PatientSearchResult.fromJson`).
      final service = _FakePrescriptionService(
        rpcResponse: <Map<String, dynamic>>[
          {'id': 'abc'}, // sem full_name
        ],
      );

      await expectLater(
        service.searchPatients('Jo'),
        throwsA(
          isA<PatientSearchException>().having(
            (e) => e.message,
            'message',
            'Resultado da busca em formato inválido.',
          ),
        ),
      );
    });
  });
}
