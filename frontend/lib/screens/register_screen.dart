import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

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

  ProfessionalType? _selectedProfessionalType;
  DateTime? _selectedBirthDate;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _professionalIdController.dispose();
    _specialtyController.dispose();
    _birthDateController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
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

    final professionalIdRaw = _professionalIdController.text.trim();
    final professionalId = professionalType.extractNumber(professionalIdRaw);
    final professionalState = professionalType.extractState(professionalIdRaw);

    final success = await authProvider.registerWithProfessionalInfo(
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
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cadastro realizado com sucesso! Faca login para continuar.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Erro ao cadastrar'),
          backgroundColor: Colors.red,
        ),
      );
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
                  value: _selectedProfessionalType,
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
                      : TextFormField(
                          key: ValueKey<String>(
                              _selectedProfessionalType!.value),
                          controller: _professionalIdController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                            labelText:
                                _selectedProfessionalType!.registrationLabel,
                            hintText:
                                _selectedProfessionalType!.registrationHint,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.badge),
                            helperText: 'Campo obrigatorio',
                          ),
                          validator: (value) {
                            if (_selectedProfessionalType == null) return null;
                            return _selectedProfessionalType!
                                .validateRegistration(value);
                          },
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
