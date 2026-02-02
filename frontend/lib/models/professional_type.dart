/// Tipos de profissionais do SUS com seus respectivos conselhos
enum ProfessionalType {
  medico('MEDICO', 'Médico(a)', 'CRM', true),
  enfermeiro('ENFERMEIRO', 'Enfermeiro(a)', 'COREN', true),
  farmaceutico('FARMACEUTICO', 'Farmacêutico(a)', 'CRF', true),
  psicologo('PSICOLOGO', 'Psicólogo(a)', 'CRP', true),
  nutricionista('NUTRICIONISTA', 'Nutricionista', 'CRN', true),
  fisioterapeuta('FISIOTERAPEUTA', 'Fisioterapeuta', 'CREFITO', true),
  dentista('DENTISTA', 'Dentista', 'CRO', true),
  assistenteSocial('ASSISTENTE_SOCIAL', 'Assistente Social', 'CRESS', true),
  administrativo('ADMINISTRATIVO', 'Administrativo', 'Matrícula', false),
  outros('OUTROS', 'Outros', 'Registro', false);

  const ProfessionalType(
    this.value,
    this.displayName,
    this.councilName,
    this.requiresCouncil,
  );

  /// Valor armazenado no backend
  final String value;

  /// Nome para exibição na interface
  final String displayName;

  /// Nome do conselho profissional (CRM, COREN, etc.)
  final String councilName;

  /// Indica se o tipo requer registro em conselho
  final bool requiresCouncil;

  /// Converte string do backend para enum
  static ProfessionalType fromString(String value) {
    return ProfessionalType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProfessionalType.outros,
    );
  }

  /// Retorna label para o campo de registro
  String get registrationLabel => '$councilName (com UF)';

  /// Retorna dica para o campo de registro
  String get registrationHint {
    if (requiresCouncil) {
      return 'Ex: 123456-SP';
    }
    return 'Ex: MAT-2024-001';
  }

  /// Valida formato do registro profissional
  String? validateRegistration(String? value) {
    if (value == null || value.isEmpty) {
      if (requiresCouncil) {
        return 'Por favor, informe seu $councilName';
      }
      return null; // Administrativos podem não ter registro
    }

    // Validação básica: deve ter pelo menos 3 caracteres
    if (value.length < 3) {
      return '$councilName deve ter no mínimo 3 caracteres';
    }

    // Validação específica para conselhos que exigem UF
    if (requiresCouncil) {
      // Regex para formatos: 123456-SP, 123456/SP, 123456 SP
      final hasStatePattern = RegExp(r'[-/\s][A-Z]{2}$');
      if (!hasStatePattern.hasMatch(value)) {
        return '$councilName deve conter a UF (ex: 123456-SP)';
      }
    }

    return null;
  }

  /// Extrai o número do registro (sem UF)
  String extractNumber(String registration) {
    return registration.replaceAll(RegExp(r'[-/\s][A-Z]{2}$'), '').trim();
  }

  /// Extrai a UF do registro
  String? extractState(String registration) {
    final match = RegExp(r'[-/\s]([A-Z]{2})$').firstMatch(registration);
    return match?.group(1);
  }
}

/// Estados brasileiros para validação
const List<String> brazilianStates = [
  'AC',
  'AL',
  'AP',
  'AM',
  'BA',
  'CE',
  'DF',
  'ES',
  'GO',
  'MA',
  'MT',
  'MS',
  'MG',
  'PA',
  'PB',
  'PR',
  'PE',
  'PI',
  'RJ',
  'RN',
  'RS',
  'RO',
  'RR',
  'SC',
  'SP',
  'SE',
  'TO'
];
