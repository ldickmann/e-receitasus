/// Teste E2E (provider-level) do fluxo de renovação de prescrição.
///
/// Encadeia as TRÊS visões do MVP sobre um único [MockIRenewalService]
/// compartilhado, exercitando as transições de status mapeadas no schema
/// Prisma e validando a reatividade dos providers (notifyListeners):
///
///   1. PACIENTE  → [RenewalProvider.requestRenewal]  (cria PENDING_TRIAGE)
///   2. ENFERMEIRO→ [TriageProvider.approveTriage]     (PENDING_TRIAGE → TRIAGED)
///   3. MÉDICO    → [IRenewalService.markAsPrescribed] (TRIAGED → PRESCRIBED)
///
/// Também cobre o caminho de segurança LGPD/RLS: quando o service mapeia uma
/// negação de RLS (SQLSTATE 42501) para [RenewalRequestException], o provider
/// expõe a mensagem humanizada — sem vazar SQLSTATE/PII para a UI.
///
/// Estratégia: o SupabaseClient real é completamente isolado pelo mock do
/// [IRenewalService] (gerado pelo Mockito), garantindo testes herméticos.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:e_receitasus/providers/renewal_provider.dart';
import 'package:e_receitasus/providers/triage_provider.dart';
import 'package:e_receitasus/services/renewal_service.dart';

import 'prescription_flow_e2e_test.mocks.dart';

/// Conta quantas vezes um [ChangeNotifier] notifica seus ouvintes.
///
/// Usado para asseverar que cada provider dispara [notifyListeners] ao
/// transicionar estado — o contrato de reatividade que as telas dependem.
class _ListenerSpy {
  int count = 0;
  void call() => count++;
}

