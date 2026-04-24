/// Testes de widget para a ação de navegação do botão "Rastrear Status do Pedido"
/// implementada em [_handleTrack] da HomeScreen.
///
/// Estratégia:
/// A HomeScreen depende de [PrescriptionService] instanciado internamente sem
/// injeção via Provider — o que exigiria inicializar o SDK do Supabase para
/// renderizar a tela completa. Para evitar esse overhead em testes de UI,
/// adota-se um widget de teste mínimo que reproduz exatamente o botão e o
/// comportamento de [_handleTrack], verificando que:
///   1. O botão "Rastrear Status do Pedido" é renderizado.
///   2. O tap dispara [Navigator.push] com [RenewalTrackingScreen].
///   3. O stream da [RenewalTrackingScreen] mostra estado de carregamento
///      ao receber uma stream vazia (sem dados do Supabase).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_receitasus/models/renewal_request_model.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/renewal_provider.dart';
import 'package:e_receitasus/screens/renewal_tracking_screen.dart';
import 'package:e_receitasus/services/renewal_service.dart';

// ---------------------------------------------------------------------------
// Fake de serviço — evita dependência do SupabaseClient nos testes de widget
// ---------------------------------------------------------------------------

/// Implementação fake de [IRenewalService] que retorna streams controladas.
///
/// Substitui o serviço real, isolando completamente o Provider do Supabase.
/// Implementa os métodos sem usar Mockito para simplificar setup no widget test.
class _FakeRenewalService extends Fake implements IRenewalService {
  /// Stream que o teste pode controlar — vazia por padrão (sem dados do Supabase).
  final Stream<List<RenewalRequestModel>> fakeStream;

  _FakeRenewalService({Stream<List<RenewalRequestModel>>? stream})
      : fakeStream = stream ?? const Stream.empty();

  @override
  Stream<List<RenewalRequestModel>> streamMyRenewals() => fakeStream;

  @override
  Future<void> requestRenewal(String prescriptionId, {String? notes}) async {}

  @override
  Stream<List<RenewalRequestModel>> streamPendingTriage() =>
      const Stream.empty();

  @override
  Future<void> approveTriage(
    String renewalId, {
    String? nurseNotes,
    required String doctorUserId,
  }) async {}

  @override
  Future<void> rejectTriage(String renewalId,
      {required String nurseNotes}) async {}

  @override
  Stream<List<RenewalRequestModel>> streamTriagedForDoctor() =>
      const Stream.empty();

  @override
  Future<void> markAsPrescribed(
    String id,
    String renewedPrescriptionId,
  ) async {}

  @override
  Future<List<UserModel>> fetchDoctors() async => [];
}

// ---------------------------------------------------------------------------
// Helper — monta widget de teste com o botão Rastrear isolado
// ---------------------------------------------------------------------------

/// Monta um [MaterialApp] mínimo com apenas o botão "Rastrear Status do Pedido"
/// e os Providers necessários para [RenewalTrackingScreen].
///
/// Substitui a renderização da HomeScreen completa para evitar dependência do
/// PrescriptionService sem injeção (que acessa Supabase.instance.client no
/// construtor). O comportamento de _handleTrack é reproduzido fielmente.
Widget _buildTestableButton({
  Stream<List<RenewalRequestModel>>? renewalStream,
}) {
  final renewalProvider =
      RenewalProvider(_FakeRenewalService(stream: renewalStream));

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<RenewalProvider>.value(value: renewalProvider),
    ],
    // MaterialApp necessário para Navigator funcionar no teste
    child: MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('E-ReceitaSUS - Área do Paciente')),
          body: Center(
            // Reproduz exatamente o OutlinedButton.icon da HomeScreen com
            // a mesma lógica de _handleTrack: Navigator.push + RenewalTrackingScreen
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RenewalTrackingScreen(),
                ),
              ),
              icon: const Icon(Icons.track_changes),
              label: const Text('Rastrear Status do Pedido'),
            ),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  group('HomeScreen — botão "Rastrear Status do Pedido"', () {
    testWidgets(
      'deve renderizar o botão com ícone e texto corretos',
      (WidgetTester tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestableButton());

        // ASSERT — botão encontrado com texto e ícone esperados
        expect(
          find.widgetWithText(OutlinedButton, 'Rastrear Status do Pedido'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.track_changes), findsOneWidget);
      },
    );

    testWidgets(
      'tap no botão deve navegar para RenewalTrackingScreen',
      (WidgetTester tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestableButton());

        // ASSERT — garante que ainda estamos na tela inicial
        expect(find.byType(RenewalTrackingScreen), findsNothing);

        // ACT — simula tap do paciente no botão Rastrear
        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Rastrear Status do Pedido'),
        );
        // Aguarda animação de transição de rota concluir
        await tester.pumpAndSettle();

        // ASSERT — RenewalTrackingScreen foi empilhada pelo Navigator
        expect(find.byType(RenewalTrackingScreen), findsOneWidget);
      },
    );

    testWidgets(
      'RenewalTrackingScreen deve exibir loading enquanto stream não emite',
      (WidgetTester tester) async {
        // ARRANGE — StreamController que nunca emite nem fecha → ConnectionState.waiting
        final controller = StreamController<List<RenewalRequestModel>>();
        addTearDown(controller.close);

        await tester.pumpWidget(
          _buildTestableButton(renewalStream: controller.stream),
        );

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Rastrear Status do Pedido'),
        );
        // Avança frames suficientes para a transição de rota construir a tela,
        // mas sem pumpAndSettle — o stream nunca fecha, então pumpAndSettle
        // poderia travar aguardando um estado estável que nunca chega.
        await tester.pump(); // inicia a transição do Navigator
        await tester
            .pump(const Duration(milliseconds: 300)); // conclui animação

        // ASSERT — enquanto o stream não emitiu, exibe CircularProgressIndicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets(
      'RenewalTrackingScreen deve exibir mensagem de vazio quando stream emite lista vazia',
      (WidgetTester tester) async {
        // ARRANGE — stream controlada que emite lista vazia imediatamente
        final emptyStream = Stream<List<RenewalRequestModel>>.value(const []);

        await tester
            .pumpWidget(_buildTestableButton(renewalStream: emptyStream));

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Rastrear Status do Pedido'),
        );
        // pumpAndSettle aguarda o StreamBuilder processar a emissão
        await tester.pumpAndSettle();

        // ASSERT — mensagem de estado vazio exibida ao paciente
        expect(
          find.text('Nenhum pedido de renovação encontrado.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'RenewalTrackingScreen deve exibir card quando stream emite pedido de renovação',
      (WidgetTester tester) async {
        // ARRANGE — um pedido de renovação para exibição no card
        final renewal = RenewalRequestModel(
          id: 'test-uuid-001',
          prescriptionId: 'presc-001',
          patientUserId: 'patient-001',
          status: RenewalStatus.pendingTriage,
          createdAt: DateTime(2026, 4, 15),
          updatedAt: DateTime(2026, 4, 15),
          // Medicamento exibido no cabeçalho do card
          medicineName: 'Metformina 850mg',
        );

        final stream = Stream<List<RenewalRequestModel>>.value([renewal]);

        await tester.pumpWidget(_buildTestableButton(renewalStream: stream));

        await tester.tap(
          find.widgetWithText(OutlinedButton, 'Rastrear Status do Pedido'),
        );
        await tester.pumpAndSettle();

        // ASSERT — nome do medicamento e título da tela presentes
        expect(find.text('Metformina 850mg'), findsOneWidget);
        expect(find.text('Rastrear Pedidos de Renovação'), findsOneWidget);
      },
    );
  });
}
