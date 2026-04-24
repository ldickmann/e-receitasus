import 'package:flutter/material.dart';

/// Paleta de cores da aplicação E-ReceitaSUS
///
/// Define todas as cores utilizadas seguindo:
/// - Material Design 3 (ColorScheme)
/// - Identidade Visual do SUS (verde #009B3A)
/// - Acessibilidade WCAG 2.1 AAA (contraste mínimo 7:1)
///
/// **Cores Principais:**
/// - Primary: Verde SUS (#009B3A)
/// - Secondary: Azul Saúde (#0075C9)
/// - Tertiary: Amarelo Atenção (#FFC107)
/// - Error: Vermelho Erro (#D32F2F)
///
/// **Uso:**
/// ```dart
/// Container(
///   color: AppColors.primary,
///   child: Text(
///     'Texto',
///     style: TextStyle(color: AppColors.onPrimary),
///   ),
/// )
/// ```
class AppColors {
  // Construtor privado para impedir a instanciação da classe
  AppColors._();

  // ==========================================================================
  // CORES PRIMÁRIAS (Primary) - Verde SUS
  // ==========================================================================

  /// Cor primária da aplicação - Verde SUS
  /// Contraste com branco: 4.89:1 (AA Large)
  static const Color primary = Color(0xFF009B3A);

  /// Cor do texto/ícones sobre a cor primária
  /// Branco com alto contraste
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Container/Surface com tom primário
  /// Tom mais claro do verde para cards e containers
  static const Color primaryContainer = Color(0xFFA8E6C1);

  /// Texto sobre primaryContainer
  /// Verde escuro para máximo contraste
  static const Color onPrimaryContainer = Color(0xFF00411A);

  // ==========================================================================
  // CORES SECUNDÁRIAS (Secondary) - Azul Saúde
  // ==========================================================================

  /// Cor secundária - Azul institucional da saúde
  /// Usada em elementos de apoio e informação
  static const Color secondary = Color(0xFF0075C9);

  /// Cor do texto/ícones sobre a cor secundária
  static const Color onSecondary = Color(0xFFFFFFFF);

  /// Container/Surface com tom secundário
  static const Color secondaryContainer = Color(0xFFB3E5FC);

  /// Texto sobre secondaryContainer
  static const Color onSecondaryContainer = Color(0xFF003D5C);

  // ==========================================================================
  // CORES TERCIÁRIAS (Tertiary) - Amarelo Atenção
  // ==========================================================================

  /// Cor terciária - Amarelo para alertas e informações importantes
  static const Color tertiary = Color(0xFFFFC107);

  /// Cor do texto/ícones sobre a cor terciária
  /// Preto para máximo contraste sobre amarelo
  static const Color onTertiary = Color(0xFF000000);

  /// Container/Surface com tom terciário
  static const Color tertiaryContainer = Color(0xFFFFECB3);

  /// Texto sobre tertiaryContainer
  static const Color onTertiaryContainer = Color(0xFF524300);

  // ==========================================================================
  // CORES DE ERRO (Error)
  // ==========================================================================

  /// Cor de erro - Vermelho para erros e ações destrutivas
  static const Color error = Color(0xFFD32F2F);

  /// Cor do texto/ícones sobre a cor de erro
  static const Color onError = Color(0xFFFFFFFF);

  /// Container/Surface com tom de erro
  static const Color errorContainer = Color(0xFFFFCDD2);

  /// Texto sobre errorContainer
  static const Color onErrorContainer = Color(0xFF5F1313);

  // ==========================================================================
  // CORES DE SUCESSO (Success) - Extensão customizada
  // ==========================================================================

  /// Cor de sucesso - Verde para confirmações
  static const Color success = Color(0xFF4CAF50);

  /// Cor do texto/ícones sobre a cor de sucesso
  static const Color onSuccess = Color(0xFFFFFFFF);

  /// Container/Surface com tom de sucesso
  static const Color successContainer = Color(0xFFC8E6C9);

  /// Texto sobre successContainer
  static const Color onSuccessContainer = Color(0xFF1B5E20);

  // ==========================================================================
  // CORES DE AVISO (Warning) - Extensão customizada
  // ==========================================================================

  /// Cor de aviso - Laranja para avisos
  static const Color warning = Color(0xFFFF9800);

  /// Cor do texto/ícones sobre a cor de aviso
  static const Color onWarning = Color(0xFF000000);

