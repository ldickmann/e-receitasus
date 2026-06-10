/**
 * Suporte de contrato BaaS para os testes de integração do fluxo de renovação.
 *
 * Por que este módulo existe?
 * --------------------------------------------------------------------------
 * A arquitetura do E-ReceitaSUS é BaaS: toda a persistência e o controle de
 * acesso (RLS) do fluxo de renovação vivem no Supabase/Postgres, acessados
 * diretamente pelo app Flutter — NÃO há rotas Express para esse fluxo
 * (ver `backend/src/app.ts`). Portanto, o teste de integração do backend é,
 * por decisão de projeto, um **contract test hermético**: ele codifica como
 * executável as regras de negócio documentadas no schema Prisma
 * (`backend/prisma/schema.prisma`) e os requisitos de RLS/LGPD, sem depender
 * de um banco real nem de credenciais de staging.
 *
 * Este arquivo concentra os artefatos de teste reutilizáveis:
 *   1. Máquina de transição de status ({@link renewalTransitions}/{@link canTransition}).
 *   2. Mapeamento de erros do PostgREST para HTTP ({@link mapPostgrestErrorToHttp}).
 *   3. Sanitização de logs contra PII ({@link sanitizeLogPayload}/{@link sanitizeLogValue}).
 *   4. Cliente Supabase falso e encadeável ({@link createMockSupabaseClient}).
 *   5. Geração de sessão/JWT sintéticos ({@link buildFakeSession}).
 *   6. Orquestrador do fluxo sob teste ({@link RenewalFlowContract}).
 *
 * Não termina em `.test.ts`, então o Jest (testMatch `**\/tests\/**\/*.test.ts`)
 * não o executa como suíte — é apenas suporte.
 */

import { RenewalStatus } from '@prisma/client';

// =============================================================================
// 1. Máquina de transição de status (espelha o schema Prisma)
// =============================================================================

/**
 * Transições válidas do ciclo de vida de um `RenewalRequest`.
 *
 * Fonte da verdade: doc do model `RenewalRequest` no schema Prisma —
 * "PENDING_TRIAGE → TRIAGED → PRESCRIBED (ou REJECTED)". Estados PRESCRIBED e
 * REJECTED são terminais (nenhuma transição de saída).
 */
export const renewalTransitions: Readonly<
  Record<RenewalStatus, readonly RenewalStatus[]>
> = {
  [RenewalStatus.PENDING_TRIAGE]: [RenewalStatus.TRIAGED, RenewalStatus.REJECTED],
  [RenewalStatus.TRIAGED]: [RenewalStatus.PRESCRIBED, RenewalStatus.REJECTED],
  [RenewalStatus.PRESCRIBED]: [],
  [RenewalStatus.REJECTED]: [],
};

/**
 * Indica se a transição `from → to` é permitida pela máquina de estados.
 *
 * @param from Estado atual do pedido.
 * @param to Estado de destino pretendido.
 * @returns `true` somente quando a transição consta em {@link renewalTransitions}.
 */
export function canTransition(from: RenewalStatus, to: RenewalStatus): boolean {
  return renewalTransitions[from]?.includes(to) ?? false;
}

// =============================================================================
// 2. Mapeamento de erros PostgREST → HTTP (espelha o contrato do frontend)
// =============================================================================

/**
 * Erro mínimo no formato do `PostgrestException` do supabase-js.
 * Mantemos apenas os campos que o backend/contract precisa inspecionar.
 */
export interface PostgrestLikeError {
  code: string;
  message: string;
  details?: string | null;
  hint?: string | null;
}

/** Resultado padrão de uma operação PostgREST (`{ data, error }`). */
export interface PostgrestResult<T = unknown> {
  data: T | null;
  error: PostgrestLikeError | null;
}

/** Resposta humanizada e segura para a borda HTTP. */
export interface HttpErrorMapping {
  /** Código HTTP que a borda deve devolver. */
  status: number;
  /** Mensagem em PT-BR, livre de PII e de detalhes internos do Postgres. */
  message: string;
}

/**
 * Traduz um código SQLSTATE do PostgREST para `{ status, message }`.
 *
 * Espelha intencionalmente `_mapPostgrestErrorToUserMessage` do
 * `frontend/lib/services/renewal_service.dart`, garantindo paridade de
 * contrato entre as duas pontas. NUNCA repassa a mensagem crua do Postgres
 * (que pode conter nomes de tabela/coluna/constraint — OWASP A05/A09 e LGPD).
 *
 * @param code Código SQLSTATE (ex.: `42501`, `23505`).
 * @returns Mapeamento HTTP seguro para exposição ao cliente.
 */
