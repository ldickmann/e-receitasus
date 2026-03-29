import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Tema principal da aplicação E-ReceitaSUS
///
/// Define configurações completas de tema (claro e escuro) seguindo:
/// - Material Design 3
/// - Identidade Visual do SUS
/// - Acessibilidade WCAG 2.1 AAA
///
/// **Uso:**
/// No seu `main.dart`, aplique o tema ao MaterialApp:
///
/// ```dart
/// MaterialApp(
///   title: 'E-ReceitaSUS',
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme, // Opcional
///   themeMode: ThemeMode.system,   // Opcional
///   home: SuaHomePage(),
/// )
/// ```
class AppTheme {
  // Construtor privado para impedir a instanciação da classe.
  AppTheme._();

  // ==========================================================================
  // TEMA CLARO (Light Theme)
  // ==========================================================================
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.background,

      // Esquema de cores principal, usando o ColorScheme do Material 3
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainerHighest: AppColors.surfaceVariant,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
      ),

      // Tipografia global, usando os estilos definidos em AppTextStyles
      textTheme: const TextTheme(
        displayLarge: AppTextStyles.displayLarge,
        displayMedium: AppTextStyles.displayMedium,
        displaySmall: AppTextStyles.displaySmall,
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.titleMedium,
        titleSmall: AppTextStyles.titleSmall,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),

      // Estilos específicos para componentes da UI
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        scrolledUnderElevation: 4,
        shadowColor: AppColors.shadow.withOpacity(0.2),
        centerTitle: true,
        systemOverlayStyle:
            SystemUiOverlayStyle.light, // Ícones da status bar brancos
        titleTextStyle:
            AppTextStyles.titleLarge?.copyWith(color: AppColors.onPrimary),
      ),

      cardTheme: CardTheme(
        elevation: 1,
        color: AppColors.surface,
        surfaceTintColor: Colors
            .transparent, // Impede que o card seja "tingido" pela cor primária
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.outline.withOpacity(0.5)),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 2,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant.withOpacity(0.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        labelStyle: AppTextStyles.bodyMedium
            ?.copyWith(color: AppColors.onSurfaceVariant),
        floatingLabelStyle:
            AppTextStyles.bodyMedium?.copyWith(color: AppColors.primary),
        hintStyle: AppTextStyles.bodyMedium
            ?.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }

  // ==========================================================================
  // TEMA ESCURO (Dark Theme) - [FUTURO]
  // ==========================================================================
  static ThemeData get darkTheme {
    // Por simplicidade, estamos usando um tema escuro padrão gerado pelo Material 3
    // a partir da nossa cor primária. Para um controle total, seria necessário
    // criar uma paleta de cores escuras dedicada em app_colors.dart.
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: AppColors.primary,
      fontFamily: 'Roboto',
      // Você pode sobrescrever estilos específicos para o tema escuro aqui.
      // Ex: cardTheme: CardTheme(...)
    );
  }
}
