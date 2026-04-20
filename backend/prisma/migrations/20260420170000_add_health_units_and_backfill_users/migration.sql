-- ===========================================================================
-- UBS (Unidade Básica de Saúde) + backfill de perfis + correção da RPC
--
-- Regras de negócio introduzidas:
-- 1. Cada UBS atende UM bairro de uma cidade (par único {district, city}).
-- 2. Profissionais ficam vinculados a UMA UBS (máx. 3 por UBS).
-- 3. Pacientes também são vinculados a uma UBS — inferida automaticamente
--    pelo bairro (district) e cidade informados no cadastro.
-- 4. O filtro de busca de pacientes para prescrição usa a UBS do prescritor:
--    um médico só enxerga pacientes que compartilham a sua UBS.
-- ===========================================================================

-- 1) Tabela de UBS -----------------------------------------------------------
CREATE TABLE public.health_units (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name               TEXT NOT NULL,
  district           TEXT NOT NULL,
  city               TEXT NOT NULL,
  state              CHAR(2) NOT NULL,
  max_professionals  INTEGER NOT NULL DEFAULT 3 CHECK (max_professionals BETWEEN 1 AND 3),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT health_units_district_city_unique UNIQUE (district, city)
);

CREATE INDEX idx_health_units_district_city ON public.health_units(district, city);

-- 2) FK em User --------------------------------------------------------------
ALTER TABLE public."User"
  ADD COLUMN "healthUnitId" UUID REFERENCES public.health_units(id) ON DELETE SET NULL;

CREATE INDEX idx_user_health_unit_id ON public."User"("healthUnitId");

-- 3) Seed das 14 UBS de Navegantes/SC ---------------------------------------
INSERT INTO public.health_units (name, district, city, state, max_professionals) VALUES
  ('UBS Centro',                   'Centro',                   'Navegantes', 'SC', 3),
  ('UBS Escalvadinhos',            'Escalvadinhos',            'Navegantes', 'SC', 3),
  ('UBS Escalvados',               'Escalvados',               'Navegantes', 'SC', 3),
  ('UBS Gravatá',                  'Gravatá',                  'Navegantes', 'SC', 3),
  ('UBS Hugo de Almeida',          'Hugo de Almeida',          'Navegantes', 'SC', 3),
  ('UBS Machados',                 'Machados',                 'Navegantes', 'SC', 3),
  ('UBS Meia-Praia',               'Meia-Praia',               'Navegantes', 'SC', 3),
  ('UBS Nossa Senhora das Graças', 'Nossa Senhora das Graças', 'Navegantes', 'SC', 3),
  ('UBS Pedreiras',                'Pedreiras',                'Navegantes', 'SC', 3),
  ('UBS Porto Escalvado',          'Porto Escalvado',          'Navegantes', 'SC', 3),
  ('UBS São Domingos',             'São Domingos',             'Navegantes', 'SC', 3),
  ('UBS São Paulo',                'São Paulo',                'Navegantes', 'SC', 3),
  ('UBS São Pedro',                'São Pedro',                'Navegantes', 'SC', 3),
  ('UBS Volta Grande',             'Volta Grande',             'Navegantes', 'SC', 3);

-- 4) Backfill public."User" a partir de auth.users --------------------------
INSERT INTO public."User" (
  id, email, name, "firstName", "lastName",
  "professionalType", "professionalId", "professionalState", specialty,
  "birthDate", "addressCity", "addressState", district, "updatedAt"
)
SELECT
  au.id::text,
  au.email,
  COALESCE(
    NULLIF(TRIM(au.raw_user_meta_data->>'name'), ''),
    TRIM(COALESCE(au.raw_user_meta_data->>'first_name','') || ' ' || COALESCE(au.raw_user_meta_data->>'last_name',''))
  ),
  NULLIF(TRIM(au.raw_user_meta_data->>'first_name'), ''),
  NULLIF(TRIM(au.raw_user_meta_data->>'last_name'), ''),
  COALESCE(NULLIF(au.raw_user_meta_data->>'professional_type', ''), 'ADMINISTRATIVO')::"ProfessionalType",
  NULLIF(au.raw_user_meta_data->>'professional_id', ''),
  NULLIF(au.raw_user_meta_data->>'professional_state', ''),
  NULLIF(au.raw_user_meta_data->>'specialty', ''),
  (au.raw_user_meta_data->>'birth_date')::date,
  'Navegantes',
  'SC',
  NULL,
  NOW()
FROM auth.users au
WHERE NOT EXISTS (SELECT 1 FROM public."User" u WHERE u.id = au.id::text);

-- 5) Atribui bairro e UBS para os usuários seed -----------------------------
UPDATE public."User" u
SET district = seed.district,
    "addressCity" = 'Navegantes',
    "addressState" = 'SC',
    street = COALESCE(u.street, seed.street),
    "healthUnitId" = (SELECT hu.id FROM public.health_units hu WHERE hu.district = seed.district AND hu.city = 'Navegantes')
FROM (VALUES
  ('42809160-1e2c-454f-9e15-6fd2a96c68de', 'Centro',     'Rua Principal'),
  ('b616c5d6-613d-427c-b519-907501657d16', 'Centro',     'Rua Principal'),
  ('ccddee00-2222-2222-2222-000000000002', 'Centro',     'Rua das Flores, 100'),
  ('ccddee00-1111-1111-1111-000000000001', 'Meia-Praia', 'Av. Beira-Mar, 500'),
  ('2ad0b78e-da47-4dea-8d72-08f0c606f730', 'Meia-Praia', 'Rua do Sol, 250'),
  ('365692d4-ff89-4ea4-b082-8be403b57eff', 'Centro',     'Rua Corretor Ernesto Assini, 79'),
  ('c32ffda4-9dc8-4dd7-b83f-03e787e8d128', 'Gravatá',    'Rua da Saúde, 300'),
  ('11111111-1111-1111-1111-111111111111', 'São Pedro',  'Rua Teste, 1')
) AS seed(uid, district, street)
WHERE u.id = seed.uid;

