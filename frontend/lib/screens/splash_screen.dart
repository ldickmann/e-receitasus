import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

/// Tela de splash exibida durante inicialização do app
///
/// Responsável por verificar autenticação e redirecionar
/// para a tela apropriada (login ou home)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  /// Controller para animação de fade
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Configuração da animação
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );

    _animationController.forward();

    // ✅ CORREÇÃO: Usar addPostFrameCallback para executar após o build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  /// Verifica estado de autenticação e redireciona
  Future<void> _checkAuthentication() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Aguarda inicialização do provider
    await authProvider.initAuth();

    // Pequeno delay para melhor UX
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Redireciona baseado no papel do usuário autenticado
    if (authProvider.isAuthenticated) {
      final route = _resolveHomeRoute(authProvider);
      Navigator.pushReplacementNamed(context, route);
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  /// Determina a rota inicial conforme o tipo de profissional.
  /// Profissionais prescritores (médico, dentista, etc.) acessam o painel do
  /// prescritor; pacientes e usuários administrativos acessam a tela do paciente.
  String _resolveHomeRoute(AuthProvider authProvider) {
    final type = authProvider.user?.professionalType;
    if (type == null) return '/home';
    if (type.canPrescribe) return '/doctor_home';
    if (type.isNurse) return '/nurse_home';
    return '/home';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4CAF50),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Ícone principal
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.medication,
                  size: 80,
                  color: Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(height: 32),

              // Nome do app
              const Text(
                'E-ReceitaSUS',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              // Subtítulo
              Text(
                'Prescrição Digital do SUS',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 48),

              // Indicador de carregamento
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
