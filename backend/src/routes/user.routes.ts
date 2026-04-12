import { Router } from 'express';
import type { Request, Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middlewares/auth.middleware.js';
import {
  AuthServiceError,
  getAuthenticatedUserProfile,
} from '../services/auth.service.js';

const router = Router();

async function getMeHandler(req: AuthRequest, res: Response): Promise<Response> {
  const userId = typeof req.userId === 'string' ? req.userId.trim() : '';

  if (userId.length === 0) {
    return res.status(401).json({
      error: 'Nao autenticado',
      message: 'ID do usuario nao encontrado no token.',
    });
  }

  try {
    const user = await getAuthenticatedUserProfile(userId);

    return res.status(200).json({
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      name: user.name,
      birthDate: user.birthDate,
      email: user.email,
      professionalType: user.professionalType,
      professionalId: user.professionalId,
      professionalState: user.professionalState,
      specialty: user.specialty,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    });
  } catch (error) {
    if (error instanceof AuthServiceError) {
      return res.status(error.statusCode).json({
        error: 'Falha de autenticacao',
        message: error.message,
      });
    }

    console.error('[UserRoutes] Erro inesperado ao buscar perfil:', error);

    return res.status(500).json({
      error: 'Erro interno',
      message: 'Nao foi possivel buscar o perfil do usuario.',
    });
  }
}

router.get('/me', authenticateToken, async (req: Request, res: Response) => {
  return getMeHandler(req as AuthRequest, res);
});

export default router;