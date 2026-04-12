import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/professional_type.dart';

abstract class IAuthService {
  Future<UserModel> login(String email, String password);

  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime birthDate,
    required String password,
  });

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
  });

  Future<void> logout();
}

class AuthService implements IAuthService {
  final SupabaseClient _supabase;

  AuthService({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  @override
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = response.user;
      final session = response.session;

      if (user == null || session == null || user.email == null) {
        throw Exception('Falha na autenticacao: usuario ou sessao invalidos.');
      }

      final firstName = _resolveFirstName(user);
      final lastName = _resolveLastName(user);

      return UserModel(
        id: user.id,
        firstName: firstName,
        lastName: lastName,
        email: user.email!,
        birthDate: _resolveBirthDate(user),
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

  @override
  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime birthDate,
    required String password,
  }) {
    return registerWithProfessionalInfo(
      firstName: firstName,
      lastName: lastName,
      email: email,
      birthDate: birthDate,
      password: password,
      professionalType: ProfessionalType.administrativo,
      professionalId: null,
      professionalState: null,
      specialty: null,
    );
  }

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
    try {
      final cleanFirstName = firstName.trim();
      final cleanLastName = lastName.trim();
      final cleanEmail = email.trim().toLowerCase();
      final cleanProfessionalId = professionalId?.trim();

      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: <String, dynamic>{
          'name': '$cleanFirstName $cleanLastName'.trim(),
          'first_name': cleanFirstName,
          'last_name': cleanLastName,
          'birth_date': _formatBirthDate(birthDate),
          'professional_type': professionalType.value,
          'professional_id': cleanProfessionalId,
          'professional_state': professionalState?.trim().toUpperCase(),
          'specialty': specialty?.trim(),
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Erro ao criar conta no Supabase Auth.');
      }

      return UserModel(
        id: user.id,
        firstName: cleanFirstName,
        lastName: cleanLastName,
        email: cleanEmail,
        birthDate: birthDate,
        professionalType: professionalType,
        professionalId: cleanProfessionalId,
        professionalState: professionalState?.trim().toUpperCase(),
        specialty: specialty?.trim(),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (_) {
      throw Exception('Ocorreu um erro inesperado no cadastro.');
    }
  }

  @override
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  String _resolveFirstName(User user) {
    final value = user.userMetadata?['first_name'];
    if (value is String && value.trim().isNotEmpty) return value.trim();

    final legacyName = user.userMetadata?['name'];
    if (legacyName is String && legacyName.trim().isNotEmpty) {
      return legacyName.trim().split(RegExp(r'\s+')).first;
    }

    return 'Usuario';
  }

  String _resolveLastName(User user) {
    final value = user.userMetadata?['last_name'];
    if (value is String && value.trim().isNotEmpty) return value.trim();

    final legacyName = user.userMetadata?['name'];
    if (legacyName is String && legacyName.trim().isNotEmpty) {
      final parts = legacyName.trim().split(RegExp(r'\s+'));
      if (parts.length > 1) return parts.sublist(1).join(' ');
    }

    return 'SUS';
  }

  DateTime? _resolveBirthDate(User user) {
    final value = user.userMetadata?['birth_date'];
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _resolveTokenExpiry(Session session) {
    final expiresAt = session.expiresAt;
    if (expiresAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  }

  ProfessionalType _mapStringToProfessionalType(String? value) {
    return ProfessionalType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProfessionalType.administrativo,
    );
  }

  String _formatBirthDate(DateTime birthDate) {
    final yyyy = birthDate.year.toString().padLeft(4, '0');
    final mm = birthDate.month.toString().padLeft(2, '0');
    final dd = birthDate.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
