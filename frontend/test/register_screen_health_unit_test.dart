import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:e_receitasus/models/health_unit_model.dart';
import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/auth_provider.dart';
import 'package:e_receitasus/screens/register_screen.dart';
import 'package:e_receitasus/services/auth_service.dart';
import 'package:e_receitasus/services/health_unit_service.dart';

// ---------------------------------------------------------------------------
// PBI 198 / TASK 216 — Cobertura de testes do Dropdown de UBS na
// RegisterScreen (cadastro de profissionais).
//
// Foco da suíte:
//   1. Sem cidade/UF preenchidos: helper informativo (sem chamar service).
//   2. Cidade/UF preenchidos via ViaCEP: service é chamado e dropdown popula.
//   3. Erro do service: mensagem em vermelho + botão "Tentar novamente".
//   4. Lista vazia para a cidade/UF: helper específico.
//   5. Submit sem UBS selecionada: bloqueado com SnackBar e service de auth
//      NÃO é invocado.
// ---------------------------------------------------------------------------

/// Auth fake que apenas conta invocações — usamos para garantir que o submit
/// foi (ou não) acionado em cada cenário.
class _CountingAuthService implements IAuthService {
  int registerCallCount = 0;

  @override
  Future<UserModel> login(String email, String password) async =>
      throw UnimplementedError();

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
  }) async {
    registerCallCount += 1;
    return UserModel(
      id: 'fake-user-id',
      firstName: firstName,
      lastName: lastName,
      email: email,
      professionalType: professionalType,
      professionalId: professionalId,
      professionalState: professionalState,
    );
  }

  @override
  Future<void> logout() async {}
}

/// Fake do `IHealthUnitService` que permite cada teste configurar o resultado
/// (lista, vazio, exceção) e inspecionar argumentos recebidos.
class _FakeHealthUnitService implements IHealthUnitService {
  /// Resposta a devolver em chamadas bem-sucedidas; ignorada se [error] != null.
  List<HealthUnitModel> units;

  /// Quando não-nulo, [listByCity] lança esta exceção em vez de retornar.
  Object? error;

  /// Última cidade recebida — útil para validar dedup/staleness.
  String? lastCity;

  /// Última UF recebida.
  String? lastState;

  /// Quantidade de chamadas — base para garantir que helper "sem critério"
  /// realmente curto-circuita a busca.
  int callCount = 0;

  _FakeHealthUnitService({this.units = const [], this.error});

  @override
  Future<List<HealthUnitModel>> listByCity(String city, {String? state}) async {
    callCount += 1;
    lastCity = city;
    lastState = state;
    if (error != null) throw error!;
    return units;
  }
}

/// UBS sintética usada nos cenários populados.
const _ubsCentro = HealthUnitModel(
  id: 'ubs-centro-id',
  name: 'UBS Centro',
  district: 'Centro',
  city: 'Navegantes',
  state: 'SC',
);

/// Monta a `RegisterScreen` com fakes plugáveis.
Widget _buildTestApp({
  required _CountingAuthService fakeAuth,
  required _FakeHealthUnitService fakeHealthUnitService,
  http.Client? httpClient,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(fakeAuth),
      ),
    ],
    child: MaterialApp(
      home: RegisterScreen(
        // ViaCEP inerte por padrão — testes que precisam de autopreenchimento
        // injetam um MockClient com payload válido.
        httpClient:
            httpClient ?? MockClient((_) async => http.Response('{}', 404)),
        healthUnitService: fakeHealthUnitService,
      ),
    ),
  );
}

/// Manipula diretamente o `FormFieldState<T>` — evita instabilidade do tap em
/// menus de dropdown sob `AnimatedSwitcher`.
Future<void> _selectDropdownValue<T>({
  required WidgetTester tester,
  required Finder dropdownFinder,
  required T value,
}) async {
  await tester.ensureVisible(dropdownFinder.first);
  await tester.pumpAndSettle();
  final state = tester.state<FormFieldState<T>>(dropdownFinder);
  state.didChange(value);
  await tester.pumpAndSettle();
}

