-- ============================================================================
-- Migration: Auto-vincular profissionais à UBS (health_unit) por bairro+cidade
-- Motivação: o trigger auto_assign_patient_health_unit existia apenas para
-- public.patients. Sem o equivalente em public.professionals, todo prescritor
-- ficava com healthUnitId NULL e a RPC search_patients_for_prescription
-- retornava 'Acesso negado', quebrando o autocomplete de pacientes na tela de
-- prescrição (PBI 158).
-- ============================================================================
-- 1) Função: replica a estratégia do trigger de pacientes ---------------------
-- Faz match por (district, addressCity → health_units.district, city) e
-- preenche healthUnitId apenas quando ainda estiver nulo. Não falha em caso
-- de não-match — apenas mantém NULL para o backend tratar.
-- Tag nomeada $auto_prof$ usada para sobreviver a formatadores SQL que
-- transformariam $$ em "$ $".
CREATE
OR REPLACE FUNCTION public.auto_assign_professional_health_unit() RETURNS TRIGGER LANGUAGE plpgsql AS $ auto_prof $ BEGIN -- Só atribui se ainda não houver UBS e tivermos os dois campos de match.
IF NEW."healthUnitId" IS NULL
AND NEW.district IS NOT NULL
AND NEW."addressCity" IS NOT NULL THEN
SELECT
  hu.id INTO NEW."healthUnitId"
FROM
  public.health_units hu
WHERE
  hu.district = NEW.district
  AND hu.city = NEW."addressCity"
LIMIT
  1;

END IF;

RETURN NEW;

END;

$ auto_prof $;

-- 2) Trigger BEFORE INSERT/UPDATE em professionals ---------------------------
-- Disparado quando district ou addressCity são alterados, garantindo
-- preenchimento automático sem depender de lógica no backend/frontend.
DROP TRIGGER IF EXISTS trg_auto_assign_professional_health_unit ON public.professionals;

CREATE TRIGGER trg_auto_assign_professional_health_unit BEFORE
INSERT
  OR
UPDATE
  OF district,
  "addressCity" ON public.professionals FOR EACH ROW EXECUTE FUNCTION public.auto_assign_professional_health_unit();

-- 3) Backfill — aplica match nos profissionais já cadastrados ----------------
-- Atualiza apenas linhas onde temos endereço suficiente e ainda sem UBS.
-- Usa subquery para garantir 1 UBS por profissional (LIMIT 1).
UPDATE
  public.professionals p
SET
  "healthUnitId" = sub.unit_id
FROM
  (
    SELECT
      pr.id AS prof_id,
      (
        SELECT
          hu.id
        FROM
          public.health_units hu
        WHERE
          hu.district = pr.district
          AND hu.city = pr."addressCity"
        LIMIT
          1
      ) AS unit_id
    FROM
      public.professionals pr
    WHERE
      pr."healthUnitId" IS NULL
      AND pr.district IS NOT NULL
      AND pr."addressCity" IS NOT NULL
  ) sub
WHERE
  p.id = sub.prof_id
  AND sub.unit_id IS NOT NULL;