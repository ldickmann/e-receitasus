import type { Request, Response } from 'express';
import { prisma } from '../utils/prismaClient.js';

export const getHistory = async (req: Request, res: Response) => {
  try {
    // Busca receitas ordenadas por data (mais recentes primeiro)
    const history = await prisma.prescription.findMany({
      orderBy: { createdAt: 'desc' }
    });
    return res.status(200).json(history);
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao buscar histórico' });
  }
};