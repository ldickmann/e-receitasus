class UserModel {
  final String id;
  final String name;
  final String email;
  final String
      token; // O token JWT que será usado para requisições (Requisito de Segurança)

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.token,
  });

  // Factory constructor para criar um UserModel a partir de um mapa JSON (resposta da API)
  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Nota: Os campos 'id' e 'name' são adicionados para fins de modelo, assumindo que a API os retornará após o login/cadastro.
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      token: json['token'] as String,
    );
  }

  // Adicionar um método de conveniência para verificar se o usuário está logado
  bool get isAuthenticated => token.isNotEmpty;
}
