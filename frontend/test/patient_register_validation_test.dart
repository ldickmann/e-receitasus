import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/auth_provider.dart';
import 'package:e_receitasus/screens/patient_register_screen.dart';
import 'package:e_receitasus/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Fake do IAuthService — idêntico ao usado em patient_register_cep_test.dart
// ---------------------------------------------------------------------------

/// Fake do IAuthService que simula cadastro bem-sucedido de paciente.
///
/// Isola completamente o widget do Supabase SDK real — os testes testam
/// apenas a lógica de validação do formulário, não o fluxo de rede.
class _FakeAuthService implements IAuthService {
  @override
  Future<UserModel> login(String email, String password) async =>
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
  }) async =>
      throw UnimplementedError();

  /// Retorna UserModel mínimo válido — a tela só precisa saber se houve sucesso.
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
      UserModel(
        id: 'test-id',
        firstName: firstName,
        lastName: lastName,
        email: email,
        professionalType: ProfessionalType.paciente,
      );

  @override
  Future<void> logout() async {}
}

// ---------------------------------------------------------------------------
// Helper de montagem do widget
// ---------------------------------------------------------------------------

/// Monta PatientRegisterScreen com um MockClient que nunca é chamado.
///
/// Os testes desta suite não precisam de rede — apenas de validação de form.
/// O MockClient é passado para satisfazer o construtor sem abrir sockets reais.
Widget _buildTestApp({http.Client? httpClient}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(_FakeAuthService()),
      ),
    ],
    child: MaterialApp(
      home: PatientRegisterScreen(
        httpClient: httpClient ??
            MockClient((_) async => http.Response('{}', 200)),
      ),
      routes: {
        '/login': (_) => const Scaffold(body: Text('LOGIN_SCREEN')),
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Helpers de preenchimento do formulário
// ---------------------------------------------------------------------------

/// Preenche os campos obrigatórios para que o submit possa ser testado.
///
/// Útil para testes que querem verificar o comportamento após submit válido,
/// sem repetir o setup completo em cada teste.
Future<void> _preencherCamposObrigatorios(WidgetTester tester) async {
  // Nome
  await tester.enterText(find.widgetWithText(TextFormField, 'Nome *'), 'Maria');
  // Sobrenome
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Sobrenome *'), 'Silva');
  // E-mail
  await tester.enterText(
      find.widgetWithText(TextFormField, 'E-mail *'), 'maria@sus.gov.br');
  // Senha
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Senha *'), '123456');
  // Confirmar senha
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar senha *'), '123456');
  // Telefone — rola até o campo antes de preencher pois pode estar fora do viewport
  await tester.ensureVisible(
      find.widgetWithText(TextFormField, 'Telefone celular *'));
  await tester.enterText(
      find.widgetWithText(TextFormField, 'Telefone celular *'), '11999999999');
}

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  group('PatientRegisterScreen — Validação de campos obrigatórios', () {
    testWidgets(
      'deve exibir erros de validação ao tentar submeter formulário vazio',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // ACT — rola até o botão Cadastrar e clica sem preencher nenhum campo
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — campo Nome obrigatório
        expect(
          find.text('Informe o nome.'),
          findsOneWidget,
          reason: 'Nome é obrigatório — deve exibir mensagem de erro',
        );
        // ASSERT — campo Sobrenome obrigatório
        expect(
          find.text('Informe o sobrenome.'),
          findsOneWidget,
          reason: 'Sobrenome é obrigatório — deve exibir mensagem de erro',
        );
        // ASSERT — campo E-mail obrigatório
        expect(
          find.text('Informe o e-mail.'),
          findsOneWidget,
          reason: 'E-mail é obrigatório — deve exibir mensagem de erro',
        );
        // ASSERT — campo Senha obrigatório
        expect(
          find.text('Informe a senha.'),
          findsOneWidget,
          reason: 'Senha é obrigatória — deve exibir mensagem de erro',
        );
      },
    );

    testWidgets(
      'deve bloquear submit quando as senhas não coincidem',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Preenche senhas diferentes
        await tester.ensureVisible(
            find.widgetWithText(TextFormField, 'Senha *'));
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Senha *'), 'senha123');
        await tester.ensureVisible(
            find.widgetWithText(TextFormField, 'Confirmar senha *'));
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Confirmar senha *'),
            'senha_diferente');

        // ACT — tenta submeter
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — mensagem de senhas divergentes
        expect(
          find.text('As senhas não coincidem.'),
          findsOneWidget,
          reason:
              'Deve bloquear cadastro quando senha e confirmação são diferentes',
        );
      },
    );

    testWidgets(
      'deve exibir erro quando senha tem menos de 6 caracteres',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // ACT — preenche senha curta
        await tester.ensureVisible(
            find.widgetWithText(TextFormField, 'Senha *'));
        await tester.enterText(
            find.widgetWithText(TextFormField, 'Senha *'), '123');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — limite mínimo definido pelo Supabase Auth (6 caracteres)
        expect(
          find.text('Mínimo de 6 caracteres.'),
          findsOneWidget,
          reason: 'Supabase exige senha mínima de 6 caracteres',
        );
      },
    );

    testWidgets(
      'deve exibir erro quando e-mail tem formato inválido',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // ACT — e-mail sem domínio válido
        await tester.ensureVisible(
            find.widgetWithText(TextFormField, 'E-mail *'));
        await tester.enterText(
            find.widgetWithText(TextFormField, 'E-mail *'), 'emailsemarrobaeponto');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — validação básica de formato antes de enviar ao Supabase
        expect(
          find.text('E-mail inválido.'),
          findsOneWidget,
          reason: 'Deve rejeitar e-mail sem @ ou ponto no domínio',
        );
      },
    );
  });

  group('PatientRegisterScreen — Validação de CPF', () {
    testWidgets(
      'deve aceitar CPF vazio — campo é opcional',
      (tester) async {
        // ARRANGE — CPF é opcional; campo vazio não deve gerar erro
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // ACT — submete sem preencher CPF (campo fica vazio)
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — nenhuma mensagem de erro relacionada ao CPF
        expect(
          find.text('CPF deve ter 11 dígitos.'),
          findsNothing,
          reason: 'CPF vazio é válido — campo é opcional no cadastro SUS',
        );
      },
    );

    testWidgets(
      'deve rejeitar CPF com menos de 11 dígitos',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Encontra o campo CPF pelo hintText (evita ambiguidade com CNS)
        final cpfFinder = find.widgetWithText(TextFormField, 'CPF');
        await tester.ensureVisible(cpfFinder);

        // ACT — CPF com apenas 10 dígitos
        await tester.enterText(cpfFinder, '1234567890');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — comprimento insuficiente (validação de dígitos verificadores
        // é responsabilidade do backend para não expor o algoritmo no cliente)
        expect(
          find.text('CPF deve ter 11 dígitos.'),
          findsOneWidget,
          reason: 'CPF incompleto deve ser rejeitado no frontend',
        );
      },
    );

    testWidgets(
      'deve aceitar CPF com exatamente 11 dígitos',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        final cpfFinder = find.widgetWithText(TextFormField, 'CPF');
        await tester.ensureVisible(cpfFinder);

        // ACT — CPF com 11 dígitos (formato correto — verificação de dígito
        // é feita no backend)
        await tester.enterText(cpfFinder, '12345678901');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — nenhum erro de CPF quando comprimento está correto
        expect(
          find.text('CPF deve ter 11 dígitos.'),
          findsNothing,
          reason: 'CPF com 11 dígitos deve passar pela validação do frontend',
        );
      },
    );
  });

  group('PatientRegisterScreen — Validação de CNS', () {
    testWidgets(
      'deve aceitar CNS vazio — campo é opcional',
      (tester) async {
        // CNS é opcional — presente apenas para pacientes que já têm cartão
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // Nenhum erro de CNS quando o campo está vazio
        expect(
          find.text('CNS deve ter 15 dígitos.'),
          findsNothing,
          reason: 'CNS vazio é válido — cartão pode ser obtido após o cadastro',
        );
      },
    );

    testWidgets(
      'deve rejeitar CNS com menos de 15 dígitos',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Campo CNS — encontrado pelo hintText para evitar colisão com CPF
        final cnsFinder = find.widgetWithText(
            TextFormField, 'CNS (Cartão Nacional de Saúde)');
        await tester.ensureVisible(cnsFinder);

        // ACT — CNS com apenas 14 dígitos
        await tester.enterText(cnsFinder, '12345678901234');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — CNS incompleto é rejeitado
        expect(
          find.text('CNS deve ter 15 dígitos.'),
          findsOneWidget,
          reason: 'CNS do SUS tem exatamente 15 dígitos — comprimento menor é inválido',
        );
      },
    );

    testWidgets(
      'deve aceitar CNS com exatamente 15 dígitos',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        final cnsFinder = find.widgetWithText(
            TextFormField, 'CNS (Cartão Nacional de Saúde)');
        await tester.ensureVisible(cnsFinder);

        // ACT — CNS com 15 dígitos (formato correto)
        await tester.enterText(cnsFinder, '123456789012345');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — nenhum erro de comprimento
        expect(
          find.text('CNS deve ter 15 dígitos.'),
          findsNothing,
          reason: 'CNS com 15 dígitos deve passar pela validação do frontend',
        );
      },
    );
  });

  group('PatientRegisterScreen — Validação de telefone', () {
    testWidgets(
      'deve exibir erro quando telefone está vazio',
      (tester) async {
        // Telefone é obrigatório — único campo de contato exigido no cadastro SUS
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — campo obrigatório para contato e autenticação por SMS futura
        expect(
          find.text('Informe o telefone celular.'),
          findsOneWidget,
          reason: 'Telefone é obrigatório e deve exibir erro quando vazio',
        );
      },
    );

    testWidgets(
      'deve rejeitar telefone com menos de 11 dígitos',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        final phoneFinder =
            find.widgetWithText(TextFormField, 'Telefone celular *');
        await tester.ensureVisible(phoneFinder);

        // ACT — número sem DDD (apenas 9 dígitos)
        await tester.enterText(phoneFinder, '999999999');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — DDD (2 dígitos) + número (9 dígitos) = 11 dígitos obrigatórios
        expect(
          find.text('Informe DDD + número (11 dígitos).'),
          findsOneWidget,
          reason: 'Telefone sem DDD deve ser rejeitado',
        );
      },
    );

    testWidgets(
      'deve aceitar telefone com exatamente 11 dígitos',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        final phoneFinder =
            find.widgetWithText(TextFormField, 'Telefone celular *');
        await tester.ensureVisible(phoneFinder);

        // ACT — DDD + celular com 9 dígitos = 11 total
        await tester.enterText(phoneFinder, '11987654321');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — nenhum erro de telefone quando formato está correto
        expect(
          find.text('Informe DDD + número (11 dígitos).'),
          findsNothing,
          reason: 'Telefone com DDD e 9 dígitos deve passar na validação',
        );
        expect(
          find.text('Informe o telefone celular.'),
          findsNothing,
          reason: 'Campo preenchido não deve exibir erro de campo vazio',
        );
      },
    );
  });

  group('PatientRegisterScreen — Validação de CEP', () {
    testWidgets(
      'deve aceitar CEP vazio — campo é opcional',
      (tester) async {
        // CEP é opcional — pacientes sem endereço fixo não devem ser bloqueados
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        expect(
          find.text('CEP deve ter 8 dígitos.'),
          findsNothing,
          reason: 'CEP vazio é válido — endereço é opcional no cadastro',
        );
      },
    );

    testWidgets(
      'deve rejeitar CEP com menos de 8 dígitos',
      (tester) async {
        // ARRANGE
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        final cepFinder = find.byKey(const Key('cep_field'));
        await tester.ensureVisible(cepFinder);

        // ACT — CEP incompleto (7 dígitos)
        await tester.enterText(cepFinder, '0100100');
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — CEP brasileiro tem sempre 8 dígitos
        expect(
          find.text('CEP deve ter 8 dígitos.'),
          findsOneWidget,
          reason: 'CEP incompleto deve ser rejeitado antes de consultar a ViaCEP',
        );
      },
    );
  });

  group('PatientRegisterScreen — Fluxo de submit', () {
    testWidgets(
      'deve bloquear submit e exibir aviso quando data de nascimento não foi selecionada',
      (tester) async {
        // ARRANGE — todos os campos de texto obrigatórios preenchidos,
        // mas a data de nascimento (via DatePicker) não foi selecionada.
        // O botão de data exibe placeholder "Selecionar data de nascimento *"
        // enquanto _selectedBirthDate == null.
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await _preencherCamposObrigatorios(tester);

        // ACT — tenta submeter sem selecionar a data de nascimento
        await tester.ensureVisible(
            find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.tap(find.widgetWithText(FilledButton, 'Cadastrar'));
        await tester.pump();

        // ASSERT — verificação de negócio: data de nascimento é obrigatória
        // O SnackBar é exibido diretamente pelo _handleSubmit sem passar pelo Form
        // pois o DatePicker não é um TextFormField validável via _formKey
        expect(
          find.text('Informe a data de nascimento.'),
          findsOneWidget,
          reason:
              'Data de nascimento é obrigatória e verificada fora do FormKey',
        );
      },
    );

    testWidgets(
      'deve exibir botão de data com texto placeholder enquanto data não foi selecionada',
      (tester) async {
        // Verifica a presença do campo de data com o texto correto de placeholder
        // — confirma que o widget de data está renderizado e acessível
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // O botão existe e exibe o placeholder correto
        expect(
          find.widgetWithText(
              OutlinedButton, 'Selecionar data de nascimento *'),
          findsOneWidget,
          reason:
              'Campo de data deve exibir placeholder enquanto nenhuma data foi selecionada',
        );
      },
    );
  });
}
