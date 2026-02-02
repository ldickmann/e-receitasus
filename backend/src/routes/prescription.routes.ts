// ============================================================================
// ROTAS DE PRESCRIÇÕES MÉDICAS
// ============================================================================
// Este arquivo define todas as rotas HTTP relacionadas a receitas médicas.
// 
// ENDPOINTS DISPONÍVEIS:
// - POST   /prescriptions           - Criar nova receita (apenas médicos)
// - GET    /prescriptions           - Listar todas as receitas (admin)
// - GET    /prescriptions/my        - Listar receitas do paciente autenticado
// - GET    /prescriptions/:id       - Buscar detalhes de uma receita específica
// - PATCH  /prescriptions/:id/cancel - Cancelar uma receita (apenas médico prescritor)
// ============================================================================

import { Router } from 'express';
import {
  createPrescription,
  getPrescriptions,
  listMyPrescriptions,
  getPrescriptionById,
  cancelPrescription,
} from '../controllers/prescription.controller.js';
import { authenticateToken } from '../middlewares/auth.middleware.js';

// Cria instância do roteador Express
const router = Router();

// ============================================================================
// ROTAS PÚBLICAS (SEM AUTENTICAÇÃO)
// ============================================================================
// Nenhuma rota de prescrição é pública - todas requerem autenticação

// ============================================================================
// ROTAS PROTEGIDAS - CRIAÇÃO DE RECEITAS
// ============================================================================

/**
 * POST /prescriptions
 * 
 * Cria uma nova receita médica
 * 
 * @access Private (requer autenticação de médico)
 * @middleware authenticateToken - Valida JWT e extrai userId
 * @body {
 *   medicine: string,      // Nome do medicamento (obrigatório)
 *   description?: string,  // Instruções de uso (opcional)
 *   patientId: string      // UUID do paciente (obrigatório)
 * }
 * @returns {201} Receita criada com sucesso
 * @returns {400} Dados inválidos
 * @returns {401} Não autenticado
 * @returns {403} Não é médico
 * @returns {404} Paciente não encontrado
 * 
 * @example
 * POST /prescriptions
 * Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 * Body: {
 *   "medicine": "Losartana 50mg",
 *   "description": "Tomar 1 comprimido pela manhã em jejum",
 *   "patientId": "123e4567-e89b-12d3-a456-426614174000"
 * }
 */
router.post('/', authenticateToken, createPrescription);

// ============================================================================
// ROTAS PROTEGIDAS - LISTAGEM DE RECEITAS
// ============================================================================

/**
 * GET /prescriptions
 * 
 * Lista TODAS as receitas do sistema (uso administrativo)
 * 
 * ⚠️ ATENÇÃO: Esta rota deve ser restrita apenas para administradores
 * Atualmente está sem validação de role - implementar AuthZ futuramente
 * 
 * @access Private (requer autenticação)
 * @middleware authenticateToken
 * @returns {200} Lista de todas as receitas
 * @returns {401} Não autenticado
 * @returns {500} Erro interno
 * 
 * @todo Implementar middleware de autorização por role (isAdmin)
 */
router.get('/', authenticateToken, getPrescriptions);

/**
 * GET /prescriptions/my
 * 
 * Lista receitas do usuário autenticado (paciente)
 * Retorna apenas as receitas onde o usuário é o paciente
 * 
 * ⚠️ IMPORTANTE: Esta rota DEVE vir ANTES de /prescriptions/:id
 * para evitar que o Express interprete "my" como um UUID
 * 
 * @access Private (requer autenticação)
 * @middleware authenticateToken
 * @query {string} [status] - Filtro opcional (ACTIVE, EXPIRED, CANCELLED)
 * @returns {200} Lista de receitas do usuário
 * @returns {400} Status inválido
 * @returns {401} Não autenticado
 * 
 * @example
 * GET /prescriptions/my
 * GET /prescriptions/my?status=ACTIVE
 * 
 * Response: {
 *   message: "Receitas encontradas com sucesso",
 *   count: 3,
 *   data: [...]
 * }
 */
router.get('/my', authenticateToken, listMyPrescriptions);

/**
 * GET /prescriptions/:id
 * 
 * Busca detalhes de uma receita específica
 * Apenas o paciente dono da receita pode acessá-la (autorização automática)
 * 
 * @access Private (requer autenticação)
 * @middleware authenticateToken
 * @param {string} id - UUID da receita
 * @returns {200} Receita encontrada
 * @returns {400} UUID inválido
 * @returns {401} Não autenticado
 * @returns {403} Receita não pertence ao usuário
 * @returns {404} Receita não encontrada
 * 
 * @example
 * GET /prescriptions/123e4567-e89b-12d3-a456-426614174000
 * Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 */
router.get('/:id', authenticateToken, getPrescriptionById);

// ============================================================================
// ROTAS PROTEGIDAS - AÇÕES EM RECEITAS
// ============================================================================

/**
 * PATCH /prescriptions/:id/cancel
 * 
 * Cancela uma receita existente
 * Apenas o médico que criou a receita pode cancelá-la
 * 
 * @access Private (requer autenticação de médico prescritor)
 * @middleware authenticateToken
 * @param {string} id - UUID da receita
 * @returns {200} Receita cancelada com sucesso
 * @returns {400} UUID inválido ou receita já cancelada
 * @returns {401} Não autenticado
 * @returns {403} Usuário não é o médico prescritor
 * @returns {404} Receita não encontrada
 * 
 * @example
 * PATCH /prescriptions/123e4567-e89b-12d3-a456-426614174000/cancel
 * Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
 */
router.patch('/:id/cancel', authenticateToken, cancelPrescription);

// ============================================================================
// EXPORTAÇÃO
// ============================================================================

/**
 * Exporta o roteador para uso em app.ts
 * 
 * Uso em app.ts:
 * import prescriptionRoutes from './routes/prescription.routes.js';
 * app.use('/prescriptions', prescriptionRoutes);
 */
export default router;

// ============================================================================
// NOTAS TÉCNICAS IMPORTANTES
// ============================================================================

/*
 * ORDEM DAS ROTAS:
 * 
 * A ordem importa no Express! Rotas mais específicas devem vir ANTES:
 * 
 * ✅ CORRETO:
 * 1. GET /prescriptions/my        (rota específica)
 * 2. GET /prescriptions/:id       (rota genérica com parâmetro)
 * 
 * ❌ ERRADO:
 * 1. GET /prescriptions/:id       (capturaria "my" como UUID)
 * 2. GET /prescriptions/my        (nunca seria alcançada)
 * 
 * 
 * MIDDLEWARE DE AUTENTICAÇÃO:
 * 
 * - authenticateToken: Valida JWT e adiciona req.userId ao objeto Request
 * - Deve ser aplicado em TODAS as rotas de prescrição
 * - O middleware já retorna 401/403 automaticamente se token inválido
 * 
 * 
 * PRÓXIMAS MELHORIAS:
 * 
 * 1. Implementar middleware de autorização por role:
 *    - isAdmin: para GET /prescriptions
 *    - isDoctor: para POST /prescriptions e PATCH /:id/cancel
 * 
 * 2. Adicionar validação de entrada com express-validator:
 *    - Validar formato de UUID nos parâmetros
 *    - Validar tipos e campos obrigatórios no body
 * 
 * 3. Implementar rate limiting para prevenir abuso:
 *    - Limitar criação de receitas por tempo
 *    - Limitar consultas por IP/usuário
 * 
 * 4. Adicionar cache para listagens frequentes:
 *    - Cache Redis para GET /prescriptions/my
 *    - Invalidar cache ao criar/cancelar receitas
 */