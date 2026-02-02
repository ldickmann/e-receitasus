// ==========================================
// TESTES DE LISTAGEM DE RECEITAS
// ==========================================
// Este arquivo testa a User Story US-03: Listagem de Receitas
// Valida que o paciente consegue visualizar suas receitas médicas
// com filtros, ordenação e tratamento de erros adequados.

// ==========================================
// IMPORTS
// ==========================================

// Biblioteca para fazer requisições HTTP simuladas nos testes
import request from 'supertest';

// Aplicação Express (servidor web)
import { app } from '../src/app.js';

// Cliente Prisma para interagir com o banco de dados
import { prisma } from '../src/utils/prismaClient.js';

// ==========================================
// SUITE DE TESTES
// ==========================================

/**
 * Conjunto de testes para o endpoint GET /prescriptions/my
 * 
 * Testa:
 * - Autenticação (token válido/inválido)
 * - Listagem de receitas do usuário logado
 * - Filtros por status (ACTIVE, EXPIRED)
 * - Ordenação por data de criação
 * - Busca de receita específica por ID
 */
describe('Prescription List - GET /prescriptions/my', () => {

  // ==========================================
  // VARIÁVEIS DE SETUP
  // ==========================================

  // Token JWT obtido após login (usado para autenticação)
  let authToken: string;

  // ID do usuário criado para os testes
  let userId: string;

  // ID de uma receita específica (usado em alguns testes)
  let prescriptionId: string;

  // ==========================================
  // SETUP - EXECUTADO ANTES DE TODOS OS TESTES
  // ==========================================

  /**
   * beforeAll: Roda UMA VEZ antes de todos os testes
   * 
   * Propósito:
   * 1. Limpar banco de dados (estado inicial limpo)
   * 2. Criar usuário de teste
   * 3. Fazer login e obter token JWT
   * 4. Criar receitas de teste com diferentes status
   */
  beforeAll(async () => {

    // ------------------------------------------
    // PASSO 1: LIMPEZA DO BANCO DE DADOS
    // ------------------------------------------
    // Remove todas as receitas e usuários existentes
    // Garante que cada execução de teste comece com estado limpo
    await prisma.prescription.deleteMany();
    await prisma.user.deleteMany();

    // ------------------------------------------
    // PASSO 2: CRIAR USUÁRIO DE TESTE
    // ------------------------------------------
    // Simula requisição POST /auth/register
    const registerRes = await request(app)
      .post('/auth/register')
      .send({
        name: 'João Silva',
        email: 'joao.silva@sus.gov.br',
        password: 'SenhaForte123!',
      });

    // Armazena o ID do usuário criado
    userId = registerRes.body.id;

    // ------------------------------------------
    // PASSO 3: FAZER LOGIN E OBTER TOKEN
    // ------------------------------------------
    // Simula requisição POST /auth/login
    const loginRes = await request(app)
      .post('/auth/login')
      .send({
        email: 'joao.silva@sus.gov.br',
        password: 'SenhaForte123!',
      });

    // Armazena o token JWT para usar nos testes
    authToken = loginRes.body.token;

    // ------------------------------------------
    // PASSO 4: CRIAR RECEITAS DE TESTE
    // ------------------------------------------
    // Cria 3 receitas com diferentes status para testar filtros
    await prisma.prescription.createMany({
      data: [
        // Receita 1: ATIVA - Losartana
        {
          medicine: 'Losartana 50mg',
          description: 'Uso contínuo para hipertensão',
          patientId: userId,
          doctorName: 'Dr. Carlos Mendes',
          status: 'ACTIVE',
        },
        // Receita 2: ATIVA - Metformina
        {
          medicine: 'Metformina 850mg',
          description: 'Tomar após refeições',
          patientId: userId,
          doctorName: 'Dra. Ana Paula',
          status: 'ACTIVE',
        },
        // Receita 3: EXPIRADA - Captopril
        {
          medicine: 'Captopril 25mg',
          description: 'Receita vencida',
          patientId: userId,
          doctorName: 'Dr. Carlos Mendes',
          status: 'EXPIRED',
        },
      ],
    });
  });

  // ==========================================
  // TEARDOWN - EXECUTADO APÓS TODOS OS TESTES
  // ==========================================

  /**
   * afterAll: Roda UMA VEZ após todos os testes
   * 
   * Propósito:
   * - Desconectar do banco de dados
   * - Liberar recursos
   */
  afterAll(async () => {
    await prisma.$disconnect();
  });

  // ==========================================
  // TESTE 1: AUTENTICAÇÃO
  // ==========================================

  /**
   * Valida que a rota exige autenticação
   * 
   * Cenário: Usuário tenta acessar sem enviar token
   * Resultado esperado: HTTP 401 Unauthorized
   */
  it('deve retornar 401 sem autenticação', async () => {
    // AÇÃO: Faz requisição GET sem o header Authorization
    const res = await request(app).get('/prescriptions/my');

    // VERIFICAÇÕES:
    // 1. Status HTTP deve ser 401 (Não autenticado)
    expect(res.status).toBe(401);

    // 2. Mensagem de erro deve mencionar token
    expect(res.body.message).toContain('Token não fornecido');
  });

  // ==========================================
  // TESTE 2: LISTAGEM COMPLETA
  // ==========================================

  /**
   * Valida que o usuário consegue listar TODAS suas receitas
   * 
   * Cenário: Usuário autenticado busca suas receitas
   * Resultado esperado: HTTP 200 com array de 3 receitas
   */
  it('deve listar todas as receitas do usuário', async () => {
    // AÇÃO: Faz requisição GET com token válido
    const res = await request(app)
      .get('/prescriptions/my')
      .set('Authorization', `Bearer ${authToken}`); // Envia token no header

    // VERIFICAÇÕES:
    // 1. Status HTTP deve ser 200 (Sucesso)
    expect(res.status).toBe(200);

    // 2. Deve retornar array com 3 receitas
    expect(res.body.data).toHaveLength(3);

    // 3. Propriedade count deve ser 3
    expect(res.body.count).toBe(3);

    // 4. Primeira receita deve ter as propriedades esperadas
    expect(res.body.data[0]).toHaveProperty('medicine');
    expect(res.body.data[0]).toHaveProperty('status');
  });

  // ==========================================
  // TESTE 3: FILTRO POR STATUS ACTIVE
  // ==========================================

  /**
   * Valida filtro por status ACTIVE via query string
   * 
   * Cenário: Usuário busca apenas receitas ativas (?status=ACTIVE)
   * Resultado esperado: HTTP 200 com 2 receitas ativas
   */
  it('deve filtrar receitas por status ACTIVE', async () => {
    // AÇÃO: Faz requisição GET com query param status=ACTIVE
    const res = await request(app)
      .get('/prescriptions/my?status=ACTIVE') // Query string
      .set('Authorization', `Bearer ${authToken}`);

    // VERIFICAÇÕES:
    // 1. Status HTTP deve ser 200
    expect(res.status).toBe(200);

    // 2. Deve retornar exatamente 2 receitas (temos 2 ACTIVE no setup)
    expect(res.body.count).toBe(2);

    // 3. TODAS as receitas retornadas devem ter status ACTIVE
    // every() retorna true se TODOS os elementos passam no teste
    expect(res.body.data.every((p: any) => p.status === 'ACTIVE')).toBe(true);
  });

  // ==========================================
  // TESTE 4: FILTRO POR STATUS EXPIRED
  // ==========================================

  /**
   * Valida filtro por status EXPIRED via query string
   * 
   * Cenário: Usuário busca apenas receitas expiradas (?status=EXPIRED)
   * Resultado esperado: HTTP 200 com 1 receita expirada
   */
  it('deve filtrar receitas por status EXPIRED', async () => {
    // AÇÃO: Faz requisição GET com query param status=EXPIRED
    const res = await request(app)
      .get('/prescriptions/my?status=EXPIRED')
      .set('Authorization', `Bearer ${authToken}`);

    // VERIFICAÇÕES:
    // 1. Status HTTP deve ser 200
    expect(res.status).toBe(200);

    // 2. Deve retornar exatamente 1 receita
    expect(res.body.count).toBe(1);

    // 3. A receita retornada deve ser o Captopril (único EXPIRED)
    expect(res.body.data[0].medicine).toBe('Captopril 25mg');
  });

  // ==========================================
  // TESTE 5: VALIDAÇÃO DE STATUS INVÁLIDO
  // ==========================================

  /**
   * Valida que a API rejeita status inválidos
   * 
   * Cenário: Usuário envia status que não existe (?status=INVALID)
   * Resultado esperado: HTTP 400 Bad Request
   */
  it('deve retornar erro para status inválido', async () => {
    // AÇÃO: Faz requisição GET com status inválido
    const res = await request(app)
      .get('/prescriptions/my?status=INVALID')
      .set('Authorization', `Bearer ${authToken}`);

    // VERIFICAÇÕES:
    // 1. Status HTTP deve ser 400 (Bad Request)
    expect(res.status).toBe(400);

    // 2. Mensagem de erro deve mencionar "Status inválido"
    expect(res.body.message).toContain('Status inválido');
  });

  // ==========================================
  // TESTE 6: ORDENAÇÃO POR DATA
  // ==========================================

  /**
   * Valida que as receitas vêm ordenadas por data decrescente
   * 
   * Cenário: Usuário lista receitas
   * Resultado esperado: Mais recentes primeiro (ordem decrescente)
   */
  it('deve ordenar receitas por data decrescente', async () => {
    // AÇÃO: Faz requisição GET
    const res = await request(app)
      .get('/prescriptions/my')
      .set('Authorization', `Bearer ${authToken}`);

    // PREPARAÇÃO: Converte strings de data em objetos Date
    const dates = res.body.data.map((p: any) => new Date(p.createdAt));

    // VERIFICAÇÃO: Percorre o array verificando ordenação
    // Cada data deve ser >= à próxima (ordem decrescente)
    for (let i = 0; i < dates.length - 1; i++) {
      expect(dates[i].getTime()).toBeGreaterThanOrEqual(dates[i + 1].getTime());
    }
  });

  // ==========================================
  // TESTE 7: BUSCA POR ID ESPECÍFICO
  // ==========================================

  /**
   * Valida que o usuário consegue buscar UMA receita específica
   * 
   * Cenário: Usuário busca receita pelo ID (GET /prescriptions/:id)
   * Resultado esperado: HTTP 200 com dados da receita
   */
  it('deve retornar receita específica por ID', async () => {
    // PASSO 1: Busca a lista de receitas
    const listRes = await request(app)
      .get('/prescriptions/my')
      .set('Authorization', `Bearer ${authToken}`);

    // PASSO 2: Extrai o ID da primeira receita
    const prescriptionId = listRes.body.data[0].id;

    // PASSO 3: Busca a receita específica usando o ID
    const res = await request(app)
      .get(`/prescriptions/${prescriptionId}`) // Rota dinâmica
      .set('Authorization', `Bearer ${authToken}`);

    // VERIFICAÇÕES:
    // 1. Status HTTP deve ser 200
    expect(res.status).toBe(200);

    // 2. ID retornado deve ser igual ao ID buscado
    expect(res.body.data.id).toBe(prescriptionId);
  });

  // ==========================================
  // TESTE 8: RECEITA INEXISTENTE
  // ==========================================

  /**
   * Valida tratamento de erro para receita inexistente
   * 
   * Cenário: Usuário busca receita com ID que não existe
   * Resultado esperado: HTTP 404 Not Found
   */
  it('deve retornar 404 para receita inexistente', async () => {
    // PREPARAÇÃO: ID fake no formato UUID válido
    const fakeId = '00000000-0000-0000-0000-000000000000';

    // AÇÃO: Tenta buscar receita com ID inexistente
    const res = await request(app)
      .get(`/prescriptions/${fakeId}`)
      .set('Authorization', `Bearer ${authToken}`);

    // VERIFICAÇÃO: Deve retornar 404 (Não encontrado)
    expect(res.status).toBe(404);
  });
});

// ==========================================
// COMANDOS PARA EXECUTAR OS TESTES
// ==========================================

/*
 * Para rodar este arquivo de teste:
 *
 * 1. Rodar todos os testes:
 *    npm test
 *
 * 2. Rodar apenas este arquivo:
 *    npm test prescription-list.test.ts
 *
 * 3. Rodar em modo watch (re-executa ao salvar):
 *    npm test -- --watch
 *
 * 4. Ver cobertura de código:
 *    npm test -- --coverage
 */

// ==========================================
// ESTRUTURA DO ARQUIVO
// ==========================================

/*
 * ORGANIZAÇÃO:
 * 
 * 1. IMPORTS - Bibliotecas necessárias
 * 2. DESCRIBE - Suite de testes (agrupa testes relacionados)
 * 3. VARIÁVEIS - Estado compartilhado entre testes
 * 4. BEFOREALL - Setup executado uma vez antes
 * 5. AFTERALL - Cleanup executado uma vez depois
 * 6. IT/TEST - Casos de teste individuais
 * 
 * PADRÃO AAA (Arrange-Act-Assert):
 * 
 * - Arrange (Preparar): Setup do teste
 * - Act (Agir): Executar a ação testada
 * - Assert (Verificar): Validar o resultado
 */