-- Migration: fix_trigger_include_updated_at
-- Aplicada via Supabase MCP (mcp_supabase_apply_migration) em 2026-04-17
--
-- PROBLEMA: handle_new_user não incluía "updatedAt" no INSERT.
-- O campo é NOT NULL sem default no banco (Prisma @updatedAt é gerenciado
-- em runtime pelo ORM, não cria DEFAULT no PostgreSQL).
-- Resultado: qualquer novo signUp via Supabase Auth falharia silenciosamente.
--
-- SOLUÇÃO: adiciona "updatedAt" = NOW() ao INSERT do trigger.

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_first_name  TEXT;
  v_last_name   TEXT;
  v_full_name   TEXT;
  v_prof_type   TEXT;
BEGIN
  -- Extrai firstName — tenta camelCase (legado) antes de snake_case (atual)
  v_first_name := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'firstName'), ''),
    NULLIF(TRIM(new.raw_user_meta_data->>'first_name'), ''),
    'Nao informado'
  );

  -- Extrai lastName — mesma estratégia de fallback
  v_last_name := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'lastName'), ''),
    NULLIF(TRIM(new.raw_user_meta_data->>'last_name'), ''),
    'Nao informado'
  );

  -- Nome completo para o campo legado `name`
  v_full_name := v_first_name || ' ' || v_last_name;

  -- Lê professional_type em snake_case (Flutter atual) com fallback para camelCase (legado)
  v_prof_type := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'professionalType'), ''),
    NULLIF(TRIM(new.raw_user_meta_data->>'professional_type'), ''),
    'ADMINISTRATIVO'
  );

  -- Valida que o valor é membro válido do enum antes do cast
  IF v_prof_type NOT IN (
    'MEDICO', 'ENFERMEIRO', 'FARMACEUTICO', 'PSICOLOGO',
    'NUTRICIONISTA', 'FISIOTERAPEUTA', 'DENTISTA',
    'ASSISTENTE_SOCIAL', 'ADMINISTRATIVO', 'OUTROS', 'PACIENTE'
  ) THEN
    v_prof_type := 'ADMINISTRATIVO';
  END IF;

  INSERT INTO public."User" (
    id,
    email,
    name,
    "firstName",
    "lastName",
    "professionalType",
    "updatedAt"
  )
  VALUES (
    new.id::text,
    new.email,
    v_full_name,
    v_first_name,
    v_last_name,
    v_prof_type::"ProfessionalType",
    NOW()
  )
  -- Idempotência: se o registro já existir (ex: retry ou upsert anterior), ignora
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
END;
$$;

-- Recria o trigger para garantir que aponta para a versão corrigida da função
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
