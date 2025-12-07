import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_receitasus/screens/home_screen.dart';

void main() {
  testWidgets(
      'Deve encontrar botão de Histórico e navegar para a lista completa',
      (WidgetTester tester) async {
    // 1. Carregar a HomeScreen
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));

    // 2. Tentar encontrar o botão "Ver Histórico Completo"
    // (Este botão ainda não foi adicionado na interface, então vai falhar aqui)
    final historyBtn = find.text('Ver Histórico Completo');
    expect(historyBtn, findsOneWidget);

    // 3. Navegação (não será executada pois falha antes)
    await tester.tap(historyBtn);
    await tester.pumpAndSettle();
    expect(find.text('Histórico de Medicamentos'), findsOneWidget);
  });
}
