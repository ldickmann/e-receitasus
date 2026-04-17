import 'package:flutter/material.dart';
import '../models/prescription_model.dart';
import '../models/prescription_type.dart';

/// Renderiza visualmente uma prescrição médica digital conforme
/// layout baseado nos modelos oficiais da ANVISA.
///
/// Suporta os 4 tipos de receitas: Branca, Controle Especial, Amarela e Azul.
class PrescriptionViewScreen extends StatelessWidget {
  const PrescriptionViewScreen({super.key, required this.prescription});

  final PrescriptionModel prescription;

  static String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    return '$dd/$mm/$yyyy';
  }

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;

    return Scaffold(
      appBar: AppBar(
        title: Text(type.displayName),
        backgroundColor: _appBarColor(type),
        foregroundColor: _appBarForeground(type),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Compartilhar',
            onPressed: () => _handleShare(context),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Imprimir',
            onPressed: () => _handlePrint(context),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFEEEEEE),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _buildPrescriptionDocument(context),
          ),
        ),
      ),
      bottomNavigationBar: _CopiesBar(type: type),
    );
  }

  // ---------------------------------------------------------------------------
  // Documento da receita
  // ---------------------------------------------------------------------------

  Widget _buildPrescriptionDocument(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        decoration: BoxDecoration(
          color: prescription.type.backgroundColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: _borderColor(prescription.type),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DocumentHeader(prescription: prescription),
            _HorizontalDivider(type: prescription.type),
            _BodySection(
              prescription: prescription,
              formatDate: _formatDate,
            ),
            _HorizontalDivider(type: prescription.type),
            _SignatureSection(
              prescription: prescription,
              formatDate: _formatDate,
            ),
            _LegalFooterSection(prescription: prescription),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers de cor
  // ---------------------------------------------------------------------------

  Color _appBarColor(PrescriptionType type) {
    switch (type) {
      case PrescriptionType.amarela:
        return const Color(0xFFF9A825);
      case PrescriptionType.azul:
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF009B3A);
    }
  }

  Color _appBarForeground(PrescriptionType type) {
    switch (type) {
      case PrescriptionType.amarela:
        return const Color(0xFF212121);
      default:
        return Colors.white;
    }
  }

  Color _borderColor(PrescriptionType type) {
    switch (type) {
      case PrescriptionType.branca:
        return const Color(0xFFBDBDBD);
      case PrescriptionType.controlada:
        return const Color(0xFF9E9E9E);
      case PrescriptionType.amarela:
        return const Color(0xFFF9A825);
      case PrescriptionType.azul:
        return const Color(0xFF1565C0);
    }
  }

  void _handleShare(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Função de compartilhamento em breve.')),
    );
  }

  void _handlePrint(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Função de impressão em breve.')),
    );
  }
}

// =============================================================================
// Widgets de layout do documento
// =============================================================================

/// Cabeçalho da receita (dados do estabelecimento + título oficial)
class _DocumentHeader extends StatelessWidget {
  const _DocumentHeader({required this.prescription});
  final PrescriptionModel prescription;

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;
    final isNotification = type.isNotification;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Número de notificação (Amarela/Azul) — topo direito
          if (isNotification && prescription.notificationNumber != null)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: type.foregroundColor),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Nº ${prescription.notificationNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: type.foregroundColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (prescription.notificationUf != null)
                      Text(
                        'UF: ${prescription.notificationUf}',
                        style: TextStyle(
                          fontSize: 11,
                          color: type.foregroundColor.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ),

          if (isNotification) const SizedBox(height: 8),

          // Nome do estabelecimento
          if (prescription.clinicName != null &&
              prescription.clinicName!.isNotEmpty)
            Text(
              prescription.clinicName!.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: type.foregroundColor,
                letterSpacing: 1,
              ),
            ),

          const SizedBox(height: 4),

          // Endereço do médico
          Text(
            '${prescription.doctorAddress}, '
            '${prescription.doctorCity} — ${prescription.doctorState}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: type.foregroundColor.withOpacity(0.75),
            ),
          ),

          if (prescription.doctorPhone != null) ...[
            const SizedBox(height: 2),
            Text(
              'Tel.: ${prescription.doctorPhone}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: type.foregroundColor.withOpacity(0.75),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Título oficial da receita
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal:
                    BorderSide(color: type.foregroundColor.withOpacity(0.4)),
              ),
            ),
            child: Text(
              type.officialHeader,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: type.foregroundColor,
                letterSpacing: 0.8,
              ),
            ),
          ),

          // Badge "CONTROLE ESPECIAL" para receita controlada
          if (type == PrescriptionType.controlada) ...[
            const SizedBox(height: 4),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withOpacity(0.08),
                border: Border.all(color: const Color(0xFFD32F2F)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'USO SUJEITO A CONTROLE ESPECIAL — Portaria SVS/MS 344/98',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HorizontalDivider extends StatelessWidget {
  const _HorizontalDivider({required this.type});
  final PrescriptionType type;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: type.foregroundColor.withOpacity(0.25),
    );
  }
}

/// Corpo da receita: dados do paciente + medicamento + posologia
class _BodySection extends StatelessWidget {
  const _BodySection({
    required this.prescription,
    required this.formatDate,
  });

