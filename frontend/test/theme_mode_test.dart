import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:e_receitasus/providers/theme_provider.dart';
import 'package:e_receitasus/theme/app_theme.dart';

/// Testes de regressão para a PBI #196 — garantem que o app SEMPRE inicia em
/// `ThemeMode.light`, independente da preferência do sistema operacional.
///
/// Estratégia: validamos o comportamento em duas camadas isoladas para evitar
/// dependência do `Supabase.initialize()` exigido pelo `MyApp` real:
///   1. `ThemeProvider` em isolamento — contrato de estado inicial.
///   2. `MaterialApp` envolvido pelo mesmo `Consumer<ThemeProvider>` usado em
///      `main.dart` — contrato de integração com o widget tree.
void main() {
  group('PBI #196 — App sempre inicia em tema claro', () {
    test('ThemeProvider tem ThemeMode.light como estado inicial', () {
      // Decisão de produto: ignorar a preferência do SO e abrir sempre claro.
      final provider = ThemeProvider();
      expect(provider.themeMode, ThemeMode.light);
      expect(provider.isDark, isFalse);
    });

    testWidgets(
      'MaterialApp construído com ThemeProvider expõe themeMode == light',
      (tester) async {
        // Reproduz o mesmo padrão Consumer<ThemeProvider> usado em main.dart
        // para garantir que qualquer regressão (ex.: voltar a ThemeMode.system)
        // seja capturada pelo CI antes de chegar a produção.
        await tester.pumpWidget(
          ChangeNotifierProvider<ThemeProvider>(
            create: (_) => ThemeProvider(),
            child: Consumer<ThemeProvider>(
              builder: (context, themeProvider, _) => MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: themeProvider.themeMode,
                home: const Scaffold(body: SizedBox.shrink()),
              ),
            ),
          ),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.light);
      },
    );

    testWidgets(
      'MediaQuery em dark NÃO força o app para o tema escuro',
      (tester) async {
        // Simula um dispositivo com SO em modo escuro: o app deve ignorar essa
        // preferência e continuar em ThemeMode.light (acceptance criterion #2).
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(platformBrightness: Brightness.dark),
            child: ChangeNotifierProvider<ThemeProvider>(
              create: (_) => ThemeProvider(),
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) => MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: themeProvider.themeMode,
                  home: const Scaffold(body: SizedBox.shrink()),
                ),
              ),
            ),
          ),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.light);
      },
    );
  });
}
