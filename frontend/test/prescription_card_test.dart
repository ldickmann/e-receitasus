import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:e_receitasus/models/prescription_model.dart';
import 'package:e_receitasus/models/prescription_type.dart';
import 'package:e_receitasus/theme/app_colors.dart';
import 'package:e_receitasus/widgets/prescription_card.dart';

// =============================================================================
// Helpers de fixture
// =============================================================================

/// Cria um [PrescriptionModel] mínimo e válido para uso nos testes.
///
/// Os parâmetros [status], [issuedAt] e [validUntil] permitem variar
/// apenas o que cada teste precisa sem repetir todos os campos obrigatórios.
PrescriptionModel _buildPrescription({
  PrescriptionType type = PrescriptionType.branca,
  String medicineName = 'Metformina 850mg',
  String dosage = '1 comprimido via oral 2x ao dia',
  String instructions = 'Tomar após as refeições',
  String doctorName = 'Ana Paula Ferreira',
  String status = 'ativa',
  DateTime? issuedAt,
  DateTime? validUntil,
}) {
  final now = DateTime(2026, 4, 15);
  return PrescriptionModel(
    id: 'test-uuid-001',
    type: type,
    medicineName: medicineName,
    dosage: dosage,
    instructions: instructions,
    doctorName: doctorName,
    doctorCouncil: 'CRM-SC 12345',
    doctorCouncilState: 'SC',
    doctorAddress: 'Rua das Flores, 100',
    doctorCity: 'Florianópolis',
    doctorState: 'SC',
    patientName: 'João da Silva',
    quantity: '60 comprimidos',
    issuedAt: issuedAt ?? now,
    validUntil: validUntil ?? now.add(const Duration(days: 30)),
    status: status,
  );
}

/// Envolve o widget em [MaterialApp] com o tema padrão para renderização correta.
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(body: child),
  );
}

// =============================================================================
// Testes
// =============================================================================

