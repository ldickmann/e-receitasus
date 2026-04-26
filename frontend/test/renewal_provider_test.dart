/// Testes do RenewalProvider — perfil paciente.
///
/// Cobre as operacoes de renovacao de prescricao isolando completamente o
/// SupabaseClient via mock de [IRenewalService] (gerado pelo Mockito).
///
/// Estrategia:
/// - Provider e construido com [MockIRenewalService] no setUp.
/// - Cada teste valida uma branch do fluxo: sucesso, RenewalRequestException
///   (erro tipado mapeado pelo service), StateError (sessao expirada) e
///   excecao inesperada.
/// - Testes de stream apenas verificam delegacao ao service (sem subscribe).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:e_receitasus/models/renewal_request_model.dart';
import 'package:e_receitasus/providers/renewal_provider.dart';
import 'package:e_receitasus/services/renewal_service.dart';

import 'renewal_provider_test.mocks.dart';

/// Gera MockIRenewalService — isola provider do Supabase real.
@GenerateMocks([IRenewalService])
void main() {
  late MockIRenewalService mockService;
  late RenewalProvider provider;

  setUp(() {
    mockService = MockIRenewalService();
    provider = RenewalProvider(mockService);
  });

  group('RenewalProvider — streamMyRenewals', () {
    test('deve delegar ao service sem alterar estado interno', () {
      // ARRANGE — service retorna stream vazia controlada
      when(mockService.streamMyRenewals())
          .thenAnswer((_) => const Stream<List<RenewalRequestModel>>.empty());

      // ACT
      final stream = provider.streamMyRenewals();

      // ASSERT — apenas delega; nao toca em isSubmitting/errorMessage
      expect(stream, isA<Stream<List<RenewalRequestModel>>>());
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, isNull);
      verify(mockService.streamMyRenewals()).called(1);
    });
  });

  group('RenewalProvider — requestRenewal sucesso', () {
    test('deve retornar true e limpar errorMessage', () async {
      // ARRANGE — service responde sem lancar
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenAnswer((_) async {});

      // ACT
      final result = await provider.requestRenewal(
        prescriptionId: 'presc-123',
        notes: 'urgente',
      );

      // ASSERT
      expect(result, isTrue);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, isNull);
      verify(mockService.requestRenewal('presc-123', notes: 'urgente'))
          .called(1);
    });
  });

  group('RenewalProvider — requestRenewal falhas', () {
    test('deve repassar mensagem de RenewalRequestException 23505 (duplicado)',
        () async {
      // ARRANGE — service ja mapeia o codigo para mensagem humanizada
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(RenewalRequestException(
        'Você já possui um pedido de renovação ativo para esta prescrição.',
        code: '23505',
      ));

      // ACT
      final result = await provider.requestRenewal(prescriptionId: 'p-1');

      // ASSERT
      expect(result, isFalse);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, contains('já possui um pedido'));
    });

    test('deve repassar mensagem de RenewalRequestException 42501 (RLS negou)',
        () async {
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(RenewalRequestException(
        'Você não tem permissão para solicitar essa renovação. '
        'Faça login novamente e tente de novo.',
        code: '42501',
      ));

      final result = await provider.requestRenewal(prescriptionId: 'p-rls');

      expect(result, isFalse);
      expect(provider.errorMessage, contains('não tem permissão'));
    });

    test(
        'deve repassar mensagem de RenewalRequestException 23503 (FK quebrada)',
        () async {
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(RenewalRequestException(
        'Receita não encontrada. Atualize a tela e tente novamente.',
        code: '23503',
      ));

      final result = await provider.requestRenewal(prescriptionId: 'p-fk');

      expect(result, isFalse);
      expect(provider.errorMessage, contains('Receita não encontrada'));
    });

    test(
        'deve repassar mensagem de RenewalRequestException 23502 (NOT NULL — bug AB#228)',
        () async {
      // Caso historico do bug AB#228: ate 26/04/2026 a tabela RenewalRequest
      // tinha id/updatedAt sem default, todo INSERT do paciente quebrava.
      // Hoje resolvido pela migration renewal_request_defaults, mas mantemos
      // o teste como guardrail.
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(RenewalRequestException(
        'Não foi possível enviar o pedido de renovação. '
        'Avise o suporte se o problema persistir.',
        code: '23502',
      ));

      final result = await provider.requestRenewal(prescriptionId: 'p-null');

      expect(result, isFalse);
      expect(provider.errorMessage, contains('suporte'));
    });

    test(
        'deve repassar mensagem de RenewalRequestException 42P01 (tabela inexistente)',
        () async {
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(RenewalRequestException(
        'Erro de configuração do sistema. Avise o suporte.',
        code: '42P01',
      ));

      final result = await provider.requestRenewal(prescriptionId: 'p-cfg');

      expect(result, isFalse);
      expect(provider.errorMessage, contains('configuração'));
    });

    test('deve mapear StateError para mensagem de relogin', () async {
      // ARRANGE — usuario perdeu sessao no meio da operacao (lancado pelo
      // _currentUserId no service antes do INSERT).
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(StateError('usuario_nao_autenticado'));

      // ACT
      final result = await provider.requestRenewal(prescriptionId: 'p-3');

      // ASSERT
      expect(result, isFalse);
      expect(provider.errorMessage, contains('não autenticado'));
    });

    test('deve mapear excecao inesperada para mensagem generica de conexao',
        () async {
      // ARRANGE — qualquer Exception nao prevista
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(Exception('boom'));

      // ACT
      final result = await provider.requestRenewal(prescriptionId: 'p-4');

      // ASSERT
      expect(result, isFalse);
      expect(provider.errorMessage, contains('inesperado'));
    });
  });

  group('RenewalProvider — clearError', () {
    test('deve zerar errorMessage e notificar listeners apenas se havia erro',
        () async {
      // ARRANGE — gera erro previo
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(Exception('x'));
      await provider.requestRenewal(prescriptionId: 'p-x');
      expect(provider.errorMessage, isNotNull);

      // Conta notificacoes para garantir que clearError dispara notifyListeners
      var notifications = 0;
      provider.addListener(() => notifications++);

      // ACT
      provider.clearError();

      // ASSERT
      expect(provider.errorMessage, isNull);
      expect(notifications, 1);
    });
  });
}
