-- =============================================================================
-- Adiciona tabelas à publication supabase_realtime
--
-- Problema: a publication estava vazia — nenhum evento postgres_changes era
-- emitido. Os streams do app (fila de triagem do enfermeiro, acompanhamento
-- do paciente, pedidos atribuídos ao médico, prescrições via .stream())
-- faziam o fetch inicial mas nunca recebiam atualizações: após aprovar uma
-- triagem, o card permanecia na fila até recarregar o app.
--
-- Consumidores no Flutter:
--   "RenewalRequest" → onPostgresChanges em streamMyRenewals,
--                      streamPendingTriage e streamAssignedToDoctor
--   prescriptions    → .stream(primaryKey) no home do paciente e do médico
--
-- A autorização dos eventos respeita RLS: cada usuário só recebe eventos de
-- linhas que pode ler via SELECT (ex.: profissional_ve_atribuidos).
-- =============================================================================

-- DO blocks tornam a migration idempotente — ALTER PUBLICATION ADD TABLE
-- falha se a tabela já estiver na publication (re-execução em outro ambiente).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'RenewalRequest'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public."RenewalRequest";
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'prescriptions'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.prescriptions;
  END IF;
END $$;
