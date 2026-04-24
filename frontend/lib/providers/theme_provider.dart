import 'package:flutter/material.dart';

/// Provider responsável pelo gerenciamento do tema visual da aplicação.
///
/// Permite ao usuário alternar entre tema claro e escuro diretamente
/// pelo app, independente da preferência do sistema operacional.
///
/// Segue o padrão `ChangeNotifier` já adotado pelos demais providers
/// (AuthProvider, PrescriptionProvider etc.) para manter consistência
/// arquitetural na camada de estado global.
class ThemeProvider extends ChangeNotifier {
  /// Estado interno do tema; inicia seguindo a preferência do sistema.
  /// Ao primeiro toggle, assume controle explícito (light ↔ dark).
  ThemeMode _themeMode = ThemeMode.system;

  /// Tema atualmente ativo, consumido pelo `MaterialApp` via Consumer.
  ThemeMode get themeMode => _themeMode;

  /// Retorna `true` quando o tema escuro está ativo.
  ///
  /// Usado pelos widgets para decidir qual ícone exibir no botão de
  /// alternância: sol (para ir ao claro) ou lua (para ir ao escuro).
  bool get isDark => _themeMode == ThemeMode.dark;

  /// Alterna entre tema claro e escuro.
  ///
  /// - Tema escuro ativo → muda para claro.
  /// - Tema claro ou sistema → muda para escuro.
  ///
  /// Notifica todos os ouvintes para que o `MaterialApp` reconstrua
  /// com o novo `themeMode`.
  void toggleTheme() {
    // Inverte o tema: escuro vira claro, qualquer outro vira escuro
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }
}
