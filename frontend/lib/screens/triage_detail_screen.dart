import 'package:flutter/material.dart';

import '../models/renewal_request_model.dart';
import '../theme/app_colors.dart';

/// Tela de detalhes de um pedido de renovação para triagem pelo enfermeiro.
///
/// Recebe o [request] selecionado na [NurseHomeScreen] e permite ao enfermeiro
/// aprovar (designando um médico) ou rejeitar o pedido com motivo obrigatório.
///
/// Implementação completa será realizada no PBI 131 — TASK 4.2.
/// Esta versão é um placeholder com as informações básicas do pedido.
class TriageDetailScreen extends StatelessWidget {
  /// Pedido de renovação a ser avaliado pelo enfermeiro.
  final RenewalRequestModel request;

  const TriageDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final medicine = request.medicineName ?? 'Medicamento não informado';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe do Pedido'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Resumo do pedido selecionado
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status: ${request.status.label}',
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (request.patientNotes != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Observações do paciente: ${request.patientNotes}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Placeholder para as ações de triagem (aprovar/rejeitar)
            // Será implementado na TASK 4.2 do PBI 131
            const Center(
              child: Text(
                'Ações de triagem serão implementadas em breve.',
                style: TextStyle(color: AppColors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
