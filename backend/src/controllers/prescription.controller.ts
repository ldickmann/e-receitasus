import type { Request, Response } from 'express';
import { prisma } from '../utils/prismaClient.js';

export const createPrescription = async (req: Request, res: Response) => {
  try {
    const { medicine, description } = req.body;
    // Criação da receita no banco
    const prescription = await prisma.prescription.create({
      data: {
        medicine,
        description,
        // Em um app real, pegaríamos o ID do usuário autenticado via req.user
      },
    });
    return res.status(201).json(prescription);
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao criar receita' });
  }
};

// NOVO: Listar todas as prescrições
export const getPrescriptions = async (req: Request, res: Response) => {
  try {
    const prescriptions = await prisma.prescription.findMany({
      orderBy: { createdAt: 'desc' },
    });
    return res.status(200).json(prescriptions);
  } catch (error) {
    return res.status(500).json({ error: 'Erro ao buscar prescrições' });
  }
};