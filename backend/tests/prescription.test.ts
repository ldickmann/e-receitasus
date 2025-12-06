import request from 'supertest';
import { app } from '../src/app.js';
import { prisma } from '../src/utils/prismaClient.js';

describe('Prescription Flow - /prescriptions', () => {
  let authToken: string;

  // Limpa o banco antes e depois dos testes
  beforeAll(async () => {
    await prisma.prescription.deleteMany().catch(() => { }); // Ignora se a tabela não existir ainda
    await prisma.user.deleteMany();

    // 1. Cria um usuário para termos um token válido
    await request(app).post('/auth/register').send({
      name: 'Paciente Teste',
      email: 'paciente@sus.gov.br',
      password: 'SenhaForte123!'
    });

    const loginRes = await request(app).post('/auth/login').send({
      email: 'paciente@sus.gov.br',
      password: 'SenhaForte123!'
    });

    authToken = loginRes.body.token;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('deve permitir solicitar uma nova receita (POST /prescriptions) e retornar 201', async () => {
    // AÇÃO: Tenta enviar uma solicitação de receita
    const res = await request(app)
      .post('/prescriptions')
      .set('Authorization', `Bearer ${authToken}`) // Envia o token
      .send({
        medicine: 'Losartana 50mg',
        description: 'Uso contínuo para hipertensão'
      });

    // VERIFICAÇÃO (Vai falhar pois a rota não existe)
    expect(res.status).toBe(201);
    expect(res.body).toHaveProperty('id');
    expect(res.body.medicine).toBe('Losartana 50mg');
  });
});