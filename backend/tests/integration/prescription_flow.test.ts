import { jest } from '@jest/globals';
import { RenewalStatus } from '@prisma/client';

import {
  RenewalFlowContract,
  ContractError,
  canTransition,
  renewalTransitions,
  mapPostgrestErrorToHttp,
  sanitizeLogPayload,
  sanitizeLogValue,
  createMockSupabaseClient,
  decodeFakeJwtPayload,
  REDACTED,
  type MockAuthUser,
  type MockSupabaseClient,
  type PostgrestResult,
  type RecordedOperation,
} from './support/baasContract.js';

// =============================================================================
// Teste de integração — Fluxo E2E de renovação de prescrição (Backend BaaS)
//
// Arquitetura: o fluxo assistencial é BaaS (Supabase + RLS) e NÃO possui rotas
// Express (ver `backend/src/app.ts`). Logo, este é um *contract test*
// hermético: codifica como executável as três visões (Paciente, Enfermeiro,
// Médico) e as regras transacionais do schema Prisma
// (`backend/prisma/schema.prisma`), sem banco real nem credenciais de staging.
//
// Cobre, conforme solicitado:
//   1. Fase de Autenticação (JWT por role: PACIENTE, ENFERMEIRO, MEDICO).
//   2. Ciclo de vida do registro (PENDING_TRIAGE → TRIAGED → PRESCRIBED),
//      com inserção correspondente na tabela BaaS `prescriptions`.
//   3. Segurança LGPD / RLS (Paciente A x Paciente B → 403 ou lista vazia).
//   4. Sanitização de logs (try/catch nunca expõe CNS, CPF ou e-mail).
// =============================================================================

// ---- Fixtures: usuários sintéticos das três visões --------------------------

const PACIENTE_A: MockAuthUser = {
  id: 'aaaaaaaa-0000-0000-0000-000000000001',
  email: 'paciente.a@sus.gov.br',
  role: 'authenticated',
  professionalType: 'PACIENTE',
};

const PACIENTE_B: MockAuthUser = {
  id: 'bbbbbbbb-0000-0000-0000-000000000002',
  email: 'paciente.b@sus.gov.br',
  role: 'authenticated',
  professionalType: 'PACIENTE',
};

const ENFERMEIRO: MockAuthUser = {
  id: 'cccccccc-0000-0000-0000-000000000003',
  email: 'enfermeiro@sus.gov.br',
  role: 'authenticated',
  professionalType: 'ENFERMEIRO',
};

const MEDICO: MockAuthUser = {
  id: 'dddddddd-0000-0000-0000-000000000004',
  email: 'medico@sus.gov.br',
  role: 'authenticated',
  professionalType: 'MEDICO',
};

// ---- Helpers de asserção sobre operações registradas ------------------------

/** Retorna a primeira operação que casa table+type, falhando o teste se ausente. */
function expectOperation(
  client: MockSupabaseClient,
  table: string,
  type: RecordedOperation['type'],
): RecordedOperation {
  const op = client.operations.find((o) => o.table === table && o.type === type);
  if (!op) {
    throw new Error(
      `Operação esperada não registrada: ${type.toUpperCase()} ${table}. ` +
        `Operações: ${JSON.stringify(client.operations)}`,
    );
  }
  return op;
}

/** Açúcar para tratar o payload registrado como um mapa tipado. */
function payloadOf(op: RecordedOperation): Record<string, unknown> {
  return (op.payload ?? {}) as Record<string, unknown>;
}

