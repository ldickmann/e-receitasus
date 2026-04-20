/// Modelo imutável da UBS (Unidade Básica de Saúde) — espelha a tabela
/// `public.health_units` do Supabase.
///
/// Uma UBS atende exatamente UM bairro (district) de uma cidade. Profissionais
/// são vinculados manualmente (máximo 3 por UBS, garantido por trigger no
/// banco). Pacientes são atribuídos automaticamente pelo bairro informado
/// no cadastro.
class HealthUnitModel {
  /// UUID da UBS
  final String id;

  /// Nome humano (ex: "UBS Centro")
  final String name;

  /// Bairro atendido
  final String district;

  /// Cidade (no MVP: "Navegantes")
  final String city;

  /// UF com 2 caracteres (no MVP: "SC")
  final String state;

  /// Limite máximo de profissionais vinculados (1–3)
  final int maxProfessionals;

  const HealthUnitModel({
    required this.id,
    required this.name,
    required this.district,
    required this.city,
    required this.state,
    this.maxProfessionals = 3,
  });

  /// Constrói a partir do JSON devolvido pelo PostgREST do Supabase.
  /// Aceita chaves em snake_case (padrão da tabela) e camelCase.
  factory HealthUnitModel.fromJson(Map<String, dynamic> json) {
    return HealthUnitModel(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      district: (json['district'] as String? ?? '').trim(),
      city: (json['city'] as String? ?? '').trim(),
      state: (json['state'] as String? ?? '').trim(),
      maxProfessionals:
          (json['max_professionals'] ?? json['maxProfessionals'] ?? 3) as int,
    );
  }

  /// Rótulo completo da UBS com bairro e cidade — uso em dropdown/listagem.
  String get label => '$name — $district, $city/$state';
}
