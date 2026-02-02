import type { Request, Response } from 'express';
import { prisma } from '../utils/prismaClient.js';
import { PrescriptionStatus } from '@prisma/client';

// ==========================================
// INTERFACES E TIPOS
// ==========================================

/**
 * Interface para requisições autenticadas
 * O middleware de autenticação adiciona o userId ao objeto Request
 */
interface AuthenticatedRequest extends Request {
  userId?: string;
}

// ==========================================
// CONTROLLER: CRIAR RECEITA
// ==========================================

/**
 * Cria uma nova receita médica
 * 
 * @route POST /prescriptions
 * @access Private (requer autenticação de médico)
 * @body { medicine: string, description?: string, patientId: string }
 * 
 * @example
 * POST /prescriptions
 * Body: {
 *   "medicine": "Losartana 50mg",
 *   "description": "Tomar 1 comprimido pela manhã",
 *   "patientId": "uuid-do-paciente"
 * }
 */
export const createPrescription = async (req: AuthenticatedRequest, res: Response) => {
  try {
    // 1. Extrai dados do body da requisição
    const { medicine, description, patientId } = req.body;

    // 2. Validação básica dos campos obrigatórios
    if (!medicine || !patientId) {
      return res.status(400).json({ 
        message: 'Campos obrigatórios: medicine e patientId' 
      });
    }

    // 3. Verifica se o médico está autenticado
    if (!req.userId) {
      return res.status(401).json({ 
        message: 'Usuário não autenticado' 
      });
    }

    // 4. Busca informações do médico para validação
    const doctor = await prisma.user.findUnique({
      where: { id: req.userId },
      select: { 
        id: true, 
        name: true, 
        professionalType: true,
        professionalId: true,
        professionalState: true,
      },
    });

    // 5. Valida se o usuário existe e é um médico
    if (!doctor) {
      return res.status(404).json({ 
        message: 'Médico não encontrado' 
      });
    }

    if (doctor.professionalType !== 'MEDICO') {
      return res.status(403).json({ 
        message: 'Apenas médicos podem criar receitas' 
      });
    }

    // 6. Valida se o paciente existe
    const patientExists = await prisma.user.findUnique({
      where: { id: patientId },
      select: { id: true, name: true },
    });

    if (!patientExists) {
      return res.status(404).json({ 
        message: 'Paciente não encontrado' 
      });
    }

    // 7. Formata o nome do médico com CRM
    const doctorName = doctor.professionalId && doctor.professionalState
      ? `Dr(a). ${doctor.name} - CRM ${doctor.professionalId}/${doctor.professionalState}`
      : `Dr(a). ${doctor.name}`;

    // 8. Cria a receita no banco de dados
    const prescription = await prisma.prescription.create({
      data: {
        medicine,
        description: description || null,
        patientId,
        doctorId: req.userId,
        doctorName,
        status: PrescriptionStatus.ACTIVE, // Status inicial: ATIVA
      },
      // Inclui informações relacionadas na resposta
      include: {
        patient: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        doctor: {
          select: {
            id: true,
            name: true,
            professionalId: true,
            professionalState: true,
          },
        },
      },
    });

    // 9. Log de sucesso (útil para auditoria)
    console.log(`✅ [PRESCRIPTION] Receita criada: ${prescription.id} por ${doctorName}`);

    // 10. Retorna sucesso com a receita criada
    return res.status(201).json({
      message: 'Receita criada com sucesso',
      data: prescription,
    });

  } catch (error) {
    // Log do erro no console do servidor
    console.error('❌ [PRESCRIPTION] Erro ao criar receita:', error);
    
    // Retorna erro genérico para o cliente (não expõe detalhes internos)
    return res.status(500).json({ 
      message: 'Erro interno ao criar receita',
      error: process.env.NODE_ENV === 'development' ? error : undefined,
    });
  }
};

// ==========================================
// CONTROLLER: LISTAR TODAS AS RECEITAS (ADMIN)
// ==========================================

/**
 * Lista todas as receitas do sistema (uso administrativo)
 * 
 * @route GET /prescriptions
 * @access Private (apenas administradores)
 * 
 * @example GET /prescriptions
 */
