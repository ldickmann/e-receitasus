/// Testes de widget — cenário de solicitação duplicada em [RequestRenewalScreen].
///
/// Cobre o caminho de erro DUPLICATE_RENEWAL_REQUEST (trigger anti-duplicidade
/// `trg_block_duplicate_renewal`, PBI 242): o paciente tenta renovar uma
/// receita que já possui solicitação ativa e a tela deve exibir o AlertDialog
/// amigável com ação de navegação para [RenewalTrackingScreen], sem travar o
/// botão de envio e sem vazar SQLSTATE/token técnico na UI.
///
/// O [IRenewalService] é mockado (Mockito) lançando [RenewalRequestException]
/// com `isDuplicate: true` — exatamente o que o service real produz ao
/// interceptar o token do trigger. O [PrescriptionService] é substituído por
/// um stub com stream determinístico, sem qualquer chamada ao Supabase.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:e_receitasus/models/renewal_request_model.dart';
import 'package:e_receitasus/providers/renewal_provider.dart';
import 'package:e_receitasus/screens/renewal_tracking_screen.dart';
import 'package:e_receitasus/screens/request_renewal_screen.dart';
import 'package:e_receitasus/services/prescription_service.dart';
import 'package:e_receitasus/services/renewal_service.dart';

import 'request_renewal_screen_duplicate_test.mocks.dart';

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

  /// Monta a tela com o provider acima do [MaterialApp] — assim a
  /// [RenewalTrackingScreen] empilhada pelo diálogo também encontra o
  /// [RenewalProvider] mockado ao chamar `context.read` no initState.
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

  /// Configura o mock para lançar a exceção de duplicata (como o service real
  /// faz ao interceptar o token do trigger), seleciona a receita e envia.
  Future<void> submitWithDuplicateError(WidgetTester tester) async {
    when(service.requestRenewal(any, notes: anyNamed('notes'))).thenThrow(
      RenewalRequestException(
        RenewalService.duplicateRenewalMessage,
        code: 'P0001',
        isDuplicate: true,
      ),
    );

    await pumpScreen(tester, rows: [activePrescription()]);

    await tester.tap(find.text('Losartana 50mg'));
    await tester.pump();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Enviar Pedido de Renovação'),
    );
    await tester.pumpAndSettle();
  }

  group('RequestRenewalScreen — duplicata: feedback visual', () {
    testWidgets(
        'exibe AlertDialog com mensagem amigável e ação Ver rastreamento',
        (tester) async {
      await submitWithDuplicateError(tester);

      // Diálogo dedicado ao cenário de duplicata, com a mensagem humanizada
      // exata definida no service (única fonte da verdade do texto).
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Solicitação em andamento'), findsOneWidget);
      expect(find.text(RenewalService.duplicateRenewalMessage), findsOneWidget);
      expect(find.text('Ver rastreamento'), findsOneWidget);

      // Nenhum detalhe técnico vaza para a UI (LGPD + segurança).
      expect(find.textContaining('P0001'), findsNothing);
      expect(find.textContaining('DUPLICATE_RENEWAL_REQUEST'), findsNothing);
    });

    testWidgets('botão de envio volta habilitado após fechar o diálogo',
        (tester) async {
      await submitWithDuplicateError(tester);

      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();

      // Sem tela travada: diálogo fechado, seleção preservada e botão ativo
      // para o paciente tentar com outra receita.
      expect(find.byType(AlertDialog), findsNothing);
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Enviar Pedido de Renovação'),
      );
      expect(button.onPressed, isNotNull);

      // Estado do provider limpo pelo clearError — sem erro residual.
      expect(provider.isDuplicate, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.isSubmitting, isFalse);
    });
  });

  group('RequestRenewalScreen — duplicata: navegação ao rastreamento', () {
    testWidgets('tap em Ver rastreamento empilha a RenewalTrackingScreen',
        (tester) async {
      // A tela de rastreamento consome streamMyRenewals no initState —
      // stub com lista vazia evita MissingStubError e renderiza estado vazio.
      when(service.streamMyRenewals()).thenAnswer(
        (_) => Stream<List<RenewalRequestModel>>.value(
          const <RenewalRequestModel>[],
        ),
      );

      await submitWithDuplicateError(tester);

      await tester.tap(find.text('Ver rastreamento'));
      await tester.pumpAndSettle();

      // Navegou via Navigator.push: rastreamento no topo, sem diálogo órfão.
      expect(find.byType(RenewalTrackingScreen), findsOneWidget);
      expect(find.text('Rastrear Pedidos de Renovação'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      verify(service.streamMyRenewals()).called(1);

      // Voltar retorna direto para a tela de solicitação (diálogo já fechado).
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(RequestRenewalScreen), findsOneWidget);
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
