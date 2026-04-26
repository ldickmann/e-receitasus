# Modelagem de Dados

O banco separa pacientes SUS e profissionais de saúde em tabelas distintas. A tabela `prescriptions` é tratada como BaaS via SQL/PostgREST e não é modelada no Prisma (`README.md`, linhas 292–295).

## Entidades principais

### Patient

Paciente SUS receptor das prescrições. Contém identificação, CPF, CNS, dados de nascimento, endereço, vínculo com UBS e metadados (`README.md`, linhas 296–307).

### Professional

Profissional de saúde ou administrativo vinculado a uma UBS. Contém identificação, tipo profissional, registro profissional, especialidade, endereço, vínculo com UBS e metadados (`README.md`, linhas 309–319).

### HealthUnit

Unidade Básica de Saúde que atende um bairro. Campos: `id`, `name`, `district`, `city`, `state`, `maxProfessionals` (`README.md`, linhas 321–332).

### prescriptions

Tabela gerenciada diretamente pelo Supabase/PostgREST com RLS. Campos principais: `medicine_name`, `description`, `type`, `doctor_name`, `status`, `patient_id`, `doctor_id`, `issued_at`, `valid_until` (`README.md`, linhas 334–351).

### RenewalRequest

Pedido de renovação de receita. Percorre `PENDING_TRIAGE`, `TRIAGED`, `PRESCRIBED` ou `REJECTED`. Campos principais: `prescriptionId`, `patientUserId`, `doctorUserId`, `nurseUserId`, `status`, notas e `renewedPrescriptionId` (`README.md`, linhas 353–369).

## Enums

- `ProfessionalType`: inclui `MEDICO`, `DENTISTA`, `ENFERMEIRO`, outros perfis e `PACIENTE` (`README.md`, linhas 371–377).
- `RenewalStatus`: `PENDING_TRIAGE`, `TRIAGED`, `PRESCRIBED`, `REJECTED` (`README.md`, linhas 379–386).
- `PrescriptionStatus`: `ACTIVE`, `EXPIRED`, `CANCELLED` (`README.md`, linhas 388–394).
