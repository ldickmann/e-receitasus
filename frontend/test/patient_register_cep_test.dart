import 'dart:convert';

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
// Fake do IAuthService
// ---------------------------------------------------------------------------

/// Fake do IAuthService com cadastro de paciente completo.
///
/// Necessário para isolar o widget de cadastro do Supabase SDK real
/// durante os testes de preenchimento automático via ViaCEP.
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

  /// Simula cadastro bem-sucedido de paciente sem chamar o Supabase real.
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
// Helpers de montagem do widget
// ---------------------------------------------------------------------------

/// Monta PatientRegisterScreen dentro de um app de teste isolado.
///
/// O [httpClient] é repassado ao construtor da tela — evita chamadas HTTP
/// reais à ViaCEP sem necessidade de HttpOverrides ou mocks de dart:io.
Widget _buildTestApp({required http.Client httpClient}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>(
        create: (_) => AuthProvider(_FakeAuthService()),
      ),
    ],
    child: MaterialApp(
      home: PatientRegisterScreen(httpClient: httpClient),
      routes: {
        '/login': (_) => const Scaffold(body: Text('LOGIN_SCREEN')),
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// Fixtures ViaCEP
// ---------------------------------------------------------------------------

/// Resposta de sucesso da ViaCEP para o CEP 01001-000 (Praça da Sé, SP).
///
/// Mantida fiel ao contrato público da API para garantir que mudanças no
/// parsing do JSON sejam detectadas nos testes antes de chegar à produção.
const _cepSuccessPayload = {
  'cep': '01001-000',
  'logradouro': 'Praça da Sé',
  'complemento': 'lado ímpar',
  'bairro': 'Sé',
  'localidade': 'São Paulo',
  'uf': 'SP',
};

/// Resposta da ViaCEP para CEP inexistente — status 200 com {"erro": true}.
///
/// A ViaCEP não retorna 404; o campo "erro" é a única forma de identificar
/// um CEP inválido — o código trata esse caso separadamente de erros HTTP.
const _cepNotFoundPayload = {'erro': true};

// ---------------------------------------------------------------------------
// Testes
// ---------------------------------------------------------------------------

void main() {
  group('PatientRegisterScreen — Preenchimento automático via ViaCEP', () {
    testWidgets(
      'deve preencher logradouro, bairro e cidade ao digitar 8 dígitos válidos',
      (tester) async {
        // ARRANGE — MockClient intercepta a chamada sem tocar a rede real.
        // charset=utf-8 é obrigatório: http.Response usa _encodingForHeaders(headers)
        // para encodar o body no construtor; sem ele usa latin1, cujos bytes
        // (códigos 0x80–0xFF) causam FormatException no utf8.decode de produção.
        var callCount = 0;
        final mockClient = MockClient((_) async {
          callCount++;
          return http.Response(
            jsonEncode(_cepSuccessPayload),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        await tester.pumpWidget(_buildTestApp(httpClient: mockClient));
        await tester.pumpAndSettle();

        final cepFinder = find.byKey(const Key('cep_field'));
        await tester.ensureVisible(cepFinder);
        await tester.pumpAndSettle();

        // ACT — 8 dígitos disparam o listener _onCepChanged.
        // pump(500ms) avança o relógio fake, dispara timers, drena microtasks
        // e processa o frame resultante — tudo em uma chamada, evitando a
        // condição de corrida que ocorre com pump() + pump(500ms) em cascata.
        await tester.tap(cepFinder);
        await tester.enterText(cepFinder, '01001000');
        await tester.pump(const Duration(milliseconds: 500));

        // Confirma que o MockClient foi chamado exatamente uma vez
        expect(callCount, equals(1),
            reason: 'MockClient deve ter sido chamado uma vez');

        // ASSERT — campos preenchidos com dados da fixture ViaCEP.
        // find.text com skipOffstage: false encontra EditableText mesmo que
        // o campo esteja além do viewport no SingleChildScrollView.
        expect(
          find.text('Praça da Sé', skipOffstage: false),
          findsOneWidget,
          reason: 'Logradouro deve ser preenchido com o retorno da ViaCEP',
        );
        expect(
          find.text('Sé', skipOffstage: false),
          findsOneWidget,
          reason: 'Bairro deve ser preenchido com o retorno da ViaCEP',
        );
        expect(
          find.text('São Paulo', skipOffstage: false),
          findsOneWidget,
          reason: 'Cidade deve ser preenchida com o retorno da ViaCEP',
        );
      },
    );

    testWidgets(
      'deve exibir SnackBar de aviso quando CEP não existir na base ViaCEP',
      (tester) async {
        // ARRANGE — ViaCEP retorna {"erro": true} para CEP inexistente (HTTP 200)
        final mockClient = MockClient((_) async {
          return http.Response(jsonEncode(_cepNotFoundPayload), 200);
        });

        await tester.pumpWidget(_buildTestApp(httpClient: mockClient));
        await tester.pumpAndSettle();

        final cepFinder = find.byKey(const Key('cep_field'));
        await tester.ensureVisible(cepFinder);
        await tester.pumpAndSettle();

        // ACT — digita CEP que não existe na base ViaCEP
        await tester.tap(cepFinder);
        await tester.enterText(cepFinder, '00000000');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // ASSERT — SnackBar orienta o preenchimento manual
        expect(
          find.text('CEP não encontrado. Preencha o endereço manualmente.'),
          findsOneWidget,
          reason:
              'Deve alertar o usuário quando o CEP não existir na base ViaCEP',
        );
      },
    );

    testWidgets(
      'deve exibir SnackBar de erro quando a requisição à ViaCEP falhar',
      (tester) async {
        // ARRANGE — simula falha genérica de rede/servidor
        final mockClient = MockClient((_) async {
          throw Exception('Sem conexão com a internet');
        });

        await tester.pumpWidget(_buildTestApp(httpClient: mockClient));
        await tester.pumpAndSettle();

        final cepFinder = find.byKey(const Key('cep_field'));
        await tester.ensureVisible(cepFinder);
        await tester.pumpAndSettle();

        // ACT — digita CEP com cliente em falha
        await tester.tap(cepFinder);
        await tester.enterText(cepFinder, '01310100');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // ASSERT — SnackBar informa a falha de rede ao usuário
        expect(
          find.text('Não foi possível consultar o CEP. Verifique a conexão.'),
          findsOneWidget,
          reason: 'Deve informar ao usuário sobre falha ao consultar o CEP',
        );
      },
    );

    testWidgets(
      'não deve disparar segunda requisição para o mesmo CEP já consultado',
      (tester) async {
        // Contador de chamadas HTTP para verificar a deduplicação pelo _lastFetchedCep
        var callCount = 0;
        final mockClient = MockClient((_) async {
          callCount++;
          return http.Response(jsonEncode(_cepSuccessPayload), 200);
        });

        await tester.pumpWidget(_buildTestApp(httpClient: mockClient));
        await tester.pumpAndSettle();

        final cepFinder = find.byKey(const Key('cep_field'));
        await tester.ensureVisible(cepFinder);
        await tester.pumpAndSettle();

        // ACT — digita o CEP completo, apaga um dígito e redigita
        // Simula o caso em que o usuário edita o campo sem mudar o CEP final
        await tester.tap(cepFinder);
        await tester.enterText(cepFinder, '01001000');
        await tester.pump(const Duration(milliseconds: 500));

        await tester.enterText(cepFinder, '0100100'); // apaga último dígito
        await tester.pump();
        await tester.enterText(cepFinder, '01001000'); // redigita
        await tester.pump(const Duration(milliseconds: 500));

        // ASSERT — apenas 1 chamada HTTP; _lastFetchedCep evita a duplicata
        expect(
          callCount,
          equals(1),
          reason:
              'Deve evitar chamada duplicada ao ViaCEP para o mesmo CEP já buscado',
        );
      },
    );
  });
}
