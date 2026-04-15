enum ProfessionalType {
  medico('MEDICO', 'Medico(a)', 'CRM', true),
  enfermeiro('ENFERMEIRO', 'Enfermeiro(a)', 'COREN', true),
  farmaceutico('FARMACEUTICO', 'Farmaceutico(a)', 'CRF', true),
  psicologo('PSICOLOGO', 'Psicologo(a)', 'CRP', true),
  nutricionista('NUTRICIONISTA', 'Nutricionista', 'CRN', true),
  fisioterapeuta('FISIOTERAPEUTA', 'Fisioterapeuta', 'CREFITO', true),
  dentista('DENTISTA', 'Dentista', 'CRO', true),
  assistenteSocial('ASSISTENTE_SOCIAL', 'Assistente Social', 'CRESS', true),
  administrativo(
      'ADMINISTRATIVO', 'Administrativo', 'Matricula funcional', false),
  outros('OUTROS', 'Outros', 'Registro institucional', false);

  const ProfessionalType(
    this.value,
    this.displayName,
    this.councilName,
    this.requiresCouncil,
  );

  final String value;
  final String displayName;
  final String councilName;
  final bool requiresCouncil;

  static ProfessionalType fromString(String value) {
    return ProfessionalType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => ProfessionalType.outros,
    );
  }

  String get registrationLabel {
    if (requiresCouncil) {
      return '$councilName (com UF)';
    }
    return councilName;
  }

  /// Indica se este tipo de profissional tem autorização para prescrever
  /// receitas médicas/odontológicas/de enfermagem conforme legislação vigente.
  bool get isPrescriber {
    const prescribers = {
      ProfessionalType.medico,
      ProfessionalType.dentista,
      ProfessionalType.enfermeiro,
      ProfessionalType.farmaceutico,
      ProfessionalType.psicologo,
      ProfessionalType.nutricionista,
      ProfessionalType.fisioterapeuta,
    };
    return prescribers.contains(this);
  }

  String get registrationHint {
    if (requiresCouncil) {
      return 'Ex: 123456-SP';
    }
    return 'Ex: MAT-2024-001';
  }

  String? validateRegistration(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Informe obrigatoriamente o seu $councilName';
    }

    if (input.length < 3) {
      return '$councilName deve ter no minimo 3 caracteres';
    }

    if (requiresCouncil) {
      final match = RegExp(r'[-/\s]([A-Za-z]{2})$').firstMatch(input);
      if (match == null) {
        return '$councilName deve conter UF (ex: 123456-SP)';
      }

      final uf = (match.group(1) ?? '').toUpperCase();
      if (!brazilianStates.contains(uf)) {
        return 'UF invalida para $councilName';
      }
    }

    return null;
  }

  String extractNumber(String registration) {
    return registration.replaceAll(RegExp(r'[-/\s][A-Za-z]{2}$'), '').trim();
  }

  String? extractState(String registration) {
    final match = RegExp(r'[-/\s]([A-Za-z]{2})$').firstMatch(registration);
    return match?.group(1)?.toUpperCase();
  }
}

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
