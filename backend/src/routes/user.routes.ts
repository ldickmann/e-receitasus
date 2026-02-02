import { Router } from 'express';
import { authenticateToken } from '../middlewares/auth.middleware.js';
import { prisma } from '../utils/prismaClient.js';

const router = Router();

// Rota protegida para obter perfil do usuário
router.get('/me', authenticateToken, async (req, res) => {
  try {
    console.log('userId recebido do middleware:', req.userId);

    if (!req.userId) {
      return res.status(401).json({ message: 'ID do usuário não encontrado no token' });
    }

    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: { 
        id: true, 
        name: true, 
        email: true
      },
    });

    if (!user) {
      return res.status(404).json({ message: 'Usuário não encontrado' });
    }

    return res.status(200).json(user);
  } catch (error) {
    console.error('Erro ao buscar usuário:', error);
    
    return res.status(500).json({ 
      message: 'Erro ao buscar usuário'
    });
  }
});

export default router;