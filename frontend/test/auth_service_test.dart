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
      // Session null simula confirmação de e-mail pendente — o bloco PostgREST
      // não é executado, evitando chamadas extras ao Supabase durante o teste
      when(mockAuthResponse.session).thenReturn(null);
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
    test(
        'deve cadastrar paciente com todos os campos e retornar UserModel correto',
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

    // ─── Testes de regressão PBI #179 — snake_case no mapa de update ──────────
    // Estes testes verificam diretamente os mapas construídos pelos métodos
    // @visibleForTesting, evitando a necessidade de mockar PostgrestFilterBuilder
    // (não exportado pela API pública do postgrest 2.7.0).

    /// Garante que o mapa enviado ao .update() em 'professionals' usa snake_case.
    /// Regressão para PBI #179: antes do fix, camelCase ('zipCode', 'birthDate',
    /// 'addressCity', 'addressState') era enviado e ignorado silenciosamente
    /// pelo PostgREST, deixando os campos nulos no banco.
    test(
        'buildProfessionalsUpdateMap: todas as chaves devem estar em snake_case',
        () {
      final map = authService.buildProfessionalsUpdateMap(
        birthDate: DateTime(1985, 6, 15),
        zipCode: '88000-000',
        street: 'Rua das Flores',
        streetNumber: '42',
        complement: 'Ap 3',
        district: 'Centro',
        addressCity: 'Florianópolis',
        addressState: 'sc',
      );

      // Verifica presença das chaves snake_case corretas
      expect(map.containsKey('birth_date'), isTrue,
          reason: 'birthDate → birth_date');
      expect(map.containsKey('zip_code'), isTrue,
          reason: 'zipCode → zip_code');
      expect(map.containsKey('street_number'), isTrue,
          reason: 'streetNumber → street_number');
      expect(map.containsKey('address_city'), isTrue,
          reason: 'addressCity → address_city');
      expect(map.containsKey('address_state'), isTrue,
          reason: 'addressState → address_state');

      // Garante ausência das chaves camelCase que causavam falha silenciosa
      expect(map.containsKey('birthDate'), isFalse);
      expect(map.containsKey('zipCode'), isFalse);
      expect(map.containsKey('streetNumber'), isFalse);
      expect(map.containsKey('addressCity'), isFalse);
      expect(map.containsKey('addressState'), isFalse);

      // Verifica que address_state é normalizado para maiúsculas
      expect(map['address_state'], 'SC');
    });

    /// Garante que o mapa enviado ao .update() em 'patients' usa snake_case.
    /// Regressão para PBI #179: campos como 'socialName', 'maritalStatus',
    /// 'birthDate', etc. eram enviados em camelCase e silenciosamente ignorados.
    test('buildPatientsUpdateMap: todas as chaves devem estar em snake_case',
        () {
      final map = authService.buildPatientsUpdateMap(
        birthDate: DateTime(1990, 3, 10),
        phone: '48999998888',
        cns: '123456789012345',
        cpf: '000.000.000-00',
        socialName: 'Ana Maria',
        motherParentName: 'Maria dos Santos',
        birthCity: 'Blumenau',
        birthState: 'sc',
        gender: 'feminino',
        ethnicity: 'parda',
        maritalStatus: 'solteiro',
        education: 'superior',
        zipCode: '88010-000',
        street: 'Av. Beira Mar',
        streetNumber: '1000',
        complement: 'Apto 101',
        district: 'Centro',
        addressCity: 'Florianópolis',
        addressState: 'sc',
      );

      // Verifica presença das chaves snake_case corretas
      expect(map.containsKey('birth_date'), isTrue,
          reason: 'birthDate → birth_date');
      expect(map.containsKey('social_name'), isTrue,
          reason: 'socialName → social_name');
      expect(map.containsKey('mother_parent_name'), isTrue,
          reason: 'motherParentName → mother_parent_name');
      expect(map.containsKey('birth_city'), isTrue,
          reason: 'birthCity → birth_city');
      expect(map.containsKey('birth_state'), isTrue,
          reason: 'birthState → birth_state');
      expect(map.containsKey('marital_status'), isTrue,
          reason: 'maritalStatus → marital_status');
      expect(map.containsKey('zip_code'), isTrue,
          reason: 'zipCode → zip_code');
      expect(map.containsKey('street_number'), isTrue,
          reason: 'streetNumber → street_number');
      expect(map.containsKey('address_city'), isTrue,
          reason: 'addressCity → address_city');
      expect(map.containsKey('address_state'), isTrue,
          reason: 'addressState → address_state');

      // Garante ausência das chaves camelCase que causavam falha silenciosa
      expect(map.containsKey('birthDate'), isFalse);
      expect(map.containsKey('socialName'), isFalse);
      expect(map.containsKey('motherParentName'), isFalse);
      expect(map.containsKey('birthCity'), isFalse);
      expect(map.containsKey('birthState'), isFalse);
      expect(map.containsKey('maritalStatus'), isFalse);
      expect(map.containsKey('zipCode'), isFalse);
      expect(map.containsKey('streetNumber'), isFalse);
      expect(map.containsKey('addressCity'), isFalse);
      expect(map.containsKey('addressState'), isFalse);

      // Verifica que address_state e birth_state são normalizados para maiúsculas
      expect(map['address_state'], 'SC');
      expect(map['birth_state'], 'SC');

      // Verifica campos simples (sem transformação de nome)
      expect(map['phone'], '48999998888');
      expect(map.containsKey('cns'), isTrue);
      expect(map.containsKey('cpf'), isTrue);
    });

    /// Verifica que campos opcionais ausentes NÃO aparecem no mapa de update.
    /// PostgREST enviaria null para colunas com valor ausente, o que poderia
    /// sobrescrever dados existentes — campos opcionais devem ser omitidos.
    test(
        'buildPatientsUpdateMap: campos opcionais ausentes nao aparecem no mapa',
        () {
      // Apenas campos obrigatórios — sem nenhum opcional
      final map = authService.buildPatientsUpdateMap(
        birthDate: DateTime(1990, 3, 10),
        phone: '48999998888',
      );

      expect(map.containsKey('birth_date'), isTrue);
      expect(map.containsKey('phone'), isTrue);

      // Campos opcionais não devem estar presentes quando null
      expect(map.containsKey('cns'), isFalse);
      expect(map.containsKey('cpf'), isFalse);
      expect(map.containsKey('social_name'), isFalse);
      expect(map.containsKey('zip_code'), isFalse);
      expect(map.containsKey('address_city'), isFalse);
      expect(map.length, 2, reason: 'Apenas birth_date e phone devem estar presentes');
    });
  });
}
