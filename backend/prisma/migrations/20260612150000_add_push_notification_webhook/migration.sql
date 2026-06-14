-- =============================================================================
-- Webhook de push notification para mudanças de status da RenewalRequest
-- (TASK #257 / PBI #244)
--
-- Dispara a Edge Function send-push-notification a cada UPDATE que altera o
-- status de um pedido de renovação. Implementado com pg_net (HTTP assíncrono —
-- não bloqueia a transação do UPDATE) em vez do Database Webhook do Dashboard,
-- para manter a configuração versionada em migration.
--
-- O payload replica o formato padrão dos webhooks Supabase
-- ({type, table, schema, record, old_record}), que a Edge Function já espera.
--
-- Segurança:
--   - O header Authorization usa o anon key (público por design — é o mesmo
--     embarcado no app Flutter); a Edge Function está com verify_jwt ativo.
--   - SECURITY DEFINER restrito: a função só monta o payload da própria linha.
--   - WHEN no trigger evita requests para updates que não mudam status.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE OR REPLACE FUNCTION public.notify_renewal_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM net.http_post(
    url := 'https://shnahlongybxxilworck.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNobmFobG9uZ3lieHhpbHdvcmNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5ODU5MTUsImV4cCI6MjA5MTU2MTkxNX0.aleTKEwx7nJOj7iH6H9Y4pjeEmZTlaYVTlLMDRdS-6w'
    ),
    body := jsonb_build_object(
      'type', 'UPDATE',
      'table', TG_TABLE_NAME,
      'schema', TG_TABLE_SCHEMA,
      'record', to_jsonb(NEW),
      'old_record', to_jsonb(OLD)
    ),
    timeout_milliseconds := 5000
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_renewal_status_change ON "RenewalRequest";

CREATE TRIGGER notify_renewal_status_change
  AFTER UPDATE ON "RenewalRequest"
  FOR EACH ROW
  WHEN (OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.notify_renewal_status_change();
