import { jest } from '@jest/globals';
import request from 'supertest';
import { prisma } from '../src/utils/prismaClient.js';

/**
 * Mock da funcao jwtVerify do pacote jose.
 * Isso permite simular tokens validos/invalidos sem depender da chave privada real.
 */
const jwtVerifyMock = jest.fn<(token: string, key: unknown) => Promise<{ payload: Record<string, unknown> }>>();

jest.unstable_mockModule('jose', async () => {
  const actual = await import('jose');
  return {
    ...actual,
    jwtVerify: jwtVerifyMock,
  };
});

const { app } = await import('../src/app.js');

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

    await prisma.user.deleteMany();

    await prisma.user.create({
      data: user,
    });
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(() => {
    jwtVerifyMock.mockReset();
  });

  /**
   * Deve permitir acesso ao perfil com token valido.
   */
  it('deve retornar 200 no GET /user/me com token valido', async () => {
    mockValidToken(user.id);

    const response = await request(app)
      .get('/user/me')
      .set('Authorization', 'Bearer token-valido');

    expect(response.status).toBe(200);
    expect(response.body.id).toBe(user.id);
    expect(response.body.email).toBe(user.email);
  });

  /**
   * Deve bloquear sem token.
   */
  it('deve retornar 401 sem Authorization', async () => {
    const response = await request(app).get('/user/me');

    expect(response.status).toBe(401);
    expect(String(response.body.message)).toContain('Token');
  });

  /**
   * Deve bloquear token invalido.
   */
  it('deve retornar 403 quando assinatura for invalida', async () => {
    jwtVerifyMock.mockRejectedValueOnce(new Error('invalid signature'));

    const response = await request(app)
      .get('/user/me')
      .set('Authorization', 'Bearer token-invalido');

    expect(response.status).toBe(403);
  });

  /**
   * Endpoints legados devem permanecer desativados com 410.
   */
  it('deve retornar 410 no POST /auth/login', async () => {
    const response = await request(app).post('/auth/login').send({
      email: 'qualquer@sus.gov.br',
      password: 'qualquer-senha',
    });

    expect(response.status).toBe(410);
  });
});