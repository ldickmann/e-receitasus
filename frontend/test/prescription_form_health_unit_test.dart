import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:e_receitasus/models/health_unit_model.dart';
import 'package:e_receitasus/models/prescription_type.dart';
import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/auth_provider.dart';
import 'package:e_receitasus/screens/prescription_form_screen.dart';
import 'package:e_receitasus/services/auth_service.dart';
import 'package:e_receitasus/services/health_unit_service.dart';
import 'package:e_receitasus/services/prescription_service.dart';

/// Auth fake mínimo — autentica um médico sintético para popular o
/// AuthProvider sem rede, idêntico ao usado em outros widget tests.
class _FakeAuthService implements IAuthService {
  static final UserModel doctor = UserModel(
    id: 'doctor-test-id',
    firstName: 'Medica',
    lastName: 'Teste',
    email: 'medica.teste@example.invalid',
    professionalType: ProfessionalType.medico,
    professionalId: '123456',
    professionalState: 'SC',
    specialty: 'Clinica Geral',
  );

  @override
  Future<UserModel> login(String email, String password) async => doctor;

  @override
  Future<void> logout() async {}

  @override
  Future<UserModel> registerPatient({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime birthDate,
    required String password,
    required String phone,
    String? cns,
    String? cpf,
    String? socialName,
    String? motherParentName,
    String? birthCity,
    String? birthState,
    String? gender,
    String? ethnicity,
    String? maritalStatus,
    String? education,
    String? zipCode,
    String? street,
    String? streetNumber,
    String? complement,
    String? district,
    String? addressCity,
    String? addressState,
  }) async =>
      throw UnimplementedError();

  @override
  Future<UserModel> registerWithProfessionalInfo({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime birthDate,
    required String password,
    required ProfessionalType professionalType,
    String? professionalId,
    String? professionalState,
    String? specialty,
    String? zipCode,
    String? street,
    String? streetNumber,
    String? complement,
    String? district,
    String? addressCity,
    String? addressState,
  }) async =>
      throw UnimplementedError();
}

/// Cliente Supabase nulo — necessário para construir um PrescriptionService
/// real sem abrir conexão. Nenhum teste deste arquivo dispara RPC.
class _NoopSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Implementação fake de [IHealthUnitService] que devolve uma lista controlada
/// ou lança um erro determinístico — essencial para validar os três estados
/// visuais do dropdown (loading, sucesso, erro).
class _FakeHealthUnitService implements IHealthUnitService {
  _FakeHealthUnitService({this.units = const [], this.error});

  final List<HealthUnitModel> units;
  final Object? error;

  /// Última cidade requisitada — útil para validar que o filtro foi enviado.
  String? lastCity;
  String? lastState;
  int callCount = 0;

  @override
  Future<List<HealthUnitModel>> listByCity(String city, {String? state}) async {
    callCount++;
    lastCity = city;
    lastState = state;
    if (error != null) throw error!;
    return units;
  }
}

Future<Widget> _buildApp(IHealthUnitService healthUnitService) async {
  final authProvider = AuthProvider(_FakeAuthService());
  await authProvider.login('medica.teste@example.invalid', 'Senha@123');

  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp(
      home: PrescriptionFormScreen(
        type: PrescriptionType.branca,
        prescriptionService:
            PrescriptionService(supabaseClient: _NoopSupabaseClient()),
        healthUnitService: healthUnitService,
      ),
    ),
  );
}

/// Helper para preencher cidade + UF do prescritor e aguardar o debounce de
/// 400ms acionar o fetch. Sempre encerra com `pumpAndSettle` para drenar o
/// futuro do fake.
Future<void> _fillCityAndState(
  WidgetTester tester, {
  String city = 'Navegantes',
  String state = 'SC',
}) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Cidade *').last,
    city,
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'UF *').last,
    state,
  );
  // Avança o tempo virtual além do debounce de 400ms.
  await tester.pump(const Duration(milliseconds: 450));
  await tester.pumpAndSettle();
}

void main() {
  group('PrescriptionFormScreen — dropdown de UBS (TASK #215)', () {
    testWidgets(
      'sem cidade/UF preenchidas, exibe helper pedindo dados do prescritor',
      (tester) async {
        // Service fake nem deveria ser chamado neste estado.
        final fakeService = _FakeHealthUnitService();
        await tester.pumpWidget(await _buildApp(fakeService));
        await tester.pumpAndSettle();

        // Helper text orienta o usuário a preencher cidade/UF antes.
        expect(
          find.text('Preencha cidade e UF do prescritor para listar as UBS.'),
          findsOneWidget,
        );
        // Sem critério válido, o fetch não foi chamado.
        expect(fakeService.callCount, 0);
      },
    );

    testWidgets(
      'com cidade/UF válidas, carrega lista e renderiza dropdown',
      (tester) async {
        final fakeService = _FakeHealthUnitService(units: [
          const HealthUnitModel(
            id: 'ubs-1',
            name: 'UBS Centro',
            district: 'Centro',
            city: 'Navegantes',
            state: 'SC',
          ),
          const HealthUnitModel(
            id: 'ubs-2',
            name: 'UBS Gravata',
            district: 'Gravata',
            city: 'Navegantes',
            state: 'SC',
          ),
        ]);

        await tester.pumpWidget(await _buildApp(fakeService));
        await tester.pumpAndSettle();
        await _fillCityAndState(tester);

        // Filtro chegou no service exatamente como o usuário digitou
        // (cidade trim + UF uppercase).
        expect(fakeService.callCount, greaterThanOrEqualTo(1));
        expect(fakeService.lastCity, 'Navegantes');
        expect(fakeService.lastState, 'SC');

        // Dropdown renderizado com os rótulos esperados.
        expect(
          find.byType(DropdownButtonFormField<HealthUnitModel>),
          findsOneWidget,
        );
        // Abrindo o dropdown para validar que os itens da lista estão lá.
        await tester.tap(find.byType(DropdownButtonFormField<HealthUnitModel>));
        await tester.pumpAndSettle();
        expect(
          find.text('UBS Centro — Centro, Navegantes/SC'),
          findsWidgets,
        );
        expect(
          find.text('UBS Gravata — Gravata, Navegantes/SC'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'falha ao carregar UBS exibe mensagem de erro e botão de retry',
      (tester) async {
        final fakeService = _FakeHealthUnitService(
          error: HealthUnitServiceException(
            'Não foi possível carregar as UBS no momento.',
          ),
        );

        await tester.pumpWidget(await _buildApp(fakeService));
        await tester.pumpAndSettle();
        await _fillCityAndState(tester);

        // Mensagem humanizada + botão de retry visível.
        expect(
          find.text('Não foi possível carregar as UBS no momento.'),
          findsOneWidget,
        );
        expect(find.text('Tentar novamente'), findsOneWidget);
      },
    );

    testWidgets(
      'lista vazia para cidade/UF informados exibe helper específico',
      (tester) async {
        final fakeService = _FakeHealthUnitService(units: const []);

        await tester.pumpWidget(await _buildApp(fakeService));
        await tester.pumpAndSettle();
        await _fillCityAndState(tester, city: 'Itajai', state: 'SC');

        // Estado vazio orienta o usuário sem bloquear o fluxo da prescrição.
        expect(
          find.text('Nenhuma UBS cadastrada para a cidade/UF informadas.'),
          findsOneWidget,
        );
      },
    );
  });
}
