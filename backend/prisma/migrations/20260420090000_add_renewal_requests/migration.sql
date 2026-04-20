-- CreateEnum
CREATE TYPE "RenewalStatus" AS ENUM ('PENDING_TRIAGE', 'TRIAGED', 'PRESCRIBED', 'REJECTED');

-- CreateTable
CREATE TABLE "RenewalRequest" (
    "id" TEXT NOT NULL,
    "prescriptionId" TEXT NOT NULL,
    "patientUserId" TEXT NOT NULL,
    "doctorUserId" TEXT,
    "nurseUserId" TEXT,
    "status" "RenewalStatus" NOT NULL DEFAULT 'PENDING_TRIAGE',
    "patientNotes" TEXT,
    "nurseNotes" TEXT,
    "renewedPrescriptionId" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "RenewalRequest_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "RenewalRequest_patientUserId_idx" ON "RenewalRequest"("patientUserId");

-- CreateIndex
CREATE INDEX "RenewalRequest_status_idx" ON "RenewalRequest"("status");

-- CreateIndex
CREATE INDEX "RenewalRequest_nurseUserId_idx" ON "RenewalRequest"("nurseUserId");

-- CreateIndex
CREATE INDEX "RenewalRequest_doctorUserId_idx" ON "RenewalRequest"("doctorUserId");

-- CreateIndex
CREATE INDEX "RenewalRequest_createdAt_idx" ON "RenewalRequest"("createdAt");

-- AddForeignKey
ALTER TABLE "RenewalRequest" ADD CONSTRAINT "RenewalRequest_prescriptionId_fkey" FOREIGN KEY ("prescriptionId") REFERENCES "Prescription"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RenewalRequest" ADD CONSTRAINT "RenewalRequest_patientUserId_fkey" FOREIGN KEY ("patientUserId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RenewalRequest" ADD CONSTRAINT "RenewalRequest_doctorUserId_fkey" FOREIGN KEY ("doctorUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "RenewalRequest" ADD CONSTRAINT "RenewalRequest_nurseUserId_fkey" FOREIGN KEY ("nurseUserId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
