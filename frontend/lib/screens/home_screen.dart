import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Callbacks
  void _handleLogout() {
    // A Lógica de Logout real será implementada com Provider
    print('Ação de Logout');
  }

  void _handleSolicitation() {
    // A Lógica de solicitação de receita será implementada posteriormente
    print('Ação de Solicitar Receita');
  }

  void _handleTrack() {
    // A Lógica de rastreamento será implementada posteriormente
    print('Ação de Rastrear Receita');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-ReceitaSUS - Área do Paciente'),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _handleLogout, // Callback
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Card de Status/Boas-Vindas
            const Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bem-vindo(a), Paciente SUS!',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text(
                        'Use a opção abaixo para solicitar ou rastrear sua receita.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Módulo 1: Solicitação Remota (Requisito Principal)
            ElevatedButton.icon(
              onPressed: _handleSolicitation, // Callback
              icon: const Icon(Icons.medical_services_outlined, size: 24),
              label: const Text('Solicitar Revalidação de Receita',
                  style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 10),

            // Módulo 2: Rastreabilidade (Requisito Secundário)
            OutlinedButton.icon(
              onPressed: _handleTrack, // Callback
              icon: const Icon(Icons.track_changes),
              label: const Text('Rastrear Status do Pedido'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
            const SizedBox(height: 30),

            // Módulo 3: Histórico (Visualização de Dados)
            const Text('Seu Histórico de Receitas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),

            // Placeholder para a Lista de Histórico
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30.0),
                child: Text(
                    'Nenhum histórico encontrado. Solicite sua primeira receita!',
                    textAlign: TextAlign.center),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
