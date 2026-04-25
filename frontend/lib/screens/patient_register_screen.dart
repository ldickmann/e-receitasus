import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Tela de cadastro exclusiva para pacientes do SUS.
///
/// Organizada em 5 seções para facilitar o preenchimento progressivo:
/// 1. Dados Pessoais — nome, nascimento, sexo, raça, estado civil, CPF, nome social
/// 2. Origem — cidade/UF de nascimento, escolaridade, nome da mãe
/// 3. Acesso — e-mail, senha
/// 4. Saúde — telefone (obrigatório), CNS
/// 5. Endereço — CEP, logradouro e complementos
///
/// O parâmetro [httpClient] é opcional e destinado exclusivamente a testes —
/// permite injetar um cliente HTTP fake sem necessidade de rede real.
class PatientRegisterScreen extends StatefulWidget {
  /// Cliente HTTP customizado; `null` usa o cliente padrão do pacote `http`.
  final http.Client? httpClient;

  const PatientRegisterScreen({super.key, this.httpClient});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Dados Pessoais ---
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _socialNameController = TextEditingController();
  final _cpfController = TextEditingController();
  // Controller do campo de texto de data — sincronizado com _selectedBirthDate
  final _birthDateController = TextEditingController();
  DateTime? _selectedBirthDate;
  String? _gender;
  String? _ethnicity;
  String? _maritalStatus;

  // --- Origem ---
  final _motherParentNameController = TextEditingController();
  final _birthCityController = TextEditingController();
  String? _birthState;
  String? _education;

  // --- Acesso ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // --- Saúde ---
  final _phoneController = TextEditingController();
  final _cnsController = TextEditingController();

  // --- Endereço ---
  final _zipCodeController = TextEditingController();
  final _streetController = TextEditingController();
  final _streetNumberController = TextEditingController();
  final _complementController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressCityController = TextEditingController();
  String? _addressState;

  // Controla o estado de busca do CEP via ViaCEP
  bool _isSearchingCep = false;
  // Evita chamadas duplicadas para o mesmo CEP já buscado
  String? _lastFetchedCep;

  // ---------------------------------------------------------------------------
  // Listas de opções para campos com valores controlados
  // ---------------------------------------------------------------------------

  static const _genderOptions = [
    'MASCULINO',
    'FEMININO',
    'NAO_BINARIO',
    'PREFIRO_NAO_INFORMAR',
  ];

  static const _genderLabels = {
    'MASCULINO': 'Masculino',
    'FEMININO': 'Feminino',
    'NAO_BINARIO': 'Não binário',
    'PREFIRO_NAO_INFORMAR': 'Prefiro não informar',
  };

  // Classificação IBGE de raça/cor — padrão adotado pelo SUS
  static const _ethnicityOptions = [
    'BRANCA',
    'PARDA',
    'PRETA',
    'AMARELA',
    'INDIGENA',
    'NAO_INFORMADO',
  ];

  static const _ethnicityLabels = {
    'BRANCA': 'Branca',
    'PARDA': 'Parda',
    'PRETA': 'Preta',
    'AMARELA': 'Amarela',
    'INDIGENA': 'Indígena',
    'NAO_INFORMADO': 'Não informado',
  };

  static const _maritalStatusOptions = [
    'SOLTEIRO',
    'CASADO',
    'UNIAO_ESTAVEL',
    'DIVORCIADO',
    'VIUVO',
    'SEPARADO',
  ];

  static const _maritalStatusLabels = {
    'SOLTEIRO': 'Solteiro(a)',
    'CASADO': 'Casado(a)',
    'UNIAO_ESTAVEL': 'União Estável',
    'DIVORCIADO': 'Divorciado(a)',
    'VIUVO': 'Viúvo(a)',
    'SEPARADO': 'Separado(a)',
  };

  static const _educationOptions = [
    'SEM_INSTRUCAO',
    'ENSINO_FUNDAMENTAL',
    'ENSINO_MEDIO',
    'ENSINO_SUPERIOR',
    'POS_GRADUACAO',
  ];

