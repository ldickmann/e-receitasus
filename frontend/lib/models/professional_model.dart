import 'professional_type.dart';

/// Modelo imutável de profissional de saúde/administrativo.
/// Mapeado para public.professionals (separado de public.patients na
/// migration 20260421000000_split_user_patients_professionals).
///
/// Não contém campos clínicos de paciente (CNS, CPF, dados demográficos)
/// — mantém separação de domínios e minimiza exposição de PII (LGPD).
class ProfessionalModel {
  /// UUID do profissional — correspondente ao auth.users.id do Supabase.
  final String id;

  /// Primeiro nome.
  final String? firstName;

  /// Sobrenome.
  final String? lastName;

  /// Nome completo — campo desnormalizado para buscas rápidas.
  final String name;

  /// E-mail proveniente do auth.users.
  final String email;

  /// Data de nascimento.
  final DateTime? birthDate;

  /// Tipo de atuação — determina permissões e fluxo de cadastro.
  final ProfessionalType professionalType;

  /// Número de registro no conselho (CRM, COREN etc.).
  final String? professionalId;

  /// UF do conselho — 2 caracteres.
  final String? professionalState;

  /// Especialidade clínica (ex: "Clínica Geral", "Enfermagem").
  final String? specialty;

  /// CEP — 8 dígitos sem hífen.
  final String? zipCode;

  /// Logradouro.
  final String? street;

  /// Número do endereço.
  final String? streetNumber;

  /// Complemento.
  final String? complement;

  /// Bairro.
  final String? district;

  /// Cidade do endereço atual.
  final String? addressCity;

  /// UF do endereço atual — 2 caracteres.
  final String? addressState;

  /// UUID da UBS vinculada.
  final String? healthUnitId;

  /// Data de criação do registro.
  final DateTime? createdAt;

  /// Data da última atualização.
  final DateTime? updatedAt;

  const ProfessionalModel({
    required this.id,
    required this.name,
    required this.email,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.professionalType = ProfessionalType.administrativo,
    this.professionalId,
    this.professionalState,
    this.specialty,
    this.zipCode,
    this.street,
    this.streetNumber,
    this.complement,
    this.district,
    this.addressCity,
    this.addressState,
    this.healthUnitId,
    this.createdAt,
    this.updatedAt,
  });

  /// Registro formatado para exibição: "CRM 12345-SP" ou "COREN 67890-RJ".
  /// Retorna null quando o profissional não possui número de conselho.
  String? get formattedRegistration {
    if (professionalId == null || professionalId!.trim().isEmpty) return null;

    // Determina o prefixo pelo tipo de profissional
    final prefix = switch (professionalType) {
      ProfessionalType.medico => 'CRM',
      ProfessionalType.enfermeiro => 'COREN',
      _ => 'REG',
    };

    final state = professionalState?.trim().toUpperCase();
    if (state != null && state.isNotEmpty) {
      return '$prefix ${professionalId!.trim()}-$state';
    }
    return '$prefix ${professionalId!.trim()}';
  }

  /// Constrói a partir do JSON retornado pelo PostgREST.
  /// Aceita tanto camelCase (PostgREST padrão) quanto snake_case.
  factory ProfessionalModel.fromJson(Map<String, dynamic> json) {
    return ProfessionalModel(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      firstName: json['firstName'] as String? ?? json['first_name'] as String?,
      lastName: json['lastName'] as String? ?? json['last_name'] as String?,
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
      zipCode: json['zipCode'] as String? ?? json['zip_code'] as String?,
      street: json['street'] as String?,
      streetNumber:
          json['streetNumber'] as String? ?? json['street_number'] as String?,
      complement: json['complement'] as String?,
      district: json['district'] as String?,
      addressCity:
          json['addressCity'] as String? ?? json['address_city'] as String?,
      addressState:
          json['addressState'] as String? ?? json['address_state'] as String?,
      healthUnitId:
          json['healthUnitId'] as String? ?? json['health_unit_id'] as String?,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: _parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  /// Serializa para JSON — omite campos nulos.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
      'professionalType': professionalType.value,
      if (professionalId != null) 'professionalId': professionalId,
      if (professionalState != null) 'professionalState': professionalState,
      if (specialty != null) 'specialty': specialty,
      if (zipCode != null) 'zipCode': zipCode,
      if (street != null) 'street': street,
      if (streetNumber != null) 'streetNumber': streetNumber,
      if (complement != null) 'complement': complement,
      if (district != null) 'district': district,
      if (addressCity != null) 'addressCity': addressCity,
      if (addressState != null) 'addressState': addressState,
      if (healthUnitId != null) 'healthUnitId': healthUnitId,
    };
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
