import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importação para a nova infraestrutura
import 'providers/auth_provider.dart';
import 'services/auth_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_screen.dart';
import 'screens/doctor_home_screen.dart';
import 'screens/nurse_home_screen.dart';
import 'screens/prescription_type_screen.dart';
import 'screens/prescription_form_screen.dart';
import 'screens/patient_register_screen.dart';
import 'models/prescription_type.dart';

/// Ponto de entrada da aplicação E-ReceitaSUS
///
/// Refatorado para inicializar o Supabase de forma assíncrona,
/// substituindo a arquitetura anterior baseada em PostgreSQL local.
void main() async {
  // 1. Garante que os bindings do Flutter estejam prontos para operações assíncronas
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa o Supabase com as credenciais do seu projeto
  // Esta configuração conecta o app diretamente ao backend-as-a-service na nuvem
  await Supabase.initialize(
    url: 'https://shnahlongybxxilworck.supabase.co',
    anonKey: 'sb_publishable_NMJeKsT7rEJ8-l7vefZcDA_ggy3EKAj',
  );

  runApp(const MyApp());
}

/// Widget raiz da aplicação
///
/// Configura providers, tema (Material 3) e o sistema de rotas nomeadas
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Definição da identidade visual do projeto conforme o PRD
    const corVerdePrincipal = Color(0xFF4CAF50);
    const corAzulSecundaria = Color(0xFF1565C0);

    return MultiProvider(
      // Configuração centralizada de estado (Provider Pattern)
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthService()),
        ),
        // Providers adicionais para a Etapa 2 (ex: Prescrições) devem ser inseridos aqui
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'E-ReceitaSUS',

        // Configuração do tema Material Design 3 otimizado para acessibilidade no SUS
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: corVerdePrincipal,
            primary: corVerdePrincipal,
            secondary: corAzulSecundaria,
            brightness: Brightness.light,
          ),

          // Customização de componentes UI
          appBarTheme: const AppBarTheme(
            backgroundColor: corVerdePrincipal,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 2,
          ),

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

          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
            fillColor: Colors.grey[100],
          ),

          cardTheme: CardTheme(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Gerenciamento de navegação
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          // Rota dedicada ao cadastro de pacientes — fluxo separado do cadastro profissional
          '/register_patient': (context) => const PatientRegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/doctor_home': (context) => const DoctorHomeScreen(),
          '/nurse_home': (context) => const NurseHomeScreen(),
          '/history': (context) => const HistoryScreen(),
          '/new_prescription': (context) => const PrescriptionTypeScreen(),
          '/prescription_form_branca': (context) =>
              const PrescriptionFormScreen(type: PrescriptionType.branca),
          '/prescription_form_controlada': (context) =>
              const PrescriptionFormScreen(type: PrescriptionType.controlada),
          '/prescription_form_amarela': (context) =>
              const PrescriptionFormScreen(type: PrescriptionType.amarela),
          '/prescription_form_azul': (context) =>
              const PrescriptionFormScreen(type: PrescriptionType.azul),
        },

        // Fallback de segurança para rotas inexistentes
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
