-- =============================================================================
-- Adiciona WITH CHECK explícito às políticas de UPDATE da "RenewalRequest"
--
-- Problema: em políticas FOR UPDATE sem WITH CHECK, o PostgreSQL reaplica a
-- expressão USING sobre a linha NOVA. Como toda transição de triagem muda o
-- status (PENDING_TRIAGE → TRIAGED/REJECTED; TRIAGED → PRESCRIBED), a linha
-- nova nunca satisfaz o USING — todo UPDATE legítimo falha com 42501
-- ("new row violates row-level security policy").
--
-- Solução: USING valida a linha atual (estado de origem + papel do usuário);
-- WITH CHECK valida a linha nova (estados de destino permitidos + integridade
-- de atribuição).
--
-- Transições permitidas (máquina de estados do fluxo de renovação):
--   Enfermeiro: PENDING_TRIAGE → TRIAGED | REJECTED
--   Médico:     TRIAGED        → PRESCRIBED | REJECTED
-- =============================================================================

DROP POLICY IF EXISTS "enfermeiro_atualiza_pendente" ON "RenewalRequest";
DROP POLICY IF EXISTS "medico_atualiza_triado"       ON "RenewalRequest";

-- Enfermeiro: aprova (TRIAGED) ou rejeita (REJECTED) pedidos pendentes.
-- WITH CHECK exige nurseUserId = usuário autenticado — o enfermeiro registra
-- a si próprio como responsável pela triagem (rastreabilidade/auditoria).
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
  )
  WITH CHECK (
    status IN ('TRIAGED', 'REJECTED')
    AND "nurseUserId" = auth.uid()::text
    AND EXISTS (
      SELECT 1 FROM public.professionals p
      WHERE p.id = auth.uid()::text
        AND p."professionalType" = 'ENFERMEIRO'::"ProfessionalType"
    )
  );

-- Médico: prescreve (PRESCRIBED) ou rejeita (REJECTED) pedidos triados
-- atribuídos a ele. WITH CHECK mantém doctorUserId = usuário autenticado —
-- o médico não pode reatribuir o pedido a outro profissional.
CREATE POLICY "medico_atualiza_triado"
  ON "RenewalRequest"
  FOR UPDATE
  USING (
    status = 'TRIAGED'
    AND auth.uid()::text = "doctorUserId"
  )
  WITH CHECK (
    status IN ('PRESCRIBED', 'REJECTED')
    AND auth.uid()::text = "doctorUserId"
  );
