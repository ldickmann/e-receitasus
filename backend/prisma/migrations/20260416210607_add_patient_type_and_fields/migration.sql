-- Adiciona o tipo PACIENTE ao enum ProfessionalType.
-- Paciente é o usuário SUS que recebe receitas — distinto dos profissionais de saúde.
ALTER TYPE "ProfessionalType" ADD VALUE 'PACIENTE';

-- Adiciona os campos exclusivos do perfil PACIENTE à tabela User.
-- Todos os campos são opcionais (nullable) para manter compatibilidade com
-- os demais tipos de usuários já existentes (médicos, enfermeiros etc.).
ALTER TABLE "User"
ADD COLUMN "addressCity"      TEXT,
ADD COLUMN "addressState"     CHAR(2),
ADD COLUMN "birthCity"        TEXT,
ADD COLUMN "birthState"       CHAR(2),
ADD COLUMN "cns"              TEXT,
ADD COLUMN "complement"       TEXT,
ADD COLUMN "cpf"              TEXT,
ADD COLUMN "district"         TEXT,
ADD COLUMN "education"        TEXT,
ADD COLUMN "ethnicity"        TEXT,
ADD COLUMN "gender"           TEXT,
ADD COLUMN "maritalStatus"    TEXT,
ADD COLUMN "motherParentName" TEXT,
ADD COLUMN "phone"            TEXT,
ADD COLUMN "socialName"       TEXT,
ADD COLUMN "street"           TEXT,
ADD COLUMN "streetNumber"     TEXT,
ADD COLUMN "zipCode"          CHAR(8);

-- Índice único para CPF — garante que dois pacientes não compartilhem o mesmo CPF.
CREATE UNIQUE INDEX "User_cpf_key" ON "User"("cpf");

-- Índice de busca para CPF — otimiza consultas por documento.
CREATE INDEX "User_cpf_idx" ON "User"("cpf");
