/// Testes de widget — reatividade de [RequestRenewalScreen] ao [RenewalProvider].
///
/// Valida que o provider, ao transicionar entre estados (submitting/sucesso/
/// erro), atualiza corretamente os componentes visuais da tela do paciente —
/// botão de envio, SnackBars de sucesso/erro e fluxo de seleção.
///
/// O [IRenewalService] é mockado (Mockito) e o [PrescriptionService] é
/// substituído por um stub que injeta um stream determinístico de prescrições
/// ativas — assim a tela renderiza a lista sem qualquer chamada ao Supabase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:e_receitasus/providers/renewal_provider.dart';
import 'package:e_receitasus/screens/request_renewal_screen.dart';
import 'package:e_receitasus/services/prescription_service.dart';
import 'package:e_receitasus/services/renewal_service.dart';

import 'request_renewal_screen_reactivity_test.mocks.dart';

@GenerateMocks([IRenewalService])
void main() {
  /// Uma prescrição ATIVA (status 'ativa' + validade futura) — única elegível
  /// para renovação segundo a regra `PrescriptionModel.isActive`.
  Map<String, dynamic> activePrescription() => {
        'id': 'presc-original-0001',
        'type': 'BRANCA',
        'medicine_name': 'Losartana 50mg',
        'doctor_name': 'Ana Paula Ferreira',
        'status': 'ativa',
        'valid_until':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };

  late MockIRenewalService service;
  late RenewalProvider provider;

  setUp(() {
    service = MockIRenewalService();
    provider = RenewalProvider(service);
  });

  /// Monta a tela com o provider acima do [MaterialApp], abrindo-a por push
  /// para que o [Navigator.pop] de sucesso retorne com segurança.
  Future<void> pumpScreen(
    WidgetTester tester, {
    required List<Map<String, dynamic>> rows,
  }) async {
    final stub = _StubPrescriptionService(rows);
    await tester.pumpWidget(
      ChangeNotifierProvider<RenewalProvider>.value(
        value: provider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          RequestRenewalScreen(prescriptionService: stub),
                    ),
                  ),
                  child: const Text('abrir-renovacao'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir-renovacao'));
    await tester.pumpAndSettle();
  }

  group('RequestRenewalScreen — render da lista de prescrições', () {
    testWidgets('exibe a prescrição ativa e o botão de envio desabilitado',
        (tester) async {
      await pumpScreen(tester, rows: [activePrescription()]);

      expect(find.text('Losartana 50mg'), findsOneWidget);

      // Sem seleção, o botão de envio inicia desabilitado.
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar Pedido de Renovação'),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('mostra estado vazio quando não há prescrições ativas',
        (tester) async {
      await pumpScreen(tester, rows: const []);

      expect(
        find.textContaining('Nenhuma receita ativa encontrada'),
        findsOneWidget,
      );
    });
  });

  group('RequestRenewalScreen — seleção habilita o envio', () {
    testWidgets('selecionar a prescrição habilita o botão de envio',
        (tester) async {
      await pumpScreen(tester, rows: [activePrescription()]);

      await tester.tap(find.text('Losartana 50mg'));
      await tester.pump();

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar Pedido de Renovação'),
      );
      expect(button.onPressed, isNotNull);
    });
  });

  group('RequestRenewalScreen — envio (criação PENDING_TRIAGE)', () {
    testWidgets('sucesso chama requestRenewal e exibe SnackBar verde',
        (tester) async {
      when(service.requestRenewal(any, notes: anyNamed('notes')))
          .thenAnswer((_) async {});

      await pumpScreen(tester, rows: [activePrescription()]);

      await tester.tap(find.text('Losartana 50mg'));
      await tester.pump();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar Pedido de Renovação'),
      );
      await tester.pumpAndSettle();

      verify(service.requestRenewal('presc-original-0001',
              notes: anyNamed('notes')))
          .called(1);
      expect(
        find.text('Pedido de renovação enviado com sucesso!'),
        findsOneWidget,
      );
    });

    testWidgets('falha (RLS 42501) exibe a mensagem humanizada do provider',
        (tester) async {
      when(service.requestRenewal(any, notes: anyNamed('notes'))).thenThrow(
        RenewalRequestException(
          'Você não tem permissão para solicitar essa renovação. '
          'Faça login novamente e tente de novo.',
          code: '42501',
        ),
      );

      await pumpScreen(tester, rows: [activePrescription()]);

      await tester.tap(find.text('Losartana 50mg'));
      await tester.pump();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Enviar Pedido de Renovação'),
      );
      await tester.pumpAndSettle();

      // A tela permanece (sem pop) e mostra a mensagem segura, sem SQLSTATE.
      expect(find.textContaining('não tem permissão'), findsOneWidget);
      expect(find.textContaining('42501'), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Stubs de teste
// ---------------------------------------------------------------------------

/// [SupabaseClient] inerte — satisfaz o construtor de [PrescriptionService]
/// sem inicializar o SDK. Nenhum método é realmente invocado porque o stub
/// sobrescreve `streamPrescriptions`.
class _NoopSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [PrescriptionService] de teste que injeta um stream determinístico,
/// substituindo a leitura real do Supabase pela lista fornecida.
class _StubPrescriptionService extends PrescriptionService {
  _StubPrescriptionService(this._rows)
      : super(supabaseClient: _NoopSupabaseClient());

  final List<Map<String, dynamic>> _rows;

  @override
  Stream<List<Map<String, dynamic>>> streamPrescriptions() =>
      Stream<List<Map<String, dynamic>>>.value(_rows);
}
