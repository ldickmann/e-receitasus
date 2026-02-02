import 'professional_type.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final ProfessionalType professionalType;
  final String? professionalId;
  final String? professionalState;
  final String? specialty;
  final String? token;
  final DateTime? tokenExpiry;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.professionalType = ProfessionalType.administrativo,
    this.professionalId,
    this.professionalState,
    this.specialty,
    this.token,
    this.tokenExpiry,
  });

  // Factory constructor para criar um UserModel a partir de um mapa JSON (resposta da API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      professionalType: json['professionalType'] != null
          ? ProfessionalType.fromString(json['professionalType'])
          : ProfessionalType.administrativo,
      professionalId: json['professionalId'],
      professionalState: json['professionalState'],
      specialty: json['specialty'],
      token: json['token'],
      tokenExpiry: json['tokenExpiry'] != null
          ? DateTime.parse(json['tokenExpiry'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
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

  /// Retorna o registro profissional formatado
  String? get formattedRegistration {
    if (professionalId == null) return null;
    if (professionalState != null) {
      return '$professionalId-$professionalState';
    }
    return professionalId;
  }
}
