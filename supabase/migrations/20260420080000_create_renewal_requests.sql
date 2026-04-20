-- =====================================================================
-- Migration: criar tabela renewal_requests com triggers
-- Task:      AB#132 (PBI 127 - FASE 1 do MVP de Renovação)
-- Escopo:    enum + tabela + índices + triggers (RLS é TASK 1.2 / AB#133)
-- =====================================================================
--
-- Por quê: tabela dedicada ao ciclo de vida de pedidos de renovação de
--          prescrição (paciente → enfermeiro → médico), separada de
--          Prescription para preservar a receita original e auditar o fluxo.
--
-- Tipos observados no banco (relevantes para FKs):
--   - public."Prescription".id  → text  (Prisma String @id)
--   - public."User".id          → text  (Prisma String @id)
--   - auth.users.id             → uuid  (Supabase Auth)
--
-- Por isso:
--   prescription_id / renewed_prescription_id → TEXT
--   patient_user_id / doctor_user_id / nurse_user_id → UUID (auth.users)
-- =====================================================================

-- Enum espelhando o ciclo de vida da renovação.
-- Estados finitos evitam valores inválidos chegando à camada de dados.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'renewal_status') THEN
        CREATE TYPE renewal_status AS ENUM (
            'PENDING_TRIAGE',
            'TRIAGED',
            'PRESCRIBED',
            'REJECTED'
        );
    END IF;
END$$;

-- Tabela principal do fluxo de renovação de receitas.
-- Cada linha representa um pedido feito pelo paciente sobre uma
-- prescrição existente, percorrendo a esteira até virar uma nova
-- prescrição (renewed_prescription_id) ou ser rejeitada.
CREATE TABLE IF NOT EXISTS public.renewal_requests (
    id                      UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    -- TEXT porque Prescription.id é text (Prisma String @id).
    prescription_id         TEXT        NOT NULL REFERENCES public."Prescription"(id),
    -- UUID porque referencia auth.users.id (Supabase Auth) para RLS via auth.uid().
    patient_user_id         UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    -- Médico designado pelo enfermeiro; opcional até o momento da triagem.
    doctor_user_id          UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
    -- Enfermeiro responsável pela triagem; preenchido após APPROVE/REJECT.
    nurse_user_id           UUID        REFERENCES auth.users(id) ON DELETE SET NULL,
    status                  renewal_status NOT NULL DEFAULT 'PENDING_TRIAGE',
    -- Observações do paciente — limite de 500 chars tratado no app (UX).
    patient_notes           TEXT,
    -- Notas internas de triagem; obrigatórias quando REJECTED (validação no app).
    nurse_notes             TEXT,
    -- TEXT porque renewed_prescription_id referencia Prescription.id (text).
    renewed_prescription_id TEXT,
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices voltados às queries do app — cada perfil filtra primariamente
-- por uma coluna distinta, portanto índices simples são suficientes.
CREATE INDEX IF NOT EXISTS renewal_requests_patient_idx ON public.renewal_requests(patient_user_id);
CREATE INDEX IF NOT EXISTS renewal_requests_status_idx  ON public.renewal_requests(status);
CREATE INDEX IF NOT EXISTS renewal_requests_nurse_idx   ON public.renewal_requests(nurse_user_id);
CREATE INDEX IF NOT EXISTS renewal_requests_doctor_idx  ON public.renewal_requests(doctor_user_id);
CREATE INDEX IF NOT EXISTS renewal_requests_created_idx ON public.renewal_requests(created_at ASC);

-- Função utilitária: mantém updated_at sincronizado sem depender do cliente.
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS renewal_requests_updated_at ON public.renewal_requests;
CREATE TRIGGER renewal_requests_updated_at
    BEFORE UPDATE ON public.renewal_requests
    FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- Defesa em profundidade: impede duplicata de pedido aberto (PENDING_TRIAGE
-- ou TRIAGED) para a mesma prescrição+paciente, mesmo se o app falhar.
CREATE OR REPLACE FUNCTION public.block_duplicate_renewal()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.renewal_requests
        WHERE prescription_id = NEW.prescription_id
          AND patient_user_id = NEW.patient_user_id
          AND status IN ('PENDING_TRIAGE', 'TRIAGED')
    ) THEN
        -- Código padronizado para o app traduzir (sem vazar detalhes internos - LGPD).
        RAISE EXCEPTION 'DUPLICATE_RENEWAL_REQUEST';
    END IF;
    RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_block_duplicate_renewal ON public.renewal_requests;
CREATE TRIGGER trg_block_duplicate_renewal
    BEFORE INSERT ON public.renewal_requests
    FOR EACH ROW EXECUTE FUNCTION public.block_duplicate_renewal();
