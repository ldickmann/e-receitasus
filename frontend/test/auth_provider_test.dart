import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:e_receitasus/models/professional_type.dart';
import 'package:e_receitasus/models/user_model.dart';
import 'package:e_receitasus/providers/auth_provider.dart';
import 'package:e_receitasus/services/auth_service.dart';

import 'auth_provider_test.mocks.dart';

/// Gera MockIAuthService via Mockito para isolar o AuthProvider do Supabase SDK.
///
/// O MockIAuthService intercepta todas as chamadas ao service real e retorna
/// respostas controláveis — fundamental para testar lógica de estado sem
/// depender de rede ou credenciais reais.
@GenerateMocks([IAuthService])
void main() {
  // ---------------------------------------------------------------------------
  // Fixtures — dados de teste representando usuários reais do SUS
  // ---------------------------------------------------------------------------

  /// Paciente com todos os campos preenchidos.
  ///
  /// Representa o fluxo completo de cadastro de um paciente do SUS com
  /// dados de saúde, telefone obrigatório e CNS opcional preenchido.
  final pacienteCompleto = UserModel(
    id: 'aabbccdd-0000-0000-0000-000000000001',
    firstName: 'Maria',
    lastName: 'Santos',
    email: 'maria.santos@sus.gov.br',
    birthDate: DateTime(1985, 3, 22),
    professionalType: ProfessionalType.paciente,
    // Telefone obrigatório no fluxo de cadastro de paciente
    phone: '48991234567',
    // CNS opcional — preenchido neste caso de teste completo
    cns: '123456789012345',
  );

  /// Médico com todos os campos preenchidos.
  ///
  /// Representa o fluxo completo de cadastro de um profissional de saúde
  /// com CRM, UF de registro e especialidade preenchidos.
  final medicoCompleto = UserModel(
    id: 'aabbccdd-0000-0000-0000-000000000002',
    firstName: 'Carlos',
    lastName: 'Oliveira',
    email: 'carlos.oliveira@sus.gov.br',
    birthDate: DateTime(1978, 7, 15),
    professionalType: ProfessionalType.medico,
    professionalId: '987654',
    professionalState: 'SC',
    specialty: 'Cardiologia',
    token: 'jwt-medico-token',
    tokenExpiry: DateTime(2026, 12, 31),
  );

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  late MockIAuthService mockService;
  late AuthProvider provider;

  setUp(() {
    mockService = MockIAuthService();
    provider = AuthProvider(mockService);
  });

  // ---------------------------------------------------------------------------
  // Grupo: Cadastro de Paciente
  // ---------------------------------------------------------------------------

  group('AuthProvider — Cadastro de Paciente', () {
    test(
      'deve retornar true e popular _user com paciente completo em sucesso',
      () async {
        // ARRANGE — service retorna o paciente completo sem lançar exceção
        when(
          mockService.registerPatient(
            firstName: anyNamed('firstName'),
            lastName: anyNamed('lastName'),
            email: anyNamed('email'),
            birthDate: anyNamed('birthDate'),
            password: anyNamed('password'),
            cns: anyNamed('cns'),
            phone: anyNamed('phone'),
          ),
        ).thenAnswer((_) async => pacienteCompleto);

        // ACT
        final result = await provider.registerPatient(
          firstName: 'Maria',
          lastName: 'Santos',
          email: 'maria.santos@sus.gov.br',
          birthDate: DateTime(1985, 3, 22),
          password: 'Senha@123',
          cns: '123456789012345',
          phone: '48991234567',
        );

        // ASSERT
        expect(result, RegistrationOutcome.success,
            reason: 'Cadastro bem-sucedido deve retornar success');
        expect(provider.isAuthenticated, isTrue);
        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);

        // Verifica mapeamento correto do UserModel
        expect(provider.user!.firstName, 'Maria');
        expect(provider.user!.lastName, 'Santos');
        expect(provider.user!.email, 'maria.santos@sus.gov.br');
        expect(provider.user!.professionalType, ProfessionalType.paciente);
        // Telefone obrigatório — deve estar presente
        expect(provider.user!.phone, '48991234567');
        // CNS opcional — presente pois foi informado
        expect(provider.user!.cns, '123456789012345');
        expect(
          provider.user!.birthDate,
          DateTime(1985, 3, 22),
          reason: 'Data de nascimento deve ser preservada',
        );
      },
    );

    test(
      'deve retornar false e preencher errorMessage quando service lanca excecao',
      () async {
        // ARRANGE — simula falha de rede ou e-mail duplicado
        when(
          mockService.registerPatient(
            firstName: anyNamed('firstName'),
            lastName: anyNamed('lastName'),
            email: anyNamed('email'),
            birthDate: anyNamed('birthDate'),
            password: anyNamed('password'),
            cns: anyNamed('cns'),
            phone: anyNamed('phone'),
          ),
        ).thenThrow(Exception('User already registered'));

        // ACT
        final result = await provider.registerPatient(
          firstName: 'Maria',
          lastName: 'Santos',
          email: 'maria.santos@sus.gov.br',
          birthDate: DateTime(1985, 3, 22),
          password: 'Senha@123',
          phone: '48991234567',
        );

        // ASSERT
        expect(result, RegistrationOutcome.failure,
            reason: 'Falha no cadastro deve retornar failure');
        expect(provider.isAuthenticated, isFalse);
        expect(provider.isLoading, isFalse);
        // O provider interpreta a exceção e expõe mensagem amigável
        expect(provider.errorMessage, isNotNull);
        expect(
          provider.errorMessage,
          contains('e-mail'),
          reason: 'Mensagem deve mencionar e-mail duplicado',
        );
      },
    );

    test('deve gerenciar isLoading corretamente durante registerPatient',
        () async {
      // ARRANGE — rastreia os estados de loading emitidos via notifyListeners
      final loadingStates = <bool>[];

      when(
        mockService.registerPatient(
          firstName: anyNamed('firstName'),
          lastName: anyNamed('lastName'),
          email: anyNamed('email'),
          birthDate: anyNamed('birthDate'),
          password: anyNamed('password'),
          cns: anyNamed('cns'),
          phone: anyNamed('phone'),
        ),
      ).thenAnswer((_) async => pacienteCompleto);

      provider.addListener(() {
        // Captura todos os estados emitidos — o provider emite loading=true
        // no início e loading=false no final (via _setLoading)
        loadingStates.add(provider.isLoading);
      });

      // ACT
      await provider.registerPatient(
        firstName: 'Maria',
        lastName: 'Santos',
        email: 'maria.santos@sus.gov.br',
        birthDate: DateTime(1985, 3, 22),
        password: 'Senha@123',
        phone: '48991234567',
      );

      // ASSERT — deve ter emitido true (início) e false (fim)
      expect(loadingStates, contains(true),
          reason: 'Deve emitir isLoading=true');
      expect(loadingStates.last, isFalse,
          reason: 'Deve terminar com isLoading=false');
    });
  });

  // ---------------------------------------------------------------------------
  // Grupo: Cadastro de Profissional de Saúde
  // ---------------------------------------------------------------------------

  group('AuthProvider — Cadastro de Profissional', () {
    test(
      'deve retornar true e popular _user com medico completo em sucesso',
      () async {
        // ARRANGE — service retorna médico completo com todos os campos
        when(
          mockService.registerWithProfessionalInfo(
            firstName: anyNamed('firstName'),
            lastName: anyNamed('lastName'),
            email: anyNamed('email'),
            birthDate: anyNamed('birthDate'),
            password: anyNamed('password'),
            professionalType: anyNamed('professionalType'),
            professionalId: anyNamed('professionalId'),
            professionalState: anyNamed('professionalState'),
            specialty: anyNamed('specialty'),
          ),
        ).thenAnswer((_) async => medicoCompleto);

        // ACT
        final result = await provider.registerWithProfessionalInfo(
          firstName: 'Carlos',
          lastName: 'Oliveira',
          email: 'carlos.oliveira@sus.gov.br',
          birthDate: DateTime(1978, 7, 15),
          password: 'Senha@456',
          professionalType: ProfessionalType.medico,
          professionalId: '987654',
          professionalState: 'SC',
          specialty: 'Cardiologia',
        );

        // ASSERT
        expect(result, RegistrationOutcome.success,
            reason:
                'Cadastro de profissional bem-sucedido deve retornar success');
        expect(provider.isAuthenticated, isTrue);
        expect(provider.isLoading, isFalse);
        expect(provider.errorMessage, isNull);

        // Verifica todos os campos do profissional
        expect(provider.user!.firstName, 'Carlos');
        expect(provider.user!.lastName, 'Oliveira');
        expect(provider.user!.email, 'carlos.oliveira@sus.gov.br');
        expect(provider.user!.professionalType, ProfessionalType.medico);
        expect(
          provider.user!.professionalType.canPrescribe,
          isTrue,
          reason: 'Médico deve ter canPrescribe=true',
        );
        expect(provider.user!.professionalId, '987654');
        expect(provider.user!.professionalState, 'SC');
        expect(provider.user!.specialty, 'Cardiologia');
        expect(
          provider.user!.birthDate,
          DateTime(1978, 7, 15),
          reason: 'Data de nascimento do profissional deve ser preservada',
        );
      },
    );

    test(
      'deve retornar false e expor errorMessage ao falhar cadastro de profissional',
      () async {
        // ARRANGE — simula erro genérico do Supabase (ex: senha fraca)
        when(
          mockService.registerWithProfessionalInfo(
            firstName: anyNamed('firstName'),
            lastName: anyNamed('lastName'),
            email: anyNamed('email'),
            birthDate: anyNamed('birthDate'),
            password: anyNamed('password'),
            professionalType: anyNamed('professionalType'),
            professionalId: anyNamed('professionalId'),
            professionalState: anyNamed('professionalState'),
            specialty: anyNamed('specialty'),
          ),
        ).thenThrow(Exception('weak_password'));

        // ACT
        final result = await provider.registerWithProfessionalInfo(
          firstName: 'Carlos',
          lastName: 'Oliveira',
          email: 'carlos.oliveira@sus.gov.br',
          birthDate: DateTime(1978, 7, 15),
          password: '123',
          professionalType: ProfessionalType.medico,
          professionalId: '987654',
          professionalState: 'SC',
          specialty: 'Cardiologia',
        );

        // ASSERT
        expect(result, RegistrationOutcome.failure);
        expect(provider.isAuthenticated, isFalse);
        expect(provider.user, isNull);
        expect(provider.errorMessage, isNotNull);
        expect(
          provider.errorMessage,
          contains('Senha'),
          reason: 'Mensagem deve mencionar política de senha fraca',
        );
      },
    );

    test(
      'deve expor clearError que limpa errorMessage e notifica listeners',
      () async {
        // ARRANGE — força um errorMessage via falha de cadastro
        when(
          mockService.registerWithProfessionalInfo(
            firstName: anyNamed('firstName'),
            lastName: anyNamed('lastName'),
            email: anyNamed('email'),
            birthDate: anyNamed('birthDate'),
            password: anyNamed('password'),
            professionalType: anyNamed('professionalType'),
            professionalId: anyNamed('professionalId'),
            professionalState: anyNamed('professionalState'),
            specialty: anyNamed('specialty'),
          ),
        ).thenThrow(Exception('Erro generico'));

        await provider.registerWithProfessionalInfo(
          firstName: 'Carlos',
          lastName: 'Oliveira',
          email: 'carlos.oliveira@sus.gov.br',
          birthDate: DateTime(1978, 7, 15),
          password: 'Senha@456',
          professionalType: ProfessionalType.medico,
          professionalId: '987654',
          professionalState: 'SC',
          specialty: 'Cardiologia',
        );

        // Garante que o erro foi registrado antes de limpar
        expect(provider.errorMessage, isNotNull);

        // ACT — chama clearError
        provider.clearError();

        // ASSERT — após limpar, errorMessage deve ser null
        expect(provider.errorMessage, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Grupo: Logout
  // ---------------------------------------------------------------------------

  group('AuthProvider — Logout', () {
    test('deve limpar _user e nao ser autenticado apos logout', () async {
      // ARRANGE — seta usuário autenticado via login bem-sucedido
      when(
        mockService.login(any, any),
      ).thenAnswer((_) async => medicoCompleto);

      await provider.login('carlos.oliveira@sus.gov.br', 'Senha@456');
      expect(provider.isAuthenticated, isTrue,
          reason: 'Pré-condição: usuário deve estar logado');

      when(mockService.logout()).thenAnswer((_) async {});

      // ACT
      await provider.logout();

      // ASSERT — após logout, estado deve ser limpo completamente
      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Grupo: UserModel — Verificações de domínio nos dados completos
  // ---------------------------------------------------------------------------

  group('UserModel — Validacoes de dominio', () {
    test('pacienteCompleto deve ter isPatient=true e canPrescribe=false', () {
      expect(pacienteCompleto.professionalType.isPatient, isTrue);
      expect(pacienteCompleto.professionalType.canPrescribe, isFalse);
      expect(pacienteCompleto.professionalType.isNurse, isFalse);
    });

    test('medicoCompleto deve ter canPrescribe=true e isPatient=false', () {
      expect(medicoCompleto.professionalType.canPrescribe, isTrue);
      expect(medicoCompleto.professionalType.isPatient, isFalse);
      expect(medicoCompleto.professionalType.isNurse, isFalse);
    });

    test('name getter deve retornar firstName + lastName concatenados', () {
      expect(pacienteCompleto.name, 'Maria Santos');
      expect(medicoCompleto.name, 'Carlos Oliveira');
    });
  });
}
