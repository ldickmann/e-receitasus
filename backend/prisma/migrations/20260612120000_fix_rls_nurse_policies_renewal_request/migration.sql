-- =============================================================================
-- Corrige políticas RLS do enfermeiro na tabela "RenewalRequest"
--
-- Problema: as políticas "enfermeiro_ve_pendentes" (SELECT) e
-- "enfermeiro_atualiza_pendente" (UPDATE) foram criadas em
-- 20260420095000_rls_renewal_request referenciando FROM "User".
-- A migration 20260421000000_split_user_patients_professionals renomeou
-- "User" para legacy_users e criou public.professionals, mas as políticas
-- nunca foram atualizadas — causando PostgrestException 42501 ao aprovar
-- ou rejeitar triagens.
--
-- Solução: recriar as duas políticas referenciando public.professionals.
-- =============================================================================

DROP POLICY IF EXISTS "enfermeiro_ve_pendentes"      ON "RenewalRequest";
DROP POLICY IF EXISTS "enfermeiro_atualiza_pendente" ON "RenewalRequest";

-- Enfermeiro visualiza todos os pedidos aguardando triagem
CREATE POLICY "enfermeiro_ve_pendentes"
  ON "RenewalRequest"
  FOR SELECT
  USING (
    status = 'PENDING_TRIAGE'
    AND EXISTS (
      SELECT 1 FROM public.professionals p
      WHERE p.id = auth.uid()::text
        AND p."professionalType" = 'ENFERMEIRO'::"ProfessionalType"
    )
  );

-- Enfermeiro atualiza somente pedidos ainda pendentes de triagem
CREATE POLICY "enfermeiro_atualiza_pendente"
  ON "RenewalRequest"
  FOR UPDATE
  USING (
    status = 'PENDING_TRIAGE'
    AND EXISTS (
      SELECT 1 FROM public.professionals p
      WHERE p.id = auth.uid()::text
        AND p."professionalType" = 'ENFERMEIRO'::"ProfessionalType"
    )
  );
