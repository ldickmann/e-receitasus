import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'history_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _handleSolicitation() {
    print('Ação de Solicitar Receita');
  }

  void _handleTrack() {
    print('Ação de Rastrear Receita');
  }

  void _handleHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const HistoryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userName = authProvider.user?.name ?? 'Usuário';

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-ReceitaSUS - Área do Paciente'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Card de Boas-Vindas
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bem-vindo(a), $userName!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use a opção abaixo para solicitar ou rastrear sua receita.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Módulo 1: Solicitação Remota
            ElevatedButton.icon(
              onPressed: _handleSolicitation,
              icon: const Icon(Icons.medical_services_outlined, size: 24),
              label: const Text(
                'Solicitar Revalidação de Receita',
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 10),

            // Módulo 2: Rastreabilidade
            OutlinedButton.icon(
              onPressed: _handleTrack,
              icon: const Icon(Icons.track_changes),
              label: const Text('Rastrear Status do Pedido'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 30),

            // Módulo 3: Histórico
            const Text(
              'Histórico',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () => _handleHistory(context),
              icon: const Icon(Icons.history),
              label: const Text('Ver Histórico Completo'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),

            // Placeholder
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30.0),
                child: Text(
                  'Nenhum histórico encontrado. Solicite sua primeira receita!',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
