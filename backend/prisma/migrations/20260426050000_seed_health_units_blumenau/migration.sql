-- Migration: ampliar seed de public.health_units para Blumenau/SC.
--
-- Motivação (TASK AB#226 / PBI #197):
-- A trigger `auto_assign_patient_health_unit` faz match exato em (district, city)
-- entre `public.patients` e `public.health_units`. O seed atual só cobre Navegantes/SC,
-- então pacientes legados de outras cidades ficam órfãos de UBS mesmo com endereço
-- completo, o que faz a RPC `search_patients_for_prescription` disparar
-- "Acesso negado" e quebrar o autocomplete de pacientes na tela de prescrição.
--
-- Esta migration:
--   1) Insere UBS reais de Blumenau (lista representativa baseada em dados públicos
--      do CNES — pode ser ampliada em migrations futuras conforme novos municípios).
--   2) Faz backfill em `public.patients` aplicando a mesma regra de match da trigger,
--      cobrindo retroativamente pacientes que se cadastraram antes desta UBS existir.
--
-- Notas operacionais:
--   - Idempotente: ON CONFLICT (district, city) DO NOTHING aproveita o índice único
--     `health_units_district_city_unique` para reexecução segura.
--   - Aplicada via `mcp_supabase_apply_migration`; `prisma migrate dev` NÃO funciona
--     contra Supabase (shadow DB sem schema `auth` => P3006).
--   - Usar nomes físicos snake_case (`health_units`, `patients`); nomes em PascalCase
--     causariam 42P01 relation does not exist.

-- 1) Seed idempotente das UBS de Blumenau/SC.
-- Coluna `state` é NOT NULL (CHAR(2) com UF) — sempre 'SC' nesta migration.
INSERT INTO public.health_units (id, name, district, city, state, max_professionals)
VALUES
  (gen_random_uuid(), 'UBS Centro',           'Centro',           'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Itoupavazinha',    'Itoupavazinha',    'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Itoupava Central', 'Itoupava Central', 'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Itoupava Norte',   'Itoupava Norte',   'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Velha',            'Velha',            'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Velha Central',    'Velha Central',    'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Garcia',           'Garcia',           'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Vorstadt',         'Vorstadt',         'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Fortaleza',        'Fortaleza',        'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Fortaleza Alta',   'Fortaleza Alta',   'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Vila Nova',        'Vila Nova',        'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Escola Agrícola',  'Escola Agrícola',  'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Ponta Aguda',      'Ponta Aguda',      'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Salto do Norte',   'Salto do Norte',   'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Tribess',          'Tribess',          'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Badenfurt',        'Badenfurt',        'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Passo Manso',      'Passo Manso',      'Blumenau', 'SC', 50),
  (gen_random_uuid(), 'UBS Boa Vista',        'Boa Vista',        'Blumenau', 'SC', 50)
ON CONFLICT (district, city) DO NOTHING;

-- 2) Backfill: vincula pacientes órfãos cuja (district, addressCity) agora bate com
-- alguma UBS recém-inserida. Reaproveita a mesma regra de match da trigger
-- `auto_assign_patient_health_unit` para garantir consistência.
UPDATE public.patients p
SET "healthUnitId" = sub.unit_id
FROM (
  SELECT pt.id AS pat_id, hu.id AS unit_id
  FROM public.patients pt
  JOIN public.health_units hu
    ON hu.district = pt.district
   AND hu.city     = pt."addressCity"
  WHERE pt."healthUnitId" IS NULL
) sub
WHERE p.id = sub.pat_id;
