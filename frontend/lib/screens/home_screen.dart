import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/prescription_model.dart';
import '../services/prescription_service.dart'; // Importação do novo serviço
import 'history_screen.dart';
import 'prescription_view_screen.dart';

/// Tela Inicial do Paciente
///
/// Refatorada para a Etapa 2 para suportar sincronismo em tempo real
/// com o banco de dados Supabase.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Encerra a sessão e redireciona para o login
  Future<void> _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();

    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _handleSolicitation() {
    debugPrint('Ação de Solicitar Receita acionada');
  }

  void _handleTrack() {
    debugPrint('Ação de Rastrear Receita acionada');
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
    final userName = authProvider.user?.name ?? 'Usuário SUS';

    return Scaffold(
      appBar: AppBar(
        title: const Text('E-ReceitaSUS - Área do Paciente'),
        // Mantendo consistência visual com o tema definido no main.dart
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _handleLogout(context),
            tooltip: 'Sair do aplicativo',
          ),
        ],
      ),
      body: RefreshIndicator(
        // Adicionada funcionalidade de "puxar para atualizar"
        onRefresh: () async => debugPrint('Atualizando dados...'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Card de Boas-Vindas Dinâmico
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
                        'Acompanhe abaixo suas prescrições digitais em tempo real.',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Ações Principais
              ElevatedButton.icon(
                onPressed: _handleSolicitation,
                icon: const Icon(Icons.medical_services_outlined, size: 24),
                label: const Text('Solicitar Revalidação'),
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: _handleTrack,
                icon: const Icon(Icons.track_changes),
                label: const Text('Rastrear Status do Pedido'),
              ),
              const SizedBox(height: 30),

              // Seção de Prescrições Ativas (Real-time)
              const Text(
                'Prescrições Recentes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // IMPLEMENTAÇÃO DO STREAMBUILDER (Ponto Crítico da Etapa 2)
              // Substitui o antigo Placeholder estático
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: PrescriptionService().streamPrescriptions(),
                builder: (context, snapshot) {
                  // Estado de Carregamento
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  // Estado de Erro
                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Erro ao carregar dados da nuvem.'),
                    );
                  }

                  // Estado Vazio (Sem receitas no banco)
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(30.0),
                        child: Text(
                          'Nenhuma receita encontrada no sistema.\nSolicite sua primeira prescrição digital!',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }

                  // Lista de Receitas Reais
                  final list = snapshot.data!;
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFF4CAF50),
                            child: Icon(Icons.medication, color: Colors.white),
                          ),
                          title: Text(
                            item['medicine'] ?? 'Medicamento',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle:
                              Text('Médico: ${item['doctorName'] ?? 'N/A'}'),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                              final prescription = PrescriptionModel.fromJson(item);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PrescriptionViewScreen(
                                    prescription: prescription,
                                  ),
                                ),
                              );
                            },
                        ),
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              TextButton.icon(
                onPressed: () => _handleHistory(context),
                icon: const Icon(Icons.history),
                label: const Text('Acessar Histórico Completo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
