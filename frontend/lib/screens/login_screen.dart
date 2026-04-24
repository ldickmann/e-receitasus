import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  /// FocusNode do campo e-mail — ao pressionar Enter, move foco para a senha.
  final _emailFocusNode = FocusNode();

  /// FocusNode do campo senha — ao pressionar Enter, submete o formulário.
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Chama login real
    final success = await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // Rota baseada no tipo de profissional
      final route = _resolveHomeRoute(authProvider);
      Navigator.pushReplacementNamed(context, route);
    } else {
      // Exibe erro
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'Erro ao fazer login'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _resolveHomeRoute(AuthProvider authProvider) {
    final type = authProvider.user?.professionalType;
    if (type == null) return '/home';
    if (type.canPrescribe) return '/doctor_home';
    if (type.isNurse) return '/nurse_home';
    return '/home';
  }

  void _handleRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  /// Navega para a tela de cadastro exclusiva de pacientes.
  ///
  /// Separado do fluxo profissional para que pacientes não vejam
  /// campos de conselho (CRM, COREN etc.) que não se aplicam a eles.
  void _handlePatientRegister() {
    Navigator.pushNamed(context, '/register_patient');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('App E-ReceitaSUS'),
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
                // Logo institucional do E-ReceitaSUS — reforça identidade visual
                // antes do título de acesso. `Image.asset` é carregada de forma
                // síncrona pois o asset está embarcado no bundle (pubspec.yaml).
                Image.asset(
                  'assets/images/logo-e-receitasus.png',
                  height: 140,
                  fit: BoxFit.contain,
                  // semanticLabel garante acessibilidade para leitores de tela
                  semanticLabel: 'Logo E-ReceitaSUS',
                ),
                const SizedBox(height: 24),
                Text(
                  'Acesso do Paciente / Administrador',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 25),

                // Campo de Email — Enter move o foco para a senha
                TextFormField(
                  controller: _emailController,
                  focusNode: _emailFocusNode,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) {
                    // Move o foco para o campo de senha ao pressionar Enter
                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                  },
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

                // Campo de Senha — Enter submete o formulário diretamente
                TextFormField(
                  controller: _passwordController,
                  focusNode: _passwordFocusNode,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    // Submete o formulário ao pressionar Enter na senha
                    _handleLogin();
                  },
                  decoration: const InputDecoration(
                    labelText: 'Senha',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, informe sua senha';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                // Botão de Login com Loading
                authProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _handleLogin,
                        child: const Text(
                          'Entrar',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                const SizedBox(height: 10),

                // Botão de Cadastro (profissional do SUS)
                TextButton(
                  onPressed: _handleRegister,
                  child: const Text('Cadastro para Profissionais do SUS'),
                ),
                // Botão de cadastro de paciente — fluxo separado sem dados de conselho.
                // Usa cor secundária (azul) para diferenciar visualmente dos dois fluxos.
                ElevatedButton(
                  onPressed: _handlePatientRegister,
                  style: ElevatedButton.styleFrom(
                    // Azul secundário — identidade visual do E-ReceitaSUS
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Cadastro Usuário SUS'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
