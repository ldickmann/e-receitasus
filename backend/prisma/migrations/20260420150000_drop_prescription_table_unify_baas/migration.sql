-- ---------------------------------------------------------------------------
-- Unifica o domínio de prescrições na tabela BaaS `prescriptions`.
--
-- A antiga tabela "Prescription" (PascalCase, gerenciada pelo Prisma) era
-- código morto: o frontend Flutter sempre usou `prescriptions` via Supabase
-- SDK. Backend Express tinha endpoints REST para "Prescription" mas nenhum
-- cliente real os consumia.
--
-- Verificado em 2026-04-20: "Prescription" tinha 0 linhas. Drop seguro.
--
-- A FK de RenewalRequest.prescriptionId apontava para "Prescription"(id) e
-- precisa ser redirecionada para `prescriptions`(id) (única tabela viva).
-- O tipo da coluna também muda de TEXT para UUID para casar com prescriptions.id.
--
-- A policy `prescriber_select_patient_for_prescription` na tabela "User"
-- também referenciava "Prescription" e foi recriada apontando para
-- `prescriptions` com colunas `doctor_user_id`/`patient_user_id` (UUID).
-- ---------------------------------------------------------------------------

-- 1) Remove policy antiga na tabela User que dependia de "Prescription"
DROP POLICY IF EXISTS prescriber_select_patient_for_prescription ON public."User";

-- 2) Remove FK antiga de RenewalRequest -> "Prescription"
ALTER TABLE public."RenewalRequest"
  DROP CONSTRAINT IF EXISTS "RenewalRequest_prescriptionId_fkey";

-- 3) Drop da tabela legada
DROP TABLE IF EXISTS public."Prescription";

-- 4) Drop do enum legado (apenas referenciado por "Prescription")
DROP TYPE IF EXISTS public."PrescriptionStatus";

-- 5) Converte o tipo de RenewalRequest.prescriptionId de TEXT para UUID
-- para casar com prescriptions.id (UUID). Tabela tem 0 linhas, cast direto seguro.
ALTER TABLE public."RenewalRequest"
  ALTER COLUMN "prescriptionId" TYPE UUID USING "prescriptionId"::uuid;

-- 6) Idem para renewedPrescriptionId (soft ref também aponta para prescriptions)
ALTER TABLE public."RenewalRequest"
  ALTER COLUMN "renewedPrescriptionId" TYPE UUID USING "renewedPrescriptionId"::uuid;

-- 7) Recria a FK apontando para a tabela BaaS `prescriptions`.
-- ON DELETE RESTRICT: impede apagar uma prescrição que tem pedido de renovação.
ALTER TABLE public."RenewalRequest"
  ADD CONSTRAINT "RenewalRequest_prescriptionId_fkey"
  FOREIGN KEY ("prescriptionId")
  REFERENCES public.prescriptions(id)
  ON DELETE RESTRICT;

-- 8) Recria a policy adaptada para a tabela BaaS `prescriptions`.
-- Permite que um médico leia dados básicos de um paciente quando já emitiu
-- pelo menos uma prescrição para ele. Usa as colunas snake_case da nova tabela.
CREATE POLICY prescriber_select_patient_for_prescription
  ON public."User"
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.prescriptions p
      WHERE p.doctor_user_id = auth.uid()
        AND p.patient_user_id::text = "User".id
    )
  );
