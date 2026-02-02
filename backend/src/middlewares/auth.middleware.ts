import type { Request, Response, NextFunction } from 'express';
import { verifyToken } from '../utils/jwt.util.js';

// Estende a interface Request para incluir userId
declare global {
  namespace Express {
    interface Request {
      userId?: string;
    }
  }
}

export const authenticateToken = (req: Request, res: Response, next: NextFunction) => {
  try {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // "Bearer TOKEN"

    if (!token) {
      return res.status(401).json({ message: 'Token não fornecido' });
    }

    const decoded = verifyToken(token);

    if (!decoded || typeof decoded !== 'object') {
      return res.status(403).json({ message: 'Token inválido ou expirado' });
    }

    // Verifica se o token contém o campo 'sub'
    if (!('sub' in decoded) || typeof decoded.sub !== 'string') {
      return res.status(403).json({ message: 'Token inválido: campo "sub" ausente' });
    }

    // Anexa o ID do usuário ao request
    req.userId = decoded.sub;
    next();
  } catch (error) {
    console.error('Erro no middleware de autenticação:', error);
    return res.status(500).json({ message: 'Erro ao processar autenticação' });
  }
};