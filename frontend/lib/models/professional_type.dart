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
  outros('OUTROS', 'Outros', 'Registro institucional', false),

  /// Paciente do SUS — cadastrado pelo app para acompanhar receitas.
  /// Não exige registro em conselho profissional.
  paciente('PACIENTE', 'Paciente', 'CNS', false);

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

  /// Indica se este profissional tem autorização legal para emitir receitas.
  ///
  /// Conforme Lei Federal 5.081/66 (odontologia) e CFM (medicina), apenas
  /// médicos e dentistas podem prescrever receitas médicas e odontológicas.
  /// Outros profissionais de saúde possuem atribuições distintas reguladas
  /// pelos seus respectivos conselhos, mas não emitem receituário.
  bool get canPrescribe =>
      this == ProfessionalType.medico || this == ProfessionalType.dentista;

  /// Indica se o profissional é enfermeiro.
  ///
  /// Enfermeiros atuam na triagem de solicitações de renovação de receitas,
  /// confirmando a necessidade clínica antes de encaminhar ao médico.
  bool get isNurse => this == ProfessionalType.enfermeiro;

  /// Indica se o perfil é de paciente (não profissional de saúde).
  ///
  /// Pacientes não possuem registro em conselho e acessam apenas a tela de
  /// acompanhamento de receitas. O valor PACIENTE é resolvido pelo trigger
  /// `handle_new_user` no Supabase quando professionalType == 'PACIENTE'.
  bool get isPatient => this == ProfessionalType.paciente;

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