/// Aguarda o debounce de 400ms do dropdown de UBS antes de coletar o resultado.
Future<void> _settleHealthUnitsDebounce(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

/// Preenche os campos comuns obrigatórios (exceto endereço — cada teste
/// configura a parte que importa para o cenário).
Future<void> _preencherCamposBasicos(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Primeiro Nome'),
    'Carlos',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Sobrenome'),
    'Oliveira',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'E-mail'),
    'carlos.oliveira@sus.gov.br',
  );

  final birthFinder = find.widgetWithText(TextFormField, 'Data de Nascimento');
  await tester.ensureVisible(birthFinder);
  await tester.enterText(birthFinder, '15071978');

  final passwordFinder = find.widgetWithText(TextFormField, 'Senha');
  await tester.ensureVisible(passwordFinder);
  await tester.enterText(passwordFinder, 'Senha@123');

  final confirmFinder = find.widgetWithText(TextFormField, 'Confirmar Senha');
  await tester.ensureVisible(confirmFinder);
  await tester.enterText(confirmFinder, 'Senha@123');

  final cepFinder = find.widgetWithText(TextFormField, 'CEP *');
  await tester.ensureVisible(cepFinder);
  await tester.enterText(cepFinder, '88370000');
  await tester.pumpAndSettle();
}

