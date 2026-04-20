-- ---------------------------------------------------------------------------
-- RLS policies para tabela prescriptions (BaaS)
--
-- Médicos podem criar prescrições (INSERT) e ver as que emitiram (SELECT).
-- Pacientes podem ver apenas as prescrições destinadas a eles (SELECT).
-- Nenhum papel pode deletar prescrições (imutabilidade de documento médico).
-- UPDATE restrito a status (cancelamento pelo médico prescritor).
-- ---------------------------------------------------------------------------

-- Médico pode inserir prescrição vinculando-se como doctor_user_id
CREATE POLICY prescriptions_insert_doctor
  ON public.prescriptions
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = doctor_user_id
  );

-- Paciente pode ler suas prescrições
CREATE POLICY prescriptions_select_patient
  ON public.prescriptions
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = patient_user_id
  );

-- Médico pode ler prescrições que emitiu
CREATE POLICY prescriptions_select_doctor
  ON public.prescriptions
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = doctor_user_id
  );

-- Médico prescritor pode atualizar (ex: cancelar) suas prescrições
CREATE POLICY prescriptions_update_doctor
  ON public.prescriptions
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = doctor_user_id
  )
  WITH CHECK (
    auth.uid() = doctor_user_id
  );