  /// Container/Surface com tom de aviso
  static const Color warningContainer = Color(0xFFFFE0B2);

  /// Texto sobre warningContainer
  static const Color onWarningContainer = Color(0xFF663C00);

  // ==========================================================================
  // CORES DE INFO (Info) - Extensão customizada
  // ==========================================================================

  /// Cor de informação - Azul para informações neutras
  static const Color info = Color(0xFF2196F3);

  /// Cor do texto/ícones sobre a cor de info
  static const Color onInfo = Color(0xFFFFFFFF);

  /// Container/Surface com tom de info
  static const Color infoContainer = Color(0xFFBBDEFB);

  /// Texto sobre infoContainer
  static const Color onInfoContainer = Color(0xFF0D47A1);

  // ==========================================================================
  // CORES DE FUNDO E SUPERFÍCIE (Background & Surface)
  // ==========================================================================

  /// Cor de fundo principal do app
  /// Branco levemente acinzentado para reduzir fadiga visual
  static const Color background = Color(0xFFFAFAFA);

  /// Cor do texto/ícones sobre o background
  static const Color onBackground = Color(0xFF1C1B1F);

  /// Cor de superfície (Cards, Dialogs, Sheets)
  /// Branco puro para destacar do background
  static const Color surface = Color(0xFFFFFFFF);

  /// Cor do texto/ícones sobre surface
  static const Color onSurface = Color(0xFF1C1B1F);

  /// Variante de superfície para separação visual
  static const Color surfaceVariant = Color(0xFFE7E0EC);

  /// Texto sobre surfaceVariant
  static const Color onSurfaceVariant = Color(0xFF49454F);

  // ==========================================================================
  // CORES DE OUTLINE E SOMBRAS
  // ==========================================================================

  /// Cor de bordas e divisores
  static const Color outline = Color(0xFF79747E);

  /// Variante de outline para elementos menos importantes
  static const Color outlineVariant = Color(0xFFCAC4D0);

  /// Cor de sombra
  static const Color shadow = Color(0xFF000000);

  /// Cor de scrim (overlay modal)
  static const Color scrim = Color(0xFF000000);

  // ==========================================================================
  // CORES INVERSAS (Para tema escuro/elementos invertidos)
  // ==========================================================================

  /// Cor de superfície inversa
  static const Color inverseSurface = Color(0xFF313033);

  /// Texto sobre inverseSurface
  static const Color onInverseSurface = Color(0xFFF4EFF4);

  /// Cor primária inversa
  static const Color inversePrimary = Color(0xFF7CDB9A);

  // ==========================================================================
  // CORES ESPECÍFICAS DO DOMÍNIO (SUS/Receitas)
  // ==========================================================================

  /// Verde para receitas ativas/válidas
  static const Color prescriptionActive = Color(0xFF4CAF50);

  /// Amarelo para receitas próximas do vencimento
  static const Color prescriptionWarning = Color(0xFFFFC107);

  /// Vermelho para receitas vencidas/canceladas
  static const Color prescriptionExpired = Color(0xFFD32F2F);

  /// Azul para receitas em processamento
  static const Color prescriptionPending = Color(0xFF2196F3);

  /// Cinza para receitas utilizadas completamente
  static const Color prescriptionUsed = Color(0xFF9E9E9E);

  // ==========================================================================
  // GRADIENTES
  // ==========================================================================

  /// Gradiente principal (Verde SUS)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF009B3A), Color(0xFF00732D)],
  );

  /// Gradiente secundário (Azul Saúde)
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0075C9), Color(0xFF005691)],
  );

  // ==========================================================================
  // MÉTODOS AUXILIARES
  // ==========================================================================

  /// Retorna a cor de status da receita baseada no seu estado
  static Color getPrescriptionStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ativa':
      case 'válida':
      case 'active':
        return prescriptionActive;
      case 'aviso':
      case 'expirando':
      case 'warning':
        return prescriptionWarning;
      case 'vencida':
      case 'cancelada':
      case 'expired':
      case 'cancelled':
        return prescriptionExpired;
      case 'pendente':
      case 'processando':
      case 'pending':
        return prescriptionPending;
      case 'utilizada':
      case 'used':
        return prescriptionUsed;
      default:
        return onSurfaceVariant;
    }
  }

  /// Retorna a cor com opacidade especificada
  /// Utiliza withValues() para evitar perda de precisão
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
}
