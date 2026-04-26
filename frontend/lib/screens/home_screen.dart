import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/renewal_request_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../models/prescription_model.dart';
import '../providers/renewal_provider.dart';
import '../services/prescription_service.dart'; // Importação do novo serviço
import '../widgets/prescription_card.dart';
import 'history_screen.dart';

import 'renewal_tracking_screen.dart';
import 'request_renewal_screen.dart';

/// Tela Inicial do Paciente
///
/// Refatorada para a Etapa 2 para suportar sincronismo em tempo real
/// com o banco de dados Supabase.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Encerra a sessão e redireciona para o login
  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  /// Navega para a tela de solicitação de renovação de prescrição.
  /// Usa [MaterialPageRoute] para empilhar a tela mantendo o botão de voltar.
  void _handleSolicitation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RequestRenewalScreen()),
    );
  }

  /// Navega para a tela de rastreamento de pedidos de renovação.
  ///
  /// Usa [MaterialPageRoute] em vez de rota nomeada para evitar dependência
  /// de contexto de argumento — a tela lê o [RenewalProvider] diretamente.
  void _handleTrack(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const RenewalTrackingScreen(),
      ),
    );
  }

  void _handleHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'Usuário SUS';

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-ReceitaSUS - Área do Paciente'),
        // Mantendo consistência visual com o tema definido no main.dart
        actions: [
          // Botão de alternância de tema — sol para claro, lua para escuro
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) => IconButton(
              icon: Icon(
                themeProvider.isDark ? Icons.light_mode : Icons.dark_mode,
                color: Colors.white,
              ),
              onPressed: themeProvider.toggleTheme,
              tooltip: themeProvider.isDark ? 'Tema claro' : 'Tema escuro',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _handleLogout(context),
            tooltip: 'Sair do aplicativo',
          ),
        ],
      ),
      // SafeArea aplicado por causa do modo edge-to-edge habilitado em main.dart
      // (PBI #199 / TASK #218): impede que botões/conteúdo sejam ocultados pela
      // system navigation bar do Android (gesture nav e botões virtuais).
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          // Adicionada funcionalidade de "puxar para atualizar"
          onRefresh: () async => debugPrint('Atualizando dados...'),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Card de Boas-Vindas Dinâmico
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bem-vindo(a), $userName!',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Acompanhe abaixo suas prescrições digitais em tempo real.',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Ações Principais
                ElevatedButton.icon(
                  onPressed: () => _handleSolicitation(context),
                  icon: const Icon(Icons.medical_services_outlined, size: 24),
                  label: const Text('Solicitar Renovação'),
                ),
                const SizedBox(height: 10),

                OutlinedButton.icon(
                  // Passa o contexto para permitir a navegação via Navigator
                  onPressed: () => _handleTrack(context),
                  icon: const Icon(Icons.track_changes),
                  label: const Text('Rastrear Status do Pedido'),
                ),
                const SizedBox(height: 30),

                // Seção de acompanhamento dos pedidos de renovação em tempo real
                const _RenewalSection(),
                const SizedBox(height: 10),

                // Seção de Prescrições Ativas (Real-time)
                const Text(
                  'Prescrições Recentes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                // IMPLEMENTAÇÃO DO STREAMBUILDER (Ponto Crítico da Etapa 2)
                // Substitui o antigo Placeholder estático
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: PrescriptionService().streamPrescriptions(),
                  builder: (context, snapshot) {
                    // Estado de Carregamento
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20.0),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    // Estado de Erro
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Erro ao carregar dados da nuvem.'),
                      );
                    }

                    // Estado Vazio (Sem receitas no banco)
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(30.0),
                          child: Text(
                            'Nenhuma receita encontrada no sistema.\nSolicite sua primeira prescrição digital!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      );
                    }

                    // Lista de Receitas Reais — converte Map para modelo antes de renderizar
                    final prescriptions =
                        snapshot.data!.map(PrescriptionModel.fromJson).toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: prescriptions.length,
                      itemBuilder: (context, index) {
                        final prescription = prescriptions[index];
                        return PrescriptionCard(
                          prescription: prescription,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/prescription_view',
                            arguments: prescription,
                          ),
                        );
                      },
                    );
                  },
                ),

                const SizedBox(height: 20),

                TextButton.icon(
                  onPressed: () => _handleHistory(context),
                  icon: const Icon(Icons.history),
                  label: const Text('Acessar Histórico Completo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RenewalSection — seção de pedidos de renovação (StatefulWidget)
// ---------------------------------------------------------------------------

/// Seção que exibe em tempo real os pedidos de renovação do paciente.
///
/// Implementada como [StatefulWidget] para inicializar o stream uma única
/// vez no [initState], evitando recriação a cada rebuild da [HomeScreen].
class _RenewalSection extends StatefulWidget {
  const _RenewalSection();

  @override
  State<_RenewalSection> createState() => _RenewalSectionState();
}

class _RenewalSectionState extends State<_RenewalSection> {
  /// Stream inicializado uma única vez para não recriar a conexão Supabase
  /// a cada rebuild da tela pai.
  late final Stream<List<RenewalRequestModel>> _stream;

  @override
  void initState() {
    super.initState();
    // Captura o provider no initState — seguro pois o contexto já está montado
    _stream = context.read<RenewalProvider>().streamMyRenewals();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Meus Pedidos de Renovação',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<List<RenewalRequestModel>>(
          stream: _stream,
          builder: (context, snapshot) {
            // Estado de carregamento inicial do stream
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            // Erro ao conectar ou ao processar os dados do Supabase
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Não foi possível carregar seus pedidos. Tente novamente.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              );
            }

            final renewals = snapshot.data ?? [];

            // Estado vazio — nenhum pedido enviado ainda
            if (renewals.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhum pedido de renovação enviado ainda.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              );
            }

            // Lista de pedidos recebidos em tempo real
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: renewals.length,
              itemBuilder: (_, index) => _RenewalCard(renewal: renewals[index]),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _RenewalCard — card individual de pedido de renovação
// ---------------------------------------------------------------------------

/// Card que exibe as informações resumidas de um pedido de renovação.
///
/// Mostra: nome do medicamento, data do pedido e chip colorido de status.
class _RenewalCard extends StatelessWidget {
  final RenewalRequestModel renewal;

  const _RenewalCard({required this.renewal});

  /// Retorna a cor de fundo do chip conforme o status do pedido.
  ///
  /// Mapeamento visual definido no PBI 130:
  /// - PENDING_TRIAGE → cinza (aguardando)
  /// - TRIAGED        → amarelo (em andamento)
  /// - PRESCRIBED     → verde (concluído com sucesso)
  /// - REJECTED       → vermelho (encerrado sem renovação)
  Color _chipColor(RenewalStatus status) {
    return switch (status) {
      RenewalStatus.pendingTriage => Colors.grey.shade300,
      RenewalStatus.triaged => Colors.amber.shade200,
      RenewalStatus.prescribed => Colors.green.shade200,
      RenewalStatus.rejected => Colors.red.shade200,
    };
  }

  /// Retorna a cor do texto do chip para manter contraste mínimo AA.
  Color _chipTextColor(RenewalStatus status) {
    return switch (status) {
      RenewalStatus.pendingTriage => Colors.grey.shade800,
      RenewalStatus.triaged => Colors.amber.shade900,
      RenewalStatus.prescribed => Colors.green.shade900,
      RenewalStatus.rejected => Colors.red.shade900,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Formata a data de criação do pedido para exibição amigável em PT-BR
    final date = renewal.createdAt.toLocal();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final medicine = renewal.medicineName ?? 'Medicamento não informado';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Ícone de renovação para identificação visual rápida
            const Icon(Icons.autorenew, size: 28, color: Colors.blueGrey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Solicitado em $dateStr',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Chip colorido de status com semântica para acessibilidade
            Semantics(
              label: 'Status do pedido: ${renewal.status.label}',
              child: Chip(
                label: Text(
                  renewal.status.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: _chipTextColor(renewal.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: _chipColor(renewal.status),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
