import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/services/auth_service.dart';

import 'auth_service_test.mocks.dart';

@GenerateMocks([
  SupabaseClient,
  GoTrueClient,
  AuthResponse,
  User,
  Session,
])
void main() {
  late MockSupabaseClient mockSupabaseClient;
  late MockGoTrueClient mockGoTrueClient;
  late AuthService authService;

  setUp(() {
    mockSupabaseClient = MockSupabaseClient();
    mockGoTrueClient = MockGoTrueClient();

    when(mockSupabaseClient.auth).thenReturn(mockGoTrueClient);

    authService = AuthService(supabaseClient: mockSupabaseClient);
  });

  group('AuthService com Supabase SDK', () {
    /// Valida login via signInWithPassword.
    test('deve autenticar e mapear UserModel corretamente', () async {
      final mockAuthResponse = MockAuthResponse();
      final mockUser = MockUser();
      final mockSession = MockSession();

      when(
        mockGoTrueClient.signInWithPassword(
          email: 'teste@sus.gov.br',
          password: 'Senha123!',
        ),
      ).thenAnswer((_) async => mockAuthResponse);

      when(mockAuthResponse.user).thenReturn(mockUser);
      when(mockAuthResponse.session).thenReturn(mockSession);

      when(mockUser.id).thenReturn('11111111-1111-1111-1111-111111111111');
      when(mockUser.email).thenReturn('teste@sus.gov.br');
      when(mockUser.userMetadata).thenReturn(<String, dynamic>{
        'name': 'Dr. Teste',
        'professional_type': 'MEDICO',
        'professional_id': '123456',
        'professional_state': 'SC',
        'specialty': 'Clinica Geral',
      });

      when(mockSession.accessToken).thenReturn('jwt-token-valido');
      when(mockSession.expiresAt).thenReturn(1893456000);

      final result = await authService.login('teste@sus.gov.br', 'Senha123!');

      expect(result.id, '11111111-1111-1111-1111-111111111111');
      expect(result.email, 'teste@sus.gov.br');
      expect(result.name, 'Dr. Teste');
      expect(result.professionalType, ProfessionalType.medico);
      expect(result.token, 'jwt-token-valido');

      verify(
        mockGoTrueClient.signInWithPassword(
          email: 'teste@sus.gov.br',
          password: 'Senha123!',
        ),
      ).called(1);
    });

    /// Valida fluxo de cadastro com metadados.
    test('deve cadastrar com signUp e retornar perfil', () async {
      final mockAuthResponse = MockAuthResponse();
      final mockUser = MockUser();

      when(
        mockGoTrueClient.signUp(
          email: 'novo@sus.gov.br',
          password: 'Senha123!',
          data: anyNamed('data'),
        ),
      ).thenAnswer((_) async => mockAuthResponse);

      when(mockAuthResponse.user).thenReturn(mockUser);
      when(mockUser.id).thenReturn('22222222-2222-2222-2222-222222222222');

      final result = await authService.registerWithProfessionalInfo(
        name: 'Novo Usuario',
        email: 'novo@sus.gov.br',
        password: 'Senha123!',
        professionalType: ProfessionalType.enfermeiro,
        professionalId: '654321',
        professionalState: 'SC',
        specialty: 'APS',
      );

      expect(result.id, '22222222-2222-2222-2222-222222222222');
      expect(result.email, 'novo@sus.gov.br');
      expect(result.professionalType, ProfessionalType.enfermeiro);

      verify(
        mockGoTrueClient.signUp(
          email: 'novo@sus.gov.br',
          password: 'Senha123!',
          data: anyNamed('data'),
        ),
      ).called(1);
    });

    /// Valida encerramento de sessao.
    test('deve chamar signOut no logout', () async {
      when(mockGoTrueClient.signOut()).thenAnswer((_) async {});

      await authService.logout();

      verify(mockGoTrueClient.signOut()).called(1);
    });
  });
}
