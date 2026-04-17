import 'professional_type.dart';

/// Modelo imutável do usuário — espelha os campos relevantes de public.User.
///
/// Campos de paciente (cns..addressState) são opcionais e só são preenchidos
/// quando professionalType == ProfessionalType.paciente. Para demais perfis
/// esses campos ficam nulos e não são exibidos nem enviados ao banco.
class UserModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime? birthDate;
  final ProfessionalType professionalType;
  final String? professionalId;
  final String? professionalState;
  final String? specialty;
  final String? token;
  final DateTime? tokenExpiry;

  // -----------------------------------------------------------------------
  // Campos exclusivos de paciente — sincronizados via PostgREST (RLS)
  // -----------------------------------------------------------------------

  /// Cartão Nacional de Saúde — 15 dígitos
  final String? cns;

  /// CPF — 11 dígitos sem formatação (constraint unique no banco)
  final String? cpf;

  /// Nome Social — não substitui nome civil em documentos oficiais
  final String? socialName;

  /// Nome da mãe ou, na ausência, do pai/responsável legal
  final String? motherParentName;

  /// Cidade de nascimento
  final String? birthCity;

  /// UF de nascimento — 2 caracteres
  final String? birthState;

  /// Sexo conforme declarado pelo paciente
  final String? gender;

  /// Raça/Cor conforme classificação IBGE
  final String? ethnicity;

  /// Estado civil
  final String? maritalStatus;

  /// Celular com DDD — 11 dígitos
  final String? phone;

  /// Escolaridade
  final String? education;

  /// CEP — 8 dígitos sem hífen
  final String? zipCode;

  /// Logradouro
  final String? street;

  /// Número do endereço
  final String? streetNumber;

  /// Complemento opcional
  final String? complement;

  /// Bairro
  final String? district;

  /// Cidade do endereço atual
  final String? addressCity;

  /// UF do endereço atual — 2 caracteres
  final String? addressState;

  UserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.birthDate,
    this.professionalType = ProfessionalType.administrativo,
    this.professionalId,
    this.professionalState,
    this.specialty,
    this.token,
    this.tokenExpiry,
    // Campos de paciente — todos opcionais para compatibilidade com perfis profissionais
    this.cns,
    this.cpf,
    this.socialName,
    this.motherParentName,
    this.birthCity,
    this.birthState,
    this.gender,
    this.ethnicity,
    this.maritalStatus,
    this.phone,
    this.education,
    this.zipCode,
    this.street,
    this.streetNumber,
    this.complement,
    this.district,
    this.addressCity,
    this.addressState,
  });

  String get name {
    final full = '$firstName $lastName'.trim();
    return full.isEmpty ? 'Usuario SUS' : full;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final legacyName = (json['name'] as String? ?? '').trim();
    final firstName =
        ((json['firstName'] ?? json['first_name']) as String? ?? '').trim();
    final lastName =
        ((json['lastName'] ?? json['last_name']) as String? ?? '').trim();

    final resolvedFirstName =
        firstName.isNotEmpty ? firstName : _splitFirstName(legacyName);
    final resolvedLastName =
        lastName.isNotEmpty ? lastName : _splitLastName(legacyName);

    return UserModel(
      id: (json['id'] as String? ?? '').trim(),
      firstName: resolvedFirstName,
      lastName: resolvedLastName,
      email: (json['email'] as String? ?? '').trim(),
      birthDate: _parseDate(json['birthDate'] ?? json['birth_date']),
      professionalType: json['professionalType'] != null
          ? ProfessionalType.fromString(json['professionalType'] as String)
          : json['professional_type'] != null
              ? ProfessionalType.fromString(json['professional_type'] as String)
              : ProfessionalType.administrativo,
      professionalId: json['professionalId'] as String? ??
          json['professional_id'] as String?,
      professionalState: json['professionalState'] as String? ??
          json['professional_state'] as String?,
      specialty: json['specialty'] as String?,
      token: json['token'] as String?,
      tokenExpiry: _parseDate(json['tokenExpiry'] ?? json['token_expiry']),
      // Campos de paciente — chaves camelCase conforme exposto pelo PostgREST
      cns: json['cns'] as String?,
      cpf: json['cpf'] as String?,
      socialName: json['socialName'] as String?,
      motherParentName: json['motherParentName'] as String?,
      birthCity: json['birthCity'] as String?,
      birthState: json['birthState'] as String?,
      gender: json['gender'] as String?,
      ethnicity: json['ethnicity'] as String?,
      maritalStatus: json['maritalStatus'] as String?,
      phone: json['phone'] as String?,
      education: json['education'] as String?,
      zipCode: json['zipCode'] as String?,
      street: json['street'] as String?,
      streetNumber: json['streetNumber'] as String?,
      complement: json['complement'] as String?,
      district: json['district'] as String?,
      addressCity: json['addressCity'] as String?,
      addressState: json['addressState'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstName': firstName,
      'lastName': lastName,
      'name': name,
      'email': email,
      'birthDate': birthDate?.toIso8601String(),
      'professionalType': professionalType.value,
      'professionalId': professionalId,
      'professionalState': professionalState,
      'specialty': specialty,
      'token': token,
      'tokenExpiry': tokenExpiry?.toIso8601String(),
      // Inclui campos de paciente apenas se preenchidos para não poluir o JSON
      if (cns != null) 'cns': cns,
      if (cpf != null) 'cpf': cpf,
      if (socialName != null) 'socialName': socialName,
      if (motherParentName != null) 'motherParentName': motherParentName,
      if (birthCity != null) 'birthCity': birthCity,
      if (birthState != null) 'birthState': birthState,
      if (gender != null) 'gender': gender,
      if (ethnicity != null) 'ethnicity': ethnicity,
      if (maritalStatus != null) 'maritalStatus': maritalStatus,
      if (phone != null) 'phone': phone,
      if (education != null) 'education': education,
      if (zipCode != null) 'zipCode': zipCode,
      if (street != null) 'street': street,
      if (streetNumber != null) 'streetNumber': streetNumber,
      if (complement != null) 'complement': complement,
      if (district != null) 'district': district,
      if (addressCity != null) 'addressCity': addressCity,
      if (addressState != null) 'addressState': addressState,
    };
  }

  bool get isTokenValid {
    if (token == null || tokenExpiry == null) return false;
    return DateTime.now().isBefore(tokenExpiry!);
  }

  String? get formattedRegistration {
    if (professionalId == null || professionalId!.trim().isEmpty) return null;
    if (professionalState != null && professionalState!.trim().isNotEmpty) {
      return '${professionalId!}-${professionalState!}';
    }
    return professionalId;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String _splitFirstName(String fullName) {
    final parts =
        fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'Usuario';
    return parts.first;
  }

  static String _splitLastName(String fullName) {
    final parts =
        fullName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length <= 1) return 'SUS';
    return parts.sublist(1).join(' ');
  }
}