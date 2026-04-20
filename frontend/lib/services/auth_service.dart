import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/professional_type.dart';

abstract class IAuthService {
  Future<UserModel> login(String email, String password);

  /// Cadastra profissional de saúde com dados do conselho e endereço opcional.
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
    // Campos de endereço — opcionais, preenchidos via ViaCEP ou manual
    String? zipCode,
    String? street,
    String? streetNumber,
    String? complement,
    String? district,
    String? addressCity,
    String? addressState,
  });

  /// Cadastra paciente com todos os dados pessoais, de saúde e endereço.
  /// Utilizado pela PatientRegisterScreen — fluxo BaaS:
  /// signUp → trigger cria User(PACIENTE) → update via PostgREST se houver sessão.
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
    // Campos de endereço — opcionais
    String? zipCode,
    String? street,
    String? streetNumber,
    String? complement,
    String? district,
    String? addressCity,
    String? addressState,
  }) async {
    try {
      final cleanFirstName = firstName.trim();
      final cleanLastName = lastName.trim();
      final cleanEmail = email.trim().toLowerCase();
      final cleanProfessionalId = professionalId?.trim();

      // Enviamos TODOS os campos no metadata para o trigger `handle_new_user`
      // criar o registro completo em public.professionals em uma unica operacao,
      // mesmo com confirmacao de e-mail habilitada (sem sessao imediata).
      final response = await _supabase.auth.signUp(
        email: cleanEmail,
        password: password,
        data: <String, dynamic>{
          'name': '$cleanFirstName $cleanLastName'.trim(),
          'first_name': cleanFirstName,
          'last_name': cleanLastName,
          'birth_date': _formatBirthDate(birthDate),
          'professional_type': professionalType.value,
          if (_notEmpty(cleanProfessionalId))
            'professional_id': cleanProfessionalId,
          if (_notEmpty(professionalState))
            'professional_state': professionalState!.trim().toUpperCase(),
          if (_notEmpty(specialty)) 'specialty': specialty!.trim(),
          if (_notEmpty(zipCode)) 'zip_code': zipCode!.trim(),
          if (_notEmpty(street)) 'street': street!.trim(),
          if (_notEmpty(streetNumber)) 'street_number': streetNumber!.trim(),
          if (_notEmpty(complement)) 'complement': complement!.trim(),
          if (_notEmpty(district)) 'district': district!.trim(),
          if (_notEmpty(addressCity)) 'address_city': addressCity!.trim(),
          if (_notEmpty(addressState))
            'address_state': addressState!.trim().toUpperCase(),
        },
      );

      final user = response.user;
      if (user == null) {
        throw Exception('Erro ao criar conta no Supabase Auth.');
      }

      // Atualiza campos de endereço via PostgREST quando há sessão imediata.
      // Sem sessão (e-mail pendente de confirmação), o profissional poderá
      // preencher o endereço via tela de perfil após confirmar o e-mail.
      if (response.session != null) {
        final updates = <String, dynamic>{
          'birthDate': _formatBirthDate(birthDate),
          if (_notEmpty(zipCode)) 'zipCode': zipCode!.trim(),
          if (_notEmpty(street)) 'street': street!.trim(),
          if (_notEmpty(streetNumber)) 'streetNumber': streetNumber!.trim(),
          if (_notEmpty(complement)) 'complement': complement!.trim(),
          if (_notEmpty(district)) 'district': district!.trim(),
          if (_notEmpty(addressCity)) 'addressCity': addressCity!.trim(),
          if (_notEmpty(addressState))
            'addressState': addressState!.trim().toUpperCase(),
        };
        // Tabela separada por domínio: profissionais → public.professionals
        // (migration 20260421000000_split_user_patients_professionals)
        await _supabase.from('professionals').update(updates).eq('id', user.id);
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
        zipCode: _notEmpty(zipCode) ? zipCode!.trim() : null,
        street: _notEmpty(street) ? street!.trim() : null,
        streetNumber: _notEmpty(streetNumber) ? streetNumber!.trim() : null,
        complement: _notEmpty(complement) ? complement!.trim() : null,
        district: _notEmpty(district) ? district!.trim() : null,
        addressCity: _notEmpty(addressCity) ? addressCity!.trim() : null,
        addressState:
            _notEmpty(addressState) ? addressState!.trim().toUpperCase() : null,
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
  ///    atualiza todos os campos complementares via PostgREST em uma única chamada
  /// 4. Se sessão for null (e-mail pendente de confirmação), os campos opcionais
  ///    ficarão null até o usuário completar o perfil — comportamento aceitável
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
  }) async {
    try {
      // Enviamos TODOS os campos no metadata do signUp (snake_case) porque o
      // trigger `handle_new_user` ja sabe ler todas estas chaves no INSERT.
      // Vantagem: funciona mesmo quando o Supabase exige confirmacao de e-mail
      // (response.session == null) — sem isso, campos opcionais ficavam NULL.
      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
        data: <String, dynamic>{
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'birth_date': _formatBirthDate(birthDate),
          'professional_type': 'PACIENTE',
          'phone': phone.trim(),
          if (_notEmpty(cns)) 'cns': cns!.trim(),
          if (_notEmpty(cpf)) 'cpf': cpf!.trim(),
          if (_notEmpty(socialName)) 'social_name': socialName!.trim(),
          if (_notEmpty(motherParentName))
            'mother_parent_name': motherParentName!.trim(),
          if (_notEmpty(gender)) 'gender': gender!.trim(),
          if (_notEmpty(ethnicity)) 'ethnicity': ethnicity!.trim(),
          if (_notEmpty(maritalStatus)) 'marital_status': maritalStatus!.trim(),
          if (_notEmpty(education)) 'education': education!.trim(),
          if (_notEmpty(birthCity)) 'birth_city': birthCity!.trim(),
          if (_notEmpty(birthState))
            'birth_state': birthState!.trim().toUpperCase(),
          if (_notEmpty(zipCode)) 'zip_code': zipCode!.trim(),
          if (_notEmpty(street)) 'street': street!.trim(),
          if (_notEmpty(streetNumber)) 'street_number': streetNumber!.trim(),
          if (_notEmpty(complement)) 'complement': complement!.trim(),
          if (_notEmpty(district)) 'district': district!.trim(),
          if (_notEmpty(addressCity)) 'address_city': addressCity!.trim(),
          if (_notEmpty(addressState))
            'address_state': addressState!.trim().toUpperCase(),
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
        // Monta o mapa apenas com valores não-nulos/não-vazios para evitar
        // sobrescrever valores existentes no banco com null acidentalmente
        final updates = <String, dynamic>{
          'birthDate': _formatBirthDate(birthDate),
          'phone': phone.trim(),
          if (_notEmpty(cns)) 'cns': cns!.trim(),
          if (_notEmpty(cpf)) 'cpf': cpf!.trim(),
          if (_notEmpty(socialName)) 'socialName': socialName!.trim(),
          if (_notEmpty(motherParentName))
            'motherParentName': motherParentName!.trim(),
          if (_notEmpty(birthCity)) 'birthCity': birthCity!.trim(),
          if (_notEmpty(birthState))
            'birthState': birthState!.trim().toUpperCase(),
          if (_notEmpty(gender)) 'gender': gender!.trim(),
          if (_notEmpty(ethnicity)) 'ethnicity': ethnicity!.trim(),
          if (_notEmpty(maritalStatus)) 'maritalStatus': maritalStatus!.trim(),
          if (_notEmpty(education)) 'education': education!.trim(),
          if (_notEmpty(zipCode)) 'zipCode': zipCode!.trim(),
          if (_notEmpty(street)) 'street': street!.trim(),
          if (_notEmpty(streetNumber)) 'streetNumber': streetNumber!.trim(),
          if (_notEmpty(complement)) 'complement': complement!.trim(),
          if (_notEmpty(district)) 'district': district!.trim(),
          if (_notEmpty(addressCity)) 'addressCity': addressCity!.trim(),
          if (_notEmpty(addressState))
            'addressState': addressState!.trim().toUpperCase(),
        };
        // Tabela separada por domínio: pacientes → public.patients
        // (migration 20260421000000_split_user_patients_professionals)
        await _supabase.from('patients').update(updates).eq('id', user.id);
      }

      return UserModel(
        id: user.id,
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        email: email.trim().toLowerCase(),
        birthDate: birthDate,
        professionalType: ProfessionalType.paciente,
        phone: phone.trim(),
        cns: _notEmpty(cns) ? cns!.trim() : null,
        cpf: _notEmpty(cpf) ? cpf!.trim() : null,
        socialName: _notEmpty(socialName) ? socialName!.trim() : null,
        motherParentName:
            _notEmpty(motherParentName) ? motherParentName!.trim() : null,
        birthCity: _notEmpty(birthCity) ? birthCity!.trim() : null,
        birthState:
            _notEmpty(birthState) ? birthState!.trim().toUpperCase() : null,
        gender: _notEmpty(gender) ? gender!.trim() : null,
        ethnicity: _notEmpty(ethnicity) ? ethnicity!.trim() : null,
        maritalStatus: _notEmpty(maritalStatus) ? maritalStatus!.trim() : null,
        education: _notEmpty(education) ? education!.trim() : null,
        zipCode: _notEmpty(zipCode) ? zipCode!.trim() : null,
        street: _notEmpty(street) ? street!.trim() : null,
        streetNumber: _notEmpty(streetNumber) ? streetNumber!.trim() : null,
        complement: _notEmpty(complement) ? complement!.trim() : null,
        district: _notEmpty(district) ? district!.trim() : null,
        addressCity: _notEmpty(addressCity) ? addressCity!.trim() : null,
        addressState:
            _notEmpty(addressState) ? addressState!.trim().toUpperCase() : null,
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

  /// Verifica se uma string opcional tem valor não-vazio.
  /// Evita repetição de null-check + isEmpty em todo o update map.
  bool _notEmpty(String? value) => value != null && value.trim().isNotEmpty;

  String _formatBirthDate(DateTime birthDate) {
    final yyyy = birthDate.year.toString().padLeft(4, '0');
    final mm = birthDate.month.toString().padLeft(2, '0');
    final dd = birthDate.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }
}
