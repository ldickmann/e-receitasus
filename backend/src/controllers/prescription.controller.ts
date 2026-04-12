import type { Request, Response } from 'express';
import type { Prisma } from '@prisma/client';
import { PrescriptionStatus } from '@prisma/client';
import type { AuthRequest } from '../middlewares/auth.middleware.js';
import { prisma } from '../utils/prismaClient.js';

// ==========================================
// CONSTANTES E HELPERS
// ==========================================

/**
 * Regex para validação de UUID no padrão 8-4-4-4-12.
 * Mantido em constante para reutilização e manutenção centralizada.
 */
const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Lista de status válidos para filtros e validações de entrada.
 */
const VALID_STATUSES: ReadonlyArray<PrescriptionStatus> = [
  PrescriptionStatus.ACTIVE,
  PrescriptionStatus.EXPIRED,
  PrescriptionStatus.CANCELLED,
];

/**
 * Obtém o userId autenticado com checagem defensiva.
 * Evita duplicação de lógica e garante retorno consistente.
 */
function getAuthenticatedUserId(req: AuthRequest): string | null {
  if (typeof req.userId !== 'string') {
    return null;
  }

  const userId = req.userId.trim();
  return userId.length > 0 ? userId : null;
}

/**
 * Valida e normaliza um parâmetro UUID vindo de req.params.
 * Resolve problemas de tipagem com exactOptionalPropertyTypes.
 */
function parseUuidParam(value: unknown): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim();
  if (!UUID_REGEX.test(normalized)) {
    return null;
  }

  return normalized;
}

/**
 * Converte e valida status vindo da query string.
 * Retorna null quando inválido.
 */
function parseStatusParam(value: unknown): PrescriptionStatus | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim().toUpperCase();

  switch (normalized) {
    case PrescriptionStatus.ACTIVE:
      return PrescriptionStatus.ACTIVE;
    case PrescriptionStatus.EXPIRED:
      return PrescriptionStatus.EXPIRED;
    case PrescriptionStatus.CANCELLED:
      return PrescriptionStatus.CANCELLED;
    default:
      return null;
  }
}

// ==========================================
// CONTROLLER: CRIAR RECEITA
// ==========================================

/**
 * Cria uma nova receita médica.
 *
 * Regras:
 * - Usuário deve estar autenticado.
 * - Usuário autenticado deve ser MEDICO.
 * - Paciente precisa existir.
 */
