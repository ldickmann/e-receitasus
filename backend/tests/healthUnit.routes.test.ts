import { jest } from '@jest/globals';
import request from 'supertest';

// =============================================================================
// Testes da rota REST GET /health-units — TASK #214 / PBI #198
//
// Estratégia: mockamos `jose` (validação JWT) e o service de UBS para isolar a
// camada HTTP — assim os asserts cobrem APENAS validação de query, mapeamento
// de status e formato da resposta. A integração real com Prisma é coberta em
// `healthUnit.repository.test.ts` e `healthUnit.service.test.ts`.
// =============================================================================

const jwtVerifyMock = jest.fn<
  (token: unknown, key: unknown, options?: unknown) => Promise<{ payload: { sub: string; aud: string } }>
>();

jest.unstable_mockModule('jose', async () => ({
  createRemoteJWKSet: jest.fn(() => ({})),
  jwtVerify: jwtVerifyMock,
}));

const listHealthUnitsByCityMock = jest.fn<
  (city: string, state?: string) => Promise<Array<Record<string, unknown>>>
>();

/**
 * Réplica local da classe de erro do service.
 *
 * Como o handler da rota faz `instanceof HealthUnitServiceError`, ambos
 * (handler e teste) precisam referenciar EXATAMENTE a mesma classe — por
 * isso ela é definida aqui e exposta pelo factory do mock. Importar o
 * módulo real antes do mock cacharia o módulo e o override não teria efeito.
 */
class FakeHealthUnitServiceError extends Error {
  statusCode: number;
  constructor(message: string, statusCode: number) {
    super(message);
    this.statusCode = statusCode;
  }
}

jest.unstable_mockModule('../src/services/healthUnit.service.js', () => ({
  listHealthUnitsByCity: listHealthUnitsByCityMock,
  HealthUnitServiceError: FakeHealthUnitServiceError,
}));

// Importação dinâmica DEPOIS dos mocks — caso contrário `app.ts` resolveria
// os módulos reais antes do override.
const { app } = await import('../src/app.js');

/** Injeta token simulado válido no próximo `jwtVerify`. */
function mockValidToken(userId = '11111111-1111-1111-1111-111111111111'): void {
  jwtVerifyMock.mockResolvedValueOnce({
    payload: { sub: userId, aud: 'authenticated' },
  });
}

describe('GET /health-units — rota REST de listagem de UBS', () => {
  beforeAll(() => {
    process.env.SUPABASE_URL = 'https://shnahlongybxxilworck.supabase.co';
  });

  beforeEach(() => {
    jwtVerifyMock.mockReset();
    listHealthUnitsByCityMock.mockReset();
  });

  it('retorna 200 com a lista do service quando city é válido', async () => {
    mockValidToken();
    const fakeRows = [
      { id: 'u1', name: 'UBS A', district: 'Centro', city: 'Navegantes', state: 'SC' },
    ];
    listHealthUnitsByCityMock.mockResolvedValueOnce(fakeRows);

    const res = await request(app)
      .get('/health-units')
      .query({ city: 'Navegantes', state: 'sc' })
      .set('Authorization', 'Bearer token-valido');

    expect(res.status).toBe(200);
    expect(res.body).toEqual(fakeRows);
    // UF deve ser normalizada para uppercase antes de chegar ao service.
    expect(listHealthUnitsByCityMock).toHaveBeenCalledWith('Navegantes', 'SC');
  });

  it('retorna 200 com array vazio quando service responde vazio (city sem UBS)', async () => {
    mockValidToken();
    listHealthUnitsByCityMock.mockResolvedValueOnce([]);

    const res = await request(app)
      .get('/health-units')
      .query({ city: 'Cidade Inexistente' })
      .set('Authorization', 'Bearer token-valido');

    expect(res.status).toBe(200);
    expect(res.body).toEqual([]);
    expect(listHealthUnitsByCityMock).toHaveBeenCalledWith('Cidade Inexistente', undefined);
  });

  it('retorna 401 quando Authorization ausente — middleware bloqueia antes da rota', async () => {
    const res = await request(app).get('/health-units').query({ city: 'Navegantes' });

    expect(res.status).toBe(401);
    expect(listHealthUnitsByCityMock).not.toHaveBeenCalled();
  });

  it('retorna 400 quando city ausente', async () => {
    mockValidToken();

    const res = await request(app)
      .get('/health-units')
      .set('Authorization', 'Bearer token-valido');

    expect(res.status).toBe(400);
    expect(listHealthUnitsByCityMock).not.toHaveBeenCalled();
  });

  it('retorna 400 quando state não é UF válida (2 letras)', async () => {
    mockValidToken();

    const res = await request(app)
      .get('/health-units')
      .query({ city: 'Navegantes', state: 'SaoPaulo' })
      .set('Authorization', 'Bearer token-valido');

    expect(res.status).toBe(400);
    expect(listHealthUnitsByCityMock).not.toHaveBeenCalled();
  });

  it('retorna 400 quando city excede o limite de tamanho', async () => {
    mockValidToken();

    const res = await request(app)
      .get('/health-units')
      .query({ city: 'a'.repeat(200) })
      .set('Authorization', 'Bearer token-valido');

    expect(res.status).toBe(400);
    expect(listHealthUnitsByCityMock).not.toHaveBeenCalled();
  });

  it('repassa statusCode quando service lança HealthUnitServiceError', async () => {
    mockValidToken();
    listHealthUnitsByCityMock.mockRejectedValueOnce(
      new FakeHealthUnitServiceError('Parâmetro inválido', 400),
    );

    const res = await request(app)
      .get('/health-units')
      .query({ city: 'Navegantes' })
      .set('Authorization', 'Bearer token-valido');

    expect(res.status).toBe(400);
    expect(res.body.message).toBe('Parâmetro inválido');
  });

  it('retorna 500 sem expor stack trace quando service explode com erro genérico', async () => {
    mockValidToken();
    listHealthUnitsByCityMock.mockRejectedValueOnce(new Error('Falha interna do banco'));

    const res = await request(app)
      .get('/health-units')
      .query({ city: 'Navegantes' })
      .set('Authorization', 'Bearer token-valido');

    expect(res.status).toBe(500);
    // Mensagem genérica — corpo NÃO deve vazar a string interna do erro.
    expect(JSON.stringify(res.body)).not.toContain('Falha interna do banco');
  });
});
