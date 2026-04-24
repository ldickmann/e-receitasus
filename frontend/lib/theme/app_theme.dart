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
        shadowColor: AppColors.shadow.withValues(alpha: 0.2),
        centerTitle: true,
        systemOverlayStyle:
            SystemUiOverlayStyle.light, // Ícones da status bar brancos
        titleTextStyle:
            AppTextStyles.titleLarge.copyWith(color: AppColors.onPrimary),
      ),

      // Flutter 3.41+ exige CardThemeData (antes era CardTheme) na propriedade cardTheme do ThemeData
      cardTheme: CardThemeData(
        elevation: 1,
        color: AppColors.surface,
        surfaceTintColor: Colors
            .transparent, // Impede que o card seja "tingido" pela cor primária
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.outline.withValues(alpha: 0.5)),
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
        // Opacidade reduzida para suavizar o fundo dos campos de texto
        fillColor: AppColors.surfaceVariant.withValues(alpha: 0.4),
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
            .copyWith(color: AppColors.onSurfaceVariant),
        floatingLabelStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
        hintStyle: AppTextStyles.bodyMedium
            .copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }

  // ==========================================================================
  // TEMA ESCURO (Dark Theme)
  // ==========================================================================
  //
  // Tema escuro simétrico ao light, derivando dos tokens de `AppColors`.
  // Mantém a identidade verde-menta através de `inversePrimary` (tom claro)
  // sobre superfícies escuras — garante contraste WCAG AA em todo o app.
  //
  // Referências de surface seguem o guia do Material 3 para dark mode:
  // background quase preto (#121212), surface levemente elevada (#1E1E1E)
  // e surfaceContainerHighest mais clara (#2A2A2A) para hierarquia visual.
  static ThemeData get darkTheme {
    // Tons fixos para superfícies do tema escuro — calibrados para reduzir
    // fadiga visual em ambientes com pouca luz (uso noturno em UPA/UBS).
    const Color darkBackground = Color(0xFF121212);
    const Color darkSurface = Color(0xFF1E1E1E);
    const Color darkSurfaceVariant = Color(0xFF2A2A2A);
    const Color darkOnSurface = Color(0xFFE6E1E5);
    const Color darkOnSurfaceVariant = Color(0xFFCAC4D0);
    const Color darkOutline = Color(0xFF938F99);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: darkBackground,

      // ColorScheme dark simétrico — usa inversePrimary como acento principal
      // para preservar contraste sobre superfícies escuras.
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        // inversePrimary (#6FDBBF) é o verde-menta clarificado para dark mode
        primary: AppColors.inversePrimary,
        onPrimary: AppColors.onPrimaryContainer,
        primaryContainer: AppColors.primaryDark,
        onPrimaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryDark,
        onSecondaryContainer: AppColors.secondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.onTertiaryContainer,
        onTertiaryContainer: AppColors.tertiaryContainer,
        error: AppColors.errorContainer,
        onError: AppColors.onErrorContainer,
        errorContainer: AppColors.onErrorContainer,
        onErrorContainer: AppColors.errorContainer,
        surface: darkSurface,
        onSurface: darkOnSurface,
        surfaceContainerHighest: darkSurfaceVariant,
        onSurfaceVariant: darkOnSurfaceVariant,
        outline: darkOutline,
        shadow: AppColors.shadow,
        scrim: AppColors.scrim,
        inverseSurface: AppColors.surface,
        onInverseSurface: AppColors.onSurface,
        inversePrimary: AppColors.primary,
      ),

      // Tipografia compartilhada — cores são resolvidas pelo ColorScheme
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

      // AppBar com fundo escuro elevado — evita brilho excessivo do verde-menta
      // sobre fundos escuros. Título e ícones em branco para alto contraste.
      appBarTheme: AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: darkOnSurface,
        elevation: 0,
        scrolledUnderElevation: 4,
        shadowColor: AppColors.shadow.withValues(alpha: 0.4),
        centerTitle: true,
        // Ícones da status bar claros (apropriado para fundo escuro)
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle:
            AppTextStyles.titleLarge.copyWith(color: darkOnSurface),
      ),

      cardTheme: CardThemeData(
        elevation: 1,
        color: darkSurface,
        // Surface tint transparente impede tingimento automático do Material 3
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: darkOutline.withValues(alpha: 0.4)),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.inversePrimary,
        foregroundColor: AppColors.onPrimaryContainer,
        elevation: 4,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.inversePrimary,
          foregroundColor: AppColors.onPrimaryContainer,
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 2,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inversePrimary,
          side: const BorderSide(color: AppColors.inversePrimary, width: 1.5),
          textStyle: AppTextStyles.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant.withValues(alpha: 0.6),
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
          borderSide:
              const BorderSide(color: AppColors.inversePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.errorContainer, width: 1.5),
        ),
        labelStyle:
            AppTextStyles.bodyMedium.copyWith(color: darkOnSurfaceVariant),
        floatingLabelStyle:
            AppTextStyles.bodyMedium.copyWith(color: AppColors.inversePrimary),
        hintStyle:
            AppTextStyles.bodyMedium.copyWith(color: darkOnSurfaceVariant),
      ),
    );
  }
}
