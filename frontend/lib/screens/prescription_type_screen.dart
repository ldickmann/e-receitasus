import 'package:flutter/material.dart';
import '../models/prescription_type.dart';
import '../theme/app_colors.dart';
import 'prescription_form_screen.dart';

/// Tela de seleção do tipo de receita para o médico prescritor.
///
/// Exibe os 4 tipos de receitas permitidas pela ANVISA conforme
/// Portaria SVS/MS 344/98 e RDC 471/2021, com suas respectivas
/// cores características e informações legais resumidas.
class PrescriptionTypeScreen extends StatelessWidget {
  const PrescriptionTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Receita — Selecione o Tipo'),
        // Usa o token primário para padronizar a cor da AppBar com o tema institucional
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      // SafeArea: edge-to-edge habilitado em main.dart (PBI #199 / TASK #218).
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _InfoBanner(),
            const SizedBox(height: 16),
            ...PrescriptionType.values.map(
              (type) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PrescriptionTypeCard(type: type),
              ),
            ),
            const SizedBox(height: 16),
            const _AnvisaLegalNote(),
          ],
        ),
      ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Banner informativo usando os tokens 'info' da paleta oficial
        color: AppColors.infoContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.info, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Selecione o tipo de receita conforme a substância prescrita '
              'e a legislação ANVISA vigente (Portaria SVS/MS 344/98).',
              // onInfoContainer assegura contraste WCAG AA sobre infoContainer
              style:
                  TextStyle(fontSize: 13, color: AppColors.onInfoContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionTypeCard extends StatelessWidget {
  const _PrescriptionTypeCard({required this.type});

  final PrescriptionType type;

  Color get _borderColor {
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

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _borderColor, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PrescriptionFormScreen(type: type),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: type.backgroundColor,
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: type.foregroundColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _borderColor),
                ),
                child: Icon(type.icon, color: type.foregroundColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.displayName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: type.foregroundColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      type.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: type.foregroundColor.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        _Badge(
                          label: type.copiesLabel,
                          icon: Icons.copy,
                          borderColor: _borderColor,
                          textColor: type.foregroundColor,
                        ),
                        _Badge(
                          label: '${type.validityDays} dias',
                          icon: Icons.schedule,
                          borderColor: _borderColor,
                          textColor: type.foregroundColor,
                        ),
                        if (type.requiresNotificationNumber)
                          _Badge(
                            label: 'Numeração SCTIE',
                            icon: Icons.numbers,
                            borderColor: _borderColor,
                            textColor: type.foregroundColor,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: type.foregroundColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor.withValues(alpha: 0.7)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
                fontSize: 11, color: textColor.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }
}

class _AnvisaLegalNote extends StatelessWidget {
  const _AnvisaLegalNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Bloco 'Base Legal' com tokens 'warning' — destaca conteúdo regulatório
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, size: 16, color: AppColors.warning),
              SizedBox(width: 6),
              Text(
                'Base Legal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.warning,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            '• Portaria SVS/MS 344/1998 — Controle de substâncias entorpecentes e psicotrópicas\n'
            '• RDC ANVISA 471/2021 — Receitas de medicamentos de uso contínuo\n'
            '• RDC ANVISA 204/2017 — Notificação de Receita\n'
            '• Lei 13.021/2014 — Exercício da Farmácia',
            style: TextStyle(
                fontSize: 11,
                color: AppColors.onWarningContainer,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
