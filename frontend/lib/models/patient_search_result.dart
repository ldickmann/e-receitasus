import 'package:flutter/foundation.dart';

/// Resultado mínimo de busca de paciente para o autocomplete do
/// formulário de prescrição.
///
/// Retornado pela função RPC `search_patients_for_prescription` do Supabase.
/// Contém apenas os campos necessários para exibir sugestões e pré-preencher
/// o formulário — princípio de minimização de dados (LGPD art. 6º, inc. III).
@immutable
class PatientSearchResult {
  /// Identificador único do paciente (Supabase Auth UID).
  final String id;

  /// Nome completo — usa nome social quando disponível.
  final String fullName;

  /// CPF do paciente ou null se não cadastrado.
  final String? cpf;

  /// Endereço resumido (logradouro, número, bairro) ou null.
  final String? address;

  /// Cidade do endereço atual ou null.
  final String? city;

  /// Idade aproximada em texto (ex.: "45 anos") ou null se sem data de nascimento.
  final String? ageText;

  const PatientSearchResult({
    required this.id,
    required this.fullName,
    this.cpf,
    this.address,
    this.city,
    this.ageText,
  });

  /// Constrói a partir do JSON retornado pela RPC `search_patients_for_prescription`.
  factory PatientSearchResult.fromJson(Map<String, dynamic> json) {
    return PatientSearchResult(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      cpf: json['cpf'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      ageText: json['age_text'] as String?,
    );
  }
}
