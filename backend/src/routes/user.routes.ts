import { Router } from 'express';
import type { Response } from 'express';
import { authenticateToken, type AuthRequest } from '../middlewares/auth.middleware.js';
import {
  AuthServiceError,
  getAuthenticatedUserProfile,
} from '../services/auth.service.js';

const router = Router();

// Endpoint de perfil do usuario autenticado.
// O handler fica inline porque o middleware `authenticateToken` ja garante
// que `req.userId` esta populado e validado — qualquer trim/normalizacao
// extra aqui seria redundante.
router.get(
  '/me',
  authenticateToken,
  async (req: AuthRequest, res: Response): Promise<Response> => {
    try {
      // userId vem garantido pelo middleware (string nao vazia validada via JWKS)
      const user = await getAuthenticatedUserProfile(req.userId ?? '');

      // Para pacientes: professionalType='PACIENTE' e campos de conselho null.
      // Para profissionais: shape completo com CRM/COREN/specialty.
      return res.status(200).json(user);
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
);

export default router;