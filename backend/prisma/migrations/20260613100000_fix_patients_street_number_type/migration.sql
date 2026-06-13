-- =============================================================================
-- Corrige o tipo de patients."streetNumber" para TEXT (drift de schema)
--
-- Problema: o trigger public.handle_new_user() (dispara AFTER INSERT em
-- auth.users) insere street_number como TEXTO
-- (NULLIF(NEW.raw_user_meta_data->>'street_number','')), mas a coluna
-- patients."streetNumber" estava como NUMERIC no banco vivo. O Postgres nao tem
-- cast implicito de text->numeric em assignment, entao o INSERT abortava com
-- SQLSTATE 42804 e TODO o signup de paciente falhava ("Database error saving
-- new user").
--
-- Drift isolado a patients: professionals."streetNumber" ja era TEXT, o
-- schema.prisma declara String? e a migration 20260421000000 declarava TEXT.
--
-- Solucao: realinhar a coluna para TEXT. Conversao numeric->text e lossless.
-- Numeros de porta com letras/"S/N" (ex.: "120-A", "S/N") passam a ser aceitos.
-- Idempotente: ALTER ... TYPE TEXT e no-op se a coluna ja for text.
-- =============================================================================

ALTER TABLE public.patients
  ALTER COLUMN "streetNumber" TYPE TEXT USING "streetNumber"::TEXT;
