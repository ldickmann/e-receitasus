import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/professional_type.dart';

/// Contrato do servico de autenticacao.
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

/// Implementacao cloud-native com Supabase Auth.
/// Nao usa API local de login nem armazenamento manual de token.
class AuthService implements IAuthService {
  final SupabaseClient _supabase;

  /// Permite injetar cliente para testes.
  AuthService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  /// Realiza login no Supabase e mapeia para UserModel.
  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final User? user = response.user;
      final Session? session = response.session;

      if (user == null || session == null || user.email == null) {
        throw Exception('Falha na autenticacao: usuario ou sessao invalidos.');
      }

      return UserModel(
        id: user.id,
        name: _resolveName(user),
        email: user.email!,
        professionalType: _mapStringToProfessionalType(
          user.userMetadata?['professional_type'] as String?,
        ),
        professionalId: user.userMetadata?['professional_id'] as String?,
        professionalState: user.userMetadata?['professional_state'] as String?,
        specialty: user.userMetadata?['specialty'] as String?,
        token: session.accessToken,
        tokenExpiry: _resolveTokenExpiry(session),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Ocorreu um erro inesperado no login.');
    }
  }

  /// Registra novo usuario no Supabase com metadados profissionais.
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
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: <String, dynamic>{
          'name': name,
          'professional_type': professionalType.value,
          'professional_id': professionalId,
          'professional_state': professionalState,
          'specialty': specialty,
        },
      );

      final User? user = response.user;
      if (user == null) {
        throw Exception('Erro ao criar conta no Supabase Auth.');
      }

      return UserModel(
        id: user.id,
        name: name,
        email: email,
        professionalType: professionalType,
        professionalId: professionalId,
        professionalState: professionalState,
        specialty: specialty,
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Ocorreu um erro inesperado no cadastro.');
    }
  }

  /// Atalho de cadastro para perfil administrativo.
  @override
  Future<UserModel> register(String name, String email, String password) {
    return registerWithProfessionalInfo(
      name: name,
      email: email,
      password: password,
      professionalType: ProfessionalType.administrativo,
    );
  }

  /// Encerra a sessao ativa.
  @override
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  /// Resolve nome para exibicao com fallback.
  String _resolveName(User user) {
    final dynamic metadataName = user.userMetadata?['name'];

    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }

    return 'Usuario SUS';
  }

  /// Resolve expiracao do token com seguranca para null.
  DateTime? _resolveTokenExpiry(Session session) {
    final int? expiresAt = session.expiresAt;

    if (expiresAt == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  }

  /// Converte string para enum de tipo profissional.
  ProfessionalType _mapStringToProfessionalType(String? value) {
    return ProfessionalType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProfessionalType.administrativo,
    );
  }
}
