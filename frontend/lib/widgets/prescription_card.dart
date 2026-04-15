import 'package:flutter/material.dart';
import '../models/prescription_model.dart';
import '../theme/app_colors.dart';

/// Card visual de uma prescrição médica para exibição em listas.
///
/// Segue a identidade visual do SUS definida em [AppColors] e exibe:
/// - Nome do medicamento e dosagem em destaque (hierarquia primária)
/// - Data de emissão e nome do médico como informação secundária
/// - Indicador visual de status (Ativa / Vencida / Cancelada / Utilizada)
/// - Ícone e cor de fundo do tipo de receita conforme padrão ANVISA
///
/// **Uso:**
/// ```dart
/// PrescriptionCard(
///   prescription: model,
///   onTap: () => Navigator.push(...),
/// )
/// ```
class PrescriptionCard extends StatelessWidget {
  const PrescriptionCard({
    super.key,
    required this.prescription,
    this.onTap,
  });

  final PrescriptionModel prescription;

  /// Callback disparado ao tocar no card — normalmente abre a tela de detalhe.
  final VoidCallback? onTap;

  // --------------------------------------------------------------------------
  // Computados de status
  // --------------------------------------------------------------------------

  /// Retorna a cor do badge de status conforme regras de negócio:
  /// - Vencida (por prazo): vermelho
  /// - Ativa: verde primário SUS
  /// - Cancelada: cinza
  /// - Utilizada: âmbar
  Color get _statusColor {
    if (prescription.isExpired) return AppColors.error;
    switch (prescription.status) {
      case 'ativa':
        return AppColors.primary;
      case 'cancelada':
        return AppColors.onSurfaceVariant;
      case 'utilizada':
        return AppColors.warning;
      default:
        return AppColors.onSurfaceVariant;
    }
  }

  Color get _statusBackgroundColor => _statusColor.withOpacity(0.12);

  /// Rótulo legível do status exibido no badge.
  String get _statusLabel {
    // Prescições expiradas por prazo têm prioridade sobre o status textual
    if (prescription.isExpired) return 'Vencida';
    final s = prescription.status;
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  // --------------------------------------------------------------------------
  // Helpers de formatação
  // --------------------------------------------------------------------------

  /// Formata data no padrão brasileiro DD/MM/AAAA.
  String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  @override
  Widget build(BuildContext context) {
    final type = prescription.type;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      // Descrição acessível lida por leitores de tela
      label: 'Receita de ${prescription.medicineName}, ${prescription.dosage}, '
          'status $_statusLabel, emitida em ${_formatDate(prescription.issuedAt)}',
      button: onTap != null,
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          // Borda sutil com a cor característica do tipo de receita ANVISA
          side: BorderSide(
            color: type.foregroundColor.withOpacity(0.18),
            width: 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ----------------------------------------------------------
                // Ícone do tipo de receita (identidade ANVISA)
                // ----------------------------------------------------------
                _TypeIcon(type: type),
                const SizedBox(width: 12),

                // ----------------------------------------------------------
                // Conteúdo principal
                // ----------------------------------------------------------
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Linha superior: medicamento + badge de status
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              prescription.medicineName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _StatusBadge(
                            label: _statusLabel,
                            color: _statusColor,
                            backgroundColor: _statusBackgroundColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Dosagem em destaque — hierarquia secundária mas visível
                      Text(
                        prescription.dosage,
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Informações secundárias: médico e data
                      _SecondaryInfo(
                        doctorName: prescription.doctorName,
                        issuedAt: _formatDate(prescription.issuedAt),
                        validUntil: _formatDate(prescription.validUntil),
                      ),
                    ],
                  ),
                ),

                // Indicador de navegação
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.outlineVariant,
                    size: 20,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Sub-widgets privados — mantêm o build() do card coeso e legível
// =============================================================================

/// Ícone circular com a cor característica do tipo de receita ANVISA.
class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type});

  final dynamic type; // PrescriptionType

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        // Cor de fundo conforme o tipo de receita (branca, amarela, azul, etc.)
        color: type.backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(
          color: type.foregroundColor.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: type.foregroundColor.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(type.icon, color: type.foregroundColor, size: 22),
    );
  }
}

/// Badge compacto de status com cor semântica.
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  final String label;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Linha de metadados secundários: nome do médico, data de emissão e validade.
class _SecondaryInfo extends StatelessWidget {
  const _SecondaryInfo({
    required this.doctorName,
    required this.issuedAt,
    required this.validUntil,
  });

  final String doctorName;
  final String issuedAt;
  final String validUntil;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.onSurfaceVariant,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.person_outline,
              size: 13,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                // Exibe primeiro nome do médico para economizar espaço
                'Dr(a). ${doctorName.split(' ').first}',
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 13,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text('Emitida: $issuedAt', style: style),
            const SizedBox(width: 8),
            Text('· Válida até: $validUntil', style: style),
          ],
        ),
      ],
    );
  }
}
