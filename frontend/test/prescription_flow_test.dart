import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:e_receitasus/screens/home_screen.dart';

void main() {
  testWidgets(
      'Deve abrir formulário de receita ao clicar no botão de solicitação',
      (WidgetTester tester) async {
    // 1. Carregar a HomeScreen
    await tester.pumpWidget(const MaterialApp(
      home: HomeScreen(),
    ));

    // 2. Encontrar o botão de solicitar receita
    final solicitarBtn = find.text('Solicitar Revalidação de Receita');
    expect(solicitarBtn, findsOneWidget);

    // 3. Clicar no botão
    await tester.tap(solicitarBtn);
    await tester.pumpAndSettle(); // Aguarda a animação de navegação

    // 4. Verificar se estamos na tela de formulário (Falhar aqui!)
    // O teste procura por um campo de texto que deveria existir na nova tela
    expect(find.byType(TextField), findsAtLeastNWidgets(1));
    expect(find.text('Nome do Medicamento'), findsOneWidget);
  });
}
