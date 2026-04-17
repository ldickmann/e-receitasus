import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/professional_type.dart';

abstract class IAuthService {
  Future<UserModel> login(String email, String password);

  /// Cadastra profissional de saúde com dados do conselho.
  /// Utilizado pela RegisterScreen (médicos, enfermeiros, dentistas, etc.).
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

  /// Cadastra paciente com dados de saúde básicos.
  /// Utilizado pela PatientRegisterScreen — fluxo BaaS:
  /// signUp → trigger cria User(PACIENTE) → update via PostgREST se houver sessão.
  Future<UserModel> registerPatient({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime birthDate,
    required String password,
    String? cns,
    String? phone,
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

  /// Cadastra paciente via Supabase Auth (BaaS).
  ///
  /// Fluxo:
  /// 1. signUp com metadata (first_name, last_name, birth_date, professional_type=PACIENTE)
  /// 2. O trigger `handle_new_user` cria o registro em public.User automaticamente
  /// 3. Se o Supabase retornar sessão imediata (confirmação de e-mail desabilitada),
  ///    atualiza campos complementares (birthDate, cns, phone) via PostgREST
  /// 4. Se sessão for null (e-mail pendente de confirmação), os campos opcionais
  ///    ficarão null até o usuário completar o perfil — comportamento aceitável
  @override
  Future<UserModel> registerPatient({
    required String firstName,
    required String lastName,
    required String email,
    required DateTime birthDate,
    required String password,
    String? cns,
    String? phone,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: {
          // snake_case — compatível com o trigger `handle_new_user` que lê esta chave
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'birth_date': _formatBirthDate(birthDate),
          // Instrui o trigger a criar o User como PACIENTE (sem conselho)
          'professional_type': 'PACIENTE',
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Cadastro não retornou usuário. Verifique o e-mail.');
      }

      // Atualiza campos complementares apenas quando há sessão ativa.
      // Sem sessão (e-mail pendente), o trigger já criou o User; campos opcionais
      // serão atualizados via tela de perfil quando o usuário confirmar o e-mail.
      if (response.session != null) {
        final updates = <String, dynamic>{
          'birthDate': _formatBirthDate(birthDate),
          if (cns != null && cns.trim().isNotEmpty) 'cns': cns.trim(),
          if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
        };
        // Usa o nome canônico da tabela com aspas — PostgREST do Supabase requer
        // o nome exato conforme definido no schema Prisma ('User' com U maiúsculo)
        await _supabase.from('User').update(updates).eq('id', user.id);
      }

      return UserModel(
        id: user.id,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().toLowerCase(),
        birthDate: birthDate,
        professionalType: ProfessionalType.paciente,
        cns: cns?.trim().isEmpty == true ? null : cns?.trim(),
        phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    } catch (e) {
      // Relança sem expor detalhes internos — mensagem genérica protege stack trace
      if (e is Exception) rethrow;
      throw Exception('Ocorreu um erro inesperado no cadastro de paciente.');
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
