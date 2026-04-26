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
// PBI 157 / TASK 166 — Cobertura de testes para o novo dropdown de UF do
// Conselho na RegisterScreen (cadastro de profissionais).
//
// Foco da suíte:
//   1. UF do Conselho é renderizado APENAS para tipos com `requiresCouncil`.
//   2. UF é OBRIGATÓRIO quando renderizado (validador do dropdown).
//   3. Submit envia `professionalId` puro (sem sufixo "-UF") e
//      `professionalState` separado — comportamento introduzido na TASK 164
//      após desacoplar a UF do número do registro.
//   4. Trocar o tipo de profissional limpa o estado da UF selecionada.
// ---------------------------------------------------------------------------

/// Fake do IAuthService que captura os argumentos do cadastro de profissional.
///
/// Não usa Mockito porque queremos inspeção direta dos argumentos passados —
/// fundamental para validar que o submit envia `professionalId` SEM sufixo
/// "-UF" e `professionalState` separado, conforme PBI 157 / TASK 164.
class _CapturingAuthService implements IAuthService {
  /// Último valor de `professionalId` recebido pelo cadastro.
  String? capturedProfessionalId;

  /// Último valor de `professionalState` recebido pelo cadastro.
  String? capturedProfessionalState;

  /// Último bairro recebido pelo cadastro de profissional.
  String? capturedDistrict;

  /// Última cidade de endereço recebida pelo cadastro de profissional.
  String? capturedAddressCity;

  /// Última UF de endereço recebida pelo cadastro de profissional.
  String? capturedAddressState;

  /// Conta quantas vezes `registerWithProfessionalInfo` foi invocado.
  /// Útil para garantir que o submit foi (ou não) acionado.
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
    // Captura argumentos para inspeção pelos testes — não passa pela rede.
    registerCallCount += 1;
    capturedProfessionalId = professionalId;
    capturedProfessionalState = professionalState;
    capturedDistrict = district;
    capturedAddressCity = addressCity;
    capturedAddressState = addressState;

    // Retorna UserModel mínimo válido — suficiente para popular o provider.
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

/// Fake do `IHealthUnitService` que sempre devolve uma única UBS pré-definida.
///
/// Necessário para os testes de submit válido após PBI 198 / TASK 216 ter
/// tornado a UBS de atuação obrigatória no cadastro de profissionais.
class _StaticHealthUnitService implements IHealthUnitService {
  final List<HealthUnitModel> units;
  _StaticHealthUnitService(this.units);

  @override
  Future<List<HealthUnitModel>> listByCity(String city, {String? state}) async {
    return units;
  }
}

/// UBS padrão usada nos cenários de submit válido.
const _ubsPadrao = HealthUnitModel(
  id: 'ubs-padrao-id',
  name: 'UBS Centro',
  district: 'Centro',
  city: 'Navegantes',
  state: 'SC',
);

/// Monta a `RegisterScreen` com o fake de auth e um MockClient HTTP.
///
/// Por padrão, o `MockClient` devolve 404 para qualquer requisição (ViaCEP
/// inerte). Testes que precisam validar autopreenchimento de endereço injetam
/// um `httpClient` com payload ViaCEP válido; testes de fallback manual deixam
/// bairro/cidade serem digitados diretamente.
Widget _buildTestApp(
  _CapturingAuthService fakeAuth, {
  http.Client? httpClient,
  IHealthUnitService? healthUnitService,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(fakeAuth),
      ),
    ],
    child: MaterialApp(
      home: RegisterScreen(
        // MockClient inerte por padrão: caso o ViaCEP seja acionado por
        // engano, devolve 404 para não abrir socket real e quebrar o teste.
        httpClient:
            httpClient ?? MockClient((_) async => http.Response('{}', 404)),
        // Fake inerte por padrão (lista vazia) — suficiente para testes que
        // não fazem submit válido. Submits válidos injetam um fake com UBS.
        healthUnitService:
            healthUnitService ?? _StaticHealthUnitService(const []),
      ),
    ),
  );
}

