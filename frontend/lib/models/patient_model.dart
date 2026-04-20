import 'professional_type.dart';

/// Modelo imutável de paciente SUS — mapeado para public.patients.
///
/// Separado de [UserModel] e [ProfessionalModel] pela migration
/// 20260421000000_split_user_patients_professionals. Contém todos os
/// campos clínicos (CNS, CPF, dados demográficos) que são exclusivos
/// do domínio de pacientes e não devem ser expostos a profissionais.
class PatientModel {
  /// UUID do paciente — correspondente ao auth.users.id do Supabase.
  final String id;

  /// Primeiro nome (pode ser null se ainda não sincronizado pelo trigger).
  final String? firstName;

  /// Sobrenome.
  final String? lastName;

  /// Nome completo — campo desnormalizado para buscas rápidas.
  final String name;

  /// E-mail proveniente do auth.users.
  final String email;

  /// Data de nascimento.
  final DateTime? birthDate;

  /// Cartão Nacional de Saúde — 15 dígitos.
  final String? cns;

  /// CPF — 11 dígitos sem formatação (constraint UNIQUE no banco).
  final String? cpf;

  /// Nome social declarado pelo paciente.
  final String? socialName;

  /// Nome da mãe (ou responsável legal).
  final String? motherParentName;

  /// Sexo conforme declarado pelo paciente.
  final String? gender;

  /// Raça/Cor conforme classificação IBGE.
  final String? ethnicity;

  /// Estado civil.
  final String? maritalStatus;

  /// Celular com DDD — 11 dígitos.
  final String? phone;

  /// Escolaridade.
  final String? education;

  /// Cidade de nascimento.
  final String? birthCity;

  /// UF de nascimento — 2 caracteres.
  final String? birthState;

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

  /// UUID da UBS vinculada (atribuído pelo trigger auto_assign_patient_health_unit).
  final String? healthUnitId;

  /// Data de criação do registro.
  final DateTime? createdAt;

  /// Data da última atualização.
  final DateTime? updatedAt;

  /// Sempre true — permite type narrowing simples sem instanceof.
  bool get isPatient => true;

  /// professionalType derivado — pacientes não têm tipo de conselho.
  ProfessionalType get professionalType => ProfessionalType.paciente;

  const PatientModel({
    required this.id,
    required this.name,
    required this.email,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.cns,
    this.cpf,
    this.socialName,
    this.motherParentName,
    this.gender,
    this.ethnicity,
    this.maritalStatus,
    this.phone,
    this.education,
    this.birthCity,
    this.birthState,
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

  /// Getter de nome de exibição — usa socialName quando disponível (dignidade do paciente).
  String get displayName {
    if (socialName != null && socialName!.trim().isNotEmpty) {
      return socialName!.trim();
    }
    final full = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return full.isNotEmpty ? full : name;
  }

  /// Constrói a partir do JSON retornado pelo PostgREST.
  /// Aceita tanto camelCase (PostgREST padrão) quanto snake_case.
  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      email: (json['email'] as String? ?? '').trim(),
      firstName: json['firstName'] as String? ?? json['first_name'] as String?,
      lastName: json['lastName'] as String? ?? json['last_name'] as String?,
      birthDate: _parseDate(json['birthDate'] ?? json['birth_date']),
      cns: json['cns'] as String?,
      cpf: json['cpf'] as String?,
      socialName:
          json['socialName'] as String? ?? json['social_name'] as String?,
      motherParentName: json['motherParentName'] as String? ??
          json['mother_parent_name'] as String?,
      gender: json['gender'] as String?,
      ethnicity: json['ethnicity'] as String?,
      maritalStatus:
          json['maritalStatus'] as String? ?? json['marital_status'] as String?,
      phone: json['phone'] as String?,
      education: json['education'] as String?,
      birthCity: json['birthCity'] as String? ?? json['birth_city'] as String?,
      birthState:
          json['birthState'] as String? ?? json['birth_state'] as String?,
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

  /// Serializa para JSON — omite campos nulos para evitar sobrescrever dados no banco.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
      if (cns != null) 'cns': cns,
      if (cpf != null) 'cpf': cpf,
      if (socialName != null) 'socialName': socialName,
      if (motherParentName != null) 'motherParentName': motherParentName,
      if (gender != null) 'gender': gender,
      if (ethnicity != null) 'ethnicity': ethnicity,
      if (maritalStatus != null) 'maritalStatus': maritalStatus,
      if (phone != null) 'phone': phone,
      if (education != null) 'education': education,
      if (birthCity != null) 'birthCity': birthCity,
      if (birthState != null) 'birthState': birthState,
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
