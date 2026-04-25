import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/professional_type.dart';

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

/// Tela de cadastro para profissionais de saúde (médico, enfermeiro, dentista, etc.).
///
/// O parâmetro [httpClient] é opcional e destinado exclusivamente a testes —
/// permite injetar um cliente HTTP fake para simular respostas da ViaCEP
/// sem abrir sockets reais.
class RegisterScreen extends StatefulWidget {
  /// Cliente HTTP customizado; `null` usa o cliente padrão do pacote `http`.
  final http.Client? httpClient;

  const RegisterScreen({super.key, this.httpClient});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _professionalIdController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- Endereço ---
  final _zipCodeController = TextEditingController();
  final _streetController = TextEditingController();
  final _streetNumberController = TextEditingController();
  final _complementController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressCityController = TextEditingController();
  String? _addressState;

  // Controla estado de busca ViaCEP para exibir loading no ícone do CEP
  bool _isSearchingCep = false;
  // Evita chamadas duplicadas para o mesmo CEP já consultado
  String? _lastFetchedCep;

  ProfessionalType? _selectedProfessionalType;
  DateTime? _selectedBirthDate;

  // PBI 157 / TASK 163 — UF do Conselho passou a ser um campo distinto do
  // número de registro. Antes a UF era extraída do final da string digitada
  // (ex: "123456-SP"), o que era frágil e gerava dado ambíguo no banco.
  // Agora a UF é selecionada explicitamente em um Dropdown dedicado.
  String? _selectedCouncilState;

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
  void dispose() {
    // Remove o listener antes de descartar o controller para evitar memory leak
    _zipCodeController.removeListener(_onCepChanged);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _professionalIdController.dispose();
    _specialtyController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _zipCodeController.dispose();
    _streetController.dispose();
    _streetNumberController.dispose();
    _complementController.dispose();
    _districtController.dispose();
    _addressCityController.dispose();
    super.dispose();
  }

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
      // o MockClient retorna imediatamente e o Timer causaria comportamento
      // indefinido no scheduler sintético do flutter_test.
      final client = widget.httpClient;
      final responseFuture = client != null
          ? client.get(uri)
          : http.get(uri).timeout(const Duration(seconds: 10));
      final response = await responseFuture;

      if (!mounted) return;

      if (response.statusCode == 200) {
        // Decodifica explicitamente como UTF-8 — evita corrupção de caracteres
        // especiais (ç, ã, é…) quando o Content-Type não declara charset.
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

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 18, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Selecione a data de nascimento',
      fieldHintText: 'DD/MM/AAAA',
    );

    if (picked == null) return;

