class UserModel {
  final String id;
  final String name;
  final String email;
  final String? crm;
  final String? specialty;
  final String? token;
  final DateTime? tokenExpiry;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.crm,
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
      crm: json['crm'],
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
      'crm': crm,
      'specialty': specialty,
      'token': token,
      'tokenExpiry': tokenExpiry?.toIso8601String(),
    };
  }

  bool get isTokenValid {
    if (token == null || tokenExpiry == null) return false;
    return DateTime.now().isBefore(tokenExpiry!);
  }
}