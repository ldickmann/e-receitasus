import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prescription_model.dart';
import '../models/prescription_type.dart';
import '../models/renewal_request_model.dart';
import '../providers/auth_provider.dart';
import '../services/prescription_service.dart';
import '../services/renewal_service.dart';
import 'prescription_type_screen.dart';
import 'prescription_view_screen.dart';
import 'renewal_prescription_screen.dart';

/// Tela principal para profissionais de saúde (médicos, dentistas, etc.).
///
/// Exibe as receitas emitidas pelo médico autenticado em tempo real
/// e permite emitir novas prescrições digitais.
class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final doctorName = user?.name ?? 'Profissional';
    final specialty = user?.specialty;
    final councilInfo = user?.formattedRegistration;

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-ReceitaSUS — Prescritor'),
        backgroundColor: const Color(0xFF009B3A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _handleLogout(context),
            tooltip: 'Sair',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card de boas-vindas do médico
              _DoctorWelcomeCard(
                doctorName: doctorName,
                specialty: specialty,
                councilInfo: councilInfo,
                professionalType:
                    user?.professionalType.displayName ?? 'Profissional',
              ),
              const SizedBox(height: 20),

              // Botão principal: nova receita
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrescriptionTypeScreen(),
                  ),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 22),
                label: const Text(
                  'Nova Receita',
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009B3A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Legenda de tipos de receita
              const _PrescriptionTypeLegend(),
              const SizedBox(height: 24),

              // Seção de renovações pendentes — aparece apenas quando há pedidos
              // com status TRIAGED designados para este médico.
              // Usa StreamBuilder direto (sem Provider) pois o dado é exclusivo
              // desta tela e não precisa ser compartilhado globalmente.
              const _PendingRenewalsSection(),

              // Lista de receitas emitidas (stream em tempo real)
              const Text(
                'Receitas Emitidas',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: PrescriptionService().streamDoctorPrescriptions(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return const _EmptyState(
                      icon: Icons.cloud_off,
                      message:
                          'Não foi possível carregar as receitas.\nVerifique sua conexão.',
                      color: Colors.red,
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.receipt_long_outlined,
                      message:
                          'Nenhuma receita emitida ainda.\nToque em "Nova Receita" para começar.',
                      color: Colors.grey,
                    );
                  }

                  final list = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final prescription = PrescriptionModel.fromJson(item);
                      return _PrescriptionListTile(
                        prescription: prescription,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PrescriptionViewScreen(
                              prescription: prescription,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Widgets do DoctorHomeScreen
// =============================================================================

class _DoctorWelcomeCard extends StatelessWidget {
  const _DoctorWelcomeCard({
    required this.doctorName,
    required this.professionalType,
    this.specialty,
    this.councilInfo,
  });

  final String doctorName;
  final String professionalType;
  final String? specialty;
  final String? councilInfo;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF009B3A), Color(0xFF00732D)],
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 28,
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF009B3A), size: 32),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    professionalType,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                  if (specialty != null)
                    Text(
                      specialty!,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  if (councilInfo != null)
                    Text(
                      councilInfo!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                          fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrescriptionTypeLegend extends StatelessWidget {
  const _PrescriptionTypeLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: PrescriptionType.values.map((type) {
        return Chip(
          avatar: Icon(type.icon, size: 14, color: type.foregroundColor),
          label: Text(
            type.displayName.split(' ').first,
            style: TextStyle(fontSize: 11, color: type.foregroundColor),
          ),
          backgroundColor: type.backgroundColor,
          side: BorderSide(color: type.foregroundColor.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }
}

class _PrescriptionListTile extends StatelessWidget {
  const _PrescriptionListTile({
    required this.prescription,
    required this.onTap,
  });

  final PrescriptionModel prescription;
  final VoidCallback onTap;

  Color get _typeColor => prescription.type.backgroundColor;

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;
    final isExpired = prescription.isExpired;
    final statusColor = isExpired
        ? const Color(0xFFD32F2F)
        : prescription.status == 'utilizada'
            ? Colors.grey
            : const Color(0xFF2E7D32);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: type.foregroundColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: _typeColor,
              shape: BoxShape.circle,
              border: Border.all(color: type.foregroundColor.withValues(alpha: 0.3)),
            ),
          child: Icon(type.icon, color: type.foregroundColor, size: 20),
        ),
        title: Text(
          prescription.medicineName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paciente: ${prescription.patientName}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              '${type.displayName.split(' ').take(2).join(' ')} • '
              '${_formatDate(prescription.issuedAt)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: statusColor),
              ),
              child: Text(
                isExpired
                    ? 'Vencida'
                    : prescription.status.isEmpty
                        ? ''
                        : prescription.status[0].toUpperCase() +
                            prescription.status.substring(1),
                style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 64, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Seção de Renovações Pendentes
// =============================================================================

/// Seção que exibe os pedidos de renovação TRIAGED designados ao médico logado.
///
/// Usa [RenewalService.streamTriagedForDoctor] para receber atualizações em
/// tempo real via Supabase Realtime. A seção é invisível (`SizedBox.shrink`)
/// quando não há pedidos, evitando espaço em branco desnecessário na tela.
class _PendingRenewalsSection extends StatelessWidget {
  const _PendingRenewalsSection();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RenewalRequestModel>>(
      stream: RenewalService().streamTriagedForDoctor(),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];

        // Oculta a seção completamente quando não há pedidos pendentes —
        // critério de aceite: "Seção não aparece quando lista está vazia".
        if (requests.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho com título e badge de contagem
            Row(
              children: [
                const Text(
                  'Renovações Pendentes',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                // Badge com o número de pedidos aguardando atendimento
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    // Cor de alerta suave para destacar a fila sem alarmar
                    color: const Color(0xFFE65100),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${requests.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Lista de cards tocáveis — cada um navega para RenewalPrescriptionScreen
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              itemBuilder: (context, index) {
                final request = requests[index];
                return _RenewalRequestCard(
                  request: request,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          RenewalPrescriptionScreen(request: request),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

// =============================================================================
// Card de pedido de renovação
// =============================================================================

/// Card que representa um pedido de renovação TRIAGED na fila do médico.
///
/// Exibe medicamento, data do pedido e notas do enfermeiro (truncadas em
/// 2 linhas para manter o layout compacto). O tap navega para a tela
/// de emissão da renovação.
class _RenewalRequestCard extends StatelessWidget {
  const _RenewalRequestCard({
    required this.request,
    required this.onTap,
  });

  final RenewalRequestModel request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: const Color(0xFFE65100).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            // Cor laranja suave para diferenciar visualmente das receitas emitidas
            color: const Color(0xFFFFF3E0),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE65100).withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(
            Icons.assignment_outlined,
            color: Color(0xFFE65100),
            size: 20,
          ),
        ),
        title: Text(
          request.medicineName ?? 'Medicamento não informado',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Solicitado em: ${_formatDate(request.createdAt)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            // Notas do enfermeiro (resumidas) — presentes obrigatoriamente
            // após a triagem, conforme regra de rejeição do IRenewalService
            if (request.nurseNotes != null)
              Text(
                request.nurseNotes!,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: const Icon(
          Icons.chevron_right,
          color: Color(0xFFE65100),
        ),
        onTap: onTap,
      ),
    );
  }

  /// Formata um [DateTime] para o padrão DD/MM/AAAA.
  /// Não usa o pacote `intl` — formatação manual conforme convenção do projeto.
  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}
