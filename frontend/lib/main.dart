import 'package:e_receitasus/screens/login_screen.dart';
import 'package:e_receitasus/screens/home_screen.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Cores extraídas da Logo
    const corVerdePrincipal = Color(0xFF4CAF50); // Verde da Cruz
    const corAzulSecundaria = Color(0xFF1565C0); // Azul da Pílula/Text

    return MaterialApp(
      debugShowCheckedModeBanner: false, // Remove a faixa de debug
      title: 'E-ReceitaSUS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: corVerdePrincipal,
          primary: corVerdePrincipal,
          secondary: corAzulSecundaria,
        ),
        // Configura a AppBar para usar a cor verde
        appBarTheme: const AppBarTheme(
          backgroundColor: corVerdePrincipal,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),// Configura os buttons para utilizar a cor verde ou azul
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: corVerdePrincipal,
            foregroundColor: Colors.white,
          ),
        ),
        useMaterial3: true,
      ),
      // Configuração de rotas nomeadas
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}
