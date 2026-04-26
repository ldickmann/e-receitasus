-- =============================================================================
-- TASK AB#228 — corrige bug crítico do PBI #227
--
-- Causa-raiz: a tabela "RenewalRequest" foi criada com `id` e `updatedAt` como
-- NOT NULL sem DEFAULT no banco. O Prisma Client gera esses valores em runtime
-- (no Node), mas o Flutter insere via PostgREST direto e NÃO envia esses
-- campos — todo INSERT do paciente falhava com 23502 (null value violates
-- not-null constraint), exibindo "alerta de erro" na UI sem detalhe.
--
-- Correção:
--   1. id → DEFAULT gen_random_uuid()::text (id é text no schema Prisma).
--   2. updatedAt → DEFAULT CURRENT_TIMESTAMP no INSERT, e trigger BEFORE
--      UPDATE para mantê-lo atualizado em qualquer escrita posterior.
--
-- A semântica do Prisma Client (`@default(uuid())` e `@updatedAt`) continua
-- funcionando — o DEFAULT no DB apenas cobre o caso em que a coluna não é
-- enviada pelo cliente, sem entrar em conflito com o valor explícito do Prisma.
-- =============================================================================

-- pgcrypto já está habilitado no projeto (validado em 26/04/2026 via MCP).
-- gen_random_uuid() devolve uuid; cast para text mantém compatibilidade com
-- a coluna `id text` do schema Prisma (sem migrar tipo, evita downtime).
ALTER TABLE "RenewalRequest"
  ALTER COLUMN "id" SET DEFAULT (gen_random_uuid())::text;

-- Default no INSERT — necessário porque o cliente Flutter não envia updatedAt.
ALTER TABLE "RenewalRequest"
  ALTER COLUMN "updatedAt" SET DEFAULT CURRENT_TIMESTAMP;

-- Trigger BEFORE UPDATE: garante que toda transição de estado (triagem,
-- aprovação, prescrição) atualize automaticamente o updatedAt mesmo quando
-- o cliente esquecer de informá-lo. Função é idempotente (CREATE OR REPLACE)
-- e segue o mesmo padrão usado em outras tabelas BaaS do projeto.
CREATE OR REPLACE FUNCTION public.set_renewal_request_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW."updatedAt" := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

-- DROP IF EXISTS torna a migration re-aplicável caso seja necessário re-rodar.
DROP TRIGGER IF EXISTS trg_renewal_request_set_updated_at ON "RenewalRequest";

CREATE TRIGGER trg_renewal_request_set_updated_at
  BEFORE UPDATE ON "RenewalRequest"
  FOR EACH ROW
  EXECUTE FUNCTION public.set_renewal_request_updated_at();
