import 'package:flutter/material.dart';
import '../models/prescription_model.dart';
import '../models/prescription_type.dart';
import '../services/prescription_service.dart';
import 'prescription_view_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Receitas'),
        backgroundColor: const Color(0xFF009B3A),
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<PrescriptionModel>>(
        future: PrescriptionService().fetchPatientHistory(),
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
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.prescription});
  final PrescriptionModel prescription;

  Color get _statusColor {
    if (prescription.isExpired) return const Color(0xFFD32F2F);
    switch (prescription.status) {
      case 'ativa':
        return const Color(0xFF2E7D32);
      case 'utilizada':
        return Colors.grey;
      case 'cancelada':
        return const Color(0xFFD32F2F);
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    if (prescription.isExpired) return 'Vencida';
    return prescription.status[0].toUpperCase() + prescription.status.substring(1);
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
          color: type.foregroundColor.withOpacity(0.2),
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
            border:
                Border.all(color: type.foregroundColor.withOpacity(0.3)),
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
            color: _statusColor.withOpacity(0.1),
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
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PrescriptionViewScreen(prescription: prescription),
          ),
        ),
      ),
    );
  }
}

