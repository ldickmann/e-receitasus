import { prisma } from '../utils/prismaClient.js';

export const findUserByEmail = async (email: string) => {
  return prisma.user.findUnique({ where: { email } });
};

export const createUser = async (data: { name: string; email: string; password: string }) => {
  return prisma.user.create({ data });
};

export const deleteAllUsers = async () => {
  return prisma.user.deleteMany();
};
