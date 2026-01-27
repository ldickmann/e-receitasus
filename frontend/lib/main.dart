import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';

/// Ponto de entrada da aplicação E-ReceitaSUS
void main() {
  // Inicialização de serviços e configurações podem ser adicionadas aqui
  runApp(const MyApp());
}

/// Widget raiz da aplicação
///
/// Configura providers, tema e rotas da aplicação
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definição das cores principais do tema
    const corVerdePrincipal = Color(0xFF4CAF50);
    const corAzulSecundaria = Color(0xFF1565C0);

    return MultiProvider(
      // Configuração dos providers da aplicação
      providers: [
        // Provider de autenticação com injeção de dependência
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthService()),
        ),
        // Futuros providers podem ser adicionados aqui
        // Ex: PrescriptionProvider, HistoryProvider, etc.
      ],
      child: MaterialApp(
        // Configurações gerais do app
        debugShowCheckedModeBanner: false,
        title: 'E-ReceitaSUS',

        // Configuração do tema Material Design 3
        theme: ThemeData(
          useMaterial3: true,

          // Esquema de cores baseado em Material 3
          colorScheme: ColorScheme.fromSeed(
            seedColor: corVerdePrincipal,
            primary: corVerdePrincipal,
            secondary: corAzulSecundaria,
            brightness: Brightness.light,
          ),

          // Tema da AppBar
          appBarTheme: const AppBarTheme(
            backgroundColor: corVerdePrincipal,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 2,
          ),

          // Tema dos botões elevados
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: corVerdePrincipal,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          // Tema dos campos de texto
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[100],
          ),

          // Tema dos cards
          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Rota inicial (splash screen)
        initialRoute: '/',

        // Definição de rotas nomeadas
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/history': (context) => const HistoryScreen(),
        },

        // Handler para rotas não encontradas
        onUnknownRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Erro')),
              body: const Center(
                child: Text('Página não encontrada'),
              ),
            ),
          );
        },
      ),
    );
  }
}