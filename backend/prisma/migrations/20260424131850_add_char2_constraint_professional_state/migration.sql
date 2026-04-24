-- PBI 157 / TASK 165
-- Restringe `professionalState` a CHAR(2) para garantir consistência com o
-- Dropdown de UF do frontend (TASK 163) e impedir gravação de UFs inválidas
-- (ex: "Santa Catarina"). Valores existentes com 2 caracteres permanecem
-- válidos; valores divergentes são truncados/rejeitados pelo Postgres.

-- AlterTable — nome físico mapeado por @@map("professionals")
ALTER TABLE "professionals" ALTER COLUMN "professionalState" SET DATA TYPE CHAR(2);
