import { jest } from '@jest/globals';
import request from 'supertest';
import type { Express } from 'express';

/**
 * Mocks do módulo `jose` devem ser declarados antes do import dinâmico da app
 * para garantir que o middleware de autenticação já use a versão mockada.
 */
jest.unstable_mockModule('jose', async () => ({
  createRemoteJWKSet: jest.fn(() => ({})),
  jwtVerify: jest.fn(),
}));

/**
 * Testes de segurança para o middleware CORS (TASK #186 — PBI #178).
 *
 * Verifica que apenas origens configuradas em ALLOWED_ORIGINS conseguem
 * fazer chamadas cross-origin ao backend, em conformidade com
 * OWASP A05:2021 — Security Misconfiguration.
 */
describe('CORS — restrição de origem (ALLOWED_ORIGINS)', () => {
  const ALLOWED = 'https://app.ereceitasus.com.br';
  const BLOCKED = 'https://origem-nao-autorizada.example.com';

  // Referência da app importada dentro do beforeAll para garantir que
  // ALLOWED_ORIGINS já esteja definida quando o módulo for carregado.
  let app: Express;

  beforeAll(async () => {
    // Define ANTES do import dinâmico — allowedOrigins é computado na inicialização
    // do módulo, então a env precisa estar definida antes do import.
    process.env.ALLOWED_ORIGINS = ALLOWED;
    process.env.SUPABASE_URL = 'https://pofzorepizdcefvodwln.supabase.co';

    const mod = await import('../src/app.js');
    app = mod.app;
  });

  afterAll(() => {
    delete process.env.ALLOWED_ORIGINS;
  });

  it('deve incluir Access-Control-Allow-Origin para origem autorizada', async () => {
    // Requisição simples (GET /health não requer JWT — ideal para isolar CORS)
    const response = await request(app)
      .get('/health')
      .set('Origin', ALLOWED);

    // O cabeçalho deve refletir exatamente a origem autorizada
    expect(response.headers['access-control-allow-origin']).toBe(ALLOWED);
  });

  it('deve retornar erro CORS para origem não autorizada', async () => {
    const response = await request(app)
      .get('/health')
      .set('Origin', BLOCKED);

    // O cors() não devolve Access-Control-Allow-Origin quando a callback rejeita a origem
    expect(response.headers['access-control-allow-origin']).toBeUndefined();
  });

  it('deve responder ao preflight OPTIONS com cabeçalhos corretos para origem autorizada', async () => {
    const response = await request(app)
      .options('/user/me')
      .set('Origin', ALLOWED)
      .set('Access-Control-Request-Method', 'GET')
      .set('Access-Control-Request-Headers', 'Authorization');

    // Preflight deve ser aceito (204 No Content) e incluir a origem permitida
    expect(response.status).toBe(204);
    expect(response.headers['access-control-allow-origin']).toBe(ALLOWED);
  });

  it('deve incluir Access-Control-Allow-Credentials para origens autorizadas', async () => {
    const response = await request(app)
      .get('/health')
      .set('Origin', ALLOWED);

    // Necessário para o Flutter Web/browser enviar cookies/tokens cross-origin
    expect(response.headers['access-control-allow-credentials']).toBe('true');
  });
});
