import { jest } from '@jest/globals';
import request from 'supertest';

const jwtVerifyMock = jest.fn<
  (token: unknown, key: unknown, options?: unknown) => Promise<{ payload: { sub: string; aud: string } }>
>();

const findUniqueMock = jest.fn<
  (args: any) => Promise<any>
>();

jest.unstable_mockModule('jose', async () => ({
  createRemoteJWKSet: jest.fn(() => ({})),
  jwtVerify: jwtVerifyMock,
}));

jest.unstable_mockModule('../src/utils/prismaClient.js', () => ({
  prisma: {
    patient: { findUnique: jest.fn().mockResolvedValue(null) },
    professional: {
      findUnique: findUniqueMock,
      deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
      create: jest.fn().mockResolvedValue({}),
    },
    $disconnect: jest.fn().mockResolvedValue(undefined),
  },
}));

// Dynamic import APÓS os mocks para garantir que app.ts e prisma já resolvam os mocks
const { app } = await import('../src/app.js');
const { prisma } = await import('../src/utils/prismaClient.js');

/**
 * Configura mock de token valido para um usuario especifico.
 *
 * @param userId ID que sera injetado no payload simulado.
 */
function mockValidToken(userId: string): void {
  jwtVerifyMock.mockResolvedValueOnce({
    payload: {
      sub: userId,
      aud: 'authenticated',
    },
  });
}

describe('Auth Flow Hibrido (JWT Supabase + rota protegida)', () => {
  const user = {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Usuario Teste',
    email: 'teste@sus.gov.br',
    professionalType: 'ADMINISTRATIVO' as const,
  };

  beforeAll(async () => {
    process.env.SUPABASE_URL = 'https://pofzorepizdcefvodwln.supabase.co';

    // Limpa apenas o profissional de teste (ADMINISTRATIVO → tabela professionals)
    await prisma.professional.deleteMany({ where: { id: user.id } });

    // Cria o profissional de teste para os asserts do endpoint GET /user/me
    await prisma.professional.create({
      data: user,
    });
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(() => {
    jwtVerifyMock.mockReset();
    findUniqueMock.mockReset();
    findUniqueMock.mockResolvedValue(user);
  });

  it('deve retornar 200 no GET /user/me com token valido', async () => {
    mockValidToken(user.id);

    const response = await request(app)
      .get('/user/me')
      .set('Authorization', 'Bearer token-valido');

    expect(response.status).toBe(200);
    expect(response.body.id).toBe(user.id);
    expect(response.body.email).toBe(user.email);
  });

  it('deve retornar 401 sem Authorization', async () => {
    const response = await request(app).get('/user/me');

    expect(response.status).toBe(401);
    expect(String(response.body.message)).toContain('Token');
  });

  it('deve retornar 403 quando assinatura for invalida', async () => {
    jwtVerifyMock.mockRejectedValueOnce(new Error('invalid signature'));

    const response = await request(app)
      .get('/user/me')
      .set('Authorization', 'Bearer token-invalido');

    expect(response.status).toBe(403);
  });

  it('deve retornar 410 no POST /auth/login', async () => {
    const response = await request(app).post('/auth/login').send({
      email: 'qualquer@sus.gov.br',
      password: 'qualquer-senha',
    });

    expect(response.status).toBe(410);
  });
});