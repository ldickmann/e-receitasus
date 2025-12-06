import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/utils/prismaClient.js';

describe('History Flow - /history', () => {
  let authToken: string;

  beforeAll(async () => {
    // Limpeza e Preparação do Ambiente
    await prisma.prescription.deleteMany().catch(() => { });
    await prisma.user.deleteMany();

    // Criar usuário para autenticação
    await request(app).post('/auth/register').send({
      name: 'History User',
      email: 'history@sus.gov.br',
      password: '123Password!'
    });

    const loginRes = await request(app).post('/auth/login').send({
      email: 'history@sus.gov.br',
      password: '123Password!'
    });

    authToken = loginRes.body.token;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('deve listar o histórico de receitas (GET /history) e retornar 200', async () => {
    // AÇÃO: Tenta acessar a rota de histórico
    const res = await request(app)
      .get('/history')
      .set('Authorization', `Bearer ${authToken}`);

    // VERIFICAÇÃO (Deve falhar com 404)
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});