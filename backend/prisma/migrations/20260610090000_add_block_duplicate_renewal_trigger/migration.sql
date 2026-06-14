-- ---------------------------------------------------------------------------
-- Trigger: block_duplicate_renewal
--
-- Impede que um paciente abra uma nova solicitação de renovação para a mesma
-- prescrição enquanto já existe uma solicitação ativa (PENDING_TRIAGE ou
-- TRIAGED). Lança a exceção 'DUPLICATE_RENEWAL_REQUEST', tratada no app.
-- SECURITY DEFINER: precisa enxergar solicitações de outros usuários para
-- detectar duplicatas, contornando a RLS de "RenewalRequest".
--
-- NOTA: este arquivo foi reconstituído a partir da definição aplicada no
-- banco remoto (a migration havia sido aplicada sem versionar o SQL).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.block_duplicate_renewal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public."RenewalRequest"
        WHERE "prescriptionId" = NEW."prescriptionId"
          AND "patientUserId"  = NEW."patientUserId"
          AND status IN ('PENDING_TRIAGE', 'TRIAGED')
    ) THEN
        RAISE EXCEPTION 'DUPLICATE_RENEWAL_REQUEST';
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_block_duplicate_renewal ON public."RenewalRequest";
CREATE TRIGGER trg_block_duplicate_renewal
  BEFORE INSERT ON public."RenewalRequest"
  FOR EACH ROW EXECUTE FUNCTION public.block_duplicate_renewal();