  final PrescriptionModel prescription;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dados do paciente
          _LabeledRow(
            label: 'Paciente:',
            value: prescription.patientName,
            textColor: type.foregroundColor,
          ),
          if (prescription.patientAge != null)
            _LabeledRow(
              label: 'Idade:',
              value: prescription.patientAge!,
              textColor: type.foregroundColor,
            ),
          if (prescription.patientCpf != null)
            _LabeledRow(
              label: 'CPF:',
              value: prescription.patientCpf!,
              textColor: type.foregroundColor,
            ),
          if (prescription.patientAddress != null)
            _LabeledRow(
              label: 'Endereço:',
              value: [
                prescription.patientAddress,
                prescription.patientCity,
                prescription.patientState,
              ]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(', '),
              textColor: type.foregroundColor,
            ),

          const SizedBox(height: 20),

          // Prescrição
          Text(
            'Prescrição:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: type.foregroundColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),

          // Caixa do medicamento
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                  color: type.foregroundColor.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(4),
              color: Colors.white.withOpacity(0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prescription.medicineName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: type.foregroundColor,
                  ),
                ),
                if (prescription.dosage.isNotEmpty)
                  Text(
                    prescription.dosage +
                        (prescription.pharmaceuticalForm != null
                            ? ' — ${prescription.pharmaceuticalForm}'
                            : ''),
                    style: TextStyle(
                      fontSize: 13,
                      color: type.foregroundColor.withOpacity(0.85),
                    ),
                  ),
                if (prescription.route != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Via: ${prescription.route}',
                    style: TextStyle(
                      fontSize: 12,
                      color: type.foregroundColor.withOpacity(0.7),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                _DashedDivider(color: type.foregroundColor.withOpacity(0.2)),
                const SizedBox(height: 6),
                Text(
                  'Quantidade: ${prescription.quantity}',
                  style: TextStyle(
                    fontSize: 13,
                    color: type.foregroundColor,
                  ),
                ),
                if (prescription.quantityWords != null)
                  Text(
                    '(${prescription.quantityWords})',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: type.foregroundColor.withOpacity(0.7),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  prescription.instructions,
                  style: TextStyle(
                    fontSize: 13,
                    color: type.foregroundColor,
                    height: 1.4,
                  ),
                ),
                if (prescription.isContinuousUse) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF009B3A).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color: const Color(0xFF009B3A).withOpacity(0.4)),
                    ),
                    child: const Text(
                      'USO CONTÍNUO — RDC ANVISA 471/2021',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Assinatura e dados do prescritor
class _SignatureSection extends StatelessWidget {
  const _SignatureSection({
    required this.prescription,
    required this.formatDate,
  });

  final PrescriptionModel prescription;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Dados do médico à esquerda
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prescription.doctorName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: type.foregroundColor,
                      ),
                    ),
                    Text(
                      '${prescription.doctorCouncil} — ${prescription.doctorCouncilState}',
                      style: TextStyle(
                        fontSize: 12,
                        color: type.foregroundColor.withOpacity(0.8),
                      ),
                    ),
                    if (prescription.doctorSpecialty != null)
                      Text(
                        prescription.doctorSpecialty!,
                        style: TextStyle(
                          fontSize: 11,
                          color: type.foregroundColor.withOpacity(0.65),
                        ),
                      ),
                  ],
                ),
              ),
              // Assinatura à direita
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                            color: type.foregroundColor.withOpacity(0.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Assinatura e Carimbo',
                    style: TextStyle(
                      fontSize: 10,
                      color: type.foregroundColor.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Data de Emissão: ${formatDate(prescription.issuedAt)}',
                style: TextStyle(
                    fontSize: 12, color: type.foregroundColor.withOpacity(0.8)),
              ),
              const Spacer(),
              Text(
                'Validade: ${formatDate(prescription.validUntil)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: prescription.isExpired
                      ? const Color(0xFFD32F2F)
                      : const Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Rodapé legal da receita
class _LegalFooterSection extends StatelessWidget {
  const _LegalFooterSection({required this.prescription});
  final PrescriptionModel prescription;

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: type.foregroundColor.withOpacity(0.05),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Text(
        type.legalFooter,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: type.foregroundColor.withOpacity(0.55),
          height: 1.5,
        ),
      ),
    );
  }
}

/// Barra inferior indicando o número de vias/cópias
class _CopiesBar extends StatelessWidget {
  const _CopiesBar({required this.type});
  final PrescriptionType type;

  @override
  Widget build(BuildContext context) {
    if (type.copies <= 1) return const SizedBox.shrink();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: type.backgroundColor,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.copy, size: 16, color: type.foregroundColor),
            const SizedBox(width: 8),
            Text(
              'Esta receita deve ser emitida em ${type.copies} vias.',
              style: TextStyle(
                fontSize: 13,
                color: type.foregroundColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Widgets utilitários
// =============================================================================

class _LabeledRow extends StatelessWidget {
  const _LabeledRow({
    required this.label,
    required this.value,
    required this.textColor,
  });

  final String label;
  final String value;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.65),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
        40,
        (i) => Expanded(
          child: Container(
            height: 1,
            color: i.isEven ? color : Colors.transparent,
          ),
        ),
      ),
    );
  }
}