/// Seleciona um item de dropdown identificado pelo seu `Finder` (geralmente
/// `find.byKey(...)`).
///
/// Estratégia: manipula diretamente o `FormFieldState<T>` do
/// `DropdownButtonFormField`, simulando o efeito do `onChanged` sem
/// depender de tap em overlay (que é instável em testes de widget devido
/// ao `InputDecorator` + animações do `AnimatedSwitcher` envolvidos).
///
/// `valueResolver` traduz o texto exibido (`optionText`) no valor real `T`
/// armazenado pelo dropdown.
Future<void> _selectDropdownValue<T>({
  required WidgetTester tester,
  required Finder dropdownFinder,
  required T value,
}) async {
  // Garante o widget visível para o `tester.state` localizar o State.
  await tester.ensureVisible(dropdownFinder.first);
  await tester.pumpAndSettle();

  // O `DropdownButtonFormField<T>` é um `FormField<T>` — manipular o State
  // dispara o `onChanged` interno (via `Form` rebuild) e atualiza a UI.
  final state = tester.state<FormFieldState<T>>(dropdownFinder);
  state.didChange(value);
  await tester.pumpAndSettle();
}

/// Preenche os campos comuns obrigatórios para chegar a um submit válido,
/// EXCETO o tipo de profissional, número do registro e UF do conselho —
/// que cada teste define conforme o cenário.
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

  // Data de nascimento: digitar 8 dígitos dispara a máscara DD/MM/AAAA
  // e o `onChanged` popula `_selectedBirthDate`. Idade ≥ 18 obrigatória.
  final birthFinder = find.widgetWithText(TextFormField, 'Data de Nascimento');
  await tester.ensureVisible(birthFinder);
  await tester.enterText(birthFinder, '15071978');

  // Senha: 8+ caracteres com maiúscula, minúscula, número e símbolo
  final passwordFinder = find.widgetWithText(TextFormField, 'Senha');
  await tester.ensureVisible(passwordFinder);
  await tester.enterText(passwordFinder, 'Senha@123');

  final confirmFinder = find.widgetWithText(TextFormField, 'Confirmar Senha');
  await tester.ensureVisible(confirmFinder);
  await tester.enterText(confirmFinder, 'Senha@123');

  // Endereço obrigatório (TASK 225 / PBI 197): o CEP dispara ViaCEP quando
  // disponível, mas os testes podem preencher bairro/cidade manualmente para
  // cobrir o fallback necessário quando o CEP não retorna endereço completo.
  final cepFinder = find.widgetWithText(TextFormField, 'CEP *');
  await tester.ensureVisible(cepFinder);
  await tester.enterText(cepFinder, '88370000');
  await tester.pumpAndSettle();
}

