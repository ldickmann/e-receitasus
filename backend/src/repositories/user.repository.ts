import { prisma } from '../utils/prismaClient.js';
import type { ProfessionalType } from '@prisma/client';

interface CreateUserData {
  name: string;
  email: string;
  password: string;
  professionalType?: ProfessionalType | string;
  professionalId?: string;
  professionalState?: string;
  specialty?: string;
}

export const findUserByEmail = async (email: string) => {
  return prisma.user.findUnique({ where: { email } });
};

export const createUser = async (data: CreateUserData) => {
  return prisma.user.create({ 
    data: {
      ...data,
      professionalType: (data.professionalType as ProfessionalType) || 'ADMINISTRATIVO',
    }
  });
};

export const deleteAllUsers = async () => {
  return prisma.user.deleteMany();
};
