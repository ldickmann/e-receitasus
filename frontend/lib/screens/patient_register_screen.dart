import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Tela de cadastro exclusiva para pacientes do SUS.
///
/// Separada da RegisterScreen (profissionais de saúde) para que o fluxo de
/// pacientes seja mais simples, sem exigir dados de conselho profissional.
/// Campos obrigatórios: nome, sobrenome, data de nascimento, e-mail, senha
/// e telefone celular. CNS é o único campo opcional.
class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _cnsController = TextEditingController();
  final _phoneController = TextEditingController();

  DateTime? _selectedBirthDate;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cnsController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  /// Abre o seletor de data de nascimento.
  ///
  /// Sem restrição de idade mínima — o SUS atende desde recém-nascidos.
  /// Limite superior é hoje para evitar datas futuras inválidas.
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
      setState(() => _selectedBirthDate = picked);
    }
  }

  /// Envia o formulário ao provider e reage ao resultado.
  ///
  /// Em sucesso exibe SnackBar informativo e retorna para a tela anterior
  /// (LoginScreen), pois o usuário pode precisar confirmar o e-mail antes
  /// de acessar o app dependendo da configuração do Supabase.
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBirthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe a data de nascimento.')),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.registerPatient(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      birthDate: _selectedBirthDate!,
      password: _passwordController.text,
      cns: _cnsController.text.trim().isEmpty
          ? null
          : _cnsController.text.trim(),
      // Telefone é obrigatório — o validator já garante que não está vazio
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // Mensagem genérica — pode haver confirmação de e-mail pendente
          content: Text(
            'Cadastro realizado! Verifique seu e-mail para confirmar o acesso.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
      // Retorna para LoginScreen — o usuário fará login após confirmar o e-mail
      Navigator.pop(context);
    } else {
      // Exibe mensagem de erro do provider sem expor detalhes internos
      if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        authProvider.clearError();
      }
    }
  }

  /// Formata a data de nascimento selecionada para exibição no botão.
  String get _formattedBirthDate {
    if (_selectedBirthDate == null) return 'Selecionar data de nascimento *';
    final d = _selectedBirthDate!;
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro de Paciente'),
        // Garante botão de voltar visível para telas com teclado aberto
        leading: const BackButton(),
      ),
      body: SafeArea(
        child: Selector<AuthProvider, bool>(
          // Reconstrói apenas o corpo quando isLoading muda, não toda a árvore
          selector: (_, auth) => auth.isLoading,
          builder: (context, isLoading, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _SectionHeader('Dados Pessoais'),
                    const SizedBox(height: 12),
                    // Nome — obrigatório
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nome *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o nome.' : null,
                    ),
                    const SizedBox(height: 12),
                    // Sobrenome — obrigatório
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Sobrenome *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Informe o sobrenome.' : null,
                    ),
                    const SizedBox(height: 12),
                    // Data de nascimento — obrigatória, sem restrição de idade
                    Semantics(
                      label: 'Data de nascimento: $_formattedBirthDate',
                      button: true,
                      // OutlinedButton puro com Row evita overflow do ícone
                      // que ocorria com OutlinedButton.icon + alignment.centerLeft
                      child: OutlinedButton(
                        onPressed: _selectBirthDate,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          alignment: Alignment.centerLeft,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 20,
                              // Usa a cor primária para indicar que é selecionável,
                              // igual ao comportamento dos outros ícones prefixos
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _formattedBirthDate,
                              style: TextStyle(
                                // Cor primária enquanto não selecionado (placeholder)
                                // Cor padrão de texto quando já tem valor
                                color: _selectedBirthDate == null
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionHeader('Acesso'),
                    const SizedBox(height: 12),
                    // E-mail — obrigatório
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'E-mail *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Informe o e-mail.';
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
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePassword = !_obscurePassword),
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
                    // Confirmar senha — deve ser idêntica à senha
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha *',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                          tooltip: _obscureConfirmPassword
                              ? 'Mostrar senha'
                              : 'Ocultar senha',
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSubmit(),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Confirme a senha.';
                        }
                        // Verifica correspondência localmente para não enviar ao servidor
                        if (v != _passwordController.text) {
                          return 'As senhas não coincidem.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // "Saúde" (sem "opcional") porque o telefone é obrigatório;
                    // apenas o CNS permanece opcional nesta seção
                    const _SectionHeader('Saúde'),
                    const SizedBox(height: 12),
                    // Telefone — obrigatório; DDD + número, exatamente 11 dígitos
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        // DDD (2) + 9 dígitos = 11 caracteres
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
                          // Campo obrigatório para contato do paciente
                          return 'Informe o telefone celular.';
                        }
                        if (v.trim().length != 11) {
                          return 'Informe DDD + número (11 dígitos).';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // CNS — único campo verdadeiramente opcional; pode ser
                    // informado depois pelo paciente no perfil
                    TextFormField(
                      controller: _cnsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        // Limita a 15 dígitos conforme especificação do CNS
                        LengthLimitingTextInputFormatter(15),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'CNS (Cartão Nacional de Saúde)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.credit_card),
                        hintText: 'Opcional — até 15 dígitos',
                      ),
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: 28),
                    // Botão de cadastro — desabilitado durante loading para evitar duplo envio
                    FilledButton(
                      onPressed: isLoading ? null : _handleSubmit,
                      style: FilledButton.styleFrom(
                        // Target de toque ≥ 48dp conforme diretrizes de acessibilidade
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
}

/// Cabeçalho de seção do formulário.
///
/// Separa visualmente grupos de campos relacionados sem criar
/// hierarquia de navegação extra — mantém o formulário em uma única tela.
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
