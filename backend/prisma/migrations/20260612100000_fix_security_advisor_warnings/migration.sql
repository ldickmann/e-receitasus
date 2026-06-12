-- ---------------------------------------------------------------------------
-- Correções do Supabase Security Advisor
--
-- 1) function_search_path_mutable (7 funções):
--    Fixa `SET search_path = ''` em todas as funções de trigger que não o
--    definiam. Sem isso, um atacante com permissão de criar objetos poderia
--    injetar tabelas/funções homônimas em outro schema e sequestrar a
--    execução. Todas as referências já são qualificadas (public.*), então o
--    search_path vazio é seguro.
--
-- 2) anon/authenticated_security_definer_function_executable (4 funções):
--    Funções SECURITY DEFINER ficam expostas via PostgREST
--    (/rest/v1/rpc/...) com EXECUTE concedido a PUBLIC por padrão. Revoga o
--    EXECUTE dos papéis anon/authenticated:
--      - block_duplicate_renewal, handle_new_user, rls_auto_enable são
--        funções de trigger/event trigger: o privilégio EXECUTE só é
--        verificado na criação do trigger, então os triggers continuam
--        disparando normalmente (cadastro de usuário incluso).
--      - search_patients_for_prescription mantém GRANT para authenticated
--        (uso intencional pelo app), revogando apenas anon/PUBLIC.
--
-- 3) auth_leaked_password_protection: não é corrigível via SQL — habilitar
--    no Dashboard (Authentication > Settings > Password Strength).
-- ---------------------------------------------------------------------------

-- ===========================================================================
-- 1) SET search_path = '' nas funções de trigger
-- ===========================================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_prescriptions_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_renewal_request_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  NEW."updatedAt" := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.auto_assign_patient_health_unit()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW."healthUnitId" IS NULL
     AND NEW.district IS NOT NULL
     AND NEW."addressCity" IS NOT NULL THEN
    SELECT hu.id INTO NEW."healthUnitId"
    FROM public.health_units hu
    WHERE hu.district = NEW.district
      AND hu.city = NEW."addressCity"
    LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.auto_assign_professional_health_unit()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
BEGIN
  IF NEW."healthUnitId" IS NULL
     AND NEW.district IS NOT NULL
     AND NEW."addressCity" IS NOT NULL THEN
    SELECT hu.id INTO NEW."healthUnitId"
    FROM public.health_units hu
    WHERE hu.district = NEW.district
      AND hu.city = NEW."addressCity"
    LIMIT 1;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.enforce_max_professionals_per_unit()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
  v_max   INTEGER;
  v_count INTEGER;
BEGIN
  IF NEW."healthUnitId" IS NULL THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE'
     AND OLD."healthUnitId" IS NOT DISTINCT FROM NEW."healthUnitId"
     AND OLD."professionalType" = NEW."professionalType" THEN
    RETURN NEW;
  END IF;
  SELECT max_professionals INTO v_max FROM public.health_units WHERE id = NEW."healthUnitId";
  SELECT COUNT(*) INTO v_count FROM public.professionals
   WHERE "healthUnitId" = NEW."healthUnitId" AND id <> NEW.id;
  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Limite de % profissionais por UBS atingido.', v_max;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.block_duplicate_renewal()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
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

-- ===========================================================================
-- 2) Revoga EXECUTE de funções SECURITY DEFINER expostas via PostgREST
-- ===========================================================================

-- Funções de trigger: ninguém deve chamá-las via RPC.
REVOKE EXECUTE ON FUNCTION public.block_duplicate_renewal() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.handle_new_user()         FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.rls_auto_enable()         FROM PUBLIC, anon, authenticated;

-- RPC de busca de pacientes: somente usuários autenticados (já há guard
-- interno exigindo profissional vinculado a uma UBS).
REVOKE EXECUTE ON FUNCTION public.search_patients_for_prescription(TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.search_patients_for_prescription(TEXT) TO authenticated;