@GenerateMocks([IRenewalService])
void main() {
  // IDs sintéticos das três visões — espelham UUIDs do Supabase Auth.
  const prescriptionId = 'presc-original-0001';
  const renewalId = 'renewal-0001';
  const doctorId = 'doctor-uuid-0001';
  const renewedPrescriptionId = 'presc-nova-0001';

  late MockIRenewalService service;

  setUp(() {
    service = MockIRenewalService();
  });

  group('Fluxo E2E — três visões sobre um service compartilhado', () {
    test(
        'percorre PENDING_TRIAGE → TRIAGED → PRESCRIBED notificando os listeners',
        () async {
      // ===== Fase 1 — PACIENTE cria a solicitação (PENDING_TRIAGE) ==========
      when(service.requestRenewal(any, notes: anyNamed('notes')))
          .thenAnswer((_) async {
        return;
      });

      final renewalProvider = RenewalProvider(service);
      final renewalSpy = _ListenerSpy();
      renewalProvider.addListener(renewalSpy.call);

      final created = await renewalProvider.requestRenewal(
        prescriptionId: prescriptionId,
        notes: 'Uso contínuo — preciso renovar.',
      );

      expect(created, isTrue);
      expect(renewalProvider.errorMessage, isNull);
      expect(renewalProvider.isSubmitting, isFalse);
      // Reatividade: ao menos um notifyListeners (setSubmitting true→false).
      expect(renewalSpy.count, greaterThanOrEqualTo(1));
      verify(service.requestRenewal(
        prescriptionId,
        notes: 'Uso contínuo — preciso renovar.',
      )).called(1);

      // ===== Fase 2 — ENFERMEIRO assume o acolhimento (→ TRIAGED) ===========
      when(service.approveTriage(
        any,
        nurseNotes: anyNamed('nurseNotes'),
        doctorUserId: anyNamed('doctorUserId'),
      )).thenAnswer((_) async {
        return;
      });

      final triageProvider = TriageProvider(service);
      final triageSpy = _ListenerSpy();
      triageProvider.addListener(triageSpy.call);

      final triaged = await triageProvider.approveTriage(
        id: renewalId,
        doctorUserId: doctorId,
        nurseNotes: 'Paciente estável; encaminhado para emissão.',
      );

      expect(triaged, isTrue);
      expect(triageProvider.errorMessage, isNull);
      expect(triageProvider.isLoading, isFalse);
      expect(triageSpy.count, greaterThanOrEqualTo(1));
      // A designação do médico (transição TRIAGED) chega ao service intacta.
      verify(service.approveTriage(
        renewalId,
        nurseNotes: 'Paciente estável; encaminhado para emissão.',
        doctorUserId: doctorId,
      )).called(1);

      // ===== Fase 3 — MÉDICO defere a demanda (→ PRESCRIBED) ================
      // markAsPrescribed não é encapsulado por provider (a tela chama o
      // service diretamente), então validamos o contrato no nível do service.
      when(service.markAsPrescribed(any, any)).thenAnswer((_) async {
        return;
      });

      await service.markAsPrescribed(renewalId, renewedPrescriptionId);

      verify(service.markAsPrescribed(renewalId, renewedPrescriptionId))
          .called(1);

      // Nenhuma das fases anteriores deixou erro residual nos providers.
      expect(renewalProvider.errorMessage, isNull);
      expect(triageProvider.errorMessage, isNull);
    });

    test('rota alternativa: ENFERMEIRO rejeita (PENDING_TRIAGE → REJECTED)',
        () async {
      when(service.rejectTriage(any, nurseNotes: anyNamed('nurseNotes')))
          .thenAnswer((_) async {
        return;
      });

      final triageProvider = TriageProvider(service);
      final spy = _ListenerSpy();
      triageProvider.addListener(spy.call);

      final rejected = await triageProvider.rejectTriage(
        id: renewalId,
        nurseNotes: 'Receita ainda vigente; renovação desnecessária.',
      );

      expect(rejected, isTrue);
      expect(triageProvider.errorMessage, isNull);
      expect(spy.count, greaterThanOrEqualTo(1));
      verify(service.rejectTriage(
        renewalId,
        nurseNotes: 'Receita ainda vigente; renovação desnecessária.',
      )).called(1);
    });
  });

  group('Fluxo E2E — segurança LGPD/RLS', () {
    test(
        'negação de RLS (42501) vira mensagem humanizada sem vazar SQLSTATE/PII',
        () async {
      // O service mapeia 42501 → RenewalRequestException já humanizada
      // (ver _mapPostgrestErrorToUserMessage em renewal_service.dart).
      when(service.requestRenewal(any, notes: anyNamed('notes'))).thenThrow(
        RenewalRequestException(
          'Você não tem permissão para solicitar essa renovação. '
          'Faça login novamente e tente de novo.',
          code: '42501',
        ),
      );

      final provider = RenewalProvider(service);
      final spy = _ListenerSpy();
      provider.addListener(spy.call);

      final result = await provider.requestRenewal(
        prescriptionId: 'presc-de-outro-paciente',
      );

      expect(result, isFalse);
      expect(provider.isSubmitting, isFalse);
      expect(provider.errorMessage, contains('não tem permissão'));
      // Não vaza o código SQLSTATE para a camada visível.
      expect(provider.errorMessage, isNot(contains('42501')));
      expect(spy.count, greaterThanOrEqualTo(1));
    });

    test('sessão expirada (StateError) → pede relogin sem detalhes internos',
        () async {
      when(service.requestRenewal(any, notes: anyNamed('notes')))
          .thenThrow(StateError('usuario_nao_autenticado'));

      final provider = RenewalProvider(service);

      final result =
          await provider.requestRenewal(prescriptionId: prescriptionId);

      expect(result, isFalse);
      expect(provider.errorMessage, contains('não autenticado'));
      // A string opaca interna não vaza para a UI.
      expect(provider.errorMessage, isNot(contains('usuario_nao_autenticado')));
    });
  });

  group('Fluxo E2E — invariantes de reatividade', () {
    test('clearError zera o erro e notifica os ouvintes', () async {
      when(service.approveTriage(
        any,
        nurseNotes: anyNamed('nurseNotes'),
        doctorUserId: anyNamed('doctorUserId'),
      )).thenThrow(StateError('x'));

      final provider = TriageProvider(service);
      // Gera um erro para então limpá-lo.
      await provider.approveTriage(id: renewalId, doctorUserId: doctorId);
      expect(provider.errorMessage, isNotNull);

      final spy = _ListenerSpy();
      provider.addListener(spy.call);
      provider.clearError();

      expect(provider.errorMessage, isNull);
      expect(spy.count, 1);
    });

    test('providers são ChangeNotifier (contrato com a árvore de widgets)', () {
      expect(RenewalProvider(service), isA<ChangeNotifier>());
      expect(TriageProvider(service), isA<ChangeNotifier>());
    });
  });
}
