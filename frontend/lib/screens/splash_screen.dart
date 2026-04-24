import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';

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
      // Fundo segue a cor prim\u00e1ria do tema (verde-menta) para alinhar
      // a tela de abertura com a nova identidade visual do E-ReceitaSUS.
      backgroundColor: AppColors.primary,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo institucional dentro de um cart\u00e3o branco arredondado.
              // Substitui o antigo \u00edcone gen\u00e9rico Icons.medication para reforçar
              // a marca E-ReceitaSUS desde o primeiro frame visualizado.
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/images/logo-e-receitasus.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo E-ReceitaSUS',
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
                  color: Colors.white.withValues(alpha: 0.9),
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