void main() {
  group('RegisterScreen — Renderização condicional do Dropdown UF', () {
    testWidgets(
      'NÃO deve renderizar o dropdown de UF para tipo sem conselho '
      '(Administrativo)',
      (tester) async {
        // ARRANGE — Administrativo tem `requiresCouncil = false`, portanto
        // o campo UF do Conselho não deve sequer ser construído.
        final fakeAuth = _CapturingAuthService();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pumpAndSettle();

        // ACT — seleciona "Administrativo" no dropdown de Tipo de Profissional
        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.administrativo,
        );

        // ASSERT — o label "UF do Conselho" não deve estar em lugar nenhum
        expect(
          find.text('UF do Conselho'),
          findsNothing,
          reason: 'Profissionais sem conselho não exibem o dropdown de UF',
        );
      },
    );

    testWidgets(
      'DEVE renderizar o dropdown de UF para tipo com conselho (Médico)',
      (tester) async {
        // ARRANGE — Médico tem `requiresCouncil = true`
        final fakeAuth = _CapturingAuthService();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pumpAndSettle();

        // ACT — seleciona "Medico(a)" no dropdown de Tipo de Profissional
        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.medico,
        );

        // ASSERT — o label "UF do Conselho" deve estar visível
        expect(
          find.text('UF do Conselho'),
          findsOneWidget,
          reason: 'Médico exige UF do conselho — dropdown deve aparecer',
        );
      },
    );
  });

  group('RegisterScreen — Validação obrigatória da UF do Conselho', () {
    testWidgets(
      'deve exibir erro "Selecione a UF do conselho" quando médico não '
      'seleciona UF',
      (tester) async {
        // ARRANGE
        final fakeAuth = _CapturingAuthService();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pumpAndSettle();

        // ACT — escolhe Médico, preenche número do CRM, mas NÃO seleciona UF
        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.medico,
        );

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número do CRM'),
          '123456',
        );

        // Submete o formulário — outros campos vazios também gerarão erros,
        // mas o foco é confirmar a mensagem específica do dropdown UF.
        await tester
            .ensureVisible(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — o validador do dropdown UF deve emitir a mensagem
        expect(
          find.text('Selecione a UF do conselho'),
          findsOneWidget,
          reason: 'UF do conselho é obrigatório para profissionais com '
              'requiresCouncil = true',
        );

        // ASSERT — o submit NÃO deve ter chegado ao service
        expect(
          fakeAuth.registerCallCount,
          0,
          reason: 'Service não pode ser chamado quando o formulário tem erros',
        );
      },
    );
  });

  group('RegisterScreen — Submit envia número e UF separadamente', () {
    testWidgets(
      'submit válido envia professionalId puro (sem "-UF") e '
      'professionalState separado',
      (tester) async {
        // ARRANGE — preenche TODOS os campos obrigatórios e seleciona Médico
        // com número do CRM "123456" e UF "SC".
        // O MockClient devolve payload válido do ViaCEP para 88370000
        // (Centro / Navegantes / SC), cobrindo o caminho de autopreenchimento.
        final fakeAuth = _CapturingAuthService();
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
          fakeAuth,
          httpClient: viaCepClient,
          healthUnitService: _StaticHealthUnitService(const [_ubsPadrao]),
        ));
        await tester.pumpAndSettle();

        await _preencherCamposBasicos(tester);
        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.medico,
        );

        // Número do CRM — APENAS o número, sem qualquer sufixo "-SC".
        // É exatamente isso que TASK 164 garante: a UF não é mais concatenada.
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Número do CRM'),
          '123456',
        );

        // UF do Conselho — seleciona "SC" via dropdown dedicado
        await _selectDropdownValue<String>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('council-state-dropdown')),
          value: 'SC',
        );

        // Aguarda debounce do dropdown de UBS (400ms) — disparado pelo ViaCEP
        // ao popular cidade/UF — e seleciona a UBS de atuação (PBI 198 / TASK 216).
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await _selectDropdownValue<HealthUnitModel>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('health-unit-dropdown')),
          value: _ubsPadrao,
        );

        // ACT — submete o formulário (todos os campos válidos)
        await tester
            .ensureVisible(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        // pumpAndSettle para resolver Future do registerWithProfessionalInfo
        // e o subsequente Navigator.pop.
        await tester.pumpAndSettle();

        // ASSERT — service foi invocado exatamente uma vez
        expect(
          fakeAuth.registerCallCount,
          1,
          reason: 'Submit válido deve invocar registerWithProfessionalInfo',
        );

        // ASSERT — número do registro NÃO contém sufixo "-UF" (PBI 157 / TASK 164)
        expect(
          fakeAuth.capturedProfessionalId,
          '123456',
          reason: 'professionalId deve ser apenas o número, sem sufixo "-SC". '
              'Antes da TASK 164 a tela enviava "123456-SC" — comportamento '
              'frágil eliminado pelo dropdown dedicado de UF.',
        );

        // ASSERT — UF é enviada em campo separado
        expect(
          fakeAuth.capturedProfessionalState,
          'SC',
          reason: 'professionalState deve vir do dropdown UF, não do parsing '
              'do número do registro',
        );
      },
    );

    testWidgets(
      'submit válido permite preencher bairro e cidade manualmente quando '
      'ViaCEP não encontra o CEP',
      (tester) async {
        // ARRANGE — ViaCEP responde `erro: true`, cenário realista para CEP
        // inexistente ou não mapeado. A tela deve manter CEP obrigatório,
        // mas permitir que o usuário complete bairro/cidade manualmente.
        final fakeAuth = _CapturingAuthService();
        final viaCepClient = MockClient((req) async {
          if (req.url.host == 'viacep.com.br') {
            return http.Response(
              '{"erro":true}',
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('{}', 404);
        });
        await tester.pumpWidget(_buildTestApp(
          fakeAuth,
          httpClient: viaCepClient,
          healthUnitService: _StaticHealthUnitService(const [_ubsPadrao]),
        ));
        await tester.pumpAndSettle();

        await _preencherCamposBasicos(tester);

        // Fallback manual: bairro/cidade precisam ser editáveis porque o
        // vínculo de UBS depende desses valores, mas ViaCEP nem sempre resolve.
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

        // Aguarda debounce do dropdown de UBS e seleciona — UBS é obrigatória
        // após PBI 198 / TASK 216.
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();
        await _selectDropdownValue<HealthUnitModel>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('health-unit-dropdown')),
          value: _ubsPadrao,
        );

        // O SnackBar de CEP não encontrado fica sobre a região inferior da
        // tela; avançamos o relógio do teste para simular o usuário aguardando
        // o aviso sumir antes de tocar no botão de cadastro.
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // ACT — submete com endereço manual mesmo após falha lógica do ViaCEP.
        await tester
            .ensureVisible(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Cadastrar'));
        await tester.pumpAndSettle();

        // ASSERT — o cadastro deve seguir e enviar os dados manuais ao service.
        expect(fakeAuth.registerCallCount, 1);
        expect(fakeAuth.capturedDistrict, 'Centro');
        expect(fakeAuth.capturedAddressCity, 'Navegantes');
        expect(fakeAuth.capturedAddressState, 'SC');
      },
    );
  });

  group('RegisterScreen — Trocar tipo de profissional limpa UF selecionada',
      () {
    testWidgets(
      'mudar de Médico (com UF=SC) para Administrativo deve limpar '
      '_selectedCouncilState',
      (tester) async {
        // ARRANGE — fluxo do usuário: escolhe Médico, seleciona UF, depois
        // muda de ideia e troca para Administrativo (sem conselho).
        final fakeAuth = _CapturingAuthService();
        await tester.pumpWidget(_buildTestApp(fakeAuth));
        await tester.pumpAndSettle();

        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.medico,
        );

        await _selectDropdownValue<String>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('council-state-dropdown')),
          value: 'SC',
        );

        // ACT — troca para Administrativo (não exige conselho)
        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.administrativo,
        );

        // ASSERT — o dropdown UF some, garantindo que `_selectedCouncilState`
        // foi resetado (o widget só é construído quando requiresCouncil = true).
        expect(
          find.text('UF do Conselho'),
          findsNothing,
          reason: 'Ao trocar para tipo sem conselho, o dropdown UF deve sumir',
        );

        // ARRANGE 2 — volta para Médico
        await _selectDropdownValue<ProfessionalType>(
          tester: tester,
          dropdownFinder: find.byKey(const Key('professional-type-dropdown')),
          value: ProfessionalType.medico,
        );

        // ASSERT 2 — dropdown UF reaparece SEM valor pré-selecionado.
        // O `initialValue` do DropdownButtonFormField agora é null
        // porque `_selectedCouncilState` foi limpo no `onChanged` do tipo.
        // Se o estado não tivesse sido limpo, o item "SC" continuaria selecionado.
        final dropdown = tester.widget<DropdownButtonFormField<String>>(
          find.byKey(const Key('council-state-dropdown')),
        );
        expect(
          dropdown.initialValue,
          isNull,
          reason: 'Trocar tipo de profissional deve limpar a UF previamente '
              'selecionada para evitar combinações inconsistentes',
        );
      },
    );
  });
}
