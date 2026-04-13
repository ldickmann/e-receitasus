import 'professional_type.dart';

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
