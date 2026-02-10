import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Estilos de texto da aplicação E-ReceitaSUS
///
/// Define todos os estilos tipográficos seguindo:
/// - Material Design 3 (Type Scale)
/// - Acessibilidade WCAG 2.1 AAA
/// - Hierarquia visual clara
///
/// **Type Scale (Material Design 3):**
/// - Display: Títulos grandes e impactantes
/// - Headline: Títulos de seções principais
/// - Title: Títulos de cards e listas
/// - Body: Texto de conteúdo principal
/// - Label: Textos de botões e labels
///
/// **Uso:**
/// ```dart
/// Text(
///   'Título Principal',
///   style: AppTextStyles.headlineLarge,
/// )
/// ```
class AppTextStyles {
  // Construtor privado para impedir a instanciação da classe
  AppTextStyles._();

  // Família de fonte padrão
  static const String _fontFamily = 'Roboto';

  // ==========================================================================
  // DISPLAY STYLES - Títulos muito grandes (raramento usados)
  // ==========================================================================

  /// Display Large - 57sp
  /// Uso: Telas de boas-vindas, splash screens
  static const TextStyle? displayLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 57,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
    height: 1.12,
    color: AppColors.onSurface,
  );

  /// Display Medium - 45sp
  /// Uso: Títulos de destaque em páginas especiais
  static const TextStyle? displayMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 45,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.16,
    color: AppColors.onSurface,
  );

  /// Display Small - 36sp
  /// Uso: Títulos grandes de seções importantes
  static const TextStyle? displaySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.22,
    color: AppColors.onSurface,
  );

  // ==========================================================================
  // HEADLINE STYLES - Títulos de seções
  // ==========================================================================

  /// Headline Large - 32sp
  /// Uso: Títulos principais de telas
  static const TextStyle? headlineLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
    color: AppColors.onSurface,
  );

  /// Headline Medium - 28sp
  /// Uso: Títulos de seções importantes dentro de telas
  static const TextStyle? headlineMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.29,
    color: AppColors.onSurface,
  );

  /// Headline Small - 24sp
  /// Uso: Subtítulos de seções
  static const TextStyle? headlineSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
    color: AppColors.onSurface,
  );

  // ==========================================================================
  // TITLE STYLES - Títulos de componentes
  // ==========================================================================

  /// Title Large - 22sp
  /// Uso: AppBar, Títulos de Dialogs
  static const TextStyle? titleLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.27,
    color: AppColors.onSurface,
  );

  /// Title Medium - 16sp
  /// Uso: Títulos de Cards, ListTiles destacados
  static const TextStyle? titleMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.50,
    color: AppColors.onSurface,
  );

  /// Title Small - 14sp
  /// Uso: Títulos menores, subtítulos de cards
  static const TextStyle? titleSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
    color: AppColors.onSurface,
  );

  // ==========================================================================
  // BODY STYLES - Texto de conteúdo
  // ==========================================================================

  /// Body Large - 16sp
  /// Uso: Texto principal de conteúdo, parágrafos importantes
  static const TextStyle? bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.50,
    color: AppColors.onSurface,
  );

  /// Body Medium - 14sp (Padrão)
  /// Uso: Texto de conteúdo geral, mais comum
  static const TextStyle? bodyMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
    color: AppColors.onSurface,
  );

  /// Body Small - 12sp
  /// Uso: Textos secundários, notas de rodapé
  static const TextStyle? bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    color: AppColors.onSurfaceVariant,
  );

  // ==========================================================================
  // LABEL STYLES - Labels e botões
  // ==========================================================================

  /// Label Large - 14sp
  /// Uso: Botões grandes (ElevatedButton, OutlinedButton)
  static const TextStyle? labelLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
    color: AppColors.onSurface,
  );

  /// Label Medium - 12sp
  /// Uso: Botões médios, chips, badges
  static const TextStyle? labelMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.33,
    color: AppColors.onSurface,
  );

  /// Label Small - 11sp
  /// Uso: Labels de campos, tooltips
  static const TextStyle? labelSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.45,
    color: AppColors.onSurfaceVariant,
  );

  // ==========================================================================
  // ESTILOS CUSTOMIZADOS PARA CONTEXTOS ESPECÍFICOS
  // ==========================================================================

  /// Estilo para números grandes (valores, contadores)
  static const TextStyle numberLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 48,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    height: 1.17,
    color: AppColors.primary,
  );

  /// Estilo para números médios em cards
  static const TextStyle numberMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.33,
    color: AppColors.primary,
  );

  /// Estilo para código (números de receita, CPF, etc.)
  static const TextStyle code = TextStyle(
    fontFamily: 'monospace',
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.0,
    height: 1.43,
    color: AppColors.onSurface,
  );

  /// Estilo para datas e timestamps
  static const TextStyle timestamp = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    color: AppColors.onSurfaceVariant,
    fontStyle: FontStyle.italic,
  );

  /// Estilo para textos de erro
  static const TextStyle error = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.33,
    color: AppColors.error,
  );

  /// Estilo para textos de sucesso
  static const TextStyle success = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    height: 1.33,
    color: AppColors.success,
  );

  /// Estilo para placeholders de campos
  static const TextStyle placeholder = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.43,
    color: AppColors.onSurfaceVariant,
    fontStyle: FontStyle.italic,
  );

  /// Estilo para links
  static const TextStyle link = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.43,
    color: AppColors.primary,
    decoration: TextDecoration.underline,
  );

  /// Estilo para badges e chips de status
  static const TextStyle badge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.45,
    color: AppColors.onPrimary,
  );

  // ==========================================================================
  // MÉTODOS AUXILIARES
  // ==========================================================================

  /// Aplica cor customizada a um estilo
  static TextStyle? withColor(TextStyle? style, Color color) {
    return style?.copyWith(color: color);
  }

  /// Aplica peso customizado a um estilo
  static TextStyle? withWeight(TextStyle? style, FontWeight weight) {
    return style?.copyWith(fontWeight: weight);
  }

  /// Aplica tamanho customizado a um estilo
  static TextStyle? withSize(TextStyle? style, double size) {
    return style?.copyWith(fontSize: size);
  }

  /// Retorna estilo baseado no status (para badges de receita)
  static TextStyle getStatusStyle(String status) {
    final color = AppColors.getPrescriptionStatusColor(status);
    return badge.copyWith(color: color);
  }
}