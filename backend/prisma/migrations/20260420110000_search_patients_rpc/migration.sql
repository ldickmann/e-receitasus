-- ---------------------------------------------------------------------------
-- RPC: search_patients_for_prescription
--
-- Permite que médicos busquem pacientes pelo nome no formulário de prescrição.
-- SECURITY DEFINER: executa com privilégios do owner (postgres), contornando
-- a RLS da tabela "User" que impede médicos de ler perfis de outros usuários.
-- Segurança compensatória: verifica que o chamador é um profissional de saúde
-- (professionalType != PACIENTE) antes de retornar qualquer dado.
-- Retorna no máximo 10 resultados — princípio de minimização (LGPD art. 6º).
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.search_patients_for_prescription(name_query TEXT)
RETURNS TABLE(
  id        TEXT,
  full_name TEXT,
  cpf       TEXT,
  address   TEXT,
  city      TEXT,
  age_text  TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Bloqueia chamadas de não-profissionais: apenas prescritores autenticados podem
  -- buscar pacientes. Previne que um paciente consulte dados de outros usuários.
  IF NOT EXISTS (
    SELECT 1 FROM "User"
    WHERE id = auth.uid()::text
      AND "professionalType" IN (
        'MEDICO', 'DENTISTA', 'ENFERMEIRO', 'FARMACEUTICO',
        'PSICOLOGO', 'NUTRICIONISTA', 'FISIOTERAPEUTA', 'ASSISTENTE_SOCIAL'
      )
  ) THEN
    RAISE EXCEPTION 'Acesso negado: apenas profissionais de saude podem buscar pacientes.';
  END IF;

  RETURN QUERY
  SELECT
    u.id,
    -- Usa nome social quando disponível (respeita identidade do paciente)
    COALESCE(u."socialName", u.name) AS full_name,
    u.cpf,
    -- Monta endereço resumido a partir dos campos normalizados
    CASE
      WHEN u.street IS NOT NULL THEN
        u.street
        || COALESCE(', ' || u."streetNumber", '')
        || COALESCE(' - ' || u.district, '')
      ELSE NULL
    END AS address,
    u."addressCity" AS city,
    -- Calcula idade aproximada a partir da data de nascimento
    CASE
      WHEN u."birthDate" IS NOT NULL THEN
        EXTRACT(YEAR FROM AGE(u."birthDate"))::TEXT || ' anos'
      ELSE NULL
    END AS age_text
  FROM "User" u
  WHERE u."professionalType" = 'PACIENTE'
    AND (
      u.name        ILIKE '%' || name_query || '%'
      OR u."socialName" ILIKE '%' || name_query || '%'
    )
  ORDER BY u.name
  LIMIT 10;
END;
$$;

-- Restringe a execução apenas a usuários autenticados (role 'authenticated').
-- O papel anon não pode chamar esta função nem indiretamente.
REVOKE EXECUTE ON FUNCTION public.search_patients_for_prescription(TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION public.search_patients_for_prescription(TEXT) TO authenticated;
