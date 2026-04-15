import 'package:flutter/material.dart';

/// Tipos de receitas permitidos pela ANVISA conforme Portaria SVS/MS 344/98
/// e RDC 471/2021 do Ministério da Saúde.
enum PrescriptionType {
  /// Receita Branca — medicamentos sem controle especial.
  /// Validade: 30 dias (ou 6 meses para uso contínuo via RDC 471/2021).
  /// Cópias: 1 via (farmácia retém uma cópia quando necessário).
  branca(
    'BRANCA',
    'Receita Branca',
    'Medicamentos sem controle especial',
    1,
    30,
    Color(0xFFFFFFFF),
    Color(0xFF212121),
  ),

  /// Receita de Controle Especial (Branca em 2 vias).
  /// Para substâncias das Listas A2, C1, C2, C3, C4 e C5 da Portaria 344/98.
  /// Validade: 30 dias. Cópias: 2 vias obrigatórias (farmácia retém 1a via).
  controlada(
    'CONTROLADA',
    'Receita de Controle Especial',
    'Substâncias das Listas A2, C1, C2, C3, C4 e C5 — 2 vias obrigatórias',
    2,
    30,
    Color(0xFFF5F5F5),
    Color(0xFF212121),
  ),

  /// Notificação de Receita A (Amarela).
  /// Para substâncias entorpecentes das Listas A1 e A3 da Portaria 344/98.
  /// Validade: 30 dias. Cópias: 3 vias.
  /// Numeração pré-impressa emitida pela Secretaria de Saúde Estadual (SCTIE/DAF).
  amarela(
    'AMARELA',
    'Notificação de Receita A (Amarela)',
    'Entorpecentes — Listas A1 e A3 — 3 vias numeradas',
    3,
    30,
    Color(0xFFFFF9C4),
    Color(0xFF212121),
  ),

  /// Notificação de Receita B (Azul).
  /// Para substâncias psicotrópicas das Listas B1 e B2 da Portaria 344/98.
  /// Validade: 30 dias. Cópias: 2 vias.
  /// Numeração pré-impressa emitida pela Secretaria de Saúde Estadual.
  azul(
    'AZUL',
    'Notificação de Receita B (Azul)',
    'Psicotrópicos — Listas B1 e B2 — 2 vias numeradas',
    2,
    30,
    Color(0xFFB3E5FC),
    Color(0xFF0D47A1),
  );

  const PrescriptionType(
    this.value,
    this.displayName,
    this.description,
    this.copies,
    this.validityDays,
    this.backgroundColor,
    this.foregroundColor,
  );

  final String value;
  final String displayName;
  final String description;

  /// Número de vias/cópias obrigatórias.
  final int copies;

  /// Validade em dias após emissão.
  final int validityDays;

  /// Cor de fundo característica da receita conforme padrão ANVISA.
  final Color backgroundColor;

  /// Cor do texto sobre o fundo da receita.
  final Color foregroundColor;

  /// Rótulo amigável do número de vias.
  String get copiesLabel {
    return copies == 1 ? '1 via' : '$copies vias';
  }

  /// Indica se a receita exige numeração pré-impressa da Secretaria de Saúde.
  bool get requiresNotificationNumber {
    return this == amarela || this == azul;
  }

  /// Indica se a receita exige 2 ou mais vias obrigatórias.
  bool get requiresTwoCopies {
    return copies >= 2;
  }

  /// Indica se esta receita é uma Notificação (formulário especial da ANVISA).
  bool get isNotification {
    return this == amarela || this == azul;
  }

  /// Ícone representativo do tipo de receita para uso na UI.
  IconData get icon {
    switch (this) {
      case branca:
        return Icons.receipt_long;
      case controlada:
        return Icons.security;
      case amarela:
        return Icons.warning_amber;
      case azul:
        return Icons.local_pharmacy;
    }
  }

  /// Converte string de banco de dados para enum.
  static PrescriptionType fromString(String value) {
    return PrescriptionType.values.firstWhere(
      (t) => t.value == value.toUpperCase(),
      orElse: () => PrescriptionType.branca,
    );
  }

  /// Texto do cabeçalho oficial que deve aparecer impresso na receita.
  String get officialHeader {
    switch (this) {
      case branca:
        return 'RECEITA MÉDICA';
      case controlada:
        return 'RECEITA DE CONTROLE ESPECIAL\n(2ª via — Farmácia)';
      case amarela:
        return 'NOTIFICAÇÃO DE RECEITA A\n(Ministério da Saúde — Portaria SVS/MS 344/98)';
      case azul:
        return 'NOTIFICAÇÃO DE RECEITA B\n(Ministério da Saúde — Portaria SVS/MS 344/98)';
    }
  }

  /// Texto legal de rodapé da receita.
  String get legalFooter {
    switch (this) {
      case branca:
        return 'Validade: 30 dias. Esta receita só é válida se contiver identificação '
            'legível do emitente, data de emissão, assinatura e CRM do profissional habilitado.';
      case controlada:
        return 'A 1ª via deverá ser retida pela farmácia / drogaria. '
            'A 2ª via deverá ser entregue ao paciente. '
            'Validade: 30 dias. Portaria SVS/MS 344/98.';
      case amarela:
        return 'Válida por 30 dias. Uso exclusivo para entorpecentes — Lista A1/A3. '
            'Esta notificação só tem validade dentro do Estado de emissão. '
            'Portaria SVS/MS 344/98 — Art. 35.';
      case azul:
        return 'Válida por 30 dias. Uso exclusivo para psicotrópicos — Lista B1/B2. '
            'Esta notificação só tem validade dentro do Estado de emissão. '
            'Portaria SVS/MS 344/98 — Art. 35.';
    }
  }
}