export const getPrescriptions = async (req: Request, res: Response) => {
  try {
    // 1. Busca todas as receitas ordenadas por data (mais recente primeiro)
    const prescriptions = await prisma.prescription.findMany({
      orderBy: { 
        createdAt: 'desc' // Ordenação decrescente por data de criação
      },
      // Inclui informações do paciente e médico
      include: {
        patient: {
          select: {
            id: true,
            name: true,
            email: true,
          },
        },
        doctor: {
          select: {
            id: true,
            name: true,
            professionalId: true,
            professionalState: true,
          },
        },
      },
    });

    // 2. Retorna sucesso com lista de receitas
    return res.status(200).json({
      message: 'Receitas encontradas',
      count: prescriptions.length,
      data: prescriptions,
    });

  } catch (error) {
    console.error('❌ [PRESCRIPTION] Erro ao buscar receitas:', error);
    
    return res.status(500).json({ 
      message: 'Erro ao buscar receitas',
      error: process.env.NODE_ENV === 'development' ? error : undefined,
    });
  }
};

// ==========================================
// CONTROLLER: LISTAR MINHAS RECEITAS (PACIENTE)
// ==========================================

/**
 * Lista receitas do usuário autenticado (paciente)
 * 
 * @route GET /prescriptions/my
 * @access Private (requer autenticação)
 * @query status - Filtro opcional por status (ACTIVE, EXPIRED, CANCELLED)
 * 
 * @example 
 * GET /prescriptions/my
 * GET /prescriptions/my?status=ACTIVE
 * GET /prescriptions/my?status=EXPIRED
 */
export const listMyPrescriptions = async (req: AuthenticatedRequest, res: Response) => {
  try {
    // 1. Verifica se o usuário está autenticado
    if (!req.userId) {
      return res.status(401).json({ 
        message: 'Usuário não autenticado. Faça login para continuar.' 
      });
    }

    // 2. Extrai filtro de status da query string (opcional)
    const { status } = req.query;

    // 3. Constrói objeto de filtro dinamicamente
    const whereClause: any = {
      patientId: req.userId, // Filtra apenas receitas do usuário logado
    };

    // 4. Adiciona filtro de status se fornecido
    if (status && typeof status === 'string') {
      // Lista de status válidos (baseado no enum PrescriptionStatus)
      const validStatuses = ['ACTIVE', 'EXPIRED', 'CANCELLED'];
      
      // Valida se o status fornecido é válido
      if (!validStatuses.includes(status.toUpperCase())) {
        return res.status(400).json({ 
          message: 'Status inválido. Use: ACTIVE, EXPIRED ou CANCELLED',
          validOptions: validStatuses,
        });
      }
      
      // Adiciona filtro ao whereClause
      whereClause.status = status.toUpperCase();
    }

    // 5. Busca receitas do paciente no banco de dados
    const prescriptions = await prisma.prescription.findMany({
      where: whereClause,
      orderBy: {
        createdAt: 'desc', // Mais recentes primeiro (ordenação decrescente)
      },
      select: {
        // Campos que serão retornados
        id: true,
        medicine: true,
        description: true,
        doctorName: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        // Não retorna patientId por segurança (usuário já sabe que é dele)
        
        // Inclui informações do médico (se disponível)
        doctor: {
          select: {
            id: true,
            name: true,
            professionalId: true,
            professionalState: true,
            specialty: true,
          },
        },
      },
    });

    // 6. Verifica se encontrou receitas
    if (prescriptions.length === 0) {
      return res.status(200).json({
        message: 'Nenhuma receita encontrada',
        data: [],
      });
    }

    // 7. Log de sucesso
    console.log(`✅ [PRESCRIPTION] ${prescriptions.length} receita(s) listada(s) para usuário ${req.userId}`);

    // 8. Retorna receitas encontradas
    return res.status(200).json({
      message: 'Receitas encontradas com sucesso',
      count: prescriptions.length,
      data: prescriptions,
    });

  } catch (error) {
    console.error('❌ [PRESCRIPTION] Erro ao listar receitas:', error);
    
    return res.status(500).json({ 
      message: 'Erro interno ao buscar receitas',
      error: process.env.NODE_ENV === 'development' ? error : undefined,
    });
  }
};

// ==========================================
// CONTROLLER: BUSCAR RECEITA ESPECÍFICA POR ID
// ==========================================

/**
 * Busca detalhes de uma receita específica
 * Apenas o paciente dono da receita pode acessá-la
 * 
 * @route GET /prescriptions/:id
 * @access Private
 * @param id - UUID da receita
 * 
 * @example GET /prescriptions/123e4567-e89b-12d3-a456-426614174000
 */