  static const _educationLabels = {
    'SEM_INSTRUCAO': 'Sem instrução',
    'ENSINO_FUNDAMENTAL': 'Ensino Fundamental',
    'ENSINO_MEDIO': 'Ensino Médio',
    'ENSINO_SUPERIOR': 'Ensino Superior',
    'POS_GRADUACAO': 'Pós-graduação',
  };

  // 26 UFs + DF ordenados alfabeticamente
  static const _ufOptions = [
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
    'TO',
  ];

  @override
  void initState() {
    super.initState();
    // Registra listener para disparar busca ViaCEP assim que 8 dígitos forem digitados
    _zipCodeController.addListener(_onCepChanged);
  }

  /// Callback do listener do campo CEP.
  ///
  /// Dispara a busca apenas quando exatamente 8 dígitos são digitados
  /// e o CEP é diferente do último já consultado — evita chamadas repetidas.
  void _onCepChanged() {
    final cep = _zipCodeController.text.trim();
    if (cep.length == 8 && cep != _lastFetchedCep) {
      _fetchAddressFromCep(cep);
    }
  }

  /// Consulta a API pública ViaCEP e preenche automaticamente os campos de endereço.
  ///
  /// A ViaCEP (viacep.com.br) é um serviço gratuito do governo brasileiro —
  /// não envia dados do usuário, apenas consulta logradouros pelo CEP informado.
  /// CEP inválido retorna `{"erro": true}` com status 200 — tratado separadamente.
  Future<void> _fetchAddressFromCep(String cep) async {
    // Impede chamada paralela se uma busca já está em andamento
    if (_isSearchingCep) return;

    // Registra o CEP consultado antes de iniciar para evitar reentrada
    _lastFetchedCep = cep;
    setState(() => _isSearchingCep = true);

    try {
      final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');
      // Usa cliente injetado (testes) ou o cliente global padrão (produção).
      // O timeout de 10s é aplicado apenas ao cliente padrão — em testes,
      // o MockClient retorna imediatamente e o Timer de timeout causaria
      // comportamento indefinido no scheduler sintético do flutter_test.
      final client = widget.httpClient;
      final responseFuture = client != null
          ? client.get(uri)
          : http.get(uri).timeout(const Duration(seconds: 10));
      final response = await responseFuture;

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Decodifica explicitamente como UTF-8 — evita corrupção de caracteres
        // especiais (ç, ã, é…) em APIs que omitem charset no Content-Type header.
        // response.body usa latin1 como fallback quando charset não é declarado.
        final data =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

        // ViaCEP responde com {"erro": true} para CEPs inexistentes (status 200)
        if (data.containsKey('erro')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('CEP não encontrado. Preencha o endereço manualmente.'),
            ),
          );
          return;
        }

