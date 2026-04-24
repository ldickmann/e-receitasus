import 'package:flutter_test/flutter_test.dart';
import 'package:e_receitasus/models/professional_type.dart';

/// Testes unitários para os getters de controle de acesso do [ProfessionalType].
///
/// Garante que as regras de negócio de prescrição e triagem estejam corretas
/// conforme legislação vigente (Lei Federal 5.081/66 e regulamentações CFM/CFO).
void main() {
  // ---------------------------------------------------------------------------
  group('ProfessionalType.canPrescribe', () {
    /// Apenas médico e dentista têm autorização legal para prescrever.
    test('retorna true apenas para medico e dentista', () {
      expect(ProfessionalType.medico.canPrescribe, isTrue);
      expect(ProfessionalType.dentista.canPrescribe, isTrue);
    });

    /// Todos os demais profissionais não podem prescrever receitas.
    test('retorna false para todos os outros perfis', () {
      const naoPrescritors = [
        ProfessionalType.enfermeiro,
        ProfessionalType.farmaceutico,
        ProfessionalType.psicologo,
        ProfessionalType.nutricionista,
        ProfessionalType.fisioterapeuta,
        ProfessionalType.assistenteSocial,
        ProfessionalType.administrativo,
        ProfessionalType.outros,
      ];

      for (final tipo in naoPrescritors) {
        expect(
          tipo.canPrescribe,
          isFalse,
          reason: '${tipo.displayName} não deve poder prescrever',
        );
      }
    });

    /// Verifica a contagem exata para evitar adição acidental de novos prescritores.
    test('exatamente 2 tipos profissionais podem prescrever', () {
      final prescritores =
          ProfessionalType.values.where((t) => t.canPrescribe).toList();

      expect(
        prescritores.length,
        equals(2),
        reason: 'Apenas médico e dentista devem constar como prescritores',
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('ProfessionalType.isNurse', () {
    /// Apenas o enfermeiro atua na triagem de renovações de receitas.
    test('retorna true apenas para enfermeiro', () {
      expect(ProfessionalType.enfermeiro.isNurse, isTrue);
    });

    /// Nenhum outro perfil deve ser identificado como enfermeiro.
    test('retorna false para todos os outros perfis', () {
      final naoEnfermeiros = ProfessionalType.values
          .where((t) => t != ProfessionalType.enfermeiro)
          .toList();

      for (final tipo in naoEnfermeiros) {
        expect(
          tipo.isNurse,
          isFalse,
          reason:
              '${tipo.displayName} não deve ser identificado como enfermeiro',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('canPrescribe e isNurse são mutuamente exclusivos', () {
    /// Um profissional não pode ser prescritor e enfermeiro ao mesmo tempo.
    test('nenhum tipo satisfaz ambos os getters simultaneamente', () {
      for (final tipo in ProfessionalType.values) {
        expect(
          tipo.canPrescribe && tipo.isNurse,
          isFalse,
          reason:
              '${tipo.displayName} não pode ter canPrescribe e isNurse ambos verdadeiros',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  group('ProfessionalType.validateRegistration — profissionais com conselho', () {
    /// Após PBI #157, o campo de número aceita apenas o número puro;
    /// a UF é capturada no dropdown separado. Fix de regressão PBI #180.

    test('aceita número puro com 4 dígitos (mínimo)', () {
      // 4 dígitos é o mínimo aceito pelo regex ^\\d{4,10}
      expect(ProfessionalType.medico.validateRegistration('1234'), isNull);
    });

    test('aceita número puro com 5 dígitos — caso padrão CRM', () {
      expect(ProfessionalType.medico.validateRegistration('12345'), isNull);
    });

    test('aceita número puro com 10 dígitos (máximo)', () {
      expect(
        ProfessionalType.medico.validateRegistration('1234567890'),
        isNull,
      );
    });

    test('aceita formato legado número/UF com barra (ex: 12345/SP)', () {
      // Compatibilidade: usuário pode colar registro no formato antigo.
      expect(ProfessionalType.medico.validateRegistration('12345/SP'), isNull);
    });

    test('aceita formato legado número-UF com hífen (ex: 12345-SP)', () {
      expect(ProfessionalType.medico.validateRegistration('12345-SP'), isNull);
    });

    test('rejeita string vazia com mensagem obrigatória', () {
      final resultado = ProfessionalType.medico.validateRegistration('');
      expect(resultado, isNotNull);
      expect(resultado, contains('Informe obrigatoriamente'));
    });

    test('rejeita null com mensagem obrigatória', () {
      final resultado = ProfessionalType.medico.validateRegistration(null);
      expect(resultado, isNotNull);
      expect(resultado, contains('Informe obrigatoriamente'));
    });

    test('rejeita string com menos de 3 caracteres', () {
      // Verificação de comprimento mínimo antes do regex.
      final resultado = ProfessionalType.medico.validateRegistration('12');
      expect(resultado, isNotNull);
      expect(resultado, contains('mínimo 3 caracteres'));
    });

    test('rejeita número com menos de 4 dígitos (falha no regex)', () {
      // '123' passa o check de comprimento (3 chars) mas falha no regex \\d{4,10}.
      final resultado = ProfessionalType.medico.validateRegistration('123');
      expect(resultado, isNotNull);
      expect(resultado, contains('inválido'));
    });

    test('rejeita texto sem dígitos (ex: abc)', () {
      final resultado = ProfessionalType.medico.validateRegistration('abc');
      expect(resultado, isNotNull);
      expect(resultado, contains('inválido'));
    });

    test('rejeita UF incompleta com apenas 1 letra (ex: 12345/S)', () {
      // Regex exige exatamente 2 letras no sufixo UF.
      final resultado = ProfessionalType.medico.validateRegistration('12345/S');
      expect(resultado, isNotNull);
      expect(resultado, contains('inválido'));
    });

    test('rejeita UF inexistente no Brasil (ex: 12345-ZZ)', () {
      // Regex aceita 2 letras, mas a validação posterior rejeita UF inválida.
      final resultado =
          ProfessionalType.medico.validateRegistration('12345-ZZ');
      expect(resultado, isNotNull);
      expect(resultado, contains('UF inválida'));
    });

    test('valida corretamente para tipos com conselho distintos (CRO, COREN)', () {
      // Garante que o fix não é exclusivo do CRM — vale para todos os conselhos.
      expect(ProfessionalType.dentista.validateRegistration('98765'), isNull);
      expect(ProfessionalType.enfermeiro.validateRegistration('54321'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('ProfessionalType.validateRegistration — sem conselho obrigatório', () {
    /// Perfis sem requiresCouncil (administrativo, outros, paciente) não passam
    /// pelo bloco de regex — qualquer string com ≥ 3 chars é aceita.

    test('administrativo aceita matrícula funcional livre (≥ 3 chars)', () {
      expect(
        ProfessionalType.administrativo.validateRegistration('MAT-2024-001'),
        isNull,
      );
    });

    test('outros aceita registro institucional livre (≥ 3 chars)', () {
      expect(
        ProfessionalType.outros.validateRegistration('REG-001'),
        isNull,
      );
    });

    test('paciente aceita CNS livre (≥ 3 chars)', () {
      expect(
        ProfessionalType.paciente.validateRegistration('123456789'),
        isNull,
      );
    });

    test('rejeita string vazia mesmo sem conselho obrigatório', () {
      final resultado =
          ProfessionalType.administrativo.validateRegistration('');
      expect(resultado, isNotNull);
      expect(resultado, contains('Informe obrigatoriamente'));
    });
  });
}
