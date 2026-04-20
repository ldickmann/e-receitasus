-- =============================================================================
-- RLS (Row Level Security) para RenewalRequest
--
-- ARQUITETURA:
--   Flutter → Supabase PostgREST → RLS valida acesso por linha/usuário.
--   Express → PostgreSQL direto com role `postgres` (superuser) → bypass RLS.
--
-- Convenção de nomes Prisma: tabela PascalCase, colunas camelCase, ambas
-- entre aspas duplas. Cast obrigatório: auth.uid()::text para comparar
-- com User.id (que é text no Prisma, não UUID).
--
-- Pré-requisito: tabela "RenewalRequest" criada pelo Prisma (TASK 1.1 AB#132).
-- =============================================================================

ALTER TABLE "RenewalRequest" ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Policy 1: Paciente lê apenas seus próprios pedidos de renovação
-- Garante isolamento total entre pacientes distintos
-- -----------------------------------------------------------------------------
CREATE POLICY "paciente_ve_proprios_pedidos"
  ON "RenewalRequest"
  FOR SELECT
  USING (auth.uid()::text = "patientUserId");

-- -----------------------------------------------------------------------------
-- Policy 2: Paciente insere pedido somente para si mesmo
-- Impede que um paciente crie pedido em nome de outro
-- -----------------------------------------------------------------------------
CREATE POLICY "paciente_insere_pedido"
  ON "RenewalRequest"
  FOR INSERT
  WITH CHECK (auth.uid()::text = "patientUserId");

-- -----------------------------------------------------------------------------
-- Policy 3: Enfermeiro visualiza todos os pedidos aguardando triagem
-- EXISTS valida que o usuário autenticado tem professionalType = ENFERMEIRO,
-- evitando que pacientes ou médicos acessem a fila de triagem
-- -----------------------------------------------------------------------------
CREATE POLICY "enfermeiro_ve_pendentes"
  ON "RenewalRequest"
  FOR SELECT
  USING (
    status = 'PENDING_TRIAGE'
    AND EXISTS (
      SELECT 1
      FROM "User" u
      WHERE u.id = auth.uid()::text
        AND u."professionalType" = 'ENFERMEIRO'::"ProfessionalType"
    )
  );

-- -----------------------------------------------------------------------------
-- Policy 4: Profissional (enfermeiro ou médico) vê pedidos onde está atribuído
-- Cobre os casos em que nurseUserId ou doctorUserId corresponde ao usuário
-- -----------------------------------------------------------------------------
CREATE POLICY "profissional_ve_atribuidos"
  ON "RenewalRequest"
  FOR SELECT
  USING (
    auth.uid()::text = "nurseUserId"
    OR auth.uid()::text = "doctorUserId"
  );

-- -----------------------------------------------------------------------------
-- Policy 5: Médico lê pedidos triados atribuídos a ele
-- Restrição dupla (status + userId) garante que médico acessa somente
-- o que está explicitamente designado para ele
-- -----------------------------------------------------------------------------
CREATE POLICY "medico_ve_triados"
  ON "RenewalRequest"
  FOR SELECT
  USING (
    status = 'TRIAGED'
    AND auth.uid()::text = "doctorUserId"
  );

-- -----------------------------------------------------------------------------
-- Policy 6: Enfermeiro atualiza somente pedidos ainda pendentes de triagem
-- Impede reprocessamento de pedidos já triados, rejeitados ou prescritos,
-- garantindo imutabilidade dos estados finais via PostgREST
-- -----------------------------------------------------------------------------
CREATE POLICY "enfermeiro_atualiza_pendente"
  ON "RenewalRequest"
  FOR UPDATE
  USING (
    status = 'PENDING_TRIAGE'
    AND EXISTS (
      SELECT 1
      FROM "User" u
      WHERE u.id = auth.uid()::text
        AND u."professionalType" = 'ENFERMEIRO'::"ProfessionalType"
    )
  );

-- -----------------------------------------------------------------------------
-- Policy 7: Médico atualiza somente pedidos triados atribuídos a ele
-- Impede que médico altere pedidos de outro médico ou pedidos ainda na triagem
-- -----------------------------------------------------------------------------
CREATE POLICY "medico_atualiza_triado"
  ON "RenewalRequest"
  FOR UPDATE
  USING (
    status = 'TRIAGED'
    AND auth.uid()::text = "doctorUserId"
  );
-- =============================================================================
-- RLS (Row Level Security) para RenewalRequest
--
-- ARQUITETURA:
--   Flutter → Supabase PostgREST → RLS valida acesso por linha/usuário.
--   Express → PostgreSQL direto com role `postgres` (superuser) → bypass RLS.
--
-- Convenção de nomes Prisma: tabela PascalCase, colunas camelCase, ambas
-- entre aspas duplas. Cast obrigatório: auth.uid()::text para comparar
-- com User.id (que é text no Prisma, não UUID).
--
-- Pré-requisito: tabela "RenewalRequest" criada pelo Prisma (TASK 1.1 AB#132).
-- =============================================================================

ALTER TABLE "RenewalRequest" ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Policy 1: Paciente lê apenas seus próprios pedidos de renovação
-- Garante isolamento total entre pacientes distintos
-- -----------------------------------------------------------------------------
CREATE POLICY "paciente_ve_proprios_pedidos"
  ON "RenewalRequest"
  FOR SELECT
  USING (auth.uid()::text = "patientUserId");

-- -----------------------------------------------------------------------------
-- Policy 2: Paciente insere pedido somente para si mesmo
-- Impede que um paciente crie pedido em nome de outro
-- -----------------------------------------------------------------------------
CREATE POLICY "paciente_insere_pedido"
  ON "RenewalRequest"
  FOR INSERT
  WITH CHECK (auth.uid()::text = "patientUserId");

-- -----------------------------------------------------------------------------
-- Policy 3: Enfermeiro visualiza todos os pedidos aguardando triagem
-- EXISTS valida que o usuário autenticado tem professionalType = ENFERMEIRO,
-- evitando que pacientes ou médicos acessem a fila de triagem
-- -----------------------------------------------------------------------------
CREATE POLICY "enfermeiro_ve_pendentes"
  ON "RenewalRequest"
  FOR SELECT
  USING (
    status = 'PENDING_TRIAGE'
    AND EXISTS (
      SELECT 1
      FROM "User" u
      WHERE u.id = auth.uid()::text
        AND u."professionalType" = 'ENFERMEIRO'::"ProfessionalType"
    )
  );

-- -----------------------------------------------------------------------------
-- Policy 4: Profissional (enfermeiro ou médico) vê pedidos onde está atribuído
-- Cobre os casos em que nurseUserId ou doctorUserId corresponde ao usuário
-- -----------------------------------------------------------------------------
CREATE POLICY "profissional_ve_atribuidos"
  ON "RenewalRequest"
  FOR SELECT
  USING (
    auth.uid()::text = "nurseUserId"
    OR auth.uid()::text = "doctorUserId"
  );

-- -----------------------------------------------------------------------------
-- Policy 5: Médico lê pedidos triados atribuídos a ele
-- Restrição dupla (status + userId) garante que médico acessa somente
-- o que está explicitamente designado para ele
-- -----------------------------------------------------------------------------
CREATE POLICY "medico_ve_triados"
  ON "RenewalRequest"
  FOR SELECT
  USING (
    status = 'TRIAGED'
    AND auth.uid()::text = "doctorUserId"
  );

-- -----------------------------------------------------------------------------
-- Policy 6: Enfermeiro atualiza somente pedidos ainda pendentes de triagem
-- Impede reprocessamento de pedidos já triados, rejeitados ou prescritos,
-- garantindo imutabilidade dos estados finais via PostgREST
-- -----------------------------------------------------------------------------
CREATE POLICY "enfermeiro_atualiza_pendente"
  ON "RenewalRequest"
  FOR UPDATE
  USING (
    status = 'PENDING_TRIAGE'
    AND EXISTS (
      SELECT 1
      FROM "User" u
      WHERE u.id = auth.uid()::text
        AND u."professionalType" = 'ENFERMEIRO'::"ProfessionalType"
    )
  );

-- -----------------------------------------------------------------------------
-- Policy 7: Médico atualiza somente pedidos triados atribuídos a ele
-- Impede que médico altere pedidos de outro médico ou pedidos ainda na triagem
-- -----------------------------------------------------------------------------
CREATE POLICY "medico_atualiza_triado"
  ON "RenewalRequest"
  FOR UPDATE
  USING (
    status = 'TRIAGED'
    AND auth.uid()::text = "doctorUserId"
  );
