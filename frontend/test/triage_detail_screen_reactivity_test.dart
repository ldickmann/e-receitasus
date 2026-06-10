/// Testes de widget — reatividade de [TriageDetailScreen] ao [TriageProvider].
///
/// Valida que o provider, ao transicionar estados (loading/sucesso/erro),
/// atualiza corretamente os componentes visuais da tela de triagem do
/// enfermeiro — o contrato de reatividade exigido pelo MVP.
///
/// O [IRenewalService] é mockado (Mockito), isolando o Supabase real. A tela
/// é aberta por navegação (push) para que o [Navigator.pop] de sucesso retorne
/// com segurança à rota anterior, sem desmontar a raiz da árvore.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:e_receitasus/models/prescription_type.dart';
import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/renewal_request_model.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/triage_provider.dart';
import 'package:e_receitasus/screens/triage_detail_screen.dart';
import 'package:e_receitasus/services/renewal_service.dart';

import 'triage_detail_screen_reactivity_test.mocks.dart';

@GenerateMocks([IRenewalService])
void main() {
  // Médico designável na triagem (sem CPF/CNS — projeção mínima, LGPD).
  final doctor = UserModel(
    id: 'doctor-uuid-0001',
    firstName: 'Carlos',
    lastName: 'Médico',
    email: 'carlos.medico@sus.gov.br',
    professionalType: ProfessionalType.medico,
    specialty: 'Clínica Geral',
  );

  /// Pedido de renovação em PENDING_TRIAGE a ser acolhido pelo enfermeiro.
  RenewalRequestModel buildRequest() {
    final now = DateTime(2026, 4, 15, 10, 30);
    return RenewalRequestModel(
      id: 'renewal-0001',
      prescriptionId: 'presc-original-0001',
      patientUserId: 'patient-uuid-0001',
      status: RenewalStatus.pendingTriage,
      patientNotes: 'Preciso renovar minha receita de uso contínuo.',
      createdAt: now,
      updatedAt: now,
      medicineName: 'Losartana 50mg',
      prescriptionType: PrescriptionType.branca,
    );
  }

  late MockIRenewalService service;
  late TriageProvider provider;

  setUp(() {
    service = MockIRenewalService();
    provider = TriageProvider(service);
  });

  /// Monta a árvore com o provider acima do [MaterialApp] e abre a tela via
  /// push, retornando após a navegação assentar.
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TriageProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TriageDetailScreen(request: buildRequest()),
                    ),
                  ),
                  child: const Text('abrir-triagem'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir-triagem'));
    await tester.pumpAndSettle();
  }

  group('TriageDetailScreen — carregamento de médicos', () {
    testWidgets('popula o dropdown com os médicos retornados pelo provider',
        (tester) async {
      when(service.fetchDoctors()).thenAnswer((_) async => [doctor]);

      await pumpScreen(tester);

      // FutureBuilder resolveu e o dropdown de seleção está visível.
      expect(find.text('Selecione o médico responsável'), findsOneWidget);
      verify(service.fetchDoctors()).called(1);
    });

    testWidgets('exibe mensagem quando não há médicos disponíveis',
        (tester) async {
      when(service.fetchDoctors()).thenAnswer((_) async => <UserModel>[]);

      await pumpScreen(tester);

      expect(find.text('Nenhum médico disponível no momento.'), findsOneWidget);
    });
  });

  group('TriageDetailScreen — regras de habilitação dos botões', () {
    testWidgets('Aprovar começa desabilitado e habilita ao escolher médico',
        (tester) async {
      when(service.fetchDoctors()).thenAnswer((_) async => [doctor]);

      await pumpScreen(tester);

      // Sem médico selecionado → botão Aprovar desabilitado.
      final approveBefore = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Aprovar'),
      );
      expect(approveBefore.onPressed, isNull);

      // Seleciona o médico no dropdown.
      final dropdown = find.byType(DropdownButtonFormField<UserModel>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      
      final item = find.text('Carlos Médico — Clínica Geral').last;
      await tester.tap(item);
      await tester.pumpAndSettle();

      // Agora o botão Aprovar fica habilitado.
      final approveAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Aprovar'),
      );
      expect(approveAfter.onPressed, isNotNull);
    });

    testWidgets('Rejeitar habilita somente após preencher as notas',
        (tester) async {
      when(service.fetchDoctors()).thenAnswer((_) async => [doctor]);

      await pumpScreen(tester);

      final rejectBefore = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Rejeitar'),
      );
      expect(rejectBefore.onPressed, isNull);

      await tester.enterText(
        find.byType(TextField),
        'Receita ainda vigente.',
      );
      await tester.pump();

      final rejectAfter = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Rejeitar'),
      );
      expect(rejectAfter.onPressed, isNotNull);
    });
  });

  group('TriageDetailScreen — aprovação (PENDING_TRIAGE → TRIAGED)', () {
    testWidgets('fluxo de sucesso chama approveTriage e exibe SnackBar',
        (tester) async {
      when(service.fetchDoctors()).thenAnswer((_) async => [doctor]);
      when(service.approveTriage(
        any,
        nurseNotes: anyNamed('nurseNotes'),
        doctorUserId: anyNamed('doctorUserId'),
      )).thenAnswer((_) async {});

      await pumpScreen(tester);

      // Seleciona médico e dispara aprovação.
      final dropdown = find.byType(DropdownButtonFormField<UserModel>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carlos Médico — Clínica Geral').last);
      await tester.pumpAndSettle();

      final approveBtn = find.widgetWithText(ElevatedButton, 'Aprovar');
      await tester.ensureVisible(approveBtn);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Diálogo de confirmação — confirma a ação (TextButton 'Aprovar').
      await tester.tap(find.widgetWithText(TextButton, 'Aprovar'));
      await tester.pumpAndSettle();

      // Transição encaminhada ao service com o médico designado.
      verify(service.approveTriage(
        'renewal-0001',
        nurseNotes: anyNamed('nurseNotes'),
        doctorUserId: doctor.id,
      )).called(1);
      // Feedback visual de sucesso.
      expect(
        find.text('Pedido aprovado e encaminhado ao médico.'),
        findsOneWidget,
      );
    });

    testWidgets('falha de RLS no provider exibe SnackBar de erro genérico',
        (tester) async {
      when(service.fetchDoctors()).thenAnswer((_) async => [doctor]);
      when(service.approveTriage(
        any,
        nurseNotes: anyNamed('nurseNotes'),
        doctorUserId: anyNamed('doctorUserId'),
      )).thenThrow(StateError('usuario_nao_autenticado'));

      await pumpScreen(tester);

      // Seleciona médico e dispara tentativa de aprovação.
      final dropdown = find.byType(DropdownButtonFormField<UserModel>);
      await tester.ensureVisible(dropdown);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carlos Médico — Clínica Geral').last);
      await tester.pumpAndSettle();

      final approveBtn = find.widgetWithText(ElevatedButton, 'Aprovar');
      await tester.ensureVisible(approveBtn);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Aprovar'));
      await tester.pumpAndSettle();

      // Provider expõe mensagem humanizada; a tela permanece (sem pop).
      expect(find.text('Usuário não autenticado. Faça login novamente.'),
          findsOneWidget);
    });
  });

  group('TriageDetailScreen — rejeição (PENDING_TRIAGE → REJECTED)', () {
    testWidgets('fluxo de sucesso chama rejectTriage com o motivo informado',
        (tester) async {
      when(service.fetchDoctors()).thenAnswer((_) async => [doctor]);
      when(service.rejectTriage(any, nurseNotes: anyNamed('nurseNotes')))
          .thenAnswer((_) async {});

      await pumpScreen(tester);

      await tester.enterText(
        find.byType(TextField),
        'Receita ainda vigente; renovação desnecessária.',
      );
      await tester.pump();

      final rejectBtn = find.widgetWithText(OutlinedButton, 'Rejeitar');
      await tester.ensureVisible(rejectBtn);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Rejeitar'));
      await tester.pumpAndSettle();

      verify(service.rejectTriage(
        'renewal-0001',
        nurseNotes: 'Receita ainda vigente; renovação desnecessária.',
      )).called(1);
      expect(find.text('Pedido rejeitado com sucesso.'), findsOneWidget);
    });
  });
}