    setState(() {
      _selectedBirthDate = DateTime(picked.year, picked.month, picked.day);
      _birthDateController.text = _formatDate(_selectedBirthDate!);
    });
  }

  String _formatDate(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString().padLeft(4, '0');
    return '$dd/$mm/$yyyy';
  }

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    final hadBirthdayThisYear = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);

    if (!hadBirthdayThisYear) {
      age -= 1;
    }

    return age;
  }

  String? _validateName(String? value, String label) {
    final input = value?.trim() ?? '';
    final regex = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]{2,}$");

    if (input.isEmpty) return 'Informe $label';
    if (!regex.hasMatch(input)) {
      return '$label invalido. Use apenas letras, espaco, apostrofo e hifen.';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final input = value?.trim() ?? '';
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (input.isEmpty) return 'Informe o e-mail';
    if (!regex.hasMatch(input)) return 'E-mail invalido';
    return null;
  }

  /// Parseia o texto digitado no formato DD/MM/AAAA em um [DateTime].
  ///
  /// Retorna null se o texto estiver incompleto ou representar uma data
  /// inexistente (ex: 31/02/2000). O Flutter normaliza datas inválidas
  /// (ex: DateTime(2000,2,31) → 2000-03-02), então comparamos os campos
  /// de volta para garantir que a data existe de verdade.
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

  String? _validateBirthDate() {
    // Tenta parsear o texto digitado se _selectedBirthDate ainda não foi
    // populado via DatePicker — permite ambas as formas de entrada
    final textDate = _parseDateText(_birthDateController.text);
    final effective = _selectedBirthDate ?? textDate;

    if (effective == null) {
      // Feedback diferenciado: campo vazio vs. data inválida
      if (_birthDateController.text.isEmpty) {
        return 'Informe a data de nascimento';
      }
      return 'Data inválida';
    }

    // Valida ≥ 18 anos apenas para profissionais de saúde (não para pacientes)
    final age = _calculateAge(effective);
    if (age < 18) {
      return 'Cadastro permitido apenas para maiores de 18 anos';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    final input = value ?? '';
    final regex =
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');

    if (input.isEmpty) return 'Informe a senha';
    if (!regex.hasMatch(input)) {
      return 'Senha deve ter 8+ caracteres com maiuscula, minuscula, numero e simbolo';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final professionalType = _selectedProfessionalType;
    final birthDate = _selectedBirthDate;

    if (professionalType == null || birthDate == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // PBI 157 / TASK 164 — Número do registro vai puro (sem sufixo "-UF"),
    // pois a UF agora vem do Dropdown dedicado `_selectedCouncilState`.
    // Para profissionais sem conselho (ADMINISTRATIVO/OUTROS) o dropdown não
    // é renderizado e o valor permanece nulo, comportamento esperado pelo
    // backend (coluna `professionalState` é opcional).
    final professionalId = _professionalIdController.text.trim();
    final professionalState = _selectedCouncilState;

    final outcome = await authProvider.registerWithProfessionalInfo(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim().toLowerCase(),
      birthDate: birthDate,
      password: _passwordController.text,
      professionalType: professionalType,
      professionalId: professionalId,
      professionalState: professionalState,
      specialty: _specialtyController.text.trim().isNotEmpty
          ? _specialtyController.text.trim()
          : null,
      // Campos de endereço — todos opcionais conforme descrição da task
      zipCode: _zipCodeController.text.trim().isNotEmpty
          ? _zipCodeController.text.trim()
          : null,
      street: _streetController.text.trim().isNotEmpty
          ? _streetController.text.trim()
          : null,
      streetNumber: _streetNumberController.text.trim().isNotEmpty
          ? _streetNumberController.text.trim()
          : null,
      complement: _complementController.text.trim().isNotEmpty
          ? _complementController.text.trim()
          : null,
      district: _districtController.text.trim().isNotEmpty
          ? _districtController.text.trim()
          : null,
      addressCity: _addressCityController.text.trim().isNotEmpty
          ? _addressCityController.text.trim()
          : null,
      addressState: _addressState,
    );

    if (!mounted) return;

    // Tratamento tripartido (TASK 207 / PBI 201) — distingue sucesso completo,
    // sucesso parcial (auth.users criado mas perfil falhou) e falha pré-signUp.
    switch (outcome) {
      case RegistrationOutcome.success:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Cadastro realizado com sucesso! Faca login para continuar.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        Navigator.pop(context);
        break;
      case RegistrationOutcome.profileIncomplete:
        // Sucesso parcial — NÃO orientar a repetir o cadastro (e-mail já em uso).
        // Cor laranja para diferenciar de sucesso pleno e de falha real.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ??
                'Conta criada. Faça login e complete seus dados.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context);
        break;
      case RegistrationOutcome.failure:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Erro ao cadastrar'),
            backgroundColor: Colors.red,
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Criar Nova Conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _firstNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Primeiro Nome',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) => _validateName(value, 'o primeiro nome'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Sobrenome',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) => _validateName(value, 'o sobrenome'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<ProfessionalType>(
                  key: const Key('professional-type-dropdown'),
                  initialValue: _selectedProfessionalType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Profissional',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                  ),
                  items: ProfessionalType.values
                      // Exclui PACIENTE do dropdown — pacientes usam a tela própria
                      .where((t) => !t.isPatient)
                      .map(
                        (type) => DropdownMenuItem<ProfessionalType>(
                          value: type,
                          child: Text(type.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProfessionalType = value;
                      _professionalIdController.clear();
                      // Limpa UF do conselho ao trocar o tipo de profissional
                      // para evitar combinações incoerentes (ex: CRM + UF
                      // selecionada após mudar para ADMINISTRATIVO, que não
                      // usa registro em conselho).
                      _selectedCouncilState = null;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Selecione o tipo de profissional';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _selectedProfessionalType == null
                      ? const SizedBox.shrink()
                      : Column(
                          key: ValueKey<String>(
                              _selectedProfessionalType!.value),
                          children: [
                            TextFormField(
                              controller: _professionalIdController,
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                // Label/hint deixam claro que o campo recebe
                                // APENAS o número do registro. A UF é coletada
                                // no Dropdown imediatamente abaixo (TASK 163).
                                labelText:
                                    'Número do ${_selectedProfessionalType!.councilName}',
                                hintText:
                                    _selectedProfessionalType!.requiresCouncil
                                        ? 'Ex: 123456'
                                        : 'Ex: MAT-2024-001',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.badge),
                                helperText: 'Campo obrigatorio',
                              ),
                              // Validação local mínima: não-vazio e tamanho
                              // mínimo. Validação de UF é responsabilidade do
                              // Dropdown abaixo, o que evita parsing frágil
                              // da string "123456-SP".
                              validator: (value) {
                                final input = value?.trim() ?? '';
                                if (input.isEmpty) {
                                  return 'Informe obrigatoriamente o seu '
                                      '${_selectedProfessionalType!.councilName}';
                                }
                                if (input.length < 3) {
                                  return '${_selectedProfessionalType!.councilName} '
                                      'deve ter no minimo 3 caracteres';
                                }
                                return null;
                              },
                            ),
                            // Só mostra UF para profissionais que possuem
                            // registro em conselho (médico, enfermeiro etc.).
                            // ADMINISTRATIVO/OUTROS usam matrícula interna,
                            // que não tem UF.
                            if (_selectedProfessionalType!.requiresCouncil) ...[
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                key: const Key('council-state-dropdown'),
                                initialValue: _selectedCouncilState,
                                decoration: const InputDecoration(
                                  labelText: 'UF do Conselho',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.flag_outlined),
                                  helperText: 'Campo obrigatorio',
                                ),
                                items: _ufOptions
                                    .map(
                                      (uf) => DropdownMenuItem<String>(
                                        value: uf,
                                        child: Text(uf),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => _selectedCouncilState = value);
                                },
                                // Obrigatório apenas quando o tipo selecionado
                                // exige registro em conselho. Em runtime o
                                // dropdown nem é renderizado se !requiresCouncil,
                                // mas a guarda extra protege contra mudanças
                                // futuras de fluxo.
                                validator: (value) {
                                  if (_selectedProfessionalType
                                          ?.requiresCouncil !=
                                      true) {
                                    return null;
                                  }
                                  if (value == null || value.isEmpty) {
                                    return 'Selecione a UF do conselho';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _birthDateController,
                  // readOnly removido — permite digitação direta com máscara
                  keyboardType: TextInputType.number,
                  inputFormatters: [_DateMaskFormatter()],
                  onChanged: (text) {
                    // Ao completar 10 caracteres (DD/MM/AAAA), parseia e
                    // atualiza _selectedBirthDate para validação e envio
                    if (text.length == 10) {
                      setState(() => _selectedBirthDate = _parseDateText(text));
                    } else {
                      // Reseta para forçar nova validação ao limpar o campo
                      setState(() => _selectedBirthDate = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Data de Nascimento',
                    hintText: 'DD/MM/AAAA',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.cake_outlined),
                    // Ícone de calendário mantido para abrir DatePicker
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      tooltip: 'Selecionar data no calendário',
                      onPressed: _pickBirthDate,
                    ),
                  ),
                  validator: (_) => _validateBirthDate(),
                ),
                const SizedBox(height: 12),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: _selectedProfessionalType == ProfessionalType.medico ||
                          _selectedProfessionalType ==
                              ProfessionalType.dentista ||
                          _selectedProfessionalType ==
                              ProfessionalType.psicologo
                      ? Column(
                          children: [
                            TextFormField(
                              controller: _specialtyController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Especialidade',
                                hintText: 'Ex: Clinica Geral, Pediatria',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.medical_services),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: _validatePassword,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Confirme sua senha';
                    if (value != _passwordController.text) {
                      return 'As senhas nao coincidem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // --- Seção Endereço ---
                // Campos opcionais. CEP dispara ViaCEP automaticamente ao
                // completar 8 dígitos; logradouro, bairro e cidade são
                // preenchidos automaticamente e ficam somente-leitura.
                Text(
                  'Endereço (opcional)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _zipCodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  // Contador de caracteres desnecessário para CEP — remove-se
                  // o sufixo de "X/8" que polui o campo visualmente
                  decoration: InputDecoration(
                    labelText: 'CEP',
                    hintText: '00000000',
                    border: const OutlineInputBorder(),
                    counterText: '',
                    prefixIcon: _isSearchingCep
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _streetController,
                  // readOnly: preenchido automaticamente via ViaCEP —
                  // bloqueia edição acidental; o usuário pode ainda limpar
                  // e redigitar se o logradouro vier incompleto da API
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Logradouro',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.signpost_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      flex: 2,
                      child: TextFormField(
                        controller: _streetNumberController,
                        keyboardType: TextInputType.streetAddress,
                        decoration: const InputDecoration(
                          labelText: 'Número',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 3,
                      child: TextFormField(
                        controller: _complementController,
                        decoration: const InputDecoration(
                          labelText: 'Complemento',
                          hintText: 'Apto, sala…',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _districtController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Bairro',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Flexible(
                      flex: 3,
                      child: TextFormField(
                        controller: _addressCityController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Cidade',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_city_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _addressState,
                        decoration: const InputDecoration(
                          labelText: 'UF',
                          border: OutlineInputBorder(),
                        ),
                        items: _ufOptions
                            .map(
                              (uf) => DropdownMenuItem<String>(
                                value: uf,
                                child: Text(uf),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _addressState = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleRegister,
                        child: const Text(
                          'Cadastrar',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