void main() {
  group('PrescriptionCard — Conteúdo principal', () {
    /// Verifica que nome do medicamento e dosagem aparecem em destaque.
    testWidgets('exibe nome do medicamento e dosagem', (tester) async {
      final model = _buildPrescription();
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      expect(find.text('Metformina 850mg'), findsOneWidget);
      expect(find.text('1 comprimido via oral 2x ao dia'), findsOneWidget);
    });

    /// Nome do médico é formatado com apenas o primeiro nome precedido de "Dr(a).".
    testWidgets('exibe primeiro nome do médico com prefixo Dr(a).',
        (tester) async {
      final model = _buildPrescription();
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      // Apenas o primeiro nome por limitação de espaço no card
      expect(find.textContaining('Dr(a). Ana'), findsOneWidget);
    });

    /// Data de emissão deve aparecer no formato brasileiro DD/MM/AAAA.
    testWidgets('exibe data de emissão formatada em DD/MM/AAAA',
        (tester) async {
      final model = _buildPrescription(
        issuedAt: DateTime(2026, 4, 15),
        validUntil: DateTime(2026, 5, 15),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      expect(find.textContaining('15/04/2026'), findsOneWidget);
    });

    /// Data de validade deve estar visível no card.
    testWidgets('exibe data de validade', (tester) async {
      final model = _buildPrescription(
        issuedAt: DateTime(2026, 4, 15),
        validUntil: DateTime(2026, 5, 15),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      expect(find.textContaining('15/05/2026'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  group('PrescriptionCard — Indicador de status', () {
    /// Receita com status ativa e dentro do prazo exibe badge "Ativa".
    testWidgets('exibe badge "Ativa" para prescrição ativa dentro do prazo',
        (tester) async {
      final model = _buildPrescription(
        status: 'ativa',
        validUntil: DateTime.now().add(const Duration(days: 10)),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      expect(find.text('Ativa'), findsOneWidget);
    });

    /// Receita com validUntil no passado exibe badge "Vencida" independente do status.
    testWidgets('exibe badge "Vencida" para prescrição expirada por prazo',
        (tester) async {
      final model = _buildPrescription(
        status: 'ativa',
        // validUntil no passado → isExpired == true
        validUntil: DateTime(2025, 1, 1),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      expect(find.text('Vencida'), findsOneWidget);
    });

    /// Receita com status "cancelada" exibe badge "Cancelada".
    testWidgets('exibe badge "Cancelada" para prescrição cancelada',
        (tester) async {
      final model = _buildPrescription(
        status: 'cancelada',
        validUntil: DateTime.now().add(const Duration(days: 10)),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      expect(find.text('Cancelada'), findsOneWidget);
    });

    /// Receita com status "utilizada" exibe badge "Utilizada".
    testWidgets('exibe badge "Utilizada" para prescrição utilizada',
        (tester) async {
      final model = _buildPrescription(
        status: 'utilizada',
        validUntil: DateTime.now().add(const Duration(days: 10)),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      expect(find.text('Utilizada'), findsOneWidget);
    });

    /// A cor do badge de prescrição ativa deve ser AppColors.primary (verde SUS).
    testWidgets('badge "Ativa" usa cor primária verde SUS', (tester) async {
      final model = _buildPrescription(
        status: 'ativa',
        validUntil: DateTime.now().add(const Duration(days: 10)),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      // Localiza o texto do badge e verifica sua cor
      final badgeText = tester.widget<Text>(find.text('Ativa'));
      expect(badgeText.style?.color, AppColors.primary);
    });

    /// A cor do badge de prescrição vencida deve ser AppColors.error (vermelho).
    testWidgets('badge "Vencida" usa cor de erro', (tester) async {
      final model = _buildPrescription(
        status: 'ativa',
        validUntil: DateTime(2025, 1, 1),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      final badgeText = tester.widget<Text>(find.text('Vencida'));
      expect(badgeText.style?.color, AppColors.error);
    });
  });

  // ---------------------------------------------------------------------------
  group('PrescriptionCard — Tipos de receita ANVISA', () {
    /// Receita branca renderiza sem erro (cor de fundo branca).
    testWidgets('renderiza tipo branca sem erro', (tester) async {
      final model = _buildPrescription(type: PrescriptionType.branca);
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));
      expect(find.byType(PrescriptionCard), findsOneWidget);
    });

    /// Receita amarela renderiza sem erro.
    testWidgets('renderiza tipo amarela sem erro', (tester) async {
      final model = _buildPrescription(type: PrescriptionType.amarela);
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));
      expect(find.byType(PrescriptionCard), findsOneWidget);
    });

    /// Receita azul renderiza sem erro.
    testWidgets('renderiza tipo azul sem erro', (tester) async {
      final model = _buildPrescription(type: PrescriptionType.azul);
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));
      expect(find.byType(PrescriptionCard), findsOneWidget);
    });

    /// Receita controlada renderiza sem erro.
    testWidgets('renderiza tipo controlada sem erro', (tester) async {
      final model = _buildPrescription(type: PrescriptionType.controlada);
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));
      expect(find.byType(PrescriptionCard), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  group('PrescriptionCard — Interação', () {
    /// onTap deve ser invocado ao tocar no card.
    testWidgets('dispara onTap ao tocar no card', (tester) async {
      var tapped = false;
      final model = _buildPrescription();
      await tester.pumpWidget(
        _wrap(
          PrescriptionCard(
            prescription: model,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(PrescriptionCard));
      await tester.pump();

      expect(tapped, isTrue);
    });

    /// Sem onTap, o ícone de chevron não deve aparecer.
    testWidgets('oculta chevron quando onTap é nulo', (tester) async {
      final model = _buildPrescription();
      await tester.pumpWidget(
        _wrap(PrescriptionCard(prescription: model)),
      );

      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    /// Com onTap, o ícone de chevron deve aparecer para indicar navegação.
    testWidgets('exibe chevron quando onTap está definido', (tester) async {
      final model = _buildPrescription();
      await tester.pumpWidget(
        _wrap(
          PrescriptionCard(
            prescription: model,
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  group('PrescriptionCard — Acessibilidade', () {
    /// O widget deve ter Semantics com label descritivo para leitores de tela.
    testWidgets('possui Semantics com label acessível', (tester) async {
      final model = _buildPrescription(
        medicineName: 'Metformina 850mg',
        status: 'ativa',
        issuedAt: DateTime(2026, 4, 15),
        validUntil: DateTime(2026, 5, 15),
      );
      await tester.pumpWidget(_wrap(PrescriptionCard(prescription: model)));

      // Verifica que o Semantics com label contendo o medicamento existe
      final semantics = tester.getSemantics(find.byType(PrescriptionCard));
      expect(semantics.label, contains('Metformina 850mg'));
    });
  });
}
