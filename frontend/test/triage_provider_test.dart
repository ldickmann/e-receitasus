/// Testes do TriageProvider — perfil enfermeiro.
///
/// Cobre as operacoes de triagem de pedidos de renovacao isolando o
/// SupabaseClient via mock de [IRenewalService] (gerado pelo Mockito).
///
/// Cobertura:
/// - streamPendingTriage delega corretamente
/// - approveTriage: validacao de doctorUserId vazio, sucesso, falhas
/// - rejectTriage: validacao de nurseNotes obrigatorio, sucesso, falhas
/// - fetchDoctors: sucesso e tratamento de erros
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/renewal_request_model.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/triage_provider.dart';
import 'package:e_receitasus/services/renewal_service.dart';

import 'triage_provider_test.mocks.dart';

@GenerateMocks([IRenewalService])
void main() {
  late MockIRenewalService mockService;
  late TriageProvider provider;

  setUp(() {
    mockService = MockIRenewalService();
    provider = TriageProvider(mockService);
  });

  group('TriageProvider — streamPendingTriage', () {
    test('deve delegar ao service', () {
      when(mockService.streamPendingTriage())
          .thenAnswer((_) => const Stream<List<RenewalRequestModel>>.empty());

      provider.streamPendingTriage();

      verify(mockService.streamPendingTriage()).called(1);
    });
  });

  group('TriageProvider — approveTriage validacoes', () {
    test('deve rejeitar quando doctorUserId for vazio sem chamar service',
        () async {
      // ACT — nao deve chegar ao service
      final result = await provider.approveTriage(
        id: 'r-1',
        doctorUserId: '   ',
      );

      // ASSERT
      expect(result, isFalse);
      expect(provider.errorMessage, contains('Selecione um médico'));
      verifyNever(mockService.approveTriage(any,
          nurseNotes: anyNamed('nurseNotes'),
          doctorUserId: anyNamed('doctorUserId')));
    });

    test('deve aprovar com sucesso e limpar erro', () async {
      // ARRANGE
      when(mockService.approveTriage(any,
              nurseNotes: anyNamed('nurseNotes'),
              doctorUserId: anyNamed('doctorUserId')))
          .thenAnswer((_) async {});

      // ACT
      final result = await provider.approveTriage(
        id: 'r-1',
        doctorUserId: 'doc-1',
        nurseNotes: 'ok',
      );

      // ASSERT
      expect(result, isTrue);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      verify(mockService.approveTriage('r-1',
              nurseNotes: 'ok', doctorUserId: 'doc-1'))
          .called(1);
    });

    test('deve mapear PostgrestException para mensagem generica', () async {
      // ARRANGE — RLS pode bloquear ou estado invalido
      when(mockService.approveTriage(any,
              nurseNotes: anyNamed('nurseNotes'),
              doctorUserId: anyNamed('doctorUserId')))
          .thenThrow(const PostgrestException(
        message: 'rls denied',
        code: '42501',
      ));

      // ACT
      final result = await provider.approveTriage(
        id: 'r-1',
        doctorUserId: 'doc-1',
      );

      // ASSERT — mensagem nao expoe detalhes (LGPD)
      expect(result, isFalse);
      expect(provider.errorMessage, contains('Não foi possível aprovar'));
    });
  });

  group('TriageProvider — rejectTriage validacoes', () {
    test('deve exigir nurseNotes nao vazio (auditoria LGPD)', () async {
      // ACT — motivo vazio bloqueia antes de chamar service
      final result = await provider.rejectTriage(id: 'r-1', nurseNotes: ' ');

      // ASSERT
      expect(result, isFalse);
      expect(provider.errorMessage, contains('motivo'));
      verifyNever(
          mockService.rejectTriage(any, nurseNotes: anyNamed('nurseNotes')));
    });

    test('deve rejeitar com sucesso quando motivo for fornecido', () async {
      // ARRANGE
      when(mockService.rejectTriage(any, nurseNotes: anyNamed('nurseNotes')))
          .thenAnswer((_) async {});

      // ACT
      final result = await provider.rejectTriage(
        id: 'r-1',
        nurseNotes: 'sem indicacao clinica',
      );

      // ASSERT
      expect(result, isTrue);
      expect(provider.errorMessage, isNull);
      verify(mockService.rejectTriage('r-1',
              nurseNotes: 'sem indicacao clinica'))
          .called(1);
    });
  });

  group('TriageProvider — fetchDoctors', () {
    test('deve retornar lista do service quando bem sucedido', () async {
      // ARRANGE — fixture minima de medico
      final doctors = [
        UserModel(
          id: 'doc-1',
          firstName: 'Carlos',
          lastName: 'Oliveira',
          email: 'carlos@sus.gov.br',
          professionalType: ProfessionalType.medico,
        ),
      ];
      when(mockService.fetchDoctors()).thenAnswer((_) async => doctors);

      // ACT
      final result = await provider.fetchDoctors();

      // ASSERT
      expect(result, hasLength(1));
      expect(result.first.id, 'doc-1');
      expect(provider.errorMessage, isNull);
    });

    test(
        'deve retornar lista vazia e popular errorMessage em PostgrestException',
        () async {
      // ARRANGE — banco indisponivel
      when(mockService.fetchDoctors())
          .thenThrow(const PostgrestException(message: 'down', code: '08006'));

      // ACT
      final result = await provider.fetchDoctors();

      // ASSERT — UI nao quebra; lista vazia + mensagem amigavel
      expect(result, isEmpty);
      expect(provider.errorMessage, contains('lista de médicos'));
    });
  });
}
