import 'prescription_type.dart';

/// Modelo completo de uma prescrição médica digital conforme padrões ANVISA.
///
/// Suporta os 4 tipos de receitas regulamentadas pela Portaria SVS/MS 344/98
/// e RDC 471/2021: Branca, Controle Especial, Amarela e Azul.
class PrescriptionModel {
  final String? id;
  final PrescriptionType type;

  // Dados do profissional prescritor
  final String doctorName;
  final String doctorCouncil; // CRM, CRO, etc.
  final String doctorCouncilState; // UF do conselho
  final String? doctorSpecialty;
  final String doctorAddress;
  final String doctorCity;
  final String doctorState;
  final String? doctorPhone;
  final String? doctorCnes; // Código CNES do estabelecimento (opcional)

  // Dados do estabelecimento de saúde
  final String? clinicName;
  final String? clinicCnpj;

  // Dados do paciente
  final String patientName;
  final String? patientCpf;
  final String? patientAddress;
  final String? patientCity;
  final String? patientState;
  final String? patientPhone;
  final String? patientAge;

  // Prescrição
  final String medicineName;
  final String dosage;
  final String? pharmaceuticalForm; // ex: comprimido, cápsula, solução
  final String? route; // ex: oral, sublingual, IV
  final String quantity; // quantidade numérica ex: "30 comprimidos"
  final String? quantityWords; // por extenso (obrigatório para amarela/azul)
  final String instructions; // posologia detalhada

  // Campos exclusivos para Notificações (Amarela/Azul)
  final String? notificationNumber; // número pré-impresso da Secretaria de Saúde
  final String? notificationUf; // UF emissora da numeração

  // Campos para receita contínua (RDC 471/2021 — Receita Branca)
  final bool isContinuousUse;
  final int? continuousValidityMonths; // até 6 meses via RDC 471/2021

  // Status e metadados
  final DateTime issuedAt;
  final DateTime validUntil;
  final String status; // 'ativa', 'utilizada', 'vencida', 'cancelada'

  // Referências de usuários no Supabase Auth
  final String? doctorUserId;
  final String? patientUserId;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const PrescriptionModel({
    this.id,
    required this.type,
    required this.doctorName,
    required this.doctorCouncil,
    required this.doctorCouncilState,
    this.doctorSpecialty,
    required this.doctorAddress,
    required this.doctorCity,
    required this.doctorState,
    this.doctorPhone,
    this.doctorCnes,
    this.clinicName,
    this.clinicCnpj,
    required this.patientName,
    this.patientCpf,
    this.patientAddress,
    this.patientCity,
    this.patientState,
    this.patientPhone,
    this.patientAge,
    required this.medicineName,
    required this.dosage,
    this.pharmaceuticalForm,
    this.route,
    required this.quantity,
    this.quantityWords,
    required this.instructions,
    this.notificationNumber,
    this.notificationUf,
    this.isContinuousUse = false,
    this.continuousValidityMonths,
    required this.issuedAt,
    required this.validUntil,
    this.status = 'ativa',
    this.doctorUserId,
    this.patientUserId,
    this.createdAt,
    this.updatedAt,
  });

