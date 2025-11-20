// Importação da biblioteca de testes HTTP
import request from 'supertest';
// Importação da aplicação Express (extensão .js obrigatória com moduleResolution: nodenext)
import { app } from '../src/app.js';
// Importação do cliente Prisma para operações no banco
import { prisma } from '../src/utils/prismaClient.js';

describe('Auth - /auth', () => {
  const user = {
    name: 'Test User',
    email: 'test@example.com',
    password: 'Senha123!'
  };

  beforeAll(async () => {
    await prisma.user.deleteMany(); // limpa o banco antes de iniciar
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('should register a user and return 201', async () => {
    const res = await request(app).post('/auth/register').send(user);

    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
    expect(res.body.email).toBe(user.email);
  });

  it('should login and return a valid JWT token', async () => {
    await request(app).post('/auth/register').send({
      name: 'LoginTeste',
      email: 'login@example.com',
      password: 'Senha123!'
    });

    const res = await request(app).post('/auth/login').send({
      email: 'login@example.com',
      password: 'Senha123!'
    });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(typeof res.body.token).toBe('string');
  });
});
