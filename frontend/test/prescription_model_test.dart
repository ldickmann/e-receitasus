/// Testes do PrescriptionModel — serializacao, validade e regras ANVISA.
///
/// PrescriptionService ainda nao tem interface abstrata (planejado na Fase 12);
/// portanto esta suite cobre o componente critico que o service apenas
/// repassa: o mapeamento snake_case <-> camelCase do PrescriptionModel,
/// regras de validade por tipo (RDC 471/2021, Portaria 344/98) e o status
/// derivado (isExpired/isActive).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:e_receitasus/models/prescription_model.dart';
import 'package:e_receitasus/models/prescription_type.dart';

void main() {
  group('PrescriptionModel.create — calculo de validade', () {
    test(
        'receita branca padrao deve usar validityDays do tipo (sem uso continuo)',
        () {
      final p = PrescriptionModel.create(
        type: PrescriptionType.branca,
        doctorName: 'Dr. X',
        doctorCouncil: 'CRM 1',
        doctorCouncilState: 'SP',
        doctorAddress: 'rua A',
        doctorCity: 'SP',
        doctorState: 'SP',
        patientName: 'Paciente',
        medicineName: 'Dipirona',
        dosage: '500mg',
        quantity: '20 cp',
        instructions: 'oral',
      );

      // Validade = issuedAt + validityDays do tipo (PrescriptionType.branca)
      final expectedValidity = p.issuedAt.add(
        Duration(days: PrescriptionType.branca.validityDays),
      );
      expect(p.validUntil, expectedValidity);
      expect(p.isContinuousUse, isFalse);
      expect(p.status, 'ativa');
    });

    test(
        'receita branca de uso continuo deve respeitar continuousValidityMonths (RDC 471/2021)',
        () {
      // RDC 471/2021 permite ate 6 meses para uso continuo em receita branca
      final p = PrescriptionModel.create(
        type: PrescriptionType.branca,
        doctorName: 'Dr. X',
        doctorCouncil: 'CRM 1',
        doctorCouncilState: 'SP',
        doctorAddress: 'rua A',
        doctorCity: 'SP',
        doctorState: 'SP',
        patientName: 'Paciente',
        medicineName: 'Losartana',
        dosage: '50mg',
        quantity: '90 cp',
        instructions: 'oral 1x/dia',
        isContinuousUse: true,
        continuousValidityMonths: 3,
      );

      // 3 meses x 30 dias = 90 dias de validade
      final expected = p.issuedAt.add(const Duration(days: 90));
      expect(p.validUntil, expected);
    });

    test(
        'receita amarela deve usar validityDays do tipo mesmo quando isContinuousUse for true',
        () {
      // Notificacoes amarelas/azuis nao se beneficiam da regra de uso continuo.
      // Apenas branca aplica continuousValidityMonths — comportamento atual do create.
      final p = PrescriptionModel.create(
        type: PrescriptionType.amarela,
        doctorName: 'Dr. X',
        doctorCouncil: 'CRM 1',
        doctorCouncilState: 'SP',
        doctorAddress: 'rua A',
        doctorCity: 'SP',
        doctorState: 'SP',
        patientName: 'Paciente',
        medicineName: 'Substancia A1',
        dosage: '10mg',
        quantity: '30 cp',
        quantityWords: 'trinta',
        instructions: 'oral',
        isContinuousUse: true,
        continuousValidityMonths: 6,
      );

      final expected = p.issuedAt.add(
        Duration(days: PrescriptionType.amarela.validityDays),
      );
      expect(p.validUntil, expected);
    });
  });

  group('PrescriptionModel — isExpired/isActive', () {
    /// Constroi modelo com validade ja vencida — usa construtor cru para evitar
    /// dependencia de DateTime.now() do PrescriptionModel.create.
    PrescriptionModel buildExpired() {
      final past = DateTime.now().subtract(const Duration(days: 60));
      return PrescriptionModel(
        type: PrescriptionType.branca,
        doctorName: 'Dr. X',
        doctorCouncil: 'CRM 1',
        doctorCouncilState: 'SP',
        doctorAddress: 'rua A',
        doctorCity: 'SP',
        doctorState: 'SP',
        patientName: 'Paciente',
        medicineName: 'X',
        dosage: '1mg',
        quantity: '1',
        instructions: 'oral',
        issuedAt: past,
        validUntil: past.add(const Duration(days: 30)),
      );
    }

    test('isExpired deve ser true quando validUntil for passado', () {
      final p = buildExpired();
      expect(p.isExpired, isTrue);
      // isActive depende de status='ativa' E !isExpired — vencida nao e ativa
      expect(p.isActive, isFalse);
    });

    test('isActive deve ser false quando status for cancelada mesmo no prazo',
        () {
      final future = DateTime.now().add(const Duration(days: 30));
      final p = PrescriptionModel(
        type: PrescriptionType.branca,
        doctorName: 'Dr. X',
        doctorCouncil: 'CRM 1',
        doctorCouncilState: 'SP',
        doctorAddress: 'rua A',
        doctorCity: 'SP',
        doctorState: 'SP',
        patientName: 'Paciente',
        medicineName: 'X',
        dosage: '1mg',
        quantity: '1',
        instructions: 'oral',
        issuedAt: DateTime.now(),
        validUntil: future,
        status: 'cancelada',
      );
      expect(p.isExpired, isFalse);
      expect(p.isActive, isFalse);
    });
  });

  group('PrescriptionModel — fromJson/toJson roundtrip', () {
    test('deve preservar todos os campos relevantes em roundtrip', () {
      // Json com chaves snake_case conforme tabela `prescriptions` no Supabase
      final issuedAt = DateTime.utc(2026, 4, 1, 12, 0);
      final validUntil = DateTime.utc(2026, 7, 1, 12, 0);
      final json = <String, dynamic>{
        'id': 'pres-001',
        'type': 'BRANCA',
        'doctor_name': 'Dr. Joao',
        'doctor_council': 'CRM 999',
        'doctor_council_state': 'SC',
        'doctor_specialty': 'Clinica Geral',
        'doctor_address': 'Rua das Flores 100',
        'doctor_city': 'Florianopolis',
        'doctor_state': 'SC',
        'doctor_phone': '4830000000',
        'doctor_cnes': '1234567',
        'clinic_name': 'UBS Centro',
        'clinic_cnpj': '00.000.000/0001-00',
        'patient_name': 'Maria Souza',
        'patient_cpf': '12345678901',
        'patient_address': 'Av. Beira-Mar',
        'patient_city': 'Florianopolis',
        'patient_state': 'SC',
        'patient_phone': '48999990000',
        'patient_age': '40',
        'medicine_name': 'Losartana',
        'dosage': '50mg',
        'pharmaceutical_form': 'comprimido',
        'route': 'oral',
        'quantity': '30 cp',
        'quantity_words': 'trinta',
        'instructions': '1x ao dia',
        'notification_number': null,
        'notification_uf': null,
        'is_continuous_use': true,
        'continuous_validity_months': 3,
        'issued_at': issuedAt.toIso8601String(),
        'valid_until': validUntil.toIso8601String(),
        'status': 'ativa',
        'doctor_user_id': 'doc-uuid',
        'patient_user_id': 'pat-uuid',
      };

      final model = PrescriptionModel.fromJson(json);
      final back = model.toJson();

      // Campos chave preservados
      expect(model.id, 'pres-001');
      expect(model.type, PrescriptionType.branca);
      expect(model.medicineName, 'Losartana');
      expect(model.isContinuousUse, isTrue);
      expect(model.continuousValidityMonths, 3);
      expect(model.issuedAt.toUtc(), issuedAt);
      expect(model.validUntil.toUtc(), validUntil);

      // Roundtrip preserva chaves snake_case esperadas pelo Supabase
      expect(back['medicine_name'], 'Losartana');
      expect(back['doctor_user_id'], 'doc-uuid');
      expect(back['patient_user_id'], 'pat-uuid');
      expect(back['is_continuous_use'], isTrue);
      expect(back['type'], 'BRANCA');
    });

    test('fromJson deve aplicar defaults seguros para campos ausentes', () {
      // Resposta minima — protege contra row corrompida vinda do Supabase
      final minimal = <String, dynamic>{};

      final model = PrescriptionModel.fromJson(minimal);

      expect(model.id, isNull);
      expect(model.type, PrescriptionType.branca); // fallback do enum
      expect(model.doctorName, '');
      expect(model.medicineName, '');
      expect(model.status, 'ativa');
      expect(model.isContinuousUse, isFalse);
      // issuedAt/validUntil tem defaults baseados em now() — apenas garantir tipo
      expect(model.issuedAt, isA<DateTime>());
      expect(model.validUntil, isA<DateTime>());
    });
  });
}
