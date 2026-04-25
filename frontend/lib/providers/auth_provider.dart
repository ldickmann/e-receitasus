import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/professional_type.dart';
import '../services/auth_service.dart';
import '../services/auth_exceptions.dart';

/// Resultado de uma operação de cadastro.
///
/// Distinguir os 3 estados é essencial porque a UI deve reagir de forma
/// diferente em cada um — em especial, NÃO orientar o usuário a tentar
/// novamente quando o usuário já foi criado em auth.users (sucesso parcial).
enum RegistrationOutcome {
  /// Cadastro completo: usuário criado em auth.users + perfil persistido.
  success,

  /// Usuário criado em auth.users, mas update do perfil falhou. NÃO é seguro
  /// pedir ao usuário para repetir o signUp (geraria erro "e-mail em uso").
  /// UI deve orientar a fazer login e completar o perfil.
  profileIncomplete,

  /// Falha real antes do signUp (ou no próprio signUp). Usuário não foi
  /// criado — UI pode pedir para corrigir os dados e tentar novamente.
  failure,
}

class AuthProvider with ChangeNotifier {
  final IAuthService _authService;

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authService);

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<void> initAuth() async {
    _setLoading(true);

    try {
      final session = Supabase.instance.client.auth.currentSession;
      final user = Supabase.instance.client.auth.currentUser;

      if (session != null && user != null && user.email != null) {
        final metadata = user.userMetadata ?? <String, dynamic>{};

        final firstName = _safeString(
          metadata['first_name'],
          fallback: _splitFirstName(
              _safeString(metadata['name'], fallback: 'Usuario SUS')),
        );

        final lastName = _safeString(
          metadata['last_name'],
          fallback: _splitLastName(
              _safeString(metadata['name'], fallback: 'Usuario SUS')),
        );

        _user = UserModel(
          id: user.id,
          firstName: firstName,
          lastName: lastName,
          email: user.email!,
          birthDate: _parseDate(metadata['birth_date']),
          professionalType:
              _parseProfessionalType(metadata['professional_type']),
          professionalId: _nullableString(metadata['professional_id']),
          professionalState: _nullableString(metadata['professional_state']),
          specialty: _nullableString(metadata['specialty']),
          token: session.accessToken,
          tokenExpiry: _parseTokenExpiry(session.expiresAt),
        );
      }
    } catch (e) {
      _errorMessage = 'Erro ao recuperar sessao: ${e.toString()}';
      debugPrint('Erro initAuth: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.login(email, password);
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _user = null;
      _setLoading(false);
      return false;
    }
  }

  /// Delega cadastro de profissional ao service e atualiza estado.
  ///
  /// Retorna [RegistrationOutcome] tripartido:
  /// - [RegistrationOutcome.success] quando tudo deu certo;
  /// - [RegistrationOutcome.profileIncomplete] quando o usuário foi criado em
  ///   auth.users mas o update em public.professionals falhou (sucesso parcial);
  /// - [RegistrationOutcome.failure] quando a falha ocorreu antes/durante o
  ///   signUp e o usuário NÃO foi criado.
  Future<RegistrationOutcome> registerWithProfessionalInfo({
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
  }) async {
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.registerWithProfessionalInfo(
        firstName: firstName,
        lastName: lastName,
        email: email,
        birthDate: birthDate,
        password: password,
        professionalType: professionalType,
        professionalId: professionalId,
        professionalState: professionalState,
        specialty: specialty,
        zipCode: zipCode,
        street: street,
        streetNumber: streetNumber,
        complement: complement,
        district: district,
        addressCity: addressCity,
        addressState: addressState,
      );

      _setLoading(false);
      return RegistrationOutcome.success;
    } on RegisterException catch (e) {
      // Falha real pré-signUp — usuário NÃO foi criado.
      _errorMessage = e.userMessage;
      _user = null;
      _setLoading(false);
      return RegistrationOutcome.failure;
    } on ProfileIncompleteException catch (_) {
      // Sucesso parcial — auth.users já tem o usuário; orientar a fazer login.
      _errorMessage =
          'Conta criada com sucesso. Faça login e complete seus dados quando solicitado.';
      _user = null;
      _setLoading(false);
      return RegistrationOutcome.profileIncomplete;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _user = null;
      _setLoading(false);
      return RegistrationOutcome.failure;
    }
  }

  /// Delega cadastro de paciente ao service e atualiza estado.
  ///
  /// Fluxo BaaS: service chama signUp no Supabase → trigger cria User(PACIENTE)
  /// → service atualiza todos os campos via PostgREST se houver sessão imediata.
  /// Retorna [RegistrationOutcome] tripartido (ver doc do método de profissional).
  Future<RegistrationOutcome> registerPatient({
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
    _setLoading(true);
    _clearError();

    try {
      _user = await _authService.registerPatient(
        firstName: firstName,
        lastName: lastName,
        email: email,
        birthDate: birthDate,
        password: password,
        phone: phone,
        cns: cns,
        cpf: cpf,
        socialName: socialName,
        motherParentName: motherParentName,
        birthCity: birthCity,
        birthState: birthState,
        gender: gender,
        ethnicity: ethnicity,
        maritalStatus: maritalStatus,
        education: education,
        zipCode: zipCode,
        street: street,
        streetNumber: streetNumber,
        complement: complement,
        district: district,
        addressCity: addressCity,
        addressState: addressState,
      );

      _setLoading(false);
      return RegistrationOutcome.success;
    } on RegisterException catch (e) {
      // Falha real pré-signUp — usuário NÃO foi criado.
      _errorMessage = e.userMessage;
      _user = null;
      _setLoading(false);
      return RegistrationOutcome.failure;
    } on ProfileIncompleteException catch (_) {
      // Sucesso parcial — auth.users já tem o usuário; orientar a fazer login.
      _errorMessage =
          'Conta criada com sucesso. Faça login e complete seus dados quando solicitado.';
      _user = null;
      _setLoading(false);
      return RegistrationOutcome.profileIncomplete;
    } catch (e) {
      _errorMessage = _parseErrorMessage(e);
      _user = null;
      _setLoading(false);
      return RegistrationOutcome.failure;
    }
  }

  Future<void> logout() async {
    try {
      await _authService.logout();
      _user = null;
      _clearError();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro no logout: $e');
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void clearError() {
    _clearError();
    notifyListeners();
  }

  String _parseErrorMessage(Object error) {
    // LGPD: NÃO logar `error` cru — pode conter e-mail/CPF em mensagens do Supabase.
    if (error is AuthException) {
      if (error.message.contains('Database error saving new user')) {
        return 'Erro interno ao sincronizar cadastro no banco. Verifique trigger SQL no Supabase.';
      }
      return error.message;
    }

    final e = error.toString();

    if (e.contains('Invalid login credentials')) {
      return 'E-mail ou senha incorretos.';
    }
    if (e.contains('User already registered')) {
      return 'Este e-mail ja esta em uso.';
    }
    if (e.contains('weak_password')) {
      return 'Senha fraca. Use pelo menos 8 caracteres com letras, numero e simbolo.';
    }
    if (e.contains('network') ||
        e.contains('SocketException') ||
        e.contains('Failed to fetch')) {
      return 'Erro de conexao. Verifique internet, URL do Supabase e CORS.';
    }

    return 'Ocorreu um erro. Tente novamente em instantes.';
  }

  String _safeString(dynamic value, {required String fallback}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  String? _nullableString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }

  DateTime? _parseTokenExpiry(int? expiresAt) {
    if (expiresAt == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
  }

  ProfessionalType _parseProfessionalType(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      return ProfessionalType.fromString(value.trim());
    }
    return ProfessionalType.administrativo;
  }

  String _splitFirstName(String fullName) {
    final parts =
        fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Usuario';
    return parts.first;
  }

  String _splitLastName(String fullName) {
    final parts =
        fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) return 'SUS';
    return parts.sublist(1).join(' ');
  }
}
