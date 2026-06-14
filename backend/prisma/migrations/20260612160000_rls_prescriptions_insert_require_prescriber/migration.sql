-- =============================================================================
-- Exige profissional prescritor no INSERT de "prescriptions" (hardening #2)
--
-- Problema: a policy "prescriptions_insert_doctor" (20260420141300) só exigia
-- auth.uid() = doctor_user_id. Como o endpoint Express de prescrição foi
-- removido (a "validação no Express" citada no comentário original não existe
-- mais), qualquer usuário autenticado — inclusive um paciente — podia inserir
-- uma prescrição apontando a si mesmo como doctor_user_id, forjando um
-- documento médico-legal para qualquer patient_user_id.
--
-- Solução: o INSERT passa a exigir, além de doctor_user_id próprio, que o autor
-- seja um profissional prescritor (MEDICO ou DENTISTA) em public.professionals.
--
-- Limitação conhecida (achado #1, fora do escopo desta migration): não impede
-- um usuário que se auto-cadastrou como MEDICO pelo app (register_screen.dart);
-- esse vetor depende de decisão de produto sobre verificação de profissionais.
-- =============================================================================

-- Recria a policy de INSERT com o guard de papel (DROP idempotente antes).
DROP POLICY IF EXISTS prescriptions_insert_doctor ON public.prescriptions;

CREATE POLICY prescriptions_insert_doctor
  ON public.prescriptions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = doctor_user_id
    AND EXISTS (
      SELECT 1
      FROM public.professionals pr
      WHERE pr.id = auth.uid()::text
        AND pr."professionalType" IN ('MEDICO', 'DENTISTA')
    )
  );