export function mapPostgrestErrorToHttp(code: string | undefined): HttpErrorMapping {
  switch (code) {
    // RLS negou a operação (cross-patient, sessão expirada, identidade forjada).
    case '42501':
      return {
        status: 403,
        message:
          'Você não tem permissão para acessar este recurso. Faça login novamente e tente de novo.',
      };
    // Unique violation — já existe pedido ativo para a prescrição.
    case '23505':
      return {
        status: 409,
        message: 'Já existe um pedido de renovação ativo para esta prescrição.',
      };
    // FK violation — prescrição referenciada não existe (ou foi removida).
    case '23503':
      return {
        status: 404,
        message: 'Receita não encontrada. Atualize a tela e tente novamente.',
      };
    // NOT NULL violation — coluna obrigatória ausente (guardrail histórico AB#228).
    case '23502':
      return {
        status: 422,
        message:
          'Não foi possível processar o pedido de renovação. Avise o suporte se persistir.',
      };
    // Tabela inexistente — erro de configuração de ambiente, não do usuário.
    case '42P01':
      return {
        status: 500,
        message: 'Erro de configuração do sistema. Avise o suporte.',
      };
    // Exceção customizada de trigger PL/pgSQL — mensagem já humanizada no banco,
    // mas como não controlamos seu conteúdo aqui, devolvemos texto genérico.
    case 'P0001':
      return {
        status: 422,
        message: 'Não foi possível concluir a operação. Verifique os dados e tente novamente.',
      };
    default:
      return {
        status: 500,
        message: 'Não foi possível concluir a operação. Tente novamente.',
      };
  }
}

// =============================================================================
// 3. Sanitização de logs contra PII (LGPD art. 6º VII / OWASP A09)
// =============================================================================

/** Marcador usado para substituir qualquer dado pessoal identificável. */
export const REDACTED = '[REDACTED]';

/**
 * Chaves cujo VALOR é sempre PII e deve ser redigido independentemente do
 * conteúdo. Espelha os campos sensíveis isolados no model `Patient`.
 */
const SENSITIVE_KEYS: ReadonlySet<string> = new Set([
  'cns',
  'cpf',
  'email',
  'phone',
  'socialName',
  'motherParentName',
  'birthDate',
  'password',
  'access_token',
  'refresh_token',
]);

/**
 * Padrões de PII detectados no CONTEÚDO de strings, mesmo quando embutidos em
 * mensagens livres. A ordem importa: padrões mais longos/específicos primeiro
 * para não serem parcialmente consumidos por padrões mais curtos.
 */
const PII_PATTERNS: ReadonlyArray<RegExp> = [
  // E-mail.
  /[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}/gi,
  // CNS — 15 dígitos (com ou sem espaços a cada 3).
  /\b\d{3}\s?\d{4}\s?\d{4}\s?\d{4}\b/g,
  /\b\d{15}\b/g,
  // CPF formatado (000.000.000-00).
  /\b\d{3}\.\d{3}\.\d{3}-\d{2}\b/g,
  // CPF/telefone — 11 dígitos crus (após CNS para não quebrar o de 15).
  /\b\d{11}\b/g,
];

/**
 * Redige PII embutida em uma string livre, aplicando todos os {@link PII_PATTERNS}.
 *
 * @param value Valor arbitrário; objetos/arrays são serializados antes.
 * @returns String segura para log, com PII substituída por {@link REDACTED}.
 */
export function sanitizeLogValue(value: unknown): string {
  const raw = typeof value === 'string' ? value : safeStringify(value);
  return PII_PATTERNS.reduce(
    (acc, pattern) => acc.replace(pattern, REDACTED),
    raw,
  );
}

/**
 * Redige profundamente um payload de log: remove valores de chaves sensíveis
 * por nome E varre o conteúdo textual restante em busca de PII.
 *
 * Use SEMPRE antes de enviar qualquer contexto a `console.error`/logger em
 * blocos try/catch que possam conter dados de paciente.
 *
 * @param payload Objeto/valor a ser logado.
 * @returns Cópia estruturalmente similar com toda PII redigida.
 */
