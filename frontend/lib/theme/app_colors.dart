import 'package:flutter/material.dart';

/// Paleta de cores da aplicação E-ReceitaSUS
///
/// Atualizada com a nova identidade visual baseada no gradiente da logo:
/// verde-menta (#43C59E) → azul-aço (#5AB4D4)
///
/// Define todas as cores utilizadas seguindo:
/// - Material Design 3 (ColorScheme)
/// - Nova identidade visual E-ReceitaSUS (gradiente menta→azul)
/// - Acessibilidade WCAG 2.1 AA (contraste mínimo 4.5:1)
///
/// **Cores Principais:**
/// - Primary: Verde-menta (#43C59E) — topo esquerdo do gradiente da logo
/// - Secondary: Azul-aço (#5AB4D4) — base direita do gradiente da logo
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
  // CORES PRIMÁRIAS (Primary) - Verde-menta (identidade visual da logo)
  // ==========================================================================

  /// Cor primária — Verde-menta derivado do gradiente da nova logo
  /// Contraste com [onPrimary] (#003D26): 5.77:1 (WCAG AA ✓)
  static const Color primary = Color(0xFF43C59E);

  /// Variante escura da cor primária para estados hover/pressed e
  /// superfícies que exigem maior contraste visual
  static const Color primaryDark = Color(0xFF2BA882);

  /// Cor do texto/ícones sobre a cor primária
  /// Verde escuro para atingir contraste WCAG AA (5.77:1) sobre o verde-menta
  static const Color onPrimary = Color(0xFF003D26);

  /// Container/Surface com tom primário
  /// Tom pastel do verde-menta para cards e containers
  static const Color primaryContainer = Color(0xFFB8F0DF);

  /// Texto sobre primaryContainer
  /// Verde muito escuro para contraste mínimo de 7:1 (WCAG AAA)
  static const Color onPrimaryContainer = Color(0xFF002117);

  // ==========================================================================
  // CORES SECUNDÁRIAS (Secondary) - Azul-aço (identidade visual da logo)
  // ==========================================================================

  /// Cor secundária — Azul-aço derivado do gradiente da nova logo
  /// Usada em elementos de apoio, informação e detalhes visuais
  /// Contraste com [onSecondary] (#003547): 5.63:1 (WCAG AA ✓)
  static const Color secondary = Color(0xFF5AB4D4);

  /// Variante escura da cor secundária para estados hover/pressed e
  /// superfícies que exigem maior contraste visual
  static const Color secondaryDark = Color(0xFF3A95B5);

  /// Cor do texto/ícones sobre a cor secundária
  /// Azul escuro para atingir contraste WCAG AA (5.63:1) sobre o azul-aço
  static const Color onSecondary = Color(0xFF003547);

  /// Container/Surface com tom secundário
  static const Color secondaryContainer = Color(0xFFC9E8F5);

  /// Texto sobre secondaryContainer
  static const Color onSecondaryContainer = Color(0xFF001F2A);

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

  /// Cor primária inversa — tom claro do verde-menta para uso em superfícies escuras
  static const Color inversePrimary = Color(0xFF6FDBBF);

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

  /// Gradiente da identidade visual — Verde-menta → Azul-aço
  /// Replica o gradiente presente na nova logo do E-ReceitaSUS
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF43C59E), Color(0xFF5AB4D4)],
  );

  /// Gradiente com variantes escuras — para superfícies que exigem maior contraste
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2BA882), Color(0xFF3A95B5)],
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
