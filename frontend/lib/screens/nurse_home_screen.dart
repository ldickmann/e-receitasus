import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/renewal_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/triage_provider.dart';
import '../theme/app_colors.dart';
import 'triage_detail_screen.dart';

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

/// Seção de solicitações pendentes de triagem com stream realtime.
///
/// Usa [StatefulWidget] para memoizar o stream de [TriageProvider.streamPendingTriage]
/// no [initState], evitando reconexão a cada rebuild — mesmo padrão adotado
/// na [HomeScreen] para pedidos de renovação do paciente.
class _PendingRenewalsSection extends StatefulWidget {
  @override
  State<_PendingRenewalsSection> createState() => _PendingRenewalsSectionState();
}

class _PendingRenewalsSectionState extends State<_PendingRenewalsSection> {
  late final Stream<List<RenewalRequestModel>> _stream;

  @override
  void initState() {
    super.initState();
    // Memoiza o stream na inicialização para que o StreamBuilder não crie
    // uma nova assinatura a cada rebuild da árvore de widgets.
    _stream = context.read<TriageProvider>().streamPendingTriage();
  }

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

        StreamBuilder<List<RenewalRequestModel>>(
          stream: _stream,
          builder: (context, snapshot) {
            // Aguardando primeira emissão do stream (conexão em andamento)
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            // Erro retornado pelo stream (ex.: sem permissão RLS ou offline)
            if (snapshot.hasError) {
              return const _ErrorState(
                message:
                    'Não foi possível carregar as solicitações. '
                    'Verifique sua conexão e tente novamente.',
              );
            }

            final requests = snapshot.data ?? [];

            // Nenhuma solicitação pendente — reutiliza widget de estado vazio já existente
            if (requests.isEmpty) return const _EmptyPendingState();

            // Lista de cards tocáveis para cada pedido pendente
            return ListView.separated(
              // Desabilita scroll próprio — controlado pelo SingleChildScrollView pai
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _PendingRequestCard(request: requests[index]),
            );
          },
        ),
      ],
    );
  }
}

/// Card individual de um pedido de renovação aguardando triagem.
///
/// Exibe: nome do medicamento, data de criação formatada e chip de status.
/// O toque navega para [TriageDetailScreen] passando o pedido completo.
class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({required this.request});

  final RenewalRequestModel request;

  /// Mapeia [RenewalStatus] para a cor de fundo do chip de status.
  Color _chipColor(RenewalStatus status) {
    return switch (status) {
      RenewalStatus.pendingTriage => Colors.grey.shade300,
      RenewalStatus.triaged      => Colors.amber.shade200,
      RenewalStatus.prescribed   => Colors.green.shade200,
      RenewalStatus.rejected     => Colors.red.shade200,
    };
  }

  @override
  Widget build(BuildContext context) {
    final medicine = request.medicineName ?? 'Medicamento não informado';
    // Formata a data de criação do pedido para exibição amigável em PT-BR
    final date = request.createdAt.toLocal();
    final dateFormatted =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          // Navega para a tela de detalhes passando o pedido completo
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TriageDetailScreen(request: request),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Ícone representativo da triagem
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication_outlined,
                  color: AppColors.onPrimaryContainer,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Informações principais do pedido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solicitado em $dateFormatted',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Chip de status com semântica para acessibilidade
              Semantics(
                label: 'Status: ${request.status.label}',
                child: Chip(
                  label: Text(
                    request.status.label,
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: _chipColor(request.status),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado de erro ao carregar solicitações pendentes.
///
/// Exibe mensagem humanizada sem expor detalhes internos (LGPD).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vazio da lista de solicitações pendentes.
class _EmptyPendingState extends StatelessWidget {
  const _EmptyPendingState();

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