void main() {
  group('RegisterScreen — Dropdown de UBS (PBI 198 / TASK 216)', () {
    testWidgets(
      'sem cidade/UF preenchidos exibe helper e NÃO chama o service',
      (tester) async {
        // ARRANGE — tela recém-aberta, nenhum endereço informado.
        final fakeAuth = _CountingAuthService();
        final fakeHealthUnitService = _FakeHealthUnitService();

        await tester.pumpWidget(_buildTestApp(
          fakeAuth: fakeAuth,
          fakeHealthUnitService: fakeHealthUnitService,
        ));
        await tester.pumpAndSettle();

        // ASSERT — helper "sem critério" presente, dropdown ausente.
        expect(
          find.text('Informe a cidade e a UF do endereço para listar as UBS.'),
          findsOneWidget,
          reason: 'Sem cidade/UF a UI deve orientar o usuário, sem dropdown.',
        );
        expect(find.byKey(const Key('health-unit-dropdown')), findsNothing);
        expect(
          fakeHealthUnitService.callCount,
          0,
          reason: 'Service não pode ser chamado sem cidade/UF.',
        );
      },
    );

    testWidgets(
      'após ViaCEP popular cidade/UF, service é chamado e dropdown aparece',
      (tester) async {
        // ARRANGE — ViaCEP retorna Centro/Navegantes/SC para 88370-000;
        // service devolve UBS Centro como única opção.
        final fakeAuth = _CountingAuthService();
        final fakeHealthUnitService =
            _FakeHealthUnitService(units: [_ubsCentro]);
        final viaCepClient = MockClient((req) async {
          if (req.url.host == 'viacep.com.br') {
            return http.Response(
              '{"cep":"88370-000","logradouro":"","bairro":"Centro",'
              '"localidade":"Navegantes","uf":"SC"}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 404);
        });

        await tester.pumpWidget(_buildTestApp(
          fakeAuth: fakeAuth,
          fakeHealthUnitService: fakeHealthUnitService,
          httpClient: viaCepClient,
        ));
        await tester.pumpAndSettle();

        // ACT — apenas o CEP precisa ser tocado; ViaCEP autofill cuida do resto.
        final cepFinder = find.widgetWithText(TextFormField, 'CEP *');
        await tester.ensureVisible(cepFinder);
        await tester.enterText(cepFinder, '88370000');
        await tester.pumpAndSettle();
        await _settleHealthUnitsDebounce(tester);

        // ASSERT — service consultado com cidade/UF do ViaCEP.
        expect(fakeHealthUnitService.callCount, greaterThanOrEqualTo(1));
        expect(fakeHealthUnitService.lastCity, 'Navegantes');
        expect(fakeHealthUnitService.lastState, 'SC');

        // Dropdown renderizado com a UBS retornada.
        expect(find.byKey(const Key('health-unit-dropdown')), findsOneWidget);
      },
    );

    testWidgets(
      'erro do service exibe mensagem e botão "Tentar novamente"',
      (tester) async {
        // ARRANGE — service falha com mensagem amigável.
        final fakeAuth = _CountingAuthService();
        final fakeHealthUnitService = _FakeHealthUnitService(
          error: HealthUnitServiceException('Servidor indisponível'),
        );

        await tester.pumpWidget(_buildTestApp(
          fakeAuth: fakeAuth,
          fakeHealthUnitService: fakeHealthUnitService,
        ));
        await tester.pumpAndSettle();

        // ACT — preenche cidade e UF para acionar a busca.
        final cityFinder = find.widgetWithText(TextFormField, 'Cidade *');
        await tester.ensureVisible(cityFinder);
        await tester.enterText(cityFinder, 'Navegantes');
        await _selectDropdownValue<String>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('address-state-dropdown')),
          value: 'SC',
        );
        await _settleHealthUnitsDebounce(tester);

        // ASSERT — mensagem do service propagada e CTA de retry visível.
        expect(find.text('Servidor indisponível'), findsOneWidget);
        expect(find.text('Tentar novamente'), findsOneWidget);
      },
    );

    testWidgets(
      'lista vazia exibe helper específico de "nenhuma UBS"',
      (tester) async {
        // ARRANGE — backend retorna lista vazia para a cidade/UF.
        final fakeAuth = _CountingAuthService();
        final fakeHealthUnitService = _FakeHealthUnitService(units: const []);

        await tester.pumpWidget(_buildTestApp(
          fakeAuth: fakeAuth,
          fakeHealthUnitService: fakeHealthUnitService,
        ));
        await tester.pumpAndSettle();

        final cityFinder = find.widgetWithText(TextFormField, 'Cidade *');
        await tester.ensureVisible(cityFinder);
        await tester.enterText(cityFinder, 'Navegantes');
        await _selectDropdownValue<String>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('address-state-dropdown')),
          value: 'SC',
        );
        await _settleHealthUnitsDebounce(tester);

        // ASSERT — helper diferenciado de "sem critério" e "erro".
        expect(
          find.text('Nenhuma UBS cadastrada para a cidade/UF informadas.'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('health-unit-dropdown')), findsNothing);
      },
    );

    testWidgets(
      'submit sem UBS selecionada é bloqueado com SnackBar e auth NÃO é '
      'chamado',
      (tester) async {
        // ARRANGE — todos os campos válidos, exceto UBS (lista vazia → não há
        // como selecionar). Garante que o validator/SnackBar funcionam mesmo
        // sem o dropdown estar habilitado.
        final fakeAuth = _CountingAuthService();
        final fakeHealthUnitService = _FakeHealthUnitService(units: const []);

        await tester.pumpWidget(_buildTestApp(
          fakeAuth: fakeAuth,
          fakeHealthUnitService: fakeHealthUnitService,
        ));
        await tester.pumpAndSettle();

        await _preencherCamposBasicos(tester);

        // Endereço manual — necessário para `validate()` passar nos demais
        // campos. UBS continua nula.
        final districtFinder = find.widgetWithText(TextFormField, 'Bairro *');
        await tester.ensureVisible(districtFinder);
        await tester.enterText(districtFinder, 'Centro');

        final cityFinder = find.widgetWithText(TextFormField, 'Cidade *');
        await tester.ensureVisible(cityFinder);
        await tester.enterText(cityFinder, 'Navegantes');

        await _selectDropdownValue<String>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('address-state-dropdown')),
          value: 'SC',
        );

        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.medico,
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número do CRM'),
          '123456',
        );

        await _selectDropdownValue<String>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('council-state-dropdown')),
          value: 'SC',
        );

        await _settleHealthUnitsDebounce(tester);

        // ACT — tenta cadastrar sem UBS selecionada.
        final btnFinder = find.widgetWithText(ElevatedButton, 'Cadastrar');
        await tester.ensureVisible(btnFinder);
        await tester.pumpAndSettle();
        await tester.tap(btnFinder);
        await tester.pump();

        // ASSERT — SnackBar de bloqueio + auth não chamado.
        expect(
          find.text('Selecione a UBS de atuação para concluir o cadastro.'),
          findsOneWidget,
          reason: 'UBS é obrigatória — submit deve ser bloqueado com aviso.',
        );
        expect(
          fakeAuth.registerCallCount,
          0,
          reason: 'Auth NÃO pode ser chamado sem UBS selecionada.',
        );
      },
    );
  });
}
