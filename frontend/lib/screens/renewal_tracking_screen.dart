import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/renewal_request_model.dart';
import '../providers/renewal_provider.dart';

/// Tela de rastreamento de pedidos de renovação do paciente.
///
/// Exibe em tempo real todos os pedidos de renovação do paciente autenticado,
/// consumindo o stream do [RenewalProvider] (via [IRenewalService.streamMyRenewals]).
///
/// Implementada como [StatefulWidget] para inicializar o stream uma única vez
/// no [initState], evitando recriação da conexão Supabase a cada rebuild.
class RenewalTrackingScreen extends StatefulWidget {
  const RenewalTrackingScreen({super.key});

  @override
  State<RenewalTrackingScreen> createState() => _RenewalTrackingScreenState();
}

class _RenewalTrackingScreenState extends State<RenewalTrackingScreen> {
  /// Stream inicializado uma única vez para não recriar a assinatura Supabase
  /// a cada rebuild causado pelo provider pai.
  late final Stream<List<RenewalRequestModel>> _stream;

  @override
  void initState() {
    super.initState();
    // Captura o stream no initState — contexto já montado, acesso ao provider seguro.
    // Usa `read` (não `watch`) para evitar recriação do stream a cada notifyListeners.
    _stream = context.read<RenewalProvider>().streamMyRenewals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rastrear Pedidos de Renovação'),
      ),
      body: StreamBuilder<List<RenewalRequestModel>>(
        stream: _stream,
        builder: (context, snapshot) {
          // Aguardando a primeira emissão do stream Supabase
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Erro ao conectar ou processar os dados — não vaza detalhes internos (LGPD)
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Não foi possível carregar seus pedidos.\nVerifique sua conexão e tente novamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final renewals = snapshot.data ?? [];

          // Estado vazio — paciente ainda não enviou nenhum pedido
          if (renewals.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.track_changes, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Nenhum pedido de renovação encontrado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Solicite uma renovação na tela inicial para acompanhá-la aqui.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          // Lista de pedidos com atualização em tempo real via Supabase Realtime
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: renewals.length,
            itemBuilder: (_, index) =>
                _RenewalTrackingCard(renewal: renewals[index]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _RenewalTrackingCard — card detalhado de rastreamento de pedido
// ---------------------------------------------------------------------------

/// Card que exibe o detalhe completo do status de um pedido de renovação.
///
/// Apresenta: medicamento, data do pedido, status visual com chip colorido,
/// notas do paciente e notas do enfermeiro (quando presentes).
class _RenewalTrackingCard extends StatelessWidget {
  final RenewalRequestModel renewal;

  const _RenewalTrackingCard({required this.renewal});

  /// Retorna a cor de fundo do chip de status conforme o [RenewalStatus].
  ///
  /// Mapeamento visual alinhado com o padrão definido no PBI 130:
  /// - PENDING_TRIAGE → cinza (aguardando)
  /// - TRIAGED        → amarelo (em triagem)
  /// - PRESCRIBED     → verde (concluído)
  /// - REJECTED       → vermelho (rejeitado)
  Color _chipColor(RenewalStatus status) {
    return switch (status) {
      RenewalStatus.pendingTriage => Colors.grey.shade300,
      RenewalStatus.triaged => Colors.amber.shade200,
      RenewalStatus.prescribed => Colors.green.shade200,
      RenewalStatus.rejected => Colors.red.shade200,
    };
  }

  /// Retorna a cor do texto do chip para garantir contraste mínimo AA.
  Color _chipTextColor(RenewalStatus status) {
    return switch (status) {
      RenewalStatus.pendingTriage => Colors.grey.shade800,
      RenewalStatus.triaged => Colors.amber.shade900,
      RenewalStatus.prescribed => Colors.green.shade900,
      RenewalStatus.rejected => Colors.red.shade900,
    };
  }

  /// Retorna o ícone de progresso conforme o estado do pedido.
  IconData _stepIcon(RenewalStatus status) {
    return switch (status) {
      RenewalStatus.pendingTriage => Icons.hourglass_empty,
      RenewalStatus.triaged => Icons.medical_information_outlined,
      RenewalStatus.prescribed => Icons.check_circle_outline,
      RenewalStatus.rejected => Icons.cancel_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Formata a data de criação em PT-BR para exibição amigável
    final date = renewal.createdAt.toLocal();
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    final medicine = renewal.medicineName ?? 'Medicamento não informado';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho: ícone de progresso, medicamento e chip de status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _stepIcon(renewal.status),
                  size: 28,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Solicitado em $dateStr',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Chip de status colorido — feedback visual imediato
                Chip(
                  label: Text(
                    renewal.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: _chipTextColor(renewal.status),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: _chipColor(renewal.status),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),

            // Notas do paciente — exibidas apenas quando informadas
            if (renewal.patientNotes != null &&
                renewal.patientNotes!.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'Suas observações:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                renewal.patientNotes!,
                style: const TextStyle(fontSize: 13),
              ),
            ],

            // Notas do enfermeiro — visíveis ao paciente após triagem/rejeição
            if (renewal.nurseNotes != null &&
                renewal.nurseNotes!.isNotEmpty) ...[
              const Divider(height: 20),
              Text(
                'Nota da equipe de saúde:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                renewal.nurseNotes!,
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
