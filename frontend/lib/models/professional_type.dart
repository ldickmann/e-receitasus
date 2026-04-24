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

  /// Rótulo do campo de número de registro exibido no formulário de cadastro.
  ///
  /// Após PBI #157 a UF foi movida para um [DropdownButtonFormField] separado,
  /// portanto o rótulo não inclui mais "(com UF)".
  String get registrationLabel => councilName;

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

  /// Texto de dica exibido no campo de número de registro.
  ///
  /// Após PBI #157 a UF é capturada em campo separado — o hint mostra
  /// apenas o número puro, sem o sufixo de estado.
  String get registrationHint {
    if (requiresCouncil) {
      return 'Ex: 123456';
    }
    return 'Ex: MAT-2024-001';
  }

  /// Valida o número de registro profissional informado no formulário de cadastro.
  ///
  /// Após PBI #157, a UF é informada em campo separado ([_selectedCouncilState]
  /// em `register_screen.dart`), portanto o campo de número aceita:
  /// - **Número puro** (ex: `123456`) — fluxo padrão pós-PBI #157.
  /// - **Número com UF opcional** (ex: `123456-SP`) — compatibilidade com
  ///   formatos legados eventualmente colados pelo usuário.
  ///
  /// Retorna `null` quando válido ou mensagem de erro para exibição no formulário.
  String? validateRegistration(String? value) {
    final input = value?.trim() ?? '';

    if (input.isEmpty) {
      return 'Informe obrigatoriamente o seu $councilName';
    }

    if (input.length < 3) {
      return '$councilName deve ter no mínimo 3 caracteres';
    }

    if (requiresCouncil) {
      // Aceita número puro (ex: 123456) ou com UF opcional (ex: 123456-SP).
      // 4 a 10 dígitos seguidos de sufixo UF opcional separado por -, / ou espaço.
      // Fix PBI #180 / TASK #190 — anteriormente exigia UF obrigatória.
      final isValid =
          RegExp(r'^\d{4,10}([-/\s][A-Za-z]{2})?$').hasMatch(input);
      if (!isValid) {
        return 'Número de $councilName inválido (ex: 123456)';
      }

      // Se o usuário digitou UF junto ao número (formato legado), valida a sigla.
      final ufMatch = RegExp(r'[-/\s]([A-Za-z]{2})$').firstMatch(input);
      if (ufMatch != null) {
        final uf = (ufMatch.group(1) ?? '').toUpperCase();
        if (!brazilianStates.contains(uf)) {
          return 'UF inválida para $councilName';
        }
      }
    }

    return null;
  }

  /// Extrai apenas o número do registro descartando o sufixo de UF.
  ///
  /// @deprecated PBI 157 / TASK 164 — a UF passou a ser coletada em um
  /// `DropdownButtonFormField` separado em `register_screen.dart`, então o
  /// usuário já digita apenas o número. Mantido temporáriamente para não
  /// quebrar importérios externos; remover quando nenhum chamador restar.
  @Deprecated(
      'Use o valor direto do controller; UF vem do dropdown _selectedCouncilState (PBI 157).')
  String extractNumber(String registration) {
    return registration.replaceAll(RegExp(r'[-/\s][A-Za-z]{2}$'), '').trim();
  }

  /// Extrai a sigla da UF do final da string de registro.
  ///
  /// @deprecated PBI 157 / TASK 164 — substituído por seleção explícita em
  /// dropdown na tela de cadastro. Parsing por regex era frágil (aceitava
  /// UFs inválidas se a regex casasse) e impedia validador robusto.
  @Deprecated(
      'Use _selectedCouncilState do formulário em vez de parsing de string (PBI 157).')
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
