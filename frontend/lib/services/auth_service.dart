import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/professional_type.dart';

// ============================================================================
// INTERFACE DO SERVIÇO DE AUTENTICAÇÃO
// ============================================================================

/// Interface que define o contrato para o serviço de autenticação.
/// Mantida para garantir a compatibilidade com o AuthProvider existente.
abstract class IAuthService {
  Future<UserModel> login(String email, String password);

  Future<UserModel> register(String name, String email, String password);

  Future<UserModel> registerWithProfessionalInfo({
    required String name,
    required String email,
    required String password,
    required ProfessionalType professionalType,
    String? professionalId,
    String? professionalState,
    String? specialty,
  });

  Future<void> logout();
}

// ============================================================================
// IMPLEMENTAÇÃO COM SUPABASE (CLOUD-NATIVE)
// ============================================================================

/// Implementação do serviço de autenticação utilizando a infraestrutura do Supabase.
/// Substitui a implementação anterior que dependia de API REST local e PgAdmin4.
class AuthService implements IAuthService {
  // Instância do cliente Supabase inicializada no main.dart
  final _supabase = Supabase.instance.client;

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      // O Supabase realiza a autenticação e gerencia a persistência do JWT automaticamente
      final AuthResponse res = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = res.user;
      final session = res.session;

      if (user == null || session == null) {
        throw Exception('Falha na autenticação: Usuário ou sessão nulos.');
      }

      // Mapeia os dados da nuvem para o modelo interno do app
      return UserModel(
        id: user.id,
        name: user.userMetadata?['name'] ?? 'Usuário SUS',
        email: user.email!,
        professionalType: _mapStringToProfessionalType(
            user.userMetadata?['professional_type']),
        token: session.accessToken,
        tokenExpiry:
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000),
      );
    } on AuthException catch (e) {
      // Erros específicos do Supabase (Ex: credenciais inválidas)
      throw Exception(e.message);
    } catch (e) {
      throw Exception('Ocorreu um erro inesperado no login.');
    }
  }

  @override
  Future<UserModel> registerWithProfessionalInfo({
    required String name,
    required String email,
    required String password,
    required ProfessionalType professionalType,
    String? professionalId,
    String? professionalState,
    String? specialty,
  }) async {
    try {
      // Realiza o cadastro no Supabase Auth e armazena metadados adicionais
      final AuthResponse res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'professional_type': professionalType.value,
          'professional_id': professionalId,
          'professional_state': professionalState,
          'specialty': specialty,
        },
      );

      if (res.user == null) {
        throw Exception('Erro ao criar conta.');
      }

      return UserModel(
        id: res.user!.id,
        name: name,
        email: email,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  @override
  Future<UserModel> register(String name, String email, String password) {
    // Atalho para registro de usuários administrativos/pacientes
    return registerWithProfessionalInfo(
      name: name,
      email: email,
      password: password,
      professionalType: ProfessionalType.administrativo,
    );
  }

  @override
  Future<void> logout() async {
    // Encerra a sessão na nuvem e limpa os dados locais automaticamente
    await _supabase.auth.signOut();
  }

  // Métodos auxiliares de mapeamento
  ProfessionalType _mapStringToProfessionalType(String? value) {
    return ProfessionalType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ProfessionalType.administrativo,
    );
  }
}
