-- =============================================================================
-- CORREÇÃO: Trigger handle_new_user lê professionalType (camelCase)
-- mas o Flutter envia professional_type (snake_case) via signUp metadata.
--
-- Problema: todos os novos usuários recebiam ADMINISTRATIVO no banco
-- porque o COALESCE nunca encontrava a chave 'professionalType'.
-- Solução: verificar ambas as grafias, camelCase primeiro (legado),
-- snake_case em seguida (padrão atual do Flutter).
-- =============================================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
-- SECURITY DEFINER: executa com privilégios do owner (postgres), permitindo
-- inserir em public.User mesmo que o role chamador seja restricted
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

  -- CORREÇÃO PRINCIPAL: tenta camelCase 'professionalType' (legado)
  -- e snake_case 'professional_type' (padrão atual do Flutter)
  v_prof_type := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'professionalType'), ''),
    NULLIF(TRIM(new.raw_user_meta_data->>'professional_type'), ''),
    'ADMINISTRATIVO'
  );

  -- Valida que o valor é um membro válido do enum antes de inserir
  -- para evitar erro de cast em cadastros com metadados inválidos
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
    "professionalType"
  )
  VALUES (
    new.id::text,
    new.email,
    v_full_name,
    v_first_name,
    v_last_name,
    v_prof_type::"ProfessionalType"
  )
  -- ON CONFLICT garante idempotência: se o registro já existir (ex: upsert
  -- anterior via Express ou retry), não sobrescreve — apenas ignora
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
END;
$$;

-- Recria o trigger com a função corrigida (DROP é idempotente por IF EXISTS)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();
