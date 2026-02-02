import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/utils/prismaClient.js';

describe('Autenticação E2E Completa', () => {
  let authToken: string;

  beforeAll(async () => {
    await prisma.user.deleteMany();
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('Fluxo completo: Registro → Login → Acesso a Rota Protegida', async () => {
    // 1. REGISTRO
    const registerRes = await request(app)
      .post('/auth/register')
      .send({
        name: 'João Silva',
        email: 'joao@sus.gov.br',
        password: 'SenhaForte123!',
      });

    expect(registerRes.status).toBe(201);
    expect(registerRes.body).toHaveProperty('id');

    // 2. LOGIN
    const loginRes = await request(app)
      .post('/auth/login')
      .send({
        email: 'joao@sus.gov.br',
        password: 'SenhaForte123!',
      });

    expect(loginRes.status).toBe(200);
    expect(loginRes.body).toHaveProperty('token');
    authToken = loginRes.body.token;

    // 3. ACESSO A ROTA PROTEGIDA
    const profileRes = await request(app)
      .get('/user/me')
      .set('Authorization', `Bearer ${authToken}`);

    expect(profileRes.status).toBe(200);
    expect(profileRes.body.email).toBe('joao@sus.gov.br');
    expect(profileRes.body).not.toHaveProperty('password');
  });

  it('Deve negar acesso sem token', async () => {
    const res = await request(app).get('/user/me');
    expect(res.status).toBe(401);
  });

  it('Deve negar acesso com token inválido', async () => {
    const res = await request(app)
      .get('/user/me')
      .set('Authorization', 'Bearer token_invalido');
    
    expect(res.status).toBe(403);
  });
});