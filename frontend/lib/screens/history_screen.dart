import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/prescription_model.dart';
import '../providers/prescription_provider.dart';
import '../theme/app_colors.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Receitas'),
        // Usa o token primário (verde-menta da nova identidade) para manter consistência visual com o resto do app
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      // SafeArea: edge-to-edge habilitado em main.dart (PBI #199 / TASK #218).
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<PrescriptionModel>>(
        // Delega ao PrescriptionProvider em vez de instanciar o service diretamente —
        // segue a arquitetura screen → provider → service do projeto e permite
        // substituição por mock em testes unitários (TDD com Mockito).
        future: context.read<PrescriptionProvider>().fetchPatientHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Não foi possível carregar o histórico.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Voltar'),
                  ),
                ],
              ),
            );
          }

          final historico = snapshot.data ?? [];

          if (historico.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma receita no histórico',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: historico.length,
            itemBuilder: (context, index) {
              final prescription = historico[index];
              return _HistoryTile(prescription: prescription);
            },
          );
        },
      ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.prescription});
  final PrescriptionModel prescription;

  Color get _statusColor {
    // Cores de status mapeadas para os tokens semanticos da paleta oficial
    // (AppColors.error/success) — garante consistência com a nova identidade
    // visual e suporte automático a futuras mudanças de tema.
    if (prescription.isExpired) return AppColors.error;
    switch (prescription.status) {
      case 'ativa':
        return AppColors.success;
      case 'utilizada':
        return Colors.grey;
      case 'cancelada':
        return AppColors.error;
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    if (prescription.isExpired) return 'Vencida';
    final s = prescription.status;
    return s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;
    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          // withValues evita perda de precisão na conversão de canal alpha
          color: type.foregroundColor.withValues(alpha: 0.2),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: type.backgroundColor,
            shape: BoxShape.circle,
            // withValues evita perda de precisão na conversão de canal alpha
            border:
                Border.all(color: type.foregroundColor.withValues(alpha: 0.3)),
          ),
          child: Icon(type.icon, color: type.foregroundColor, size: 20),
        ),
        title: Text(
          prescription.medicineName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${type.displayName.split(' ').take(2).join(' ')} — '
              'Dr(a). ${prescription.doctorName.split(' ').first}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Emitida: ${_formatDate(prescription.issuedAt)} · '
              'Válida até: ${_formatDate(prescription.validUntil)}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            // withValues evita perda de precisão na conversão de canal alpha
            color: _statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _statusColor),
          ),
          child: Text(
            _statusLabel,
            style: TextStyle(
              fontSize: 10,
              color: _statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        onTap: () => Navigator.pushNamed(
          context,
          '/prescription_view',
          arguments: prescription,
        ),
      ),
    );
  }
}
