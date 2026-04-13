import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/auth_provider.dart';
import 'package:e_receitasus/screens/login_screen.dart';
import 'package:e_receitasus/services/auth_service.dart';

/// Implementação fake do contrato IAuthService para testes de widget.
///
/// Este fake remove acoplamento com SupabaseClient e Mockito nesse teste de UI,
/// focando apenas no comportamento visual e no fluxo do AuthProvider.
class FakeAuthService implements IAuthService {
  final bool shouldLoginSucceed;

  FakeAuthService({required this.shouldLoginSucceed});

  /// Simula login com sucesso ou falha de forma determinística.
  @override
  Future<UserModel> login(String email, String password) async {
    if (!shouldLoginSucceed) {
      throw Exception('Invalid login credentials');
    }

    // CORREÇÃO: UserModel agora usa firstName/lastName em vez de name
    return UserModel(
      id: '11111111-1111-1111-1111-111111111111',
      firstName: 'Usuário',
      lastName: 'de Teste',
      email: email,
      professionalType: ProfessionalType.administrativo,
      token: 'token-teste',
      tokenExpiry: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  /// Simulação simples para manter contrato completo.
  /// IAuthService.register agora usa parâmetros nomeados
  /// com firstName, lastName e birthDate obrigatórios.
  @override
  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime birthDate,
    required String password,
  }) async {
    return UserModel(
      id: '22222222-2222-2222-2222-222222222222',
      firstName: firstName,
      lastName: lastName,
      email: email,
      birthDate: birthDate,
      professionalType: ProfessionalType.administrativo,
    );
  }

  /// Simulação simples para manter contrato completo.
  /// IAuthService.registerWithProfessionalInfo agora inclui
  /// firstName, lastName e birthDate como parâmetros obrigatórios.
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
  }) async {
    return UserModel(
      id: '33333333-3333-3333-3333-333333333333',
      firstName: firstName,
      lastName: lastName,
      email: email,
      birthDate: birthDate,
      professionalType: professionalType,
      professionalId: professionalId,
      professionalState: professionalState,
      specialty: specialty,
    );
  }

  /// Simulação de logout sem efeitos colaterais.
  @override
  Future<void> logout() async {}
}

void main() {
  late IAuthService authService;
  late AuthProvider authProvider;

  setUp(() {
    authService = FakeAuthService(shouldLoginSucceed: true);
    authProvider = AuthProvider(authService);
  });

  testWidgets(
    'LoginScreen deve renderizar campos e navegar para home em login válido',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ],
          child: MaterialApp(
            home: const LoginScreen(),
            routes: {
              '/home': (_) => const Scaffold(body: Text('HOME_SCREEN')),
            },
          ),
        ),
      );

      expect(find.widgetWithText(TextFormField, 'E-mail SUS'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Senha'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Entrar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Não tem conta? Cadastre-se'),
          findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-mail SUS'),
        'teste@sus.gov.br',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Senha'),
        'Senha123!',
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(find.text('HOME_SCREEN'), findsOneWidget);
    },
  );
}
