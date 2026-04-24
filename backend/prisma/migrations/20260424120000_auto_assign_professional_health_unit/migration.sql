-- ============================================================================
-- Migration: Auto-vincular profissionais à UBS (health_unit) por bairro+cidade
-- Motivação: o trigger auto_assign_patient_health_unit existia apenas para
-- public.patients. Sem o equivalente em public.professionals, todo prescritor
-- ficava com healthUnitId NULL e a RPC search_patients_for_prescription
-- retornava 'Acesso negado', quebrando o autocomplete de pacientes na tela de
-- prescrição (PBI 158).
--
-- IMPORTANTE: este arquivo NÃO deve ser reformatado por nenhum SQL formatter
-- (ex.: prettier-plugin-sql, sql-formatter). Formatadores quebram os
-- dollar-quoted strings ($$ ... $$) inserindo espaços ("$ $"), o que invalida
-- o corpo PL/pgSQL no Postgres com erro 42601 ("syntax error at or near '$'").
-- Por isso o corpo da função é mantido em uma única linha lógica.
-- ============================================================================

-- 1) Função PL/pgSQL: replica a estratégia do trigger de pacientes -----------
-- Match por (district, addressCity → health_units.district, city). Só preenche
-- quando healthUnitId ainda for NULL e ambos os campos de match existirem.
-- Não falha em caso de não-match: retorna NEW e o backend lida com o NULL.
CREATE OR REPLACE FUNCTION public.auto_assign_professional_health_unit() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN IF NEW."healthUnitId" IS NULL AND NEW.district IS NOT NULL AND NEW."addressCity" IS NOT NULL THEN SELECT hu.id INTO NEW."healthUnitId" FROM public.health_units hu WHERE hu.district = NEW.district AND hu.city = NEW."addressCity" LIMIT 1; END IF; RETURN NEW; END; $$;

-- 2) Trigger BEFORE INSERT/UPDATE em professionals ---------------------------
-- Disparado quando district ou addressCity são alterados, garantindo
-- preenchimento automático sem depender de lógica no backend/frontend.
DROP TRIGGER IF EXISTS trg_auto_assign_professional_health_unit ON public.professionals;

CREATE TRIGGER trg_auto_assign_professional_health_unit
    BEFORE INSERT OR UPDATE OF district, "addressCity"
    ON public.professionals
    FOR EACH ROW
    EXECUTE FUNCTION public.auto_assign_professional_health_unit();

-- 3) Backfill — aplica match nos profissionais já cadastrados ----------------
-- Atualiza apenas linhas onde temos endereço suficiente e ainda sem UBS.
-- Usa subquery para garantir 1 UBS por profissional (LIMIT 1 dentro do SELECT).
UPDATE public.professionals p
SET "healthUnitId" = sub.unit_id
FROM (
    SELECT
        pr.id AS prof_id,
        (
            SELECT hu.id
            FROM public.health_units hu
            WHERE hu.district = pr.district
              AND hu.city = pr."addressCity"
            LIMIT 1
        ) AS unit_id
    FROM public.professionals pr
    WHERE pr."healthUnitId" IS NULL
      AND pr.district IS NOT NULL
      AND pr."addressCity" IS NOT NULL
) sub
WHERE p.id = sub.prof_id
  AND sub.unit_id IS NOT NULL;
