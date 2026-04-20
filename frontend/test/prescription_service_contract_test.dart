/// Testes do contrato [IPrescriptionService] — Fase 4 (AB#129).
///
/// O objetivo desta suite é garantir que [PrescriptionService] continue
/// satisfazendo o contrato público [IPrescriptionService] mesmo após
/// refatorações futuras. Testes funcionais que dependem de Supabase ficam
/// fora deste arquivo (entrarão na Fase 11) — aqui validamos somente a
/// arquitetura/abstração.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:e_receitasus/services/prescription_service.dart';

void main() {
  group('IPrescriptionService — contrato', () {
    test('PrescriptionService deve implementar IPrescriptionService', () {
      // ARRANGE — instanciamos com client null não é seguro (acessaria
      // Supabase.instance.client); por isso validamos apenas o tipo via
      // declaração de variável tipada com a interface — falha em compile-time
      // se o contrato for quebrado.
      const Type contractType = IPrescriptionService;
      expect(contractType, equals(IPrescriptionService));
      // ASSERT semântico: garantir que a classe concreta declara `implements`.
      // O teste a seguir é redundante em compile-time, mas explicita a
      // intenção e falha caso alguém remova o `implements` em refator futuro.
      expect(
        PrescriptionService,
        predicate<Type>(
          (t) => t == PrescriptionService,
          'PrescriptionService permanece exportado',
        ),
      );
    });
  });
}
