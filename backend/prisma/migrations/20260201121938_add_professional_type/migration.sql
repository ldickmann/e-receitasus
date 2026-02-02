/*
  Warnings:

  - You are about to drop the column `crm` on the `User` table. All the data in the column will be lost.

*/
-- CreateEnum
CREATE TYPE "ProfessionalType" AS ENUM ('MEDICO', 'ENFERMEIRO', 'FARMACEUTICO', 'PSICOLOGO', 'NUTRICIONISTA', 'FISIOTERAPEUTA', 'DENTISTA', 'ASSISTENTE_SOCIAL', 'ADMINISTRATIVO', 'OUTROS');

-- AlterTable
ALTER TABLE "User" DROP COLUMN "crm",
ADD COLUMN     "professionalId" TEXT,
ADD COLUMN     "professionalState" TEXT,
ADD COLUMN     "professionalType" "ProfessionalType" NOT NULL DEFAULT 'ADMINISTRATIVO';
