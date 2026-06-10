# Modelagem de Dados

Resumo das entidades principais e onde elas são gerenciadas (Prisma vs Supabase BaaS).

## Nota importante

- Tabelas gerenciadas pelo Supabase BaaS (ex.: `prescriptions`) não fazem parte do schema Prisma. Alterações nelas exigem migrations SQL do Supabase e revisão das policies RLS.

## Entidades principais (onde estão modeladas)

### `Patient` (Prisma)

Paciente SUS receptor das prescrições. Campos relevantes: identificação, `cns`, `cpf`, dados de nascimento, endereço, `healthUnitId` e metadados (`createdAt`, `updatedAt`). Modelo definido em `backend/prisma/schema.prisma`.

### `Professional` (Prisma)

Profissional de saúde ou administrativo vinculado a uma UBS. Campos relevantes: `professionalType`, `professionalId` (registro), `professionalState`, `specialty`, `healthUnitId` e metadados.

### `HealthUnit` (Prisma)

Representa a UBS (unidade), mapeada por `district` dentro de uma `city`. Campos: `id`, `name`, `district`, `city`, `state`, `maxProfessionals`.

### `prescriptions` (Supabase PostgREST / BaaS)

Tabela gerenciada pelo Supabase com PostgREST e políticas RLS. Campos principais:

- `id` (UUID)
- `medicine_name`
- `description`
- `type` (enum ANVISA)
- `doctor_name`
- `status` (`PrescriptionStatus`)
- `patient_id` (UUID)
- `doctor_id` (UUID?)
- `issued_at`, `valid_until`, `created_at`, `updated_at`

Alterar esta tabela: crie SQL migrations específicas para o Supabase e atualize as policies RLS conforme apropriado.

### `RenewalRequest` (Prisma)

Pedido de renovação de prescrição — modelado no Prisma e migrado via `prisma migrate`. Campos: `prescriptionId`, `patientUserId`, `doctorUserId`, `nurseUserId`, `status` (`RenewalStatus`), `patientNotes`, `nurseNotes`, `renewedPrescriptionId`.

## Enums

- `ProfessionalType`: `MEDICO`, `DENTISTA`, `ENFERMEIRO`, `FARMACEUTICO`, `PSICOLOGO`, `NUTRICIONISTA`, `FISIOTERAPEUTA`, `ASSISTENTE_SOCIAL`, `ADMINISTRATIVO`, `OUTROS`, `PACIENTE`.
- `RenewalStatus`: `PENDING_TRIAGE`, `TRIAGED`, `PRESCRIBED`, `REJECTED`.
- `PrescriptionStatus`: `ACTIVE`, `EXPIRED`, `CANCELLED`.

---

Ver also: `backend/prisma/schema.prisma` and `docs/wiki/Banco-de-Dados-e-Migrations.md` for migration patterns.
