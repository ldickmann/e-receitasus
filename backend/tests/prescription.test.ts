import { jest } from '@jest/globals';
import request from 'supertest';
import { PrescriptionStatus } from '@prisma/client';
import { prisma } from '../src/utils/prismaClient.js';

/**
 * Mock do módulo jose via jest.unstable_mockModule (padrão ESM).
 * Deve ser declarado ANTES do dynamic import do app para garantir
 * que o middleware carregue o mock e não o módulo real.
 */
const jwtVerifyMock = jest.fn();

jest.unstable_mockModule('jose', async () => ({
  createRemoteJWKSet: jest.fn(() => ({})),
  jwtVerify: jwtVerifyMock,
}));

// Dynamic import APÓS o mock para garantir que app.ts já resolve jose mockado
const { app } = await import('../src/app.js');

describe('Prescription List - GET /prescriptions/my', () => {
  const tokenPaciente = 'token-paciente';
  const tokenOutroPaciente = 'token-outro-paciente';

  const paciente = {
    id: '11111111-1111-1111-1111-111111111111',
    name: 'Paciente Principal',
    email: 'paciente.principal@sus.gov.br',
    professionalType: 'ADMINISTRATIVO' as const,
  };

  const outroPaciente = {
    id: '22222222-2222-2222-2222-222222222222',
    name: 'Paciente Secundario',
    email: 'paciente.secundario@sus.gov.br',
    professionalType: 'ADMINISTRATIVO' as const,
  };

  let ownPrescriptionId = '';
  let foreignPrescriptionId = '';

  beforeAll(async () => {
    process.env.SUPABASE_URL = 'https://pofzorepizdcefvodwln.supabase.co';

    await prisma.prescription.deleteMany();
    await prisma.user.deleteMany();

    await prisma.user.create({ data: paciente });
    await prisma.user.create({ data: outroPaciente });

    const first = await prisma.prescription.create({
      data: {
        medicine: 'Losartana 50mg',
        description: 'Uso continuo para hipertensao',
        patientId: paciente.id,
        doctorName: 'Dr. Carlos Mendes',
        status: PrescriptionStatus.ACTIVE,
      },
    });

    await prisma.prescription.create({
      data: {
        medicine: 'Metformina 850mg',
        description: 'Tomar apos refeicoes',
        patientId: paciente.id,
        doctorName: 'Dra. Ana Paula',
        status: PrescriptionStatus.ACTIVE,
      },
    });

    await prisma.prescription.create({
      data: {
        medicine: 'Captopril 25mg',
        description: 'Receita vencida',
        patientId: paciente.id,
        doctorName: 'Dr. Carlos Mendes',
        status: PrescriptionStatus.EXPIRED,
      },
    });

    const foreign = await prisma.prescription.create({
      data: {
        medicine: 'AAS 100mg',
        description: 'Receita de outro paciente',
        patientId: outroPaciente.id,
        doctorName: 'Dr. Externo',
        status: PrescriptionStatus.ACTIVE,
      },
    });

    ownPrescriptionId = first.id;
    foreignPrescriptionId = foreign.id;
  });

  afterAll(async () => {
    await prisma.$disconnect();
  });

  beforeEach(() => {
    jwtVerifyMock.mockReset();

    jwtVerifyMock.mockImplementation(async (token: unknown) => {
      if (token === tokenPaciente) {
        return { payload: { sub: paciente.id, aud: 'authenticated' } };
      }
      if (token === tokenOutroPaciente) {
        return { payload: { sub: outroPaciente.id, aud: 'authenticated' } };
      }
      throw new Error('invalid token');
    });
  });

  it('deve retornar 401 sem autenticacao', async () => {
    const response = await request(app).get('/prescriptions/my');
    expect(response.status).toBe(401);
  });

  it('deve retornar 403 com token invalido', async () => {
    const response = await request(app)
      .get('/prescriptions/my')
      .set('Authorization', 'Bearer token-invalido');
    expect(response.status).toBe(403);
  });

  it('deve listar receitas do usuario autenticado', async () => {
    const response = await request(app)
      .get('/prescriptions/my')
      .set('Authorization', 'Bearer ' + tokenPaciente);

    expect(response.status).toBe(200);
    expect(response.body.count).toBe(3);
  });

  it('deve filtrar por status ACTIVE', async () => {
    const response = await request(app)
      .get('/prescriptions/my?status=ACTIVE')
      .set('Authorization', 'Bearer ' + tokenPaciente);

    expect(response.status).toBe(200);
    expect(response.body.count).toBe(2);
  });

  it('deve retornar 400 para status invalido', async () => {
    const response = await request(app)
      .get('/prescriptions/my?status=INVALID')
      .set('Authorization', 'Bearer ' + tokenPaciente);

    expect(response.status).toBe(400);
  });

  it('deve buscar receita especifica do proprio paciente', async () => {
    const response = await request(app)
      .get('/prescriptions/' + ownPrescriptionId)
      .set('Authorization', 'Bearer ' + tokenPaciente);

    expect(response.status).toBe(200);
    expect(response.body.data.id).toBe(ownPrescriptionId);
  });

  it('deve retornar 403 ao acessar receita de outro usuario', async () => {
    const response = await request(app)
      .get('/prescriptions/' + foreignPrescriptionId)
      .set('Authorization', 'Bearer ' + tokenPaciente);

    expect(response.status).toBe(403);
  });

  it('deve retornar 404 para receita inexistente', async () => {
    const response = await request(app)
      .get('/prescriptions/00000000-0000-0000-0000-000000000000')
      .set('Authorization', 'Bearer ' + tokenPaciente);

    expect(response.status).toBe(404);
  });
});