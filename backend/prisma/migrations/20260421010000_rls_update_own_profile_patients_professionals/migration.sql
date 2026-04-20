-- Permite paciente atualizar seu proprio registro (campos opcionais
-- preenchidos via tela de perfil ou complemento pos-signUp).
-- Sem essa policy, UPDATEs do PostgREST sao silenciosamente bloqueados
-- pelo RLS (afetam 0 linhas, sem retornar erro) — gerava NULLs em todos
-- os campos opcionais durante o cadastro do paciente.
--
-- IMPORTANTE: usamos DROP POLICY IF EXISTS antes do CREATE para garantir
-- idempotencia. Em deploys anteriores essa migration falhou parcialmente
-- (a policy "patient_update_own" ja existia no banco prod), deixando o
-- estado do Prisma como "failed" (P3018 / SQLSTATE 42710). Tornar o
-- script idempotente evita erro de "policy already exists" em
-- reexecucoes e mantem o comportamento correto em ambientes limpos.
DROP POLICY IF EXISTS "patient_update_own" ON public.patients;
CREATE POLICY "patient_update_own"
  ON public.patients
  FOR UPDATE
  USING ((auth.uid())::text = id)
  WITH CHECK ((auth.uid())::text = id);

-- Mesma simetria para profissionais editarem o proprio perfil.
DROP POLICY IF EXISTS "professional_update_own" ON public.professionals;
CREATE POLICY "professional_update_own"
  ON public.professionals
  FOR UPDATE
  USING ((auth.uid())::text = id)
  WITH CHECK ((auth.uid())::text = id);

-- Garante que profissionais possam ler o proprio registro
-- (idempotente — patients ja tem patient_select_own).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policy
    WHERE polrelid = 'public.professionals'::regclass
      AND polname = 'professional_select_own'
  ) THEN
    EXECUTE $p$
      CREATE POLICY "professional_select_own"
        ON public.professionals
        FOR SELECT
        USING ((auth.uid())::text = id)
    $p$;
  END IF;
END$$;
