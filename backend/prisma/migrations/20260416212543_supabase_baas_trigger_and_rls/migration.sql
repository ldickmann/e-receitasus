-- =============================================================================
-- BaaS (Backend as a Service) — Trigger de criação automática de perfil
-- e políticas de Row Level Security (RLS)
--
-- ARQUITETURA:
--   Flutter → Supabase Auth (signup/login)
--     └─► trigger cria User automaticamente (sem Express)
--   Flutter → Supabase PostgREST → RLS valida acesso por usuário
--   Express → PostgreSQL direto (role postgres = superuser, bypass RLS)
--     └─► Express é confiável; RLS só protege o acesso via SDK Flutter
-- =============================================================================


-- =============================================================================
-- SEÇÃO 1: TRIGGER — Criação automática de perfil em User após signup
--
-- Quando o Supabase Auth cria um registro em auth.users, este trigger
-- espelha os dados básicos na nossa tabela public.User automaticamente.
-- Isso elimina a necessidade de chamada ao Express para criar o perfil.
-- Os metadados (firstName, lastName, professionalType) são enviados pelo
-- Flutter no campo `data` do signUp e ficam em raw_user_meta_data.
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
  -- Extrai firstName e lastName dos metadados enviados pelo Flutter no signUp
  v_first_name := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'firstName'), ''),
    NULLIF(TRIM(new.raw_user_meta_data->>'first_name'), ''),
    'Nao informado'
  );

  v_last_name := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'lastName'), ''),
    NULLIF(TRIM(new.raw_user_meta_data->>'last_name'), ''),
    'Nao informado'
  );

  -- Nome completo para o campo legado `name`
  v_full_name := v_first_name || ' ' || v_last_name;

  -- Tipo profissional enviado pelo Flutter — fallback para ADMINISTRATIVO
  -- quando não informado (ex: cadastros legados ou OAuth)
  v_prof_type := COALESCE(
    NULLIF(TRIM(new.raw_user_meta_data->>'professionalType'), ''),
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
  -- anterior via Express), não sobrescreve — apenas ignora
  ON CONFLICT (id) DO NOTHING;

  RETURN new;
END;
$$;

-- Remove trigger anterior se existir para garantir idempotência do script
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

-- Dispara APÓS inserção em auth.users — uma vez por registro novo
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();


-- =============================================================================
-- SEÇÃO 2: ROW LEVEL SECURITY (RLS) — Controle de acesso por linha
--
-- RLS só afeta conexões via PostgREST (Supabase SDK no Flutter).
-- O Express usa a role `postgres` (superuser) que bypassa RLS por design.
-- Isso garante que Flutter só lê/altera dados do próprio usuário,
-- enquanto o backend Express confiável pode operar sem restrições.
-- =============================================================================

-- Habilita RLS nas tabelas sensíveis
ALTER TABLE "User" ENABLE ROW LEVEL SECURITY;
ALTER TABLE "Prescription" ENABLE ROW LEVEL SECURITY;


-- -----------------------------------------------------------------------------
-- Políticas em User
-- -----------------------------------------------------------------------------

-- Leitura: usuário lê apenas seu próprio perfil
CREATE POLICY "user_select_own_profile"
  ON "User"
  FOR SELECT
  USING (auth.uid()::text = id);

-- Inserção: usuário só cria seu próprio perfil (segurança extra ao trigger)
CREATE POLICY "user_insert_own_profile"
  ON "User"
  FOR INSERT
  WITH CHECK (auth.uid()::text = id);

-- Atualização: usuário só edita seu próprio perfil
-- Isso permite que o Flutter atualize campos do paciente diretamente,
-- sem precisar passar pelo Express
CREATE POLICY "user_update_own_profile"
  ON "User"
  FOR UPDATE
  USING (auth.uid()::text = id);

-- Leitura cruzada: médico/dentista pode ver dados básicos do paciente
-- somente quando existe uma prescrição vinculando os dois.
-- Isso permite ao Flutter exibir o nome do paciente na prescrição.
CREATE POLICY "prescriber_select_patient_for_prescription"
  ON "User"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM "Prescription" p
      WHERE p."doctorId"  = auth.uid()::text
        AND p."patientId" = "User".id
    )
  );


-- -----------------------------------------------------------------------------
-- Políticas em Prescription
-- -----------------------------------------------------------------------------

-- Paciente lê suas próprias receitas
CREATE POLICY "patient_select_own_prescriptions"
  ON "Prescription"
  FOR SELECT
  USING (auth.uid()::text = "patientId");

-- Médico/dentista lê as receitas que emitiu
CREATE POLICY "prescriber_select_own_prescriptions"
  ON "Prescription"
  FOR SELECT
  USING (auth.uid()::text = "doctorId");

-- Somente o prescritor cria receitas com seu próprio id como doctorId.
-- A validação de canPrescribe (apenas médico/dentista) é feita no Express,
-- onde a regra de negócio complexa fica protegida server-side.
CREATE POLICY "prescriber_insert_prescription"
  ON "Prescription"
  FOR INSERT
  WITH CHECK (auth.uid()::text = "doctorId");

-- Prescritor cancela apenas suas próprias receitas
CREATE POLICY "prescriber_update_own_prescription"
  ON "Prescription"
  FOR UPDATE
  USING (auth.uid()::text = "doctorId");
