-- =============================================================================
-- Remove a anon key hard-coded do webhook de push e exige segredo (hardening #4)
--
-- Problema: a função notify_renewal_status_change (20260612150000) embutia a
-- anon key e o project-ref em texto no header Authorization. Combinado com a
-- Edge Function, que só validava WEBHOOK_SECRET quando presente, qualquer um com
-- a anon key (pública, embarcada no app) podia forjar chamadas de push.
--
-- Solução: ler do Supabase Vault (1) o anon key — para o verify_jwt da função,
-- caso ativo — e (2) um segredo compartilhado enviado em x-webhook-secret, que a
-- Edge Function passa a exigir (ver hardening #3). Nenhuma credencial em código.
--
-- Pré-requisitos operacionais (NÃO versionados — configurar no projeto Supabase):
--   1. Vault:
--        select vault.create_secret('<ANON_KEY>',      'edge_anon_key');
--        select vault.create_secret('<WEBHOOK_SECRET>', 'edge_webhook_secret');
--   2. Edge Function: supabase secrets set WEBHOOK_SECRET=<igual a edge_webhook_secret>
--
-- Robustez: SELECT ... INTO devolve NULL se o segredo não existir (sem erro) e
-- net.http_post é assíncrono (pg_net) — faltando o segredo, o push apenas não é
-- entregue (Edge Function responde 401), mas o UPDATE da RenewalRequest NUNCA é
-- bloqueado.
-- =============================================================================

-- Substitui apenas o corpo da função; o trigger de 20260612150000 permanece.
CREATE OR REPLACE FUNCTION public.notify_renewal_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_anon   TEXT;
  v_secret TEXT;
BEGIN
  -- Segredos lidos do Vault em tempo de execução (nunca em código/migration).
  SELECT decrypted_secret INTO v_anon
    FROM vault.decrypted_secrets WHERE name = 'edge_anon_key';
  SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets WHERE name = 'edge_webhook_secret';

  PERFORM net.http_post(
    url := 'https://shnahlongybxxilworck.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object(
      'Content-Type',     'application/json',
      'Authorization',    'Bearer ' || COALESCE(v_anon, ''),
      'x-webhook-secret', COALESCE(v_secret, '')
    ),
    body := jsonb_build_object(
      'type',       'UPDATE',
      'table',      TG_TABLE_NAME,
      'schema',     TG_TABLE_SCHEMA,
      'record',     to_jsonb(NEW),
      'old_record', to_jsonb(OLD)
    ),
    timeout_milliseconds := 5000
  );
  RETURN NEW;
END;
$$;
