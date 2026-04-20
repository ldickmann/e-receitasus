import 'package:flutter/material.dart';

import '../models/renewal_request_model.dart';

/// Tela de emissão de renovação de prescrição pelo médico.
///
/// Recebe o [RenewalRequestModel] triado pelo enfermeiro e exibe o resumo
/// do pedido (medicamento, posologia, notas do enfermeiro). O médico pode
/// então emitir uma nova prescrição pré-preenchida com os dados originais.
///
/// Implementação completa prevista na TASK 147 (PBI 128).
/// Este arquivo é o placeholder necessário para que TASK 146
/// (seção "Renovações Pendentes" na DoctorHomeScreen) compile sem erros.
class RenewalPrescriptionScreen extends StatelessWidget {
  /// Pedido de renovação triado que será atendido pelo médico.
  final RenewalRequestModel request;

  const RenewalPrescriptionScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    // Placeholder — implementação completa na TASK 147.
    // Exibe o medicamento para validar que o roteamento está correto.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Renovar Prescrição'),
        backgroundColor: const Color(0xFF009B3A),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.medical_services_outlined,
                size: 64,
                color: Color(0xFF009B3A),
              ),
              const SizedBox(height: 16),
              Text(
                request.medicineName ?? 'Medicamento não informado',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              // Exibe notas do enfermeiro quando presentes
              if (request.nurseNotes != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Notas do enfermeiro: ${request.nurseNotes}',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              // Aviso de implementação pendente — removido na TASK 147
              const Text(
                'Implementação completa em breve (TASK 147).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