export function sanitizeLogPayload(payload: unknown): unknown {
  if (payload === null || payload === undefined) {
    return payload;
  }

  if (typeof payload === 'string') {
    return sanitizeLogValue(payload);
  }

  if (typeof payload !== 'object') {
    // number/boolean/bigint/symbol — não carregam PII textual.
    return payload;
  }

  if (Array.isArray(payload)) {
    return payload.map((item) => sanitizeLogPayload(item));
  }

  const source = payload as Record<string, unknown>;
  const result: Record<string, unknown> = {};

  for (const [key, val] of Object.entries(source)) {
    if (SENSITIVE_KEYS.has(key)) {
      result[key] = REDACTED;
      continue;
    }
    result[key] = sanitizeLogPayload(val);
  }

  return result;
}

/** Serializa com tolerância a referências circulares (nunca lança). */
function safeStringify(value: unknown): string {
  try {
    return JSON.stringify(value) ?? String(value);
  } catch {
    return '[unserializable]';
  }
}

// =============================================================================
// 4. Cliente Supabase falso e encadeável
// =============================================================================

/** Tipo da operação registrada pelo cliente falso. */
export type OperationType = 'select' | 'insert' | 'update' | 'delete';

/** Filtro `.eq(column, value)` aplicado a uma operação. */
export interface RecordedFilter {
  column: string;
  value: unknown;
}

/** Registro auditável de uma operação executada via cliente falso. */
export interface RecordedOperation {
  table: string;
  type: OperationType;
  payload?: unknown;
  columns?: string;
  filters: RecordedFilter[];
  order?: { column: string; ascending: boolean };
  single?: boolean;
}

/** Usuário autenticado sintético. */
export interface MockAuthUser {
  id: string;
  email?: string;
  role?: string;
  professionalType?: string;
}

/** Sessão sintética devolvida por `signInWithPassword`. */
export interface MockSession {
  access_token: string;
  token_type: 'bearer';
  user: MockAuthUser;
}

/** Construtor de query encadeável e "thenable" (resolve `{ data, error }`). */
export class MockQueryBuilder<T = unknown> implements PromiseLike<PostgrestResult<T>> {
  constructor(
    private readonly op: RecordedOperation,
    private readonly resolveResult: (op: RecordedOperation) => PostgrestResult<T>,
  ) {}

  select(columns = '*'): this {
    this.op.columns = columns;
    return this;
  }

  insert(payload: unknown): this {
    this.op.type = 'insert';
    this.op.payload = payload;
    return this;
  }

  update(payload: unknown): this {
    this.op.type = 'update';
    this.op.payload = payload;
    return this;
  }

  delete(): this {
    this.op.type = 'delete';
    return this;
  }

  eq(column: string, value: unknown): this {
    this.op.filters.push({ column, value });
    return this;
  }

  order(column: string, options?: { ascending?: boolean }): this {
    this.op.order = { column, ascending: options?.ascending ?? true };
    return this;
  }

  single(): this {
    this.op.single = true;
    return this;
  }

  maybeSingle(): this {
    this.op.single = true;
    return this;
  }

  then<TResult1 = PostgrestResult<T>, TResult2 = never>(
    onfulfilled?:
      | ((value: PostgrestResult<T>) => TResult1 | PromiseLike<TResult1>)
      | null,
    onrejected?: ((reason: unknown) => TResult2 | PromiseLike<TResult2>) | null,
  ): Promise<TResult1 | TResult2> {
    return Promise.resolve(this.resolveResult(this.op)).then(onfulfilled, onrejected);
  }
}

/** Função que decide o resultado de cada operação no cliente falso. */
export type Responder = (op: RecordedOperation) => PostgrestResult;

/** Interface pública do cliente Supabase falso. */
export interface MockSupabaseClient {
  from(table: string): MockQueryBuilder;
  auth: {
    currentUser: MockAuthUser | null;
    signInWithPassword(credentials: {
      email: string;
      password: string;
    }): Promise<{ data: { session: MockSession | null; user: MockAuthUser | null }; error: PostgrestLikeError | null }>;
    getUser(): Promise<{ data: { user: MockAuthUser | null }; error: PostgrestLikeError | null }>;
    signOut(): Promise<{ error: null }>;
  };
  /** Operações registradas em ordem de execução (para asserts). */
  readonly operations: RecordedOperation[];
  /** Enfileira um resultado específico para a próxima operação (FIFO). */
  queueResult(result: PostgrestResult): void;
  /** Define um responder custom (tem prioridade sobre a fila). */
  setResponder(fn: Responder | null): void;
}

