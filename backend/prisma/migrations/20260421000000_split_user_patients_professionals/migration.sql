-- ===========================================================================
-- Separação da tabela pública "User" em patients e professionals
--
-- Motivo: a tabela User misturava domínios distintos (paciente SUS vs.
-- profissional de saúde/administrativo), dificultando RLS por perfil,
-- triggers específicos e clareza de modelo. A separação garante:
--   - Isolamento de dados sensíveis de saúde (CPF, CNS) apenas em patients
--     (LGPD — princípio da minimização de dados)
--   - RLS cirúrgica por tipo de ator
--   - Triggers sem ambiguidade de professionalType
--
-- Estratégia de rollback: "User" é renomeada para legacy_users (não removida).
--   Pode ser dropada em migration futura após validação em produção.
--
-- Nomenclatura:
--   public.patients      → usuários com professionalType = 'PACIENTE'
--   public.professionals → todos os demais tipos (MEDICO, ENFERMEIRO, etc.)
-- ===========================================================================

-- ============================================================================
-- PASSO 1 — Criar tabela patients
-- Armazena apenas usuários SUS (receptores de prescrição).
-- Campos sensíveis de saúde (CPF, CNS, etc.) ficam isolados aqui — LGPD.
-- ============================================================================
CREATE TABLE public.patients (
  id                  TEXT        PRIMARY KEY,
  "firstName"         TEXT,
  "lastName"          TEXT,
  -- name = firstName + lastName; mantido para compatibilidade com PostgREST
  name                TEXT        NOT NULL DEFAULT '',
  email               TEXT        NOT NULL UNIQUE,
  "birthDate"         DATE,
  -- ---- Dados de saúde — exclusivos de paciente (LGPD: acesso restrito por RLS) ----
  -- Cartão Nacional de Saúde — 15 dígitos
  cns                 TEXT,
  -- CPF — 11 dígitos sem formatação
  cpf                 TEXT        UNIQUE,
  -- Nome Social (prevalece sobre o civil nas interações clínicas)
  "socialName"        TEXT,
  -- Nome da mãe ou responsável legal — obrigatório no prontuário SUS
  "motherParentName"  TEXT,
  -- Sexo declarado pelo paciente
  gender              TEXT,
  -- Raça/Cor IBGE
  ethnicity           TEXT,
  -- Estado civil
  "maritalStatus"     TEXT,
  -- Celular com DDD — 11 dígitos
  phone               TEXT,
  -- Escolaridade
  education           TEXT,
  -- Município de nascimento
  "birthCity"         TEXT,
  -- UF de nascimento — 2 caracteres
  "birthState"        CHAR(2),
  -- ---- Endereço residencial ----
  "zipCode"           CHAR(8),
  street              TEXT,
  "streetNumber"      TEXT,
  complement          TEXT,
  -- Bairro — usado para auto-vincular a UBS via trigger
  district            TEXT,
  "addressCity"       TEXT,
  "addressState"      CHAR(2),
  -- ---- UBS vinculada (atribuição automática pelo bairro via trigger) ----
  "healthUnitId"      UUID        REFERENCES public.health_units(id) ON DELETE SET NULL,
  "createdAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"         TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_patients_health_unit_id ON public.patients("healthUnitId");
CREATE INDEX idx_patients_cpf            ON public.patients(cpf);
CREATE INDEX idx_patients_created_at     ON public.patients("createdAt");

-- ============================================================================
-- PASSO 2 — Criar tabela professionals
-- Armazena profissionais de saúde e administrativos vinculados às UBS.
-- Nunca conterá registros com professionalType = 'PACIENTE' (regra de negócio
-- garantida pelo roteamento no trigger handle_new_user).
-- ============================================================================
CREATE TABLE public.professionals (
  id                   TEXT        PRIMARY KEY,
  "firstName"          TEXT,
  "lastName"           TEXT,
  name                 TEXT        NOT NULL DEFAULT '',
  email                TEXT        NOT NULL UNIQUE,
  "birthDate"          DATE,
  -- ---- Dados profissionais ----
  -- Nunca PACIENTE nesta tabela — roteamento garantido pelo trigger handle_new_user
  "professionalType"   "ProfessionalType" NOT NULL DEFAULT 'ADMINISTRATIVO'::"ProfessionalType",
  -- Número de registro no conselho (CRM, COREN, CRF, etc.)
  "professionalId"     TEXT,
  -- UF do conselho (ex: SC)
  "professionalState"  TEXT,
  -- Especialidade clínica
  specialty            TEXT,
  -- ---- Endereço (opcional para profissionais) ----
  "zipCode"            CHAR(8),
  street               TEXT,
  "streetNumber"       TEXT,
  complement           TEXT,
  district             TEXT,
  "addressCity"        TEXT,
  "addressState"       CHAR(2),
  -- ---- UBS vinculada (máx. 3 por UBS — controlado por trigger) ----
  "healthUnitId"       UUID        REFERENCES public.health_units(id) ON DELETE SET NULL,
  "createdAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updatedAt"          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_professionals_health_unit_id    ON public.professionals("healthUnitId");
CREATE INDEX idx_professionals_professional_type ON public.professionals("professionalType");
CREATE INDEX idx_professionals_created_at        ON public.professionals("createdAt");

-- ============================================================================
-- PASSO 3 — Migrar dados: pacientes
-- Copia todos os usuários com professionalType = 'PACIENTE' de "User" para patients.
-- ============================================================================
INSERT INTO public.patients (
  id, "firstName", "lastName", name, email, "birthDate",
  cns, cpf, "socialName", "motherParentName",
  gender, ethnicity, "maritalStatus", phone, education,
  "birthCity", "birthState",
  "zipCode", street, "streetNumber", complement, district,
  "addressCity", "addressState",
  "healthUnitId", "createdAt", "updatedAt"
)
SELECT
  id, "firstName", "lastName", name, email, "birthDate",
  cns, cpf, "socialName", "motherParentName",
  gender, ethnicity, "maritalStatus", phone, education,
  "birthCity", "birthState",
  "zipCode", street, "streetNumber", complement, district,
  "addressCity", "addressState",
  "healthUnitId", "createdAt", "updatedAt"
FROM public."User"
WHERE "professionalType" = 'PACIENTE';

-- ============================================================================
-- PASSO 4 — Migrar dados: profissionais
-- Copia todos os usuários não-pacientes de "User" para professionals.
-- ============================================================================
INSERT INTO public.professionals (
  id, "firstName", "lastName", name, email, "birthDate",
  "professionalType", "professionalId", "professionalState", specialty,
  "zipCode", street, "streetNumber", complement, district,
  "addressCity", "addressState",
  "healthUnitId", "createdAt", "updatedAt"
)
SELECT
  id, "firstName", "lastName", name, email, "birthDate",
  "professionalType", "professionalId", "professionalState", specialty,
  "zipCode", street, "streetNumber", complement, district,
  "addressCity", "addressState",
  "healthUnitId", "createdAt", "updatedAt"
FROM public."User"
WHERE "professionalType" <> 'PACIENTE';

-- ============================================================================
-- PASSO 5 — Recriar FKs em RenewalRequest
-- patientUserId → patients(id), doctorUserId/nurseUserId → professionals(id)
-- Feito antes de renomear "User" para garantir integridade referencial.
-- ============================================================================
ALTER TABLE public."RenewalRequest"
  DROP CONSTRAINT IF EXISTS "RenewalRequest_patientUserId_fkey",
  DROP CONSTRAINT IF EXISTS "RenewalRequest_doctorUserId_fkey",
  DROP CONSTRAINT IF EXISTS "RenewalRequest_nurseUserId_fkey";

ALTER TABLE public."RenewalRequest"
  ADD CONSTRAINT "RenewalRequest_patientUserId_fkey"
    FOREIGN KEY ("patientUserId") REFERENCES public.patients(id) ON DELETE CASCADE,
  ADD CONSTRAINT "RenewalRequest_doctorUserId_fkey"
    FOREIGN KEY ("doctorUserId") REFERENCES public.professionals(id) ON DELETE SET NULL,
  ADD CONSTRAINT "RenewalRequest_nurseUserId_fkey"
    FOREIGN KEY ("nurseUserId") REFERENCES public.professionals(id) ON DELETE SET NULL;

-- ============================================================================
-- PASSO 6 — Remover triggers antigos da tabela "User"
-- ============================================================================
DROP TRIGGER IF EXISTS trg_enforce_max_professionals_per_unit ON public."User";
DROP TRIGGER IF EXISTS trg_auto_assign_patient_health_unit    ON public."User";

-- ============================================================================
-- PASSO 7 — Recriar trigger: limite máximo de profissionais por UBS
-- Agora na tabela professionals (sem pacientes, lógica mais simples).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.enforce_max_professionals_per_unit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_max   INTEGER;
  v_count INTEGER;
BEGIN
  -- Sem UBS vinculada: sem limite a verificar
  IF NEW."healthUnitId" IS NULL THEN RETURN NEW; END IF;

  -- UPDATE sem mudança de UBS nem tipo: pular recontagem para performance
  IF TG_OP = 'UPDATE'
     AND OLD."healthUnitId" IS NOT DISTINCT FROM NEW."healthUnitId"
     AND OLD."professionalType" = NEW."professionalType" THEN
    RETURN NEW;
  END IF;

  SELECT max_professionals INTO v_max
  FROM public.health_units
  WHERE id = NEW."healthUnitId";

  -- Conta os outros profissionais já vinculados (exclui o próprio registro em UPDATE)
  SELECT COUNT(*) INTO v_count
  FROM public.professionals
  WHERE "healthUnitId" = NEW."healthUnitId"
    AND id <> NEW.id;

  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Limite de % profissionais por UBS atingido.', v_max;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_enforce_max_professionals_per_unit
  BEFORE INSERT OR UPDATE OF "healthUnitId", "professionalType"
  ON public.professionals
  FOR EACH ROW EXECUTE FUNCTION public.enforce_max_professionals_per_unit();

-- ============================================================================
-- PASSO 8 — Recriar trigger: auto-atribui UBS ao paciente pelo bairro
-- Agora na tabela patients (lógica sem professionalType, sempre executa).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.auto_assign_patient_health_unit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  -- Atribui UBS automaticamente quando bairro e cidade estão presentes
  -- e o paciente ainda não foi vinculado a nenhuma UBS
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

CREATE TRIGGER trg_auto_assign_patient_health_unit
  BEFORE INSERT OR UPDATE OF district, "addressCity"
  ON public.patients
  FOR EACH ROW EXECUTE FUNCTION public.auto_assign_patient_health_unit();

-- ============================================================================
-- PASSO 9 — Recriar função handle_new_user
-- Roteia o novo usuário do Supabase Auth para patients (PACIENTE) ou
-- professionals (todos os outros tipos) com base no metadata do signup.
-- SECURITY DEFINER é necessário para escrever nas tabelas a partir do
-- contexto de auth.users (schema separado).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_type  TEXT;
  v_fname TEXT;
  v_lname TEXT;
  v_name  TEXT;
BEGIN
  v_type  := COALESCE(NULLIF(NEW.raw_user_meta_data->>'professional_type', ''), 'ADMINISTRATIVO');
  v_fname := NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), '');
  v_lname := NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), '');
  v_name  := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    TRIM(COALESCE(v_fname, '') || ' ' || COALESCE(v_lname, ''))
  );

  IF v_type = 'PACIENTE' THEN
    -- Roteamento para tabela de pacientes SUS
    INSERT INTO public.patients (
      id, email, name, "firstName", "lastName",
      cns, cpf, "socialName", "motherParentName", "birthDate",
      phone, gender, ethnicity, "maritalStatus", education,
      "birthCity", "birthState",
      "zipCode", street, "streetNumber", complement,
      district, "addressCity", "addressState",
      "updatedAt"
    ) VALUES (
      NEW.id::TEXT,
      NEW.email,
      v_name,
      v_fname,
      v_lname,
      NULLIF(NEW.raw_user_meta_data->>'cns', ''),
      NULLIF(NEW.raw_user_meta_data->>'cpf', ''),
      NULLIF(NEW.raw_user_meta_data->>'social_name', ''),
      NULLIF(NEW.raw_user_meta_data->>'mother_parent_name', ''),
      (NEW.raw_user_meta_data->>'birth_date')::DATE,
      NULLIF(NEW.raw_user_meta_data->>'phone', ''),
      NULLIF(NEW.raw_user_meta_data->>'gender', ''),
      NULLIF(NEW.raw_user_meta_data->>'ethnicity', ''),
      NULLIF(NEW.raw_user_meta_data->>'marital_status', ''),
      NULLIF(NEW.raw_user_meta_data->>'education', ''),
      NULLIF(NEW.raw_user_meta_data->>'birth_city', ''),
      NULLIF(NEW.raw_user_meta_data->>'birth_state', ''),
      NULLIF(NEW.raw_user_meta_data->>'zip_code', ''),
      NULLIF(NEW.raw_user_meta_data->>'street', ''),
      NULLIF(NEW.raw_user_meta_data->>'street_number', ''),
      NULLIF(NEW.raw_user_meta_data->>'complement', ''),
      NULLIF(NEW.raw_user_meta_data->>'district', ''),
      NULLIF(NEW.raw_user_meta_data->>'address_city', ''),
      NULLIF(NEW.raw_user_meta_data->>'address_state', ''),
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;

  ELSE
    -- Roteamento para tabela de profissionais e administrativos
    INSERT INTO public.professionals (
      id, email, name, "firstName", "lastName",
      "professionalType", "professionalId", "professionalState", specialty,
      "birthDate",
      "zipCode", street, "streetNumber", complement,
      district, "addressCity", "addressState",
      "updatedAt"
    ) VALUES (
      NEW.id::TEXT,
      NEW.email,
      v_name,
      v_fname,
      v_lname,
      v_type::"ProfessionalType",
      NULLIF(NEW.raw_user_meta_data->>'professional_id', ''),
      NULLIF(NEW.raw_user_meta_data->>'professional_state', ''),
      NULLIF(NEW.raw_user_meta_data->>'specialty', ''),
      (NEW.raw_user_meta_data->>'birth_date')::DATE,
      NULLIF(NEW.raw_user_meta_data->>'zip_code', ''),
      NULLIF(NEW.raw_user_meta_data->>'street', ''),
      NULLIF(NEW.raw_user_meta_data->>'street_number', ''),
      NULLIF(NEW.raw_user_meta_data->>'complement', ''),
      NULLIF(NEW.raw_user_meta_data->>'district', ''),
      NULLIF(NEW.raw_user_meta_data->>'address_city', ''),
      NULLIF(NEW.raw_user_meta_data->>'address_state', ''),
      NOW()
    )
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$;

-- Recria o trigger no auth.users para sincronização com signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- PASSO 10 — RLS: tabela patients
-- Paciente vê apenas seu próprio perfil.
-- Profissional de saúde da mesma UBS pode ver pacientes (para prescrição).
-- ============================================================================
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;

-- Paciente autentica e lê apenas o próprio registro
DROP POLICY IF EXISTS patient_select_own ON public.patients;
CREATE POLICY patient_select_own ON public.patients
  FOR SELECT TO authenticated
  USING (auth.uid()::TEXT = id);

-- Profissional da mesma UBS pode ver os pacientes vinculados (autocomplete de prescrição)
DROP POLICY IF EXISTS prescriber_select_patient ON public.patients;
CREATE POLICY prescriber_select_patient ON public.patients
  FOR SELECT TO authenticated
  USING (
    "healthUnitId" IS NOT NULL
    AND "healthUnitId" = (
      SELECT p."healthUnitId"
      FROM public.professionals p
      WHERE p.id = auth.uid()::TEXT
        AND p."professionalType" IN (
          'MEDICO', 'DENTISTA', 'ENFERMEIRO', 'FARMACEUTICO',
          'PSICOLOGO', 'NUTRICIONISTA', 'FISIOTERAPEUTA', 'ASSISTENTE_SOCIAL'
        )
      LIMIT 1
    )
  );

-- ============================================================================
-- PASSO 11 — RLS: tabela professionals
-- Profissional vê apenas seu próprio perfil.
-- Qualquer autenticado pode listar médicos (necessário para dropdown de triagem).
-- ============================================================================
ALTER TABLE public.professionals ENABLE ROW LEVEL SECURITY;

-- Profissional autentica e lê apenas o próprio registro
DROP POLICY IF EXISTS professional_select_own ON public.professionals;
CREATE POLICY professional_select_own ON public.professionals
  FOR SELECT TO authenticated
  USING (auth.uid()::TEXT = id);

-- Qualquer usuário autenticado pode listar médicos para o dropdown de triagem
-- (minimização: apenas MEDICO, sem dados sensíveis — controlado pelo select no service)
DROP POLICY IF EXISTS professional_select_doctors ON public.professionals;
CREATE POLICY professional_select_doctors ON public.professionals
  FOR SELECT TO authenticated
  USING ("professionalType" = 'MEDICO');

-- ============================================================================
-- PASSO 12 — Recriar RPC search_patients_for_prescription
-- Agora consulta public.patients em vez de public."User".
-- Filtro de UBS garante que um profissional só vê pacientes da sua UBS.
-- ============================================================================
DROP FUNCTION IF EXISTS public.search_patients_for_prescription(TEXT);

CREATE OR REPLACE FUNCTION public.search_patients_for_prescription(name_query TEXT)
RETURNS TABLE (
  id       TEXT,
  full_name TEXT,
  cpf      TEXT,
  address  TEXT,
  city     TEXT,
  age_text TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_caller_unit UUID;
BEGIN
  -- Verifica que o chamador é profissional de saúde vinculado a uma UBS.
  -- Sem UBS, a busca de pacientes não faz sentido — acesso negado.
  SELECT p."healthUnitId" INTO v_caller_unit
  FROM public.professionals p
  WHERE p.id = auth.uid()::TEXT
    AND p."professionalType" IN (
      'MEDICO', 'DENTISTA', 'ENFERMEIRO', 'FARMACEUTICO',
      'PSICOLOGO', 'NUTRICIONISTA', 'FISIOTERAPEUTA', 'ASSISTENTE_SOCIAL'
    );

  IF v_caller_unit IS NULL THEN
    RAISE EXCEPTION
      'Acesso negado: apenas profissionais vinculados a uma UBS podem buscar pacientes.';
  END IF;

  RETURN QUERY
  SELECT
    pt.id,
    COALESCE(pt."socialName", pt.name),
    pt.cpf,
    CASE WHEN pt.street IS NOT NULL THEN
      pt.street
        || COALESCE(', ' || pt."streetNumber", '')
        || COALESCE(' - ' || pt.district, '')
    ELSE NULL END,
    pt."addressCity",
    CASE WHEN pt."birthDate" IS NOT NULL THEN
      EXTRACT(YEAR FROM AGE(pt."birthDate"))::TEXT || ' anos'
    ELSE NULL END
  FROM public.patients pt
  WHERE pt."healthUnitId" = v_caller_unit
    AND (
      pt.name        ILIKE '%' || name_query || '%'
      OR pt."socialName" ILIKE '%' || name_query || '%'
    )
  ORDER BY pt.name
  LIMIT 10;
END;
$$;

-- ============================================================================
-- PASSO 13 — Remover políticas RLS antigas da tabela "User" antes de renomear
-- As políticas serão recriadas nas novas tabelas (passos 10 e 11).
-- ============================================================================
DROP POLICY IF EXISTS user_select_own_profile                    ON public."User";
DROP POLICY IF EXISTS prescriber_select_patient_for_prescription ON public."User";

-- ============================================================================
-- PASSO 14 — Renomear "User" → legacy_users
-- Mantida para rollback seguro. Pode ser removida em migration futura
-- após validação completa em produção.
-- ============================================================================
ALTER TABLE public."User" RENAME TO legacy_users;