        // Preenche todos os campos — sobrescreve valores anteriores porque
        // o usuário acabou de digitar um novo CEP e espera ver o endereço atualizado
        setState(() {
          _streetController.text = (data['logradouro'] as String?) ?? '';
          _districtController.text = (data['bairro'] as String?) ?? '';
          _addressCityController.text = (data['localidade'] as String?) ?? '';

          // UF vem como sigla em maiúsculas — compatível com _ufOptions
          final uf = (data['uf'] as String?)?.toUpperCase();
          if (uf != null && _ufOptions.contains(uf)) {
            _addressState = uf;
          }
        });
      }
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tempo esgotado ao consultar o CEP. Tente novamente.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Não foi possível consultar o CEP. Verifique a conexão.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSearchingCep = false);
    }
  }

  @override
  void dispose() {
    // Remove o listener antes de descartar o controller para evitar memory leak
    _zipCodeController.removeListener(_onCepChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _socialNameController.dispose();
    _cpfController.dispose();
    _birthDateController.dispose();
    _motherParentNameController.dispose();
    _birthCityController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _cnsController.dispose();
    _zipCodeController.dispose();
    _streetController.dispose();
    _streetNumberController.dispose();
    _complementController.dispose();
    _districtController.dispose();
    _addressCityController.dispose();
    super.dispose();
  }

  /// Parseia o texto digitado no formato DD/MM/AAAA em um [DateTime].
  ///
  /// Retorna null se incompleto ou se a data não existir (ex: 31/02).
  /// Compara campos de volta porque o Flutter normaliza datas inválidas.
  DateTime? _parseDateText(String text) {
    if (text.length != 10) return null;
    final parts = text.split('/');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    try {
      final date = DateTime(year, month, day);
      // Garante que a data não foi normalizada (ex: 31/02 → 03/03)
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }

  /// Abre o seletor de data de nascimento.
  ///
  /// Sem restrição de idade mínima — o SUS atende desde recém-nascidos.
  /// Limite superior é hoje para evitar datas futuras inválidas.
  /// Também atualiza o campo de texto para manter os dois sincronizados.
  Future<void> _selectBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Selecione a data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        // Popula o campo de texto para refletir a seleção do calendário
        final dd = picked.day.toString().padLeft(2, '0');
        final mm = picked.month.toString().padLeft(2, '0');
        _birthDateController.text = '$dd/$mm/${picked.year}';
      });
    }
  }

  /// Envia o formulário ao provider e reage ao resultado.
  ///
  /// Em sucesso exibe SnackBar informativo e retorna para a tela anterior
  /// (LoginScreen), pois o usuário pode precisar confirmar o e-mail antes
  /// de acessar o app dependendo da configuração do Supabase.
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // Aceita data proveniente do calendário ou digitada manualmente
    final effectiveBirthDate =
        _selectedBirthDate ?? _parseDateText(_birthDateController.text);

    if (effectiveBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma data de nascimento válida.')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final outcome = await authProvider.registerPatient(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      birthDate: effectiveBirthDate,
      password: _passwordController.text,
      // Telefone é obrigatório — o validator já garante preenchimento
      phone: _phoneController.text.trim(),
      cns: _nullIfEmpty(_cnsController.text),
      cpf: _nullIfEmpty(_cpfController.text),
      socialName: _nullIfEmpty(_socialNameController.text),
      motherParentName: _nullIfEmpty(_motherParentNameController.text),
      birthCity: _nullIfEmpty(_birthCityController.text),
      birthState: _birthState,
      gender: _gender,
      ethnicity: _ethnicity,
      maritalStatus: _maritalStatus,
      education: _education,
      zipCode: _nullIfEmpty(_zipCodeController.text),
      street: _nullIfEmpty(_streetController.text),
      streetNumber: _nullIfEmpty(_streetNumberController.text),
      complement: _nullIfEmpty(_complementController.text),
      district: _nullIfEmpty(_districtController.text),
      addressCity: _nullIfEmpty(_addressCityController.text),
      addressState: _addressState,
    );

    if (!mounted) return;

    // Tratamento tripartido (TASK 207 / PBI 201) — distingue sucesso completo,
    // sucesso parcial (auth.users criado mas perfil falhou) e falha pré-signUp.
    switch (outcome) {
      case RegistrationOutcome.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            // Mensagem genérica — pode haver confirmação de e-mail pendente
            content: Text(
              'Cadastro realizado! Verifique seu e-mail para confirmar o acesso.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        // Retorna para LoginScreen — usuário fará login após confirmar o e-mail
        Navigator.pop(context);
        break;
      case RegistrationOutcome.profileIncomplete:
        // Sucesso parcial: usuário JÁ EXISTE em auth.users — NÃO reenviar signUp.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ??
                'Conta criada. Faça login e complete seus dados.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        authProvider.clearError();
        Navigator.pop(context);
        break;
      case RegistrationOutcome.failure:
        if (authProvider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(authProvider.errorMessage!),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          authProvider.clearError();
        }
        break;
    }
  }

  /// Retorna null para strings vazias — evita gravar string vazia no banco.
  String? _nullIfEmpty(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Paciente'),
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Selector<AuthProvider, bool>(
          // Reconstrói apenas o corpo quando isLoading muda — evita rebuild total
          selector: (_, auth) => auth.isLoading,
          builder: (context, isLoading, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // =========================================================
                    // SEÇÃO 1 — Dados Pessoais
                    // =========================================================
                    const _SectionHeader('Dados Pessoais'),
                    const SizedBox(height: 12),

                    // Nome — obrigatório
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'Nome *',
                      icon: Icons.person,
                      capitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o nome.'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Sobrenome — obrigatório
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Sobrenome *',
                      icon: Icons.person_outline,
                      capitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o sobrenome.'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    // Nome Social — opcional; respeita a identidade do paciente
                    _buildTextField(
                      controller: _socialNameController,
                      label: 'Nome Social',
                      icon: Icons.badge_outlined,
                      capitalization: TextCapitalization.words,
                      hint: 'Opcional',
                    ),
                    const SizedBox(height: 12),

                    // Data de nascimento — aceita digitação direta ou calendário
                    TextFormField(
                      controller: _birthDateController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_DateMaskFormatter()],
                      onChanged: (text) {
                        // Ao completar 10 chars (DD/MM/AAAA), parseia e mantém
                        // _selectedBirthDate sincronizado para o envio do form
                        if (text.length == 10) {
                          setState(
                              () => _selectedBirthDate = _parseDateText(text));
                        } else {
                          setState(() => _selectedBirthDate = null);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'Data de nascimento *',
                        hintText: 'DD/MM/AAAA',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.cake_outlined),
                        // Ícone de calendário mantido para abrir DatePicker
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          tooltip: 'Selecionar data no calendário',
                          onPressed: _selectBirthDate,
                        ),
                      ),
                      validator: (v) {
                        // Verifica se foi preenchido por texto ou pelo calendário
                        final text = v ?? '';
                        final dateFromText = _parseDateText(text);
                        final effective = _selectedBirthDate ?? dateFromText;
                        if (effective == null) {
                          if (text.isEmpty) {
                            return 'Informe a data de nascimento.';
                          }
                          // Data com 10 chars mas inválida (ex: 31/02)
                          return 'Data inválida';
                        }
                        // Sem restrição de idade para pacientes — SUS atende todas as idades
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Sexo — dropdown com valores controlados pelo SUS
                    _buildDropdown(
                      value: _gender,
                      label: 'Sexo',
                      icon: Icons.wc,
                      options: _genderOptions,
                      labels: _genderLabels,
                      onChanged: (v) => setState(() => _gender = v),
                    ),
                    const SizedBox(height: 12),

                    // Raça/Cor — classificação IBGE exigida pelo SUS
                    _buildDropdown(
                      value: _ethnicity,
                      label: 'Raça / Cor',
                      icon: Icons.people_outline,
                      options: _ethnicityOptions,
                      labels: _ethnicityLabels,
                      onChanged: (v) => setState(() => _ethnicity = v),
                    ),
                    const SizedBox(height: 12),

                    // Estado Civil
                    _buildDropdown(
                      value: _maritalStatus,
                      label: 'Estado Civil',
                      icon: Icons.favorite_outline,
                      options: _maritalStatusOptions,
                      labels: _maritalStatusLabels,
                      onChanged: (v) => setState(() => _maritalStatus = v),
                    ),
                    const SizedBox(height: 12),

                    // CPF — 11 dígitos, sem formatação, único no banco
                    _buildTextField(
                      controller: _cpfController,
                      label: 'CPF',
                      icon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                      hint: 'Apenas números — 11 dígitos',
                      maxLength: 11,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        // Valida comprimento — dígitos verificadores são checados
                        // no backend para não expor o algoritmo de validação no cliente
                        if (v.trim().length != 11) {
                          return 'CPF deve ter 11 dígitos.';
                        }
                        return null;
                      },
                    ),

                    // =========================================================
                    // SEÇÃO 2 — Origem
                    // =========================================================
                    const _SectionHeader('Origem'),
                    const SizedBox(height: 12),

                    // Nome da mãe / responsável
                    _buildTextField(
                      controller: _motherParentNameController,
                      label: 'Nome da mãe / responsável',
                      icon: Icons.family_restroom,
                      capitalization: TextCapitalization.words,
                      hint: 'Opcional',
                    ),
                    const SizedBox(height: 12),

                    // Cidade de nascimento
                    _buildTextField(
                      controller: _birthCityController,
                      label: 'Cidade de nascimento',
                      icon: Icons.location_city_outlined,
                      capitalization: TextCapitalization.words,
                      hint: 'Opcional',
                    ),
                    const SizedBox(height: 12),

                    // UF de nascimento
                    _buildDropdown(
                      value: _birthState,
                      label: 'UF de nascimento',
                      icon: Icons.map_outlined,
                      options: _ufOptions,
                      labels: {for (final uf in _ufOptions) uf: uf},
                      onChanged: (v) => setState(() => _birthState = v),
                    ),
                    const SizedBox(height: 12),

                    // Escolaridade
                    _buildDropdown(
                      value: _education,
                      label: 'Escolaridade',
                      icon: Icons.school_outlined,
                      options: _educationOptions,
                      labels: _educationLabels,
                      onChanged: (v) => setState(() => _education = v),
                    ),

                    // =========================================================
                    // SEÇÃO 3 — Acesso
                    // =========================================================
                    const _SectionHeader('Acesso'),
                    const SizedBox(height: 12),

                    // E-mail — obrigatório
                    _buildTextField(
                      controller: _emailController,
                      label: 'E-mail *',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe o e-mail.';
                        }
                        // Validação básica de formato antes de enviar ao Supabase
                        if (!v.contains('@') || !v.contains('.')) {
                          return 'E-mail inválido.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Senha — obrigatória, mínimo 6 caracteres (limite Supabase)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Senha *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          tooltip: _obscurePassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Informe a senha.';
                        if (v.length < 6) return 'Mínimo de 6 caracteres.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Confirmar senha — verifica correspondência localmente
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                          tooltip: _obscureConfirmPassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                        ),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirme a senha.';
                        }
                        if (v != _passwordController.text) {
                          return 'As senhas não coincidem.';
                        }
                        return null;
                      },
                    ),

                    // =========================================================
                    // SEÇÃO 4 — Saúde
                    // =========================================================
                    const _SectionHeader('Saúde'),
                    const SizedBox(height: 12),

                    // Telefone — obrigatório; DDD (2) + 9 dígitos
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Telefone celular *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        hintText: 'DDD + número (11 dígitos)',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          // Obrigatório para contato e autenticação por SMS futura
                          return 'Informe o telefone celular.';
                        }
                        if (v.trim().length != 11) {
                          return 'Informe DDD + número (11 dígitos).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // CNS — único campo opcional desta seção
                    _buildTextField(
                      controller: _cnsController,
                      label: 'CNS (Cartão Nacional de Saúde)',
                      icon: Icons.credit_card,
                      keyboardType: TextInputType.number,
                      hint: 'Opcional — 15 dígitos',
                      maxLength: 15,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (v.trim().length != 15) {
                          return 'CNS deve ter 15 dígitos.';
                        }
                        return null;
                      },
                    ),

                    // =========================================================
                    // SEÇÃO 5 — Endereço
                    // =========================================================
                    const _SectionHeader('Endereço'),
                    const SizedBox(height: 12),

                    // Campo CEP com busca automática via ViaCEP.
                    // Ao digitar o 8º dígito, dispara a consulta e preenche
                    // rua, bairro, cidade e UF automaticamente.
                    TextFormField(
                      // Key utilizada nos testes de widget para encontrar
                      // este campo de forma inequívoca entre os demais
                      key: const Key('cep_field'),
                      controller: _zipCodeController,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: 'CEP',
                        hintText: '8 dígitos',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        // Oculta o contador — o hint já informa o limite
                        counterText: '',
                        // Spinner visível enquanto a consulta ViaCEP está em andamento
                        suffixIcon: _isSearchingCep
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        if (v.trim().length != 8) {
                          return 'CEP deve ter 8 dígitos.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Logradouro — preenchido automaticamente pelo ViaCEP
                    _buildTextField(
                      key: const Key('street_field'),
                      controller: _streetController,
                      label: 'Logradouro (Rua / Av.)',
                      icon: Icons.signpost_outlined,
                      capitalization: TextCapitalization.words,
                      hint: 'Opcional',
                    ),
                    const SizedBox(height: 12),

                    // Número e Complemento lado a lado
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField(
                            controller: _streetNumberController,
                            label: 'Número',
                            icon: Icons.tag,
                            keyboardType: TextInputType.text,
                            hint: 'Ex: 123',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: _buildTextField(
                            controller: _complementController,
                            label: 'Complemento',
                            icon: Icons.apartment_outlined,
                            hint: 'Apto, bloco...',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bairro
                    _buildTextField(
                      controller: _districtController,
                      label: 'Bairro',
                      icon: Icons.holiday_village_outlined,
                      capitalization: TextCapitalization.words,
                      hint: 'Opcional',
                    ),
                    const SizedBox(height: 12),

                    // Cidade do endereço
                    _buildTextField(
                      controller: _addressCityController,
                      label: 'Cidade',
                      icon: Icons.location_city,
                      capitalization: TextCapitalization.words,
                      hint: 'Opcional',
                    ),
                    const SizedBox(height: 12),

                    // UF do endereço
                    _buildDropdown(
                      value: _addressState,
                      label: 'UF',
                      icon: Icons.map,
                      options: _ufOptions,
                      labels: {for (final uf in _ufOptions) uf: uf},
                      onChanged: (v) => setState(() => _addressState = v),
                    ),

                    // =========================================================
                    // Botão de envio
                    // =========================================================
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: isLoading ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        // Target de toque >= 48dp conforme diretrizes de acessibilidade
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cadastrar'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers de construção de widgets para reduzir repetição
  // ---------------------------------------------------------------------------

  /// Campo de texto padrão do formulário.
  ///
  /// Centraliza a decoração para manter consistência visual sem duplicar código.
  Widget _buildTextField({
    Key? key,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? hint,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
    bool autocorrect = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      autocorrect: autocorrect,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        // Esconde o contador de caracteres — o hint já informa o limite
        counterText: maxLength != null ? '' : null,
      ),
      textInputAction: TextInputAction.next,
      validator: validator,
    );
  }

  /// Dropdown padrão para campos de seleção controlada.
  ///
  /// Usa DropdownButtonFormField para integração nativa com Form/validate.
  Widget _buildDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> options,
    required Map<String, String> labels,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
      ),
      // Item nulo como "Opcional" — permite desfazer seleção
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('Opcional'),
        ),
        ...options.map(
          (opt) => DropdownMenuItem<String>(
            value: opt,
            child: Text(labels[opt] ?? opt),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

// =============================================================================
// Widgets auxiliares
// =============================================================================

/// Cabeçalho de seção do formulário.
///
/// Separa visualmente grupos de campos relacionados sem criar
/// hierarquia de navegação extra — mantém o formulário em uma única tela.
/// Formata automaticamente o campo de data de nascimento no padrão DD/MM/AAAA.
///
/// Extrai apenas os dígitos do input, limita a 8 dígitos e insere '/' nas
/// posições corretas para não forçar o usuário a digitá-las manualmente.
class _DateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove qualquer '/' já existente para trabalhar só com dígitos
    final digits = newValue.text.replaceAll('/', '');

    // Limita a 8 dígitos numéricos (DDMMAAAA)
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;

    // Reconstrói a string inserindo '/' após dia (pos 2) e mês (pos 4)
    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2 || i == 4) buffer.write('/');
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        const Divider(),
      ],
    );
  }
}