/** Opções de criação do cliente falso. */
export interface MockSupabaseOptions {
  /** Mapa email → usuário, usado por `signInWithPassword`. */
  users?: Record<string, MockAuthUser>;
  /** Usuário inicialmente autenticado (`auth.currentUser`). */
  currentUser?: MockAuthUser | null;
}

/**
 * Cria um cliente Supabase falso, encadeável e auditável.
 *
 * Modela a superfície usada pelo `RenewalService` do frontend
 * (`from().insert()/update()/select().eq().order()` + `auth.*`), permitindo
 * exercitar o fluxo completo sem rede nem banco real.
 *
 * @param options Sementes de usuários e sessão inicial.
 * @returns Instância de {@link MockSupabaseClient}.
 */
export function createMockSupabaseClient(
  options: MockSupabaseOptions = {},
): MockSupabaseClient {
  const operations: RecordedOperation[] = [];
  const resultQueue: PostgrestResult[] = [];
  const users = options.users ?? {};
  let responder: Responder | null = null;
  let currentUser: MockAuthUser | null = options.currentUser ?? null;

  const resolveResult = (op: RecordedOperation): PostgrestResult => {
    if (responder) {
      return responder(op);
    }
    const next = resultQueue.shift();
    // Default seguro: RLS-friendly (lista vazia, sem erro).
    return next ?? { data: [], error: null };
  };

  const client: MockSupabaseClient = {
    from(table: string): MockQueryBuilder {
      const op: RecordedOperation = { table, type: 'select', filters: [] };
      operations.push(op);
      return new MockQueryBuilder(op, resolveResult);
    },
    auth: {
      get currentUser(): MockAuthUser | null {
        return currentUser;
      },
      set currentUser(value: MockAuthUser | null) {
        currentUser = value;
      },
      async signInWithPassword({ email }) {
        const user = users[email];
        if (!user) {
          return {
            data: { session: null, user: null },
            error: { code: 'invalid_credentials', message: 'Invalid login credentials' },
          };
        }
        currentUser = user;
        return { data: { session: buildFakeSession(user), user }, error: null };
      },
      async getUser() {
        return { data: { user: currentUser }, error: null };
      },
      async signOut() {
        currentUser = null;
        return { error: null };
      },
    },
    operations,
    queueResult(result: PostgrestResult): void {
      resultQueue.push(result);
    },
    setResponder(fn: Responder | null): void {
      responder = fn;
    },
  };

  return client;
}

// =============================================================================
// 5. Geração de sessão / JWT sintéticos
// =============================================================================

