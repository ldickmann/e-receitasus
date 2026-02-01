import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/professional_type.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _professionalIdController = TextEditingController();
  final _specialtyController = TextEditingController();

  ProfessionalType _selectedProfessionalType = ProfessionalType.administrativo;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _professionalIdController.dispose();
    _specialtyController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Extrai número e estado do registro profissional se fornecido
    String? professionalId;
    String? professionalState;

    if (_professionalIdController.text.isNotEmpty) {
      professionalId = _selectedProfessionalType
          .extractNumber(_professionalIdController.text);
      professionalState = _selectedProfessionalType
          .extractState(_professionalIdController.text);
    }

    final success = await authProvider.registerWithProfessionalInfo(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      professionalType: _selectedProfessionalType,
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
              'Cadastro realizado com sucesso! Faça login para continuar.'),
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
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Criar Nova Conta',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 25),

                // Campo de Nome
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe seu nome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Campo de Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'E-mail SUS',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe seu e-mail';
                    }
                    if (!value.contains('@')) {
                      return 'E-mail inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Dropdown de Tipo de Profissional
                DropdownButtonFormField<ProfessionalType>(
                  value: _selectedProfessionalType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Profissional',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.work),
                    helperText: 'Selecione sua categoria profissional',
                  ),
                  items: ProfessionalType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProfessionalType = value!;
                      _professionalIdController.clear();
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Por favor, selecione o tipo de profissional';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Campo de Registro Profissional (condicional)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedProfessionalType.requiresCouncil ||
                          _selectedProfessionalType == ProfessionalType.outros
                      ? Column(
                          children: [
                            TextFormField(
                              controller: _professionalIdController,
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                labelText:
                                    _selectedProfessionalType.registrationLabel,
                                hintText:
                                    _selectedProfessionalType.registrationHint,
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.badge),
                                helperText:
                                    _selectedProfessionalType.requiresCouncil
                                        ? 'Obrigatório para prescrever receitas'
                                        : 'Opcional',
                              ),
                              validator: (value) {
                                if (_selectedProfessionalType.requiresCouncil) {
                                  return _selectedProfessionalType
                                      .validateRegistration(value);
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                // Campo de Especialidade (condicional para médicos e outros)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _selectedProfessionalType == ProfessionalType.medico ||
                          _selectedProfessionalType ==
                              ProfessionalType.dentista ||
                          _selectedProfessionalType ==
                              ProfessionalType.psicologo
                      ? Column(
                          children: [
                            TextFormField(
                              controller: _specialtyController,
                              keyboardType: TextInputType.text,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Especialidade',
                                hintText: 'Ex: Clínico Geral, Pediatria',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.medical_services),
                                helperText: 'Opcional',
                              ),
                            ),
                            const SizedBox(height: 15),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                // Campo de Senha
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe sua senha';
                    }
                    if (value.length < 8) {
                      return 'A senha deve ter no mínimo 8 caracteres';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 15),

                // Campo de Confirmação de Senha
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, confirme sua senha';
                    }
                    if (value != _passwordController.text) {
                      return 'As senhas não coincidem';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // Botão de Cadastrar com Loading
                authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleRegister,
                        child: const Text(
                          'Cadastrar',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                const SizedBox(height: 10),

                // Botão de Voltar
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Já tem conta? Faça login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
