/// Testes do RenewalProvider — perfil paciente.
///
/// Cobre as operacoes de renovacao de prescricao isolando completamente o
/// SupabaseClient via mock de [IRenewalService] (gerado pelo Mockito).
///
/// Estrategia:
/// - Provider e construido com [MockIRenewalService] no setUp.
/// - Cada teste valida uma branch do fluxo: sucesso, PostgrestException com
///   codigo de unique violation, PostgrestException generica, StateError
///   (sessao expirada) e excecao inesperada.
/// - Testes de stream apenas verificam delegacao ao service (sem subscribe).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    test(
        'deve mapear PostgrestException codigo 23505 para mensagem de duplicacao',
        () async {
      // ARRANGE — simula violacao de unique constraint (pedido ja existe)
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(const PostgrestException(
        message: 'duplicate key',
        code: '23505',
      ));

      // ACT
      final result = await provider.requestRenewal(prescriptionId: 'p-1');

      // ASSERT
      expect(result, isFalse);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, contains('já possui um pedido'));
    });

    test('deve mapear PostgrestException generica para mensagem nao especifica',
        () async {
      // ARRANGE — codigo nao mapeado (qualquer outro Postgres error)
      when(mockService.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(const PostgrestException(
        message: 'connection lost',
        code: '08000',
      ));

      // ACT
      final result = await provider.requestRenewal(prescriptionId: 'p-2');

      // ASSERT — mensagem generica protege detalhes do banco (LGPD)
      expect(result, isFalse);
      expect(provider.errorMessage, contains('Não foi possível enviar'));
    });

    test('deve mapear StateError para mensagem de relogin', () async {
      // ARRANGE — usuario perdeu sessao no meio da operacao
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
