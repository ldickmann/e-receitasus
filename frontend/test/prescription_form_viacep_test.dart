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
import 'package:e_receitasus/services/via_cep_service.dart';

/// Auth fake mínimo — autentica um médico sintético para popular o
/// AuthProvider sem rede; mesmo padrão dos outros widget tests.
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

class _NoopSupabaseClient implements SupabaseClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// HealthUnitService inerte — o foco destes testes é o ViaCEP, então o
/// dropdown de UBS deve ficar vazio sem disparar HTTP real.
class _EmptyHealthUnitService implements IHealthUnitService {
  @override
  Future<List<HealthUnitModel>> listByCity(String city, {String? state}) async {
    return const [];
  }
}

/// Fake configurável de IViaCepService — permite simular sucesso, ausência
/// (CEP inexistente) e erro de rede sem qualquer chamada HTTP real.
class _FakeViaCepService implements IViaCepService {
  _FakeViaCepService({this.address, this.error});

  /// Endereço a devolver em caso de sucesso. Quando `null`, lança [error].
  final ViaCepAddress? address;

  /// Exceção a lançar quando configurada. Tem prioridade sobre [address].
  final ViaCepServiceException? error;

  /// Último CEP recebido — útil para verificar a chamada do service.
  String? lastFetchedCep;

  /// Quantidade de chamadas — usado para garantir que CEPs incompletos
  /// não disparam fetch e que CEPs repetidos não duplicam requisição.
  int callCount = 0;

  @override
  Future<ViaCepAddress> fetch(String cep) async {
    callCount++;
    lastFetchedCep = cep;
    if (error != null) throw error!;
    return address!;
  }
}

Future<Widget> _buildApp({required IViaCepService viaCepService}) async {
  final authProvider = AuthProvider(_FakeAuthService());
  await authProvider.login('medica.teste@example.invalid', 'Senha@123');

  return ChangeNotifierProvider<AuthProvider>.value(
    value: authProvider,
    child: MaterialApp(
      home: PrescriptionFormScreen(
        type: PrescriptionType.branca,
        prescriptionService:
            PrescriptionService(supabaseClient: _NoopSupabaseClient()),
        healthUnitService: _EmptyHealthUnitService(),
        viaCepService: viaCepService,
      ),
    ),
  );
}

void main() {
  group('PrescriptionFormScreen — auto-preenchimento via ViaCEP (PBI #200)',
      () {
    testWidgets(
      'TASK #220: campo CEP é renderizado entre UBS e endereço do prescritor',
      (tester) async {
        final fake = _FakeViaCepService(
          address: const ViaCepAddress(
            cep: '88370000',
            logradouro: 'Rua Teste',
            bairro: 'Centro',
            localidade: 'Navegantes',
            uf: 'SC',
          ),
        );
        await tester.pumpWidget(await _buildApp(viaCepService: fake));
        await tester.pumpAndSettle();

        // Existe um campo com label CEP no formulário.
        expect(find.widgetWithText(TextFormField, 'CEP'), findsOneWidget);
        // Sem digitar nada, o service não foi acionado.
        expect(fake.callCount, 0);
      },
    );

    testWidgets(
      'TASK #221: ao digitar 8 dígitos, ViaCEP é chamado e endereço/cidade/UF '
      'do prescritor são auto-preenchidos',
      (tester) async {
        final fake = _FakeViaCepService(
          address: const ViaCepAddress(
            cep: '88370000',
            logradouro: 'Rua das Palmeiras',
            bairro: 'Centro',
            localidade: 'Navegantes',
            uf: 'SC',
          ),
        );
        await tester.pumpWidget(await _buildApp(viaCepService: fake));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'CEP'),
          '88370000',
        );
        // Aguarda Future do fake service e o setState subsequente.
        await tester.pumpAndSettle();

        // Service foi chamado exatamente uma vez com o CEP correto.
        expect(fake.callCount, 1);
        expect(fake.lastFetchedCep, '88370000');

        // Endereço composto = logradouro + ", " + bairro.
        expect(
          find.widgetWithText(
            TextFormField,
            'Rua das Palmeiras, Centro',
          ),
          findsOneWidget,
        );
        // Cidade e UF preenchidas (campos do prescritor — usar `.last` evita
        // colidir com eventuais campos de paciente, embora aqui só haja um).
        expect(
          find.widgetWithText(TextFormField, 'Navegantes'),
          findsWidgets,
        );
        expect(
          find.widgetWithText(TextFormField, 'SC'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'TASK #221: CEP com menos de 8 dígitos NÃO dispara chamada ao service',
      (tester) async {
        final fake = _FakeViaCepService(
          address: const ViaCepAddress(
            cep: '88370000',
            logradouro: 'Rua X',
            bairro: 'Centro',
            localidade: 'Navegantes',
            uf: 'SC',
          ),
        );
        await tester.pumpWidget(await _buildApp(viaCepService: fake));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'CEP'),
          '8837',
        );
        await tester.pumpAndSettle();

        expect(fake.callCount, 0);
      },
    );

    testWidgets(
      'TASK #221: erro do ViaCEP exibe SnackBar com mensagem amigável e '
      'NÃO altera os campos de endereço',
      (tester) async {
        final fake = _FakeViaCepService(
          error: const ViaCepServiceException('CEP não encontrado.'),
        );
        await tester.pumpWidget(await _buildApp(viaCepService: fake));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextFormField, 'CEP'),
          '00000000',
        );
        await tester.pumpAndSettle();

        expect(fake.callCount, 1);
        // Mensagem PT-BR oriunda do service.
        expect(find.text('CEP não encontrado.'), findsOneWidget);
      },
    );

    testWidgets(
      'TASK #221: digitar o mesmo CEP duas vezes NÃO refaz a chamada '
      '(otimização via _lastFetchedCep)',
      (tester) async {
        final fake = _FakeViaCepService(
          address: const ViaCepAddress(
            cep: '88370000',
            logradouro: 'Rua Y',
            bairro: 'Centro',
            localidade: 'Navegantes',
            uf: 'SC',
          ),
        );
        await tester.pumpWidget(await _buildApp(viaCepService: fake));
        await tester.pumpAndSettle();

        final cepFinder = find.widgetWithText(TextFormField, 'CEP');
        await tester.enterText(cepFinder, '88370000');
        await tester.pumpAndSettle();
        // Reescreve idêntico — não deve disparar nova chamada.
        await tester.enterText(cepFinder, '88370000');
        await tester.pumpAndSettle();

        expect(fake.callCount, 1);
      },
    );
  });
}
