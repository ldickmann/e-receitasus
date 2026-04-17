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
    /// O AuthService lê userMetadata para resolver firstName/lastName:
    /// - 'name' legado é dividido em primeiro e último nome pelo _resolveFirstName/_resolveLastName.
    /// - result.name retorna '$firstName $lastName' via getter do UserModel.
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
      // result.name é um getter que retorna '$firstName $lastName'.trim()
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
    /// CORREÇÃO: registerWithProfessionalInfo agora usa firstName, lastName
    /// e birthDate como parâmetros nomeados obrigatórios.
    /// O AuthService constrói o UserModel diretamente dos parâmetros —
    /// não lê userMetadata do mockUser, apenas o id.
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
        firstName: 'Novo',
        lastName: 'Usuario',
        email: 'novo@sus.gov.br',
        birthDate: DateTime(1990, 1, 1),
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

    /// Valida cadastro de paciente com todos os campos preenchidos.
    ///
    /// Fluxo: signUp com metadata (first_name, last_name, birth_date,
    /// professional_type=PACIENTE) → trigger cria User no banco →
    /// AuthService retorna UserModel com professionalType.paciente.
    ///
    /// Nota: neste teste o session é null (confirmação de e-mail habilitada),
    /// portanto o update via PostgREST NÃO é chamado — comportamento esperado.
    test('deve cadastrar paciente com todos os campos e retornar UserModel correto',
        () async {
      // Paciente com todos os dados do fluxo PatientRegisterScreen
      final mockAuthResponse = MockAuthResponse();
      final mockUser = MockUser();

      when(
        mockGoTrueClient.signUp(
          email: 'maria.santos@sus.gov.br',
          password: 'Senha@123',
          data: anyNamed('data'),
        ),
      ).thenAnswer((_) async => mockAuthResponse);

      when(mockAuthResponse.user).thenReturn(mockUser);
      // Session null simula confirmação de e-mail pendente — comportamento BaaS padrão
      when(mockAuthResponse.session).thenReturn(null);
      when(mockUser.id).thenReturn('aabbccdd-0000-0000-0000-000000000001');

      final result = await authService.registerPatient(
        firstName: 'Maria',
        lastName: 'Santos',
        email: 'maria.santos@sus.gov.br',
        birthDate: DateTime(1985, 3, 22),
        password: 'Senha@123',
        cns: '123456789012345',
        phone: '48991234567',
      );

      // Verifica mapeamento correto dos campos do paciente
      expect(result.id, 'aabbccdd-0000-0000-0000-000000000001');
      expect(result.firstName, 'Maria');
      expect(result.lastName, 'Santos');
      expect(result.email, 'maria.santos@sus.gov.br');
      expect(result.professionalType, ProfessionalType.paciente);
      expect(result.professionalType.isPatient, isTrue);
      expect(result.professionalType.canPrescribe, isFalse);
      // Telefone obrigatório deve estar presente no retorno
      expect(result.phone, '48991234567');
      // CNS opcional — preenchido neste teste completo
      expect(result.cns, '123456789012345');
      expect(result.birthDate, DateTime(1985, 3, 22));

      verify(
        mockGoTrueClient.signUp(
          email: 'maria.santos@sus.gov.br',
          password: 'Senha@123',
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
