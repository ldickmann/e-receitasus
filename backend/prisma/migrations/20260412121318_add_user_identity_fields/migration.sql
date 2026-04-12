BEGIN;

ALTER TABLE "User"
  ADD COLUMN IF NOT EXISTS "firstName" TEXT,
  ADD COLUMN IF NOT EXISTS "lastName" TEXT,
  ADD COLUMN IF NOT EXISTS "birthDate" DATE;

ALTER TABLE "User"
  ALTER COLUMN "updatedAt" SET DEFAULT CURRENT_TIMESTAMP;

UPDATE "User"
SET
  "firstName" = COALESCE(
    NULLIF(TRIM("firstName"), ''),
    NULLIF(SPLIT_PART(TRIM("name"), ' ', 1), ''),
    'Nao informado'
  ),
  "lastName" = COALESCE(
    NULLIF(TRIM("lastName"), ''),
    NULLIF(TRIM(REGEXP_REPLACE(TRIM("name"), '^[^[:space:]]+[[:space:]]*', '')), ''),
    'Nao informado'
  )
WHERE
  "firstName" IS NULL OR TRIM("firstName") = ''
  OR "lastName" IS NULL OR TRIM("lastName") = '';

UPDATE "User"
SET "email" = LOWER(TRIM("email"))
WHERE "email" <> LOWER(TRIM("email"));

COMMIT;