export const getPrescriptionById = async (req: AuthenticatedRequest, res: Response) => {
  try {
    // 1. Verifica autenticação
    if (!req.userId) {
      return res.status(401).json({ 
        message: 'Usuário não autenticado' 
      });
    }

    // 2. Extrai ID da receita dos parâmetros da URL
    const { id } = req.params;

    // 3. Valida formato UUID do ID
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ 
        message: 'ID de receita inválido. Deve ser um UUID válido.' 
      });
    }

    // 4. Busca receita no banco de dados
    const prescription = await prisma.prescription.findUnique({
      where: { id },
      select: {
        id: true,
        medicine: true,
        description: true,
        doctorName: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        patientId: true,
        // Inclui dados do médico
        doctor: {
          select: {
            id: true,
            name: true,
            professionalId: true,
            professionalState: true,
            specialty: true,
          },
        },
      },
    });

    // 5. Verifica se a receita existe
    if (!prescription) {
      return res.status(404).json({ 
        message: 'Receita não encontrada' 
      });
    }

    // 6. Verifica se a receita pertence ao usuário autenticado
    // (Autorização: apenas o dono pode acessar)
    if (prescription.patientId !== req.userId) {
      return res.status(403).json({ 
        message: 'Você não tem permissão para acessar esta receita' 
      });
    }

    // 7. Remove patientId da resposta (não é necessário para o cliente)
    const { patientId, ...prescriptionData } = prescription;

    // 8. Retorna receita encontrada
    return res.status(200).json({
      message: 'Receita encontrada',
      data: prescriptionData,
    });

  } catch (error) {
    console.error('❌ [PRESCRIPTION] Erro ao buscar receita:', error);
    
    return res.status(500).json({ 
      message: 'Erro ao buscar receita',
      error: process.env.NODE_ENV === 'development' ? error : undefined,
    });
  }
};

// ==========================================
// CONTROLLER: CANCELAR RECEITA
// ==========================================

/**
 * Cancela uma receita (apenas o médico prescritor pode cancelar)
 * 
 * @route PATCH /prescriptions/:id/cancel
 * @access Private (apenas médico prescritor)
 * @param id - UUID da receita
 * 
 * @example PATCH /prescriptions/123e4567-e89b-12d3-a456-426614174000/cancel
 */
export const cancelPrescription = async (req: AuthenticatedRequest, res: Response) => {
  try {
    // 1. Verifica autenticação
    if (!req.userId) {
      return res.status(401).json({ 
        message: 'Usuário não autenticado' 
      });
    }

    // 2. Extrai ID da receita
    const { id } = req.params;

    // 3. Valida formato UUID
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    if (!uuidRegex.test(id)) {
      return res.status(400).json({ 
        message: 'ID de receita inválido' 
      });
    }

    // 4. Busca receita para validação
    const prescription = await prisma.prescription.findUnique({
      where: { id },
      select: {
        id: true,
        doctorId: true,
        status: true,
        medicine: true,
      },
    });

    // 5. Verifica se receita existe
    if (!prescription) {
      return res.status(404).json({ 
        message: 'Receita não encontrada' 
      });
    }

    // 6. Verifica se o usuário é o médico prescritor
    if (prescription.doctorId !== req.userId) {
      return res.status(403).json({ 
        message: 'Apenas o médico prescritor pode cancelar esta receita' 
      });
    }

    // 7. Verifica se receita já está cancelada
    if (prescription.status === PrescriptionStatus.CANCELLED) {
      return res.status(400).json({ 
        message: 'Receita já está cancelada' 
      });
    }

    // 8. Atualiza status para CANCELLED
    const updatedPrescription = await prisma.prescription.update({
      where: { id },
      data: {
        status: PrescriptionStatus.CANCELLED,
      },
    });

    // 9. Log de sucesso
    console.log(`✅ [PRESCRIPTION] Receita cancelada: ${id}`);

    // 10. Retorna sucesso
    return res.status(200).json({
      message: 'Receita cancelada com sucesso',
      data: updatedPrescription,
    });

  } catch (error) {
    console.error('❌ [PRESCRIPTION] Erro ao cancelar receita:', error);
    
    return res.status(500).json({ 
      message: 'Erro ao cancelar receita',
      error: process.env.NODE_ENV === 'development' ? error : undefined,
    });
  }
};

// ==========================================
// EXPORTAÇÕES
// ==========================================

/**
 * RESUMO DAS ROTAS:
 * 
 * POST   /prescriptions           - Criar receita (médico)
 * GET    /prescriptions           - Listar todas (admin)
 * GET    /prescriptions/my        - Listar minhas receitas (paciente)
 * GET    /prescriptions/:id       - Buscar receita específica
 * PATCH  /prescriptions/:id/cancel - Cancelar receita (médico)
 */