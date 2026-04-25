import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:e_receitasus/models/prescription_type.dart';
import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/auth_provider.dart';
import 'package:e_receitasus/screens/prescription_form_screen.dart';
import 'package:e_receitasus/services/auth_service.dart';
import 'package:e_receitasus/services/prescription_service.dart';

/// Fake mínimo de autenticação para popular o AuthProvider com um prescritor.
///
/// A tela de prescrição lê dados do profissional no `initState`; por isso o
/// teste autentica um médico sintético antes de montar o widget, sem abrir rede
/// nem depender de credenciais reais.
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

/// Serviço fake que intercepta apenas a chamada RPC de busca de pacientes.
///
/// Mantém a lógica real de `searchPatients` para validar o curto-circuito de
/// queries curtas e o mapeamento de erros, mas substitui a RPC por respostas
/// controladas e sintéticas.
class _FakePrescriptionService extends PrescriptionService {
  _FakePrescriptionService({this.rpcResponse, this.rpcError})
      : super(supabaseClient: _NoopSupabaseClient());

  /// Payload bruto que simula o retorno da RPC.
  final Object? rpcResponse;

  /// Erro opcional lançado pela RPC fake.
  final Object? rpcError;

  /// Quantidade de chamadas efetivas à RPC.
  int rpcCallCount = 0;

  /// Última query enviada à RPC fake.
  String? lastQuery;

  @override
  Future<dynamic> invokeSearchPatientsRpc(String nameQuery) async {
    rpcCallCount++;
    lastQuery = nameQuery;
    if (rpcError != null) throw rpcError!;
    return rpcResponse;
  }
}

/// Cliente Supabase nulo: nunca deve ser chamado nestes testes.
class _NoopSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<Widget> _buildTestApp(
  _FakePrescriptionService prescriptionService,
) async {
  final authProvider = AuthProvider(_FakeAuthService());
  await authProvider.login('medica.teste@example.invalid', 'Senha@123');

  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp(
      home: PrescriptionFormScreen(
        type: PrescriptionType.branca,
        prescriptionService: prescriptionService,
      ),
    ),
  );
}

Finder _patientNameField() {
  return find.widgetWithText(TextFormField, 'Nome Completo do Paciente *');
}

void main() {
  group('PrescriptionFormScreen — autocomplete de pacientes', () {
    testWidgets(
      'digitar 2+ caracteres dispara searchPatients e exibe resultados',
      (tester) async {
        // Arrange — dados sintéticos óbvios para evitar PII real em teste.
        final service = _FakePrescriptionService(
          rpcResponse: <Map<String, dynamic>>[
            {
              'id': 'patient-test-id-1',
              'full_name': 'Paciente Teste 1',
              'cpf': '00000000001',
              'address': 'Rua Teste, 100, Centro',
              'city': 'Navegantes',
              'age_text': '40 anos',
            },
            {
              'id': 'patient-test-id-2',
              'full_name': 'Paciente Teste 2',
              'cpf': '00000000002',
              'address': 'Rua Exemplo, 200, Centro',
              'city': 'Navegantes',
              'age_text': '35 anos',
            },
          ],
        );
        await tester.pumpWidget(await _buildTestApp(service));
        await tester.pumpAndSettle();

        // Act — duas letras atingem o limiar mínimo do autocomplete.
        await tester.ensureVisible(_patientNameField());
        await tester.enterText(_patientNameField(), 'Pa');
        await tester.pumpAndSettle();

        // Assert — a RPC fake foi chamada uma vez e a lista apareceu.
        expect(service.rpcCallCount, 1);
        expect(service.lastQuery, 'Pa');
        expect(find.text('Paciente Teste 1'), findsOneWidget);
        expect(find.text('Paciente Teste 2'), findsOneWidget);
      },
    );

    testWidgets(
      'selecionar sugestão preenche os campos do paciente correto',
      (tester) async {
        // Arrange
        final service = _FakePrescriptionService(
          rpcResponse: <Map<String, dynamic>>[
            {
              'id': 'patient-test-id-1',
              'full_name': 'Paciente Teste 1',
              'cpf': '00000000001',
              'address': 'Rua Teste, 100, Centro',
              'city': 'Navegantes',
              'age_text': '40 anos',
            },
            {
              'id': 'patient-test-id-2',
              'full_name': 'Paciente Teste 2',
              'cpf': '00000000002',
              'address': 'Rua Exemplo, 200, Centro',
              'city': 'Navegantes',
              'age_text': '35 anos',
            },
          ],
        );
        await tester.pumpWidget(await _buildTestApp(service));
        await tester.pumpAndSettle();

        await tester.ensureVisible(_patientNameField());
        await tester.enterText(_patientNameField(), 'Pa');
        await tester.pumpAndSettle();

        // Act — seleciona o segundo paciente para provar que o objeto correto
        // chega ao callback interno da tela.
        await tester.tap(find.text('Paciente Teste 2'));
        await tester.pumpAndSettle();

        // Assert — campos preenchidos a partir do PatientSearchResult escolhido.
        expect(find.text('Paciente Teste 2'), findsOneWidget);
        expect(find.text('00000000002'), findsOneWidget);
        expect(find.text('Rua Exemplo, 200, Centro'), findsOneWidget);
        expect(find.text('Navegantes'), findsOneWidget);
        expect(find.text('35 anos'), findsOneWidget);
      },
    );

    testWidgets(
      'erro P0001 exibe SnackBar seguro e mantém campo editável',
      (tester) async {
        // Arrange — P0001 representa falha controlada da RPC quando o médico
        // não está vinculado a uma UBS.
        final service = _FakePrescriptionService(
          rpcError: const PostgrestException(
            message:
                'Acesso negado: apenas profissionais vinculados a uma UBS podem buscar pacientes.',
            code: 'P0001',
          ),
        );
        await tester.pumpWidget(await _buildTestApp(service));
        await tester.pumpAndSettle();

        // Act
        await tester.ensureVisible(_patientNameField());
        await tester.enterText(_patientNameField(), 'Pa');
        await tester.pump();
        await tester.pump();

        // Assert — mensagem mapeada pelo service, sem detalhes técnicos do banco.
        expect(
          find.text(
            'Não foi possível buscar pacientes. Verifique se você está '
            'vinculado a uma UBS no seu cadastro.',
          ),
          findsOneWidget,
        );

        // O campo continua editável para permitir preenchimento manual.
        await tester.enterText(_patientNameField(), 'P');
        await tester.pump();
        expect(find.text('P'), findsOneWidget);
      },
    );

    testWidgets(
      'digitar 1 caractere não chama a RPC',
      (tester) async {
        // Arrange — se a RPC fosse chamada, o teste falharia por lançar erro.
        final service = _FakePrescriptionService(
          rpcError: StateError('RPC não deveria ser chamada'),
        );
        await tester.pumpWidget(await _buildTestApp(service));
        await tester.pumpAndSettle();

        // Act
        await tester.ensureVisible(_patientNameField());
        await tester.enterText(_patientNameField(), 'P');
        await tester.pumpAndSettle();

        // Assert — limiar mínimo de 2 caracteres evita consulta desnecessária.
        expect(service.rpcCallCount, 0);
      },
    );
  });
}
