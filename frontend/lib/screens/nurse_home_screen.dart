import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

/// Tela inicial do Enfermeiro — ponto de entrada para o fluxo de triagem
/// de solicitações de renovação de receitas dos pacientes.
///
/// A triagem consiste em avaliar a necessidade clínica da renovação antes
/// de encaminhar a solicitação ao médico responsável pela UBS.
///
/// Esta é a estrutura inicial da tela — a listagem de solicitações será
/// implementada no PBI de Fluxo de Renovação (Enfermeiro).
class NurseHomeScreen extends StatelessWidget {
  const NurseHomeScreen({super.key});

  /// Encerra a sessão e redireciona para o login.
  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final nurseName = authProvider.user?.name ?? 'Enfermeiro(a)';

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-ReceitaSUS — Triagem'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _handleLogout(context),
            tooltip: 'Sair do aplicativo',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NurseWelcomeCard(nurseName: nurseName),
            const SizedBox(height: 24),
            _PendingRenewalsSection(),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets privados
// =============================================================================

/// Card de boas-vindas com nome do enfermeiro autenticado.
class _NurseWelcomeCard extends StatelessWidget {
  const _NurseWelcomeCard({required this.nurseName});

  final String nurseName;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.health_and_safety_outlined,
                    color: AppColors.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bem-vindo(a), $nurseName!',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Painel de Triagem — UBS',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Avalie as solicitações de renovação de receitas dos pacientes '
              'e encaminhe ao médico responsável quando necessário.',
              style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seção de solicitações pendentes de triagem.
///
/// Placeholder para expansão no PBI de Fluxo de Renovação — Enfermeiro.
/// Exibirá stream realtime das solicitações com status PENDING_TRIAGE.
class _PendingRenewalsSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Solicitações Pendentes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        // Estado vazio — exibido até a implementação do stream de triagem
        _EmptyPendingState(),
      ],
    );
  }
}

/// Estado vazio da lista de solicitações pendentes.
class _EmptyPendingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 64,
            color: AppColors.outlineVariant,
          ),
          SizedBox(height: 16),
          Text(
            'Nenhuma solicitação de renovação pendente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'As solicitações dos pacientes aparecerão aqui\npara você avaliar a necessidade clínica.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.outlineVariant,
            ),
          ),
        ],
      ),
    );
  }
}