export const createPrescription = async (req: AuthRequest, res: Response): Promise<Response> => {
  try {
    // 1. Garante usuário autenticado
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({
        message: 'Usuário não autenticado',
      });
    }

    // 2. Lê e valida body de forma defensiva
    const body = req.body as {
      medicine?: unknown;
      description?: unknown;
      patientId?: unknown;
    };

    const medicine = typeof body.medicine === 'string' ? body.medicine.trim() : '';
    const patientId = typeof body.patientId === 'string' ? body.patientId.trim() : '';
    const description =
      typeof body.description === 'string' ? body.description.trim() : '';

    if (medicine.length === 0 || patientId.length === 0) {
      return res.status(400).json({
        message: 'Campos obrigatórios: medicine e patientId',
      });
    }

    if (!UUID_REGEX.test(patientId)) {
      return res.status(400).json({
        message: 'patientId inválido. Deve ser um UUID válido.',
      });
    }

    // 3. Confirma médico autenticado
    const doctor = await prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        professionalType: true,
        professionalId: true,
        professionalState: true,
      },
    });

    if (!doctor) {
      return res.status(404).json({
        message: 'Médico não encontrado',
      });
    }

    if (doctor.professionalType !== 'MEDICO') {
      return res.status(403).json({
        message: 'Apenas médicos podem criar receitas',
      });
    }

    // 4. Confirma paciente existente
    const patientExists = await prisma.user.findUnique({
      where: { id: patientId },
      select: { id: true, name: true },
    });

    if (!patientExists) {
      return res.status(404).json({
        message: 'Paciente não encontrado',
      });
    }

    // 5. Formata nome de exibição do médico
    const doctorName =
      doctor.professionalId && doctor.professionalState
        ? 'Dr(a). ' +
        doctor.name +
        ' - CRM ' +
        doctor.professionalId +
        '/' +
        doctor.professionalState
        : 'Dr(a). ' + doctor.name;

    // 6. Cria receita
    const prescription = await prisma.prescription.create({
      data: {
        medicine,
        description: description.length > 0 ? description : null,
        patientId,
        doctorId: userId,
        doctorName,
        status: PrescriptionStatus.ACTIVE,
      },
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

    console.log(
      '[PRESCRIPTION] Receita criada: ' + prescription.id + ' por ' + doctorName
    );

    return res.status(201).json({
      message: 'Receita criada com sucesso',
      data: prescription,
    });
  } catch (error) {
    console.error('[PRESCRIPTION] Erro ao criar receita:', error);

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
 * Lista todas as receitas do sistema.
 */
export const getPrescriptions = async (_req: Request, res: Response): Promise<Response> => {
  try {
    const prescriptions = await prisma.prescription.findMany({
      orderBy: {
        createdAt: 'desc',
      },
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

    return res.status(200).json({
      message: 'Receitas encontradas',
      count: prescriptions.length,
      data: prescriptions,
    });
  } catch (error) {
    console.error('[PRESCRIPTION] Erro ao buscar receitas:', error);

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
 * Lista receitas do usuário autenticado com filtro opcional de status.
 */
export const listMyPrescriptions = async (
  req: AuthRequest,
  res: Response
): Promise<Response> => {
  try {
    // 1. Garante autenticação
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({
        message: 'Usuário não autenticado. Faça login para continuar.',
      });
    }

    // 2. Monta filtro base
    const whereClause: Prisma.PrescriptionWhereInput = {
      patientId: userId,
    };

    // 3. Aplica filtro de status (se enviado)
    const statusParam = req.query.status;
    if (typeof statusParam !== 'undefined') {
      const parsedStatus = parseStatusParam(statusParam);

      if (!parsedStatus) {
        return res.status(400).json({
          message: 'Status inválido. Use: ACTIVE, EXPIRED ou CANCELLED',
          validOptions: VALID_STATUSES,
        });
      }

      whereClause.status = parsedStatus;
    }

    // 4. Consulta receitas do paciente
    const prescriptions = await prisma.prescription.findMany({
      where: whereClause,
      orderBy: {
        createdAt: 'desc',
      },
      select: {
        id: true,
        medicine: true,
        description: true,
        doctorName: true,
        status: true,
        createdAt: true,
        updatedAt: true,
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

    if (prescriptions.length === 0) {
      return res.status(200).json({
        message: 'Nenhuma receita encontrada',
        data: [],
      });
    }

    console.log(
      '[PRESCRIPTION] ' +
      prescriptions.length +
      ' receita(s) listada(s) para usuário ' +
      userId
    );

    return res.status(200).json({
      message: 'Receitas encontradas com sucesso',
      count: prescriptions.length,
      data: prescriptions,
    });
  } catch (error) {
    console.error('[PRESCRIPTION] Erro ao listar receitas:', error);

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
 * Busca detalhes de uma receita.
 * Apenas o paciente dono da receita pode acessar.
 */
export const getPrescriptionById = async (
  req: AuthRequest,
  res: Response
): Promise<Response> => {
  try {
    // 1. Garante autenticação
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({
        message: 'Usuário não autenticado',
      });
    }

    // 2. Valida id da rota (corrige erro de string | undefined)
    const prescriptionId = parseUuidParam(req.params.id);
    if (!prescriptionId) {
      return res.status(400).json({
        message: 'ID de receita inválido. Deve ser um UUID válido.',
      });
    }

    // 3. Busca receita
    const prescription = await prisma.prescription.findUnique({
      where: { id: prescriptionId },
      select: {
        id: true,
        medicine: true,
        description: true,
        doctorName: true,
        status: true,
        createdAt: true,
        updatedAt: true,
        patientId: true,
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

    if (!prescription) {
      return res.status(404).json({
        message: 'Receita não encontrada',
      });
    }

    // 4. Regra de autorização
    if (prescription.patientId !== userId) {
      return res.status(403).json({
        message: 'Você não tem permissão para acessar esta receita',
      });
    }

    // 5. Remove patientId da resposta
    const { patientId: _patientId, ...prescriptionData } = prescription;

    return res.status(200).json({
      message: 'Receita encontrada',
      data: prescriptionData,
    });
  } catch (error) {
    console.error('[PRESCRIPTION] Erro ao buscar receita:', error);

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
 * Cancela uma receita.
 * Apenas o médico prescritor pode cancelar.
 */
export const cancelPrescription = async (
  req: AuthRequest,
  res: Response
): Promise<Response> => {
  try {
    // 1. Garante autenticação
    const userId = getAuthenticatedUserId(req);
    if (!userId) {
      return res.status(401).json({
        message: 'Usuário não autenticado',
      });
    }

    // 2. Valida id da rota (corrige erro de string | undefined)
    const prescriptionId = parseUuidParam(req.params.id);
    if (!prescriptionId) {
      return res.status(400).json({
        message: 'ID de receita inválido. Deve ser um UUID válido.',
      });
    }

    // 3. Busca receita
    const prescription = await prisma.prescription.findUnique({
      where: { id: prescriptionId },
      select: {
        id: true,
        doctorId: true,
        status: true,
        medicine: true,
      },
    });

    if (!prescription) {
      return res.status(404).json({
        message: 'Receita não encontrada',
      });
    }

    // 4. Apenas o médico prescritor pode cancelar
    if (prescription.doctorId !== userId) {
      return res.status(403).json({
        message: 'Apenas o médico prescritor pode cancelar esta receita',
      });
    }

    // 5. Evita cancelamento repetido
    if (prescription.status === PrescriptionStatus.CANCELLED) {
      return res.status(400).json({
        message: 'Receita já está cancelada',
      });
    }

    // 6. Atualiza status para CANCELLED
    const updatedPrescription = await prisma.prescription.update({
      where: { id: prescriptionId },
      data: {
        status: PrescriptionStatus.CANCELLED,
      },
    });

    console.log('[PRESCRIPTION] Receita cancelada: ' + prescriptionId);

    return res.status(200).json({
      message: 'Receita cancelada com sucesso',
      data: updatedPrescription,
    });
  } catch (error) {
    console.error('[PRESCRIPTION] Erro ao cancelar receita:', error);

    return res.status(500).json({
      message: 'Erro ao cancelar receita',
      error: process.env.NODE_ENV === 'development' ? error : undefined,
    });
  }
};