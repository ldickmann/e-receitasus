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
import 'screens/request_renewal_screen.dart';
import 'models/prescription_type.dart';
import 'services/renewal_service.dart';
import 'providers/renewal_provider.dart';
import 'providers/triage_provider.dart';
import 'theme/app_theme.dart';

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

  // 3. Executa a aplicação Flutter
  runApp(const MyApp());
}

/// Widget raiz da aplicação
///
/// Configura providers, tema (Material 3) e o sistema de rotas nomeadas
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // O tema oficial vive em `AppTheme.lightTheme`, que utiliza a paleta
    // centralizada em `AppColors` (verde-menta #43C59E + azul-aço #5AB4D4).
    // Mantemos a definição em um único lugar para evitar divergência visual
    // entre AppBars, botões e cards — conforme a nova identidade do logo.
    return MultiProvider(
      // Configuração centralizada de estado (Provider Pattern)
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthService()),
        ),
        // Provider de renovação: utilizado pelo paciente para solicitar renovação de receitas
        ChangeNotifierProvider(
            create: (_) => RenewalProvider(RenewalService())),
        // Provider de triagem: utilizado pelo enfermeiro para aprovar ou rejeitar pedidos
        ChangeNotifierProvider(create: (_) => TriageProvider(RenewalService())),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'E-ReceitaSUS',

        // Aplicação do tema oficial centralizado em AppTheme.
        // O `themeMode` segue a preferência do sistema operacional do usuário,
        // alternando automaticamente entre claro e escuro — habilita conforto
        // visual em ambientes hospitalares com baixa luminosidade.
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,

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
          // Rota de solicitação de renovação de receita — perfil paciente
          '/request_renewal': (context) => const RequestRenewalScreen(),
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
