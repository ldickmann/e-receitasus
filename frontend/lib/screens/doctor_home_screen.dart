import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prescription_model.dart';
import '../models/prescription_type.dart';
import '../providers/auth_provider.dart';
import '../services/prescription_service.dart';
import 'prescription_type_screen.dart';
import 'prescription_view_screen.dart';

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
          side: BorderSide(color: type.foregroundColor.withOpacity(0.3)),
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
          color: type.foregroundColor.withOpacity(0.25),
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
            border: Border.all(color: type.foregroundColor.withOpacity(0.3)),
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
                color: statusColor.withOpacity(0.1),
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
          Icon(icon, size: 64, color: color.withOpacity(0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