  /// Cria um novo modelo com data de emissão = agora e validade calculada
  /// conforme o tipo de receita.
  factory PrescriptionModel.create({
    required PrescriptionType type,
    required String doctorName,
    required String doctorCouncil,
    required String doctorCouncilState,
    String? doctorSpecialty,
    required String doctorAddress,
    required String doctorCity,
    required String doctorState,
    String? doctorPhone,
    String? doctorCnes,
    String? clinicName,
    String? clinicCnpj,
    required String patientName,
    String? patientCpf,
    String? patientAddress,
    String? patientCity,
    String? patientState,
    String? patientPhone,
    String? patientAge,
    required String medicineName,
    required String dosage,
    String? pharmaceuticalForm,
    String? route,
    required String quantity,
    String? quantityWords,
    required String instructions,
    String? notificationNumber,
    String? notificationUf,
    bool isContinuousUse = false,
    int? continuousValidityMonths,
    String? doctorUserId,
    String? patientUserId,
  }) {
    final now = DateTime.now();
    final validityDays = isContinuousUse && type == PrescriptionType.branca
        ? (continuousValidityMonths ?? 6) * 30
        : type.validityDays;
    return PrescriptionModel(
      type: type,
      doctorName: doctorName,
      doctorCouncil: doctorCouncil,
      doctorCouncilState: doctorCouncilState,
      doctorSpecialty: doctorSpecialty,
      doctorAddress: doctorAddress,
      doctorCity: doctorCity,
      doctorState: doctorState,
      doctorPhone: doctorPhone,
      doctorCnes: doctorCnes,
      clinicName: clinicName,
      clinicCnpj: clinicCnpj,
      patientName: patientName,
      patientCpf: patientCpf,
      patientAddress: patientAddress,
      patientCity: patientCity,
      patientState: patientState,
      patientPhone: patientPhone,
      patientAge: patientAge,
      medicineName: medicineName,
      dosage: dosage,
      pharmaceuticalForm: pharmaceuticalForm,
      route: route,
      quantity: quantity,
      quantityWords: quantityWords,
      instructions: instructions,
      notificationNumber: notificationNumber,
      notificationUf: notificationUf,
      isContinuousUse: isContinuousUse,
      continuousValidityMonths: continuousValidityMonths,
      issuedAt: now,
      validUntil: now.add(Duration(days: validityDays)),
      status: 'ativa',
      doctorUserId: doctorUserId,
      patientUserId: patientUserId,
      createdAt: now,
    );
  }

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) {
    return PrescriptionModel(
      id: json['id'] as String?,
      type: PrescriptionType.fromString(json['type'] as String? ?? 'BRANCA'),
      doctorName: json['doctor_name'] as String? ?? '',
      doctorCouncil: json['doctor_council'] as String? ?? '',
      doctorCouncilState: json['doctor_council_state'] as String? ?? '',
      doctorSpecialty: json['doctor_specialty'] as String?,
      doctorAddress: json['doctor_address'] as String? ?? '',
      doctorCity: json['doctor_city'] as String? ?? '',
      doctorState: json['doctor_state'] as String? ?? '',
      doctorPhone: json['doctor_phone'] as String?,
      doctorCnes: json['doctor_cnes'] as String?,
      clinicName: json['clinic_name'] as String?,
      clinicCnpj: json['clinic_cnpj'] as String?,
      patientName: json['patient_name'] as String? ?? '',
      patientCpf: json['patient_cpf'] as String?,
      patientAddress: json['patient_address'] as String?,
      patientCity: json['patient_city'] as String?,
      patientState: json['patient_state'] as String?,
      patientPhone: json['patient_phone'] as String?,
      patientAge: json['patient_age'] as String?,
      medicineName: json['medicine_name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      pharmaceuticalForm: json['pharmaceutical_form'] as String?,
      route: json['route'] as String?,
      quantity: json['quantity'] as String? ?? '',
      quantityWords: json['quantity_words'] as String?,
      instructions: json['instructions'] as String? ?? '',
      notificationNumber: json['notification_number'] as String?,
      notificationUf: json['notification_uf'] as String?,
      isContinuousUse: json['is_continuous_use'] as bool? ?? false,
      continuousValidityMonths: json['continuous_validity_months'] as int?,
      issuedAt: _parseDate(json['issued_at']) ?? DateTime.now(),
      validUntil: _parseDate(json['valid_until']) ??
          DateTime.now().add(const Duration(days: 30)),
      status: json['status'] as String? ?? 'ativa',
      doctorUserId: json['doctor_user_id'] as String?,
      patientUserId: json['patient_user_id'] as String?,
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'type': type.value,
      'doctor_name': doctorName,
      'doctor_council': doctorCouncil,
      'doctor_council_state': doctorCouncilState,
      'doctor_specialty': doctorSpecialty,
      'doctor_address': doctorAddress,
      'doctor_city': doctorCity,
      'doctor_state': doctorState,
      'doctor_phone': doctorPhone,
      'doctor_cnes': doctorCnes,
      'clinic_name': clinicName,
      'clinic_cnpj': clinicCnpj,
      'patient_name': patientName,
      'patient_cpf': patientCpf,
      'patient_address': patientAddress,
      'patient_city': patientCity,
      'patient_state': patientState,
      'patient_phone': patientPhone,
      'patient_age': patientAge,
      'medicine_name': medicineName,
      'dosage': dosage,
      'pharmaceutical_form': pharmaceuticalForm,
      'route': route,
      'quantity': quantity,
      'quantity_words': quantityWords,
      'instructions': instructions,
      'notification_number': notificationNumber,
      'notification_uf': notificationUf,
      'is_continuous_use': isContinuousUse,
      'continuous_validity_months': continuousValidityMonths,
      'issued_at': issuedAt.toIso8601String(),
      'valid_until': validUntil.toIso8601String(),
      'status': status,
      'doctor_user_id': doctorUserId,
      'patient_user_id': patientUserId,
    };
  }

  bool get isExpired => DateTime.now().isAfter(validUntil);

  bool get isActive => status == 'ativa' && !isExpired;

  PrescriptionModel copyWith({String? id, String? status}) {
    return PrescriptionModel(
      id: id ?? this.id,
      type: type,
      doctorName: doctorName,
      doctorCouncil: doctorCouncil,
      doctorCouncilState: doctorCouncilState,
      doctorSpecialty: doctorSpecialty,
      doctorAddress: doctorAddress,
      doctorCity: doctorCity,
      doctorState: doctorState,
      doctorPhone: doctorPhone,
      doctorCnes: doctorCnes,
      clinicName: clinicName,
      clinicCnpj: clinicCnpj,
      patientName: patientName,
      patientCpf: patientCpf,
      patientAddress: patientAddress,
      patientCity: patientCity,
      patientState: patientState,
      patientPhone: patientPhone,
      patientAge: patientAge,
      medicineName: medicineName,
      dosage: dosage,
      pharmaceuticalForm: pharmaceuticalForm,
      route: route,
      quantity: quantity,
      quantityWords: quantityWords,
      instructions: instructions,
      notificationNumber: notificationNumber,
      notificationUf: notificationUf,
      isContinuousUse: isContinuousUse,
      continuousValidityMonths: continuousValidityMonths,
      issuedAt: issuedAt,
      validUntil: validUntil,
      status: status ?? this.status,
      doctorUserId: doctorUserId,
      patientUserId: patientUserId,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