/** Codifica um objeto em base64url (sem padding), como nos segmentos de JWT. */
function base64UrlEncode(value: object): string {
  return Buffer.from(JSON.stringify(value))
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

/**
 * Constrói um JWT sintético com 3 segmentos (header.payload.signature).
 *
 * NÃO é assinado criptograficamente — serve apenas para asserts de formato e
 * de claims (sub/role/aud) na fase de autenticação do contract test. A
 * validação real de assinatura é responsabilidade do `auth.middleware.ts`
 * (JWKS do Supabase) e é coberta por `tests/auth.test.ts`.
 *
 * @param user Usuário cujas claims serão embutidas.
 * @returns String JWT no formato `xxxxx.yyyyy.zzzzz`.
 */
export function encodeFakeJwt(user: MockAuthUser): string {
  const header = { alg: 'HS256', typ: 'JWT' };
  const issuedAt = Math.floor(Date.now() / 1000);
  const payload = {
    sub: user.id,
    role: user.role ?? 'authenticated',
    aud: 'authenticated',
    professional_type: user.professionalType ?? 'PACIENTE',
    iat: issuedAt,
    exp: issuedAt + 3600,
  };
  // Assinatura placeholder determinística — nunca verificada neste teste.
  const signature = 'test-signature';
  return `${base64UrlEncode(header)}.${base64UrlEncode(payload)}.${signature}`;
}

/**
 * Decodifica o payload de um JWT sintético gerado por {@link encodeFakeJwt}.
 *
 * @param token JWT no formato `header.payload.signature`.
 * @returns Objeto de claims do segmento de payload.
 * @throws Error quando o token não tem 3 segmentos.
 */
export function decodeFakeJwtPayload(token: string): Record<string, unknown> {
  const segments = token.split('.');
  if (segments.length !== 3) {
    throw new Error('JWT malformado: esperados 3 segmentos.');
  }
  const payloadSegment = segments[1] ?? '';
  const normalized = payloadSegment.replace(/-/g, '+').replace(/_/g, '/');
  const json = Buffer.from(normalized, 'base64').toString('utf-8');
  return JSON.parse(json) as Record<string, unknown>;
}

/**
 * Monta uma sessão sintética com JWT para um usuário.
 *
 * @param user Usuário autenticado.
 * @returns {@link MockSession} com `access_token` no formato JWT.
 */
export function buildFakeSession(user: MockAuthUser): MockSession {
  return {
    access_token: encodeFakeJwt(user),
    token_type: 'bearer',
    user,
  };
}

// =============================================================================
// 6. Orquestrador do fluxo sob teste (RenewalFlowContract)
// =============================================================================

/**
 * Erro de contrato com status HTTP e mensagem segura (sem PII).
 * Espelha o padrão `AuthServiceError`/`HealthUnitServiceError` da camada de
 * service do backend.
 */
export class ContractError extends Error {
  public readonly statusCode: number;
  public readonly code: string | undefined;

  constructor(message: string, statusCode: number, code?: string) {
    super(message);
    this.name = 'ContractError';
    this.statusCode = statusCode;
    this.code = code;
  }
}

/** Linha mínima de `RenewalRequest` usada nas leituras do contrato. */
export interface RenewalRow {
  id: string;
  prescriptionId: string;
  patientUserId: string;
  doctorUserId: string | null;
  nurseUserId: string | null;
  status: RenewalStatus;
  nurseNotes: string | null;
  renewedPrescriptionId: string | null;
}

/** Nome da tabela de pedidos (PascalCase, criada via Prisma com quoted identifier). */
const RENEWAL_TABLE = 'RenewalRequest';
/** Tabela BaaS de prescrições (lowercase — não modelada pelo Prisma). */
const PRESCRIPTIONS_TABLE = 'prescriptions';

/**
 * Orquestra o fluxo de renovação ponta a ponta sobre o cliente falso,
 * aplicando exatamente as regras documentadas no schema Prisma e no
 * `RenewalService` do frontend:
 *
 *  - Identidade SEMPRE derivada da sessão (`auth`), nunca aceita como
 *    parâmetro externo — impede falsificação de `patientUserId`/`nurseUserId`.
 *  - Transições validadas por {@link canTransition} antes de qualquer escrita.
 *  - Erros do PostgREST convertidos por {@link mapPostgrestErrorToHttp} e
 *    logados de forma sanitizada por {@link sanitizeLogPayload}.
 *
 * É o "contrato" que o `prescription_flow.test.ts` exercita e verifica.
 */
export class RenewalFlowContract {
  constructor(
    private readonly client: MockSupabaseClient,
    private readonly logger: (entry: unknown) => void = console.error,
  ) {}

  /** Lê o ID do usuário autenticado ou lança 401 (sessão ausente). */
  private async requireUserId(): Promise<string> {
    const { data } = await this.client.auth.getUser();
    const id = data.user?.id;
    if (!id) {
      throw new ContractError('Sessão expirada. Faça login novamente.', 401);
    }
    return id;
  }

  /** Garante a transição ou lança 409 (estado inválido) sem expor detalhes. */
  private assertTransition(from: RenewalStatus, to: RenewalStatus): void {
    if (!canTransition(from, to)) {
      throw new ContractError(
        `Transição de status não permitida (${from} → ${to}).`,
        409,
      );
    }
  }

  /** Converte erro PostgREST em {@link ContractError} e loga sem PII. */
  private failFrom(
    context: string,
    error: PostgrestLikeError,
    extra: Record<string, unknown> = {},
  ): ContractError {
    // LGPD: redige PII antes de qualquer log; nunca expõe a mensagem crua do BD.
    this.logger(
      sanitizeLogPayload({ context, code: error.code, message: error.message, ...extra }),
    );
    const mapped = mapPostgrestErrorToHttp(error.code);
    return new ContractError(mapped.message, mapped.status, error.code);
  }

  // ---- Paciente -----------------------------------------------------------

  /**
   * Paciente cria um pedido de renovação (status inicial PENDING_TRIAGE).
   * `patientUserId` é derivado da sessão — nunca aceito do cliente.
   */
  async requestRenewal(prescriptionId: string): Promise<void> {
    const patientUserId = await this.requireUserId();
    const result = await this.client.from(RENEWAL_TABLE).insert({
      prescriptionId,
      patientUserId,
      status: RenewalStatus.PENDING_TRIAGE,
    });
    if (result.error) {
      throw this.failFrom('requestRenewal', result.error, { prescriptionId });
    }
  }

  /**
   * Leitura dos pedidos de um paciente-alvo. Em condições normais o app só
   * consulta os próprios dados; aqui o `targetPatientId` existe para simular
   * a tentativa maliciosa (Paciente A lendo dados do Paciente B). O RLS filtra
   * silenciosamente (lista vazia) ou nega com 42501 → 403.
   */
  async readRenewalsOfPatient(targetPatientId: string): Promise<RenewalRow[]> {
    await this.requireUserId();
    const result = await this.client
      .from(RENEWAL_TABLE)
      .select('*')
      .eq('patientUserId', targetPatientId)
      .order('createdAt', { ascending: false });

    if (result.error) {
      throw this.failFrom('readRenewalsOfPatient', result.error, { targetPatientId });
    }
    return (result.data as RenewalRow[] | null) ?? [];
  }

  // ---- Enfermeiro ---------------------------------------------------------

  /**
   * Enfermeiro assume o acolhimento: PENDING_TRIAGE → TRIAGED.
   * Designa um médico e registra observações. `nurseUserId` vem da sessão.
   */
  async approveTriage(
    id: string,
    params: { currentStatus: RenewalStatus; doctorUserId: string; nurseNotes?: string },
  ): Promise<void> {
    this.assertTransition(params.currentStatus, RenewalStatus.TRIAGED);
    if (params.doctorUserId.trim().length === 0) {
      throw new ContractError('Selecione um médico responsável antes de aprovar.', 422);
    }
    const nurseUserId = await this.requireUserId();
    const result = await this.client
      .from(RENEWAL_TABLE)
      .update({
        status: RenewalStatus.TRIAGED,
        doctorUserId: params.doctorUserId,
        nurseUserId,
        ...(params.nurseNotes !== undefined ? { nurseNotes: params.nurseNotes } : {}),
      })
      .eq('id', id);

    if (result.error) {
      throw this.failFrom('approveTriage', result.error, { id });
    }
  }

  /**
   * Enfermeiro rejeita o pedido: PENDING_TRIAGE → REJECTED.
   * `nurseNotes` é obrigatório (auditoria de dados de saúde — LGPD art. 11).
   */
  async rejectTriage(
    id: string,
    params: { currentStatus: RenewalStatus; nurseNotes: string },
  ): Promise<void> {
    this.assertTransition(params.currentStatus, RenewalStatus.REJECTED);
    if (params.nurseNotes.trim().length === 0) {
      throw new ContractError('Informe o motivo da rejeição antes de confirmar.', 422);
    }
    const nurseUserId = await this.requireUserId();
    const result = await this.client
      .from(RENEWAL_TABLE)
      .update({
        status: RenewalStatus.REJECTED,
        nurseUserId,
        nurseNotes: params.nurseNotes,
      })
      .eq('id', id);

    if (result.error) {
      throw this.failFrom('rejectTriage', result.error, { id });
    }
  }

  // ---- Médico -------------------------------------------------------------

  /**
   * Médico defere a demanda: TRIAGED → PRESCRIBED.
   *
   * Insere a nova prescrição na tabela BaaS `prescriptions` e então marca o
   * pedido como PRESCRIBED com `renewedPrescriptionId` (mesma ordem da tela
   * `renewal_prescription_screen.dart`).
   *
   * @returns ID da prescrição emitida.
   */
  async markAsPrescribed(
    id: string,
    params: {
      currentStatus: RenewalStatus;
      renewedPrescriptionId: string;
      prescription: Record<string, unknown>;
    },
  ): Promise<string> {
    this.assertTransition(params.currentStatus, RenewalStatus.PRESCRIBED);
    const doctorUserId = await this.requireUserId();

    // 1) Persiste a prescrição renovada (BaaS).
    const insertResult = await this.client.from(PRESCRIPTIONS_TABLE).insert({
      id: params.renewedPrescriptionId,
      professional_id: doctorUserId,
      ...params.prescription,
    });
    if (insertResult.error) {
      throw this.failFrom('markAsPrescribed.insertPrescription', insertResult.error, { id });
    }

    // 2) Conclui o pedido de renovação.
    const updateResult = await this.client
      .from(RENEWAL_TABLE)
      .update({
        status: RenewalStatus.PRESCRIBED,
        renewedPrescriptionId: params.renewedPrescriptionId,
      })
      .eq('id', id);
    if (updateResult.error) {
      throw this.failFrom('markAsPrescribed.updateRenewal', updateResult.error, { id });
    }

    return params.renewedPrescriptionId;
  }
}