describe('Fluxo E2E de renovação (contract test hermético — BaaS + RLS)', () => {
  // ===========================================================================
  // Guarda de drift: o teste só é confiável se o enum aqui usado for idêntico
  // ao gerado pelo Prisma a partir do schema (fonte da verdade).
  // ===========================================================================
  describe('Guarda de drift do enum RenewalStatus', () => {
    it('expõe exatamente os quatro estados do schema Prisma', () => {
      expect(Object.values(RenewalStatus).sort()).toEqual(
        ['PENDING_TRIAGE', 'PRESCRIBED', 'REJECTED', 'TRIAGED'].sort(),
      );
    });

    it('mapeia transições para todos os estados (sem estado órfão)', () => {
      for (const status of Object.values(RenewalStatus)) {
        expect(renewalTransitions[status]).toBeDefined();
      }
    });

    it('mantém PRESCRIBED e REJECTED como estados terminais', () => {
      expect(renewalTransitions[RenewalStatus.PRESCRIBED]).toHaveLength(0);
      expect(renewalTransitions[RenewalStatus.REJECTED]).toHaveLength(0);
    });
  });

  // ===========================================================================
  // 1. Fase de Autenticação — login e JWT por role
  // ===========================================================================
  describe('1. Autenticação — geração de JWT por role', () => {
    function buildAuthClient(): MockSupabaseClient {
      return createMockSupabaseClient({
        users: {
          [PACIENTE_A.email!]: PACIENTE_A,
          [ENFERMEIRO.email!]: ENFERMEIRO,
          [MEDICO.email!]: MEDICO,
        },
      });
    }

    it.each([
      ['PACIENTE', PACIENTE_A],
      ['ENFERMEIRO', ENFERMEIRO],
      ['MEDICO', MEDICO],
    ] as const)(
      'emite JWT válido com claims corretas para a role %s',
      async (_label, user) => {
        const client = buildAuthClient();

        const { data, error } = await client.auth.signInWithPassword({
          email: user.email!,
          password: 'senha-de-teste',
        });

        expect(error).toBeNull();
        expect(data.session).not.toBeNull();

        const token = data.session!.access_token;
        // JWT deve ter três segmentos (header.payload.signature).
        expect(token.split('.')).toHaveLength(3);

        const claims = decodeFakeJwtPayload(token);
        expect(claims.sub).toBe(user.id);
        expect(claims.aud).toBe('authenticated');
        expect(claims.role).toBe('authenticated');
        expect(claims.professional_type).toBe(user.professionalType);
        // Sessão passa a refletir o usuário autenticado.
        expect(client.auth.currentUser?.id).toBe(user.id);
      },
    );

    it('rejeita credenciais inexistentes sem emitir sessão', async () => {
      const client = buildAuthClient();

      const { data, error } = await client.auth.signInWithPassword({
        email: 'desconhecido@sus.gov.br',
        password: 'x',
      });

      expect(data.session).toBeNull();
      expect(error?.code).toBe('invalid_credentials');
      expect(client.auth.currentUser).toBeNull();
    });
  });

  // ===========================================================================
  // 2. Ciclo de vida do registro — transições de status
  // ===========================================================================
  describe('2. Ciclo de vida — PENDING_TRIAGE → TRIAGED → PRESCRIBED', () => {
    it('a) Paciente cria a solicitação com status PENDING_TRIAGE', async () => {
      const client = createMockSupabaseClient({ currentUser: PACIENTE_A });
      client.queueResult({ data: [{ id: 'renewal-1' }], error: null });
      const contract = new RenewalFlowContract(client);

      await contract.requestRenewal('presc-original-1');

      const op = expectOperation(client, 'RenewalRequest', 'insert');
      const payload = payloadOf(op);
      expect(payload.status).toBe(RenewalStatus.PENDING_TRIAGE);
      expect(payload.prescriptionId).toBe('presc-original-1');
      // Identidade derivada da sessão — nunca forjada pelo cliente.
      expect(payload.patientUserId).toBe(PACIENTE_A.id);
    });

    it('b) Enfermeiro assume o acolhimento: PENDING_TRIAGE → TRIAGED', async () => {
      const client = createMockSupabaseClient({ currentUser: ENFERMEIRO });
      client.queueResult({ data: [{ id: 'renewal-1' }], error: null });
      const contract = new RenewalFlowContract(client);

      await contract.approveTriage('renewal-1', {
        currentStatus: RenewalStatus.PENDING_TRIAGE,
        doctorUserId: MEDICO.id,
        nurseNotes: 'Paciente estável; encaminhado para emissão.',
      });

      const op = expectOperation(client, 'RenewalRequest', 'update');
      const payload = payloadOf(op);
      expect(payload.status).toBe(RenewalStatus.TRIAGED);
      expect(payload.doctorUserId).toBe(MEDICO.id);
      // nurseUserId vem da sessão do enfermeiro.
      expect(payload.nurseUserId).toBe(ENFERMEIRO.id);
      expect(payload.nurseNotes).toContain('encaminhado');
      // Atualização endereçada ao pedido correto.
      expect(op.filters).toContainEqual({ column: 'id', value: 'renewal-1' });
    });

    it('c) Médico defere a demanda: TRIAGED → PRESCRIBED + insere em prescriptions', async () => {
      const client = createMockSupabaseClient({ currentUser: MEDICO });
      // 1º resultado: insert na tabela prescriptions; 2º: update do pedido.
      client.queueResult({ data: [{ id: 'presc-nova-1' }], error: null });
      client.queueResult({ data: [{ id: 'renewal-1' }], error: null });
      const contract = new RenewalFlowContract(client);

      const issuedId = await contract.markAsPrescribed('renewal-1', {
        currentStatus: RenewalStatus.TRIAGED,
        renewedPrescriptionId: 'presc-nova-1',
        prescription: { medicine_name: 'Losartana 50mg', type: 'Branca' },
      });

      expect(issuedId).toBe('presc-nova-1');

      // Registro correspondente na tabela BaaS `prescriptions`.
      const prescOp = expectOperation(client, 'prescriptions', 'insert');
      const prescPayload = payloadOf(prescOp);
      expect(prescPayload.id).toBe('presc-nova-1');
      expect(prescPayload.professional_id).toBe(MEDICO.id);
      expect(prescPayload.medicine_name).toBe('Losartana 50mg');

      // Conclusão do pedido de renovação.
      const renewalOp = expectOperation(client, 'RenewalRequest', 'update');
      const renewalPayload = payloadOf(renewalOp);
      expect(renewalPayload.status).toBe(RenewalStatus.PRESCRIBED);
      expect(renewalPayload.renewedPrescriptionId).toBe('presc-nova-1');
    });

    it('permite a rota alternativa de rejeição: PENDING_TRIAGE → REJECTED', async () => {
      const client = createMockSupabaseClient({ currentUser: ENFERMEIRO });
      client.queueResult({ data: [{ id: 'renewal-9' }], error: null });
      const contract = new RenewalFlowContract(client);

      await contract.rejectTriage('renewal-9', {
        currentStatus: RenewalStatus.PENDING_TRIAGE,
        nurseNotes: 'Receita ainda vigente; renovação desnecessária.',
      });

      const op = expectOperation(client, 'RenewalRequest', 'update');
      const payload = payloadOf(op);
      expect(payload.status).toBe(RenewalStatus.REJECTED);
      expect(payload.nurseUserId).toBe(ENFERMEIRO.id);
      expect(payload.nurseNotes).toContain('vigente');
    });
  });

  // ===========================================================================
  // Regras transacionais — transições inválidas são bloqueadas antes do banco
  // ===========================================================================
  describe('Regras transacionais — transições inválidas', () => {
    it('aceita apenas as transições documentadas no schema', () => {
      // Válidas.
      expect(canTransition(RenewalStatus.PENDING_TRIAGE, RenewalStatus.TRIAGED)).toBe(true);
      expect(canTransition(RenewalStatus.PENDING_TRIAGE, RenewalStatus.REJECTED)).toBe(true);
      expect(canTransition(RenewalStatus.TRIAGED, RenewalStatus.PRESCRIBED)).toBe(true);
      expect(canTransition(RenewalStatus.TRIAGED, RenewalStatus.REJECTED)).toBe(true);
      // Inválidas (pulo de etapa / volta / a partir de terminal).
      expect(canTransition(RenewalStatus.PENDING_TRIAGE, RenewalStatus.PRESCRIBED)).toBe(false);
      expect(canTransition(RenewalStatus.PRESCRIBED, RenewalStatus.TRIAGED)).toBe(false);
      expect(canTransition(RenewalStatus.REJECTED, RenewalStatus.TRIAGED)).toBe(false);
      expect(canTransition(RenewalStatus.PRESCRIBED, RenewalStatus.REJECTED)).toBe(false);
    });

    it('bloqueia médico deferindo pedido ainda em PENDING_TRIAGE (pulo de etapa)', async () => {
      const client = createMockSupabaseClient({ currentUser: MEDICO });
      const contract = new RenewalFlowContract(client);

      await expect(
        contract.markAsPrescribed('renewal-1', {
          currentStatus: RenewalStatus.PENDING_TRIAGE,
          renewedPrescriptionId: 'presc-x',
          prescription: {},
        }),
      ).rejects.toMatchObject({ statusCode: 409 });

      // Nenhuma escrita deve ter ocorrido.
      expect(client.operations).toHaveLength(0);
    });

    it('bloqueia transição a partir de estado terminal (PRESCRIBED)', async () => {
      const client = createMockSupabaseClient({ currentUser: ENFERMEIRO });
      const contract = new RenewalFlowContract(client);

      await expect(
        contract.approveTriage('renewal-1', {
          currentStatus: RenewalStatus.PRESCRIBED,
          doctorUserId: MEDICO.id,
        }),
      ).rejects.toBeInstanceOf(ContractError);
      expect(client.operations).toHaveLength(0);
    });

    it('exige médico designado para aprovar a triagem (422, sem tocar o banco)', async () => {
      const client = createMockSupabaseClient({ currentUser: ENFERMEIRO });
      const contract = new RenewalFlowContract(client);

      await expect(
        contract.approveTriage('renewal-1', {
          currentStatus: RenewalStatus.PENDING_TRIAGE,
          doctorUserId: '   ',
        }),
      ).rejects.toMatchObject({ statusCode: 422 });
      expect(client.operations).toHaveLength(0);
    });

    it('exige motivo para rejeitar (auditoria LGPD — 422, sem tocar o banco)', async () => {
      const client = createMockSupabaseClient({ currentUser: ENFERMEIRO });
      const contract = new RenewalFlowContract(client);

      await expect(
        contract.rejectTriage('renewal-1', {
          currentStatus: RenewalStatus.PENDING_TRIAGE,
          nurseNotes: '  ',
        }),
      ).rejects.toMatchObject({ statusCode: 422 });
      expect(client.operations).toHaveLength(0);
    });
  });

  // ===========================================================================
  // 3. Segurança LGPD / RLS — Paciente A não acessa dados do Paciente B
  // ===========================================================================
  describe('3. RLS / LGPD — isolamento entre pacientes', () => {
    it('retorna lista vazia quando Paciente A tenta ler pedidos do Paciente B', async () => {
      // Sessão = Paciente A.
      const client = createMockSupabaseClient({ currentUser: PACIENTE_A });
      // RLS filtra silenciosamente: a query por patientUserId=B não retorna nada.
      client.setResponder((op): PostgrestResult => {
        const targetsB = op.filters.some(
          (f) => f.column === 'patientUserId' && f.value === PACIENTE_B.id,
        );
        return targetsB ? { data: [], error: null } : { data: [{ id: 'own' }], error: null };
      });
      const contract = new RenewalFlowContract(client);

      const rows = await contract.readRenewalsOfPatient(PACIENTE_B.id);

      expect(rows).toEqual([]);
      const op = expectOperation(client, 'RenewalRequest', 'select');
      expect(op.filters).toContainEqual({ column: 'patientUserId', value: PACIENTE_B.id });
    });

    it('mapeia negação explícita do RLS (42501) para HTTP 403', async () => {
      const client = createMockSupabaseClient({ currentUser: PACIENTE_A });
      client.setResponder(
        (): PostgrestResult => ({
          data: null,
          error: { code: '42501', message: 'new row violates row-level security policy' },
        }),
      );
      const contract = new RenewalFlowContract(client);

      await expect(contract.readRenewalsOfPatient(PACIENTE_B.id)).rejects.toMatchObject({
        statusCode: 403,
      });
    });

    it('nega escrita transversal (Paciente A alterando pedido alheio) com 403', async () => {
      // Mesmo um enfermeiro mal configurado: RLS no UPDATE devolve 42501.
      const client = createMockSupabaseClient({ currentUser: ENFERMEIRO });
      client.setResponder(
        (): PostgrestResult => ({
          data: null,
          error: { code: '42501', message: 'permission denied for table RenewalRequest' },
        }),
      );
      const contract = new RenewalFlowContract(client);

      const mapping = mapPostgrestErrorToHttp('42501');
      expect(mapping.status).toBe(403);

      await expect(
        contract.approveTriage('renewal-alheio', {
          currentStatus: RenewalStatus.PENDING_TRIAGE,
          doctorUserId: MEDICO.id,
        }),
      ).rejects.toMatchObject({ statusCode: 403 });
    });
  });

  // ===========================================================================
  // 4. Sanitização de logs — try/catch nunca expõe PII (CNS, CPF, e-mail)
  // ===========================================================================
  describe('4. Sanitização de logs — sem vazamento de PII', () => {
    it('redige CNS, CPF, e-mail e telefone embutidos em texto livre', () => {
      const dirty =
        'Falha ao gravar paciente cns 123456789012345 cpf 111.222.333-44 ' +
        'email maria.silva@sus.gov.br fone 48991234567';

      const clean = sanitizeLogValue(dirty);

      expect(clean).not.toContain('123456789012345');
      expect(clean).not.toContain('111.222.333-44');
      expect(clean).not.toContain('maria.silva@sus.gov.br');
      expect(clean).not.toContain('48991234567');
      expect(clean).toContain(REDACTED);
    });

    it('redige valores de chaves sensíveis por nome, em profundidade', () => {
      const payload = {
        context: 'requestRenewal',
        patient: {
          cpf: '11122233344',
          cns: '123456789012345',
          email: 'joao@sus.gov.br',
          nome: 'Joao',
        },
        notes: ['contato: outro@sus.gov.br'],
      };

      const clean = sanitizeLogPayload(payload) as Record<string, unknown>;
      const patient = clean.patient as Record<string, unknown>;

      expect(patient.cpf).toBe(REDACTED);
      expect(patient.cns).toBe(REDACTED);
      expect(patient.email).toBe(REDACTED);
      // Campo não sensível preservado.
      expect(patient.nome).toBe('Joao');
      // PII embutida em string dentro de array também é redigida.
      expect(JSON.stringify(clean.notes)).not.toContain('outro@sus.gov.br');
    });

    it('no try/catch do fluxo, loga sanitizado e lança mensagem genérica', async () => {
      const logEntries: unknown[] = [];
      const client = createMockSupabaseClient({ currentUser: PACIENTE_A });
      // Erro do PostgREST cuja mensagem traz PII (cenário realista de vazamento).
      client.setResponder(
        (): PostgrestResult => ({
          data: null,
          error: {
            code: '23503',
            message:
              'insert violates FK; offending email paciente.a@sus.gov.br cns 123456789012345',
          },
        }),
      );
      const contract = new RenewalFlowContract(client, (entry) => logEntries.push(entry));

      await expect(contract.requestRenewal('presc-1')).rejects.toMatchObject({
        statusCode: 404,
      });

      // Houve exatamente um log e ele está sanitizado.
      expect(logEntries).toHaveLength(1);
      const serialized = JSON.stringify(logEntries[0]);
      expect(serialized).not.toContain('paciente.a@sus.gov.br');
      expect(serialized).not.toContain('123456789012345');
      expect(serialized).toContain(REDACTED);
    });

    it('usa logger padrão (console.error) também sanitizado', async () => {
      const errorSpy = jest.spyOn(console, 'error').mockImplementation(() => undefined);
      const client = createMockSupabaseClient({ currentUser: PACIENTE_A });
      client.setResponder(
        (): PostgrestResult => ({
          data: null,
          error: { code: '42501', message: 'denied for cpf 111.222.333-44' },
        }),
      );
      // Sem logger custom → cai no console.error padrão do contrato.
      const contract = new RenewalFlowContract(client);

      await expect(contract.requestRenewal('presc-1')).rejects.toBeInstanceOf(ContractError);

      expect(errorSpy).toHaveBeenCalledTimes(1);
      const logged = JSON.stringify(errorSpy.mock.calls[0]);
      expect(logged).not.toContain('111.222.333-44');
      expect(logged).toContain(REDACTED);

      errorSpy.mockRestore();
    });

    it('a mensagem do erro lançado é humanizada e livre de PII', async () => {
      const client = createMockSupabaseClient({ currentUser: PACIENTE_A });
      client.setResponder(
        (): PostgrestResult => ({
          data: null,
          error: { code: '23505', message: 'duplicate key cns 123456789012345' },
        }),
      );
      const contract = new RenewalFlowContract(client, () => undefined);

      const error = await contract.requestRenewal('presc-1').catch((e: unknown) => e);

      expect(error).toBeInstanceOf(ContractError);
      const message = (error as ContractError).message;
      expect(message).not.toContain('123456789012345');
      expect(message).toBe(mapPostgrestErrorToHttp('23505').message);
    });
  });
});
