import 'package:flutter/material.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dados mockados para demonstração
    final List<Map<String, dynamic>> historico = [
      {
        'medicamento': 'Losartana 50mg',
        'data': '15/01/2024',
        'status': 'Aprovado',
        'statusColor': Colors.green,
      },
      {
        'medicamento': 'Metformina 850mg',
        'data': '10/01/2024',
        'status': 'Em Análise',
        'statusColor': Colors.orange,
      },
      {
        'medicamento': 'Sinvastatina 20mg',
        'data': '05/01/2024',
        'status': 'Aprovado',
        'statusColor': Colors.green,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Histórico de Medicamentos'),
        backgroundColor: Colors.blueAccent,
      ),
      body: historico.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Nenhum histórico encontrado',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: historico.length,
        itemBuilder: (context, index) {
          final item = historico[index];
          return Card(
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: item['statusColor'],
                child: const Icon(Icons.medical_services,
                    color: Colors.white),
              ),
              title: Text(
                item['medicamento'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Solicitado em: ${item['data']}'),
              trailing: Chip(
                label: Text(
                  item['status'],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
                backgroundColor: item['statusColor'],
              ),
              onTap: () {
                // Futura navegação para detalhes
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Detalhes de ${item['medicamento']}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
