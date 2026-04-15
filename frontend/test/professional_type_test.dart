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
}
