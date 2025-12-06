import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_receitasus/screens/home_screen.dart';

void main() {
  testWidgets('Deve navegar para tela de rastreamento ao clicar no botão',
      (WidgetTester tester) async {
    // 1. Carregar a HomeScreen
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));

    // 2. Encontrar o botão de rastreamento pelo texto
    final rastrearBtn = find.text('Rastrear Status do Pedido');
    expect(rastrearBtn, findsOneWidget);

    // 3. Clicar no botão
    await tester.tap(rastrearBtn);
    await tester.pumpAndSettle(); // Aguarda a animação

    // 4. Verificar se encontrou a nova tela (Vai falhar aqui!)
    // Procuramos pelo título da AppBar da nova tela
    expect(find.text('Meus Pedidos'), findsOneWidget);
  });
}
