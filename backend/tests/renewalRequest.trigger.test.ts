// =============================================================================
// Testes de integração — trigger anti-duplicidade `trg_block_duplicate_renewal`
// TASK #252 / PBI #243
//
// Diferente dos demais testes do backend (que mockam o Prisma), este arquivo
// exercita o banco REAL apontado por DATABASE_URL:
//   - CI: container PostgreSQL efêmero montado pelo ci.yml via `prisma db push`.
//   - Dev: banco Supabase configurado em backend/.env.
//
// Setup:
//   1. Se o trigger não existir (container de CI — `prisma db push` não aplica
//      migrations SQL manuais), aplica o SQL da migration versionada
//      20260610090000_add_block_duplicate_renewal_trigger — o mesmo artefato
//      aplicado em produção. Se o trigger JÁ existe (banco real), nada é
//      sobrescrito — preserva a função endurecida (SET search_path = '') da
//      migration fix_security_advisor_warnings.
//   2. Cria um paciente de teste com id/email únicos por execução.
//   3. Cria uma prescrição BaaS por cenário quando a tabela `prescriptions`
//      existe (no banco real a FK RenewalRequest_prescriptionId_fkey exige a
//      row); no CI a tabela/FK não existem e um UUID avulso é suficiente.
//
// Teardown: remove pedidos, prescrições e paciente criados — ids únicos por
// execução garantem que nenhum dado real é tocado e nada vaza entre testes.
// =============================================================================

import { randomUUID } from "node:crypto";

import { prisma } from "../src/utils/prismaClient.js";
import { readMigrationStatements } from "./helpers/sql.js";

/** Sufixo único por execução — impede colisão com dados reais e entre runs. */
const runId = randomUUID();

/** Paciente de teste dono de todos os pedidos de renovação deste arquivo. */
const patientId = `trigger-test-${runId}`;

/** UUIDs de prescrições BaaS criadas — removidas no teardown. */
const createdPrescriptionIds: string[] = [];

/** Verdadeiro quando a tabela BaaS `prescriptions` existe no banco alvo. */
let prescriptionsTableExists = false;

/**
 * Garante que o trigger exista no banco alvo sem jamais sobrescrever uma
 * instalação existente (proteção contra downgrade da função endurecida).
 */
async function ensureTriggerInstalled(): Promise<void> {
  const rows = await prisma.$queryRaw<Array<{ exists: boolean }>>`
    SELECT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = 'trg_block_duplicate_renewal'
    ) AS "exists"`;
  if (rows[0]?.exists === true) return;

  const statements = readMigrationStatements(
    "20260610090000_add_block_duplicate_renewal_trigger"
  );
  for (const statement of statements) {
    await prisma.$executeRawUnsafe(statement);
  }
}

/**
 * Retorna um UUID utilizável em RenewalRequest.prescriptionId, criando a row
 * em `prescriptions` quando a tabela existe (satisfaz a FK do banco real).
 */
async function makePrescriptionId(): Promise<string> {
  const id = randomUUID();
  if (prescriptionsTableExists) {
    await prisma.$executeRaw`
      INSERT INTO public.prescriptions
        (id, doctor_name, doctor_council, doctor_council_state, doctor_address,
         doctor_city, doctor_state, patient_name, medicine_name, dosage,
         quantity, instructions)
      VALUES
        (${id}::uuid, 'Medico Teste Trigger', 'CRM-00000', 'SC', 'Rua Teste, 1',
         'Navegantes', 'SC', 'Paciente Teste Trigger', 'Losartana 50mg',
         '50mg', '30 comprimidos', 'Tomar 1 comprimido ao dia')`;
    createdPrescriptionIds.push(id);
  }
  return id;
}

/** Insere um pedido de renovação do paciente de teste via Prisma Client. */
function createRenewal(
  prescriptionId: string,
  status?: "PENDING_TRIAGE" | "TRIAGED" | "PRESCRIBED" | "REJECTED"
) {
  return prisma.renewalRequest.create({
    data: {
      prescriptionId,
      patientUserId: patientId,
      ...(status ? { status } : {}),
      // nurseNotes obrigatório em rejeição é regra do app; preenchido aqui
      // apenas para manter o dado de teste semanticamente coerente.
      ...(status === "REJECTED" ? { nurseNotes: "Rejeitado em teste." } : {}),
    },
  });
}

beforeAll(async () => {
  await ensureTriggerInstalled();

  const rows = await prisma.$queryRaw<Array<{ exists: boolean }>>`
    SELECT to_regclass('public.prescriptions') IS NOT NULL AS "exists"`;
  prescriptionsTableExists = rows[0]?.exists === true;

  await prisma.patient.create({
    data: {
      id: patientId,
      name: "Paciente Teste Trigger",
      email: `trigger-test-${runId}@teste.local`,
    },
  });
}, 30000);

afterAll(async () => {
  // Ordem importa: pedidos antes das prescrições (FK ON DELETE RESTRICT).
  await prisma.renewalRequest.deleteMany({
    where: { patientUserId: patientId },
  });
  for (const id of createdPrescriptionIds) {
    await prisma.$executeRaw`
      DELETE FROM public.prescriptions WHERE id = ${id}::uuid`;
  }
  await prisma.patient.delete({ where: { id: patientId } });
  await prisma.$disconnect();
}, 30000);

describe("trigger trg_block_duplicate_renewal — anti-duplicidade de renovação", () => {
  it("permite o primeiro INSERT sem solicitação anterior", async () => {
    const prescriptionId = await makePrescriptionId();

    const created = await createRenewal(prescriptionId);

    expect(created.id).toBeTruthy();
    expect(created.status).toBe("PENDING_TRIAGE");
  });

  it("bloqueia INSERT duplicado com PENDING_TRIAGE ativo", async () => {
    const prescriptionId = await makePrescriptionId();
    await createRenewal(prescriptionId); // permanece PENDING_TRIAGE (default)

    await expect(createRenewal(prescriptionId)).rejects.toThrow(
      /DUPLICATE_RENEWAL_REQUEST/
    );
  });

  it("bloqueia INSERT duplicado com TRIAGED ativo", async () => {
    const prescriptionId = await makePrescriptionId();
    await createRenewal(prescriptionId, "TRIAGED");

    await expect(createRenewal(prescriptionId)).rejects.toThrow(
      /DUPLICATE_RENEWAL_REQUEST/
    );
  });

  it("permite novo INSERT após solicitação REJECTED (status terminal)", async () => {
    const prescriptionId = await makePrescriptionId();
    await createRenewal(prescriptionId, "REJECTED");

    const created = await createRenewal(prescriptionId);

    expect(created.status).toBe("PENDING_TRIAGE");
  });

  it("permite novo INSERT após solicitação PRESCRIBED (status terminal)", async () => {
    const prescriptionId = await makePrescriptionId();
    await createRenewal(prescriptionId, "PRESCRIBED");

    const created = await createRenewal(prescriptionId);

    expect(created.status).toBe("PENDING_TRIAGE");
  });

  it("duplicidade é avaliada por prescrição: outra prescrição não é bloqueada", async () => {
    // Garante que o trigger não bloqueia por paciente, e sim pelo par
    // (prescriptionId, patientUserId) — regressão sutil que vale travar.
    const prescriptionA = await makePrescriptionId();
    const prescriptionB = await makePrescriptionId();
    await createRenewal(prescriptionA); // PENDING_TRIAGE ativo na prescrição A

    const created = await createRenewal(prescriptionB);

    expect(created.status).toBe("PENDING_TRIAGE");
  });
});