-- 6) Trigger: limite máximo de profissionais por UBS ------------------------
CREATE OR REPLACE FUNCTION public.enforce_max_professionals_per_unit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_max INTEGER; v_count INTEGER;
BEGIN
  IF NEW."healthUnitId" IS NULL OR NEW."professionalType" = 'PACIENTE' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE'
     AND OLD."healthUnitId" IS NOT DISTINCT FROM NEW."healthUnitId"
     AND OLD."professionalType" = NEW."professionalType" THEN RETURN NEW; END IF;
  SELECT max_professionals INTO v_max FROM public.health_units WHERE id = NEW."healthUnitId";
  SELECT COUNT(*) INTO v_count FROM public."User"
   WHERE "healthUnitId" = NEW."healthUnitId" AND "professionalType" <> 'PACIENTE' AND id <> NEW.id;
  IF v_count >= v_max THEN
    RAISE EXCEPTION 'Limite de % profissionais por UBS atingido.', v_max;
  END IF;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_enforce_max_professionals_per_unit
  BEFORE INSERT OR UPDATE OF "healthUnitId", "professionalType" ON public."User"
  FOR EACH ROW EXECUTE FUNCTION public.enforce_max_professionals_per_unit();

-- 7) Trigger: auto-atribui UBS do paciente a partir do bairro ---------------
CREATE OR REPLACE FUNCTION public.auto_assign_patient_health_unit()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW."professionalType" = 'PACIENTE'
     AND NEW."healthUnitId" IS NULL
     AND NEW.district IS NOT NULL
     AND NEW."addressCity" IS NOT NULL THEN
    SELECT hu.id INTO NEW."healthUnitId" FROM public.health_units hu
    WHERE hu.district = NEW.district AND hu.city = NEW."addressCity" LIMIT 1;
  END IF;
  RETURN NEW;
END; $$;

CREATE TRIGGER trg_auto_assign_patient_health_unit
  BEFORE INSERT OR UPDATE OF district, "addressCity", "professionalType" ON public."User"
  FOR EACH ROW EXECUTE FUNCTION public.auto_assign_patient_health_unit();

-- 8) RPC search_patients_for_prescription — corrigida e com filtro por UBS --
DROP FUNCTION IF EXISTS public.search_patients_for_prescription(TEXT);

CREATE OR REPLACE FUNCTION public.search_patients_for_prescription(name_query TEXT)
RETURNS TABLE (
  id TEXT, full_name TEXT, cpf TEXT, address TEXT, city TEXT, age_text TEXT
) LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
DECLARE v_caller_unit UUID;
BEGIN
  SELECT u."healthUnitId" INTO v_caller_unit FROM public."User" u
   WHERE u.id = auth.uid()::text
     AND u."professionalType" IN (
       'MEDICO','DENTISTA','ENFERMEIRO','FARMACEUTICO',
       'PSICOLOGO','NUTRICIONISTA','FISIOTERAPEUTA','ASSISTENTE_SOCIAL'
     );
  IF v_caller_unit IS NULL THEN
    RAISE EXCEPTION 'Acesso negado: apenas profissionais vinculados a uma UBS podem buscar pacientes.';
  END IF;

  RETURN QUERY
  SELECT u.id,
         COALESCE(u."socialName", u.name),
         u.cpf,
         CASE WHEN u.street IS NOT NULL THEN
           u.street || COALESCE(', ' || u."streetNumber",'') || COALESCE(' - ' || u.district,'')
         ELSE NULL END,
         u."addressCity",
         CASE WHEN u."birthDate" IS NOT NULL THEN
           EXTRACT(YEAR FROM AGE(u."birthDate"))::TEXT || ' anos' ELSE NULL END
  FROM public."User" u
  WHERE u."professionalType" = 'PACIENTE'
    AND u."healthUnitId" = v_caller_unit
    AND (u.name ILIKE '%' || name_query || '%' OR u."socialName" ILIKE '%' || name_query || '%')
  ORDER BY u.name LIMIT 10;
END; $$;

-- 9) RLS User: médico vê paciente da mesma UBS ------------------------------
DROP POLICY IF EXISTS prescriber_select_patient_for_prescription ON public."User";

CREATE POLICY prescriber_select_patient_for_prescription ON public."User"
  FOR SELECT TO authenticated
  USING (
    "professionalType" = 'PACIENTE'
    AND "healthUnitId" IS NOT NULL
    AND "healthUnitId" = (
      SELECT caller."healthUnitId" FROM public."User" caller
       WHERE caller.id = auth.uid()::text
         AND caller."professionalType" IN (
           'MEDICO','DENTISTA','ENFERMEIRO','FARMACEUTICO',
           'PSICOLOGO','NUTRICIONISTA','FISIOTERAPEUTA','ASSISTENTE_SOCIAL'
         )
    )
  );

-- 10) RLS health_units: qualquer authenticated pode listar ------------------
ALTER TABLE public.health_units ENABLE ROW LEVEL SECURITY;

CREATE POLICY health_units_select_all_authenticated ON public.health_units
  FOR SELECT TO authenticated USING (true);
