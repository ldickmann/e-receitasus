-- =============================================================================
-- Escapa curingas LIKE na RPC search_patients_for_prescription (hardening #8)
--
-- Problema: name_query é parametrizado (não há SQL injection), mas os curingas
-- '%' e '_' enviados pelo cliente eram interpretados pelo ILIKE. Um profissional
-- podia passar '%' e casar todos os pacientes da própria UBS de uma vez. Impacto
-- limitado (escopo de UBS + LIMIT 10), mas neutralizado por completude.
--
-- Solução: escapar \ % _ no termo recebido e usar ILIKE ... ESCAPE '\', tratando
-- esses caracteres como literais. As demais regras (guard de profissional
-- vinculado a UBS, LIMIT 10, GRANT só a authenticated) são preservadas.
-- =============================================================================

-- Recria a função; a única mudança funcional é o escape de curingas (v_q)
-- aplicado ao termo antes do ILIKE.
CREATE OR REPLACE FUNCTION public.search_patients_for_prescription(name_query TEXT)
RETURNS TABLE (
  id        TEXT,
  full_name TEXT,
  cpf       TEXT,
  address   TEXT,
  city      TEXT,
  age_text  TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_caller_unit UUID;
  v_q           TEXT;
BEGIN
  -- Guard: só profissional de saúde vinculado a uma UBS pode buscar pacientes.
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

  -- Escapa curingas para que % e _ sejam literais no ILIKE (ordem importa: \ antes).
  v_q := replace(replace(replace(name_query, '\', '\\'), '%', '\%'), '_', '\_');

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
      pt.name           ILIKE '%' || v_q || '%' ESCAPE '\'
      OR pt."socialName" ILIKE '%' || v_q || '%' ESCAPE '\'
    )
  ORDER BY pt.name
  LIMIT 10;
END;
$$;

-- Reafirma o EXECUTE restrito a authenticated (consistente com 20260612100000).
REVOKE EXECUTE ON FUNCTION public.search_patients_for_prescription(TEXT) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.search_patients_for_prescription(TEXT) TO authenticated;
