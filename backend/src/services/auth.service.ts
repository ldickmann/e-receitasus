import bcrypt from 'bcrypt';
import { createUser, findUserByEmail } from '../repositories/user.repository.js';
import { signToken } from '../utils/jwt.util.js';

const SALT_ROUNDS = 10;

interface RegisterUserPayload {
  name: string;
  email: string;
  password: string;
  professionalType?: string;
  professionalId?: string;
  professionalState?: string;
  specialty?: string;
}

export const registerUser = async (payload: RegisterUserPayload) => {
  const { name, email, password, professionalType, professionalId, professionalState, specialty } = payload;
  
  const existing = await findUserByEmail(email);
  if (existing) throw new Error('Email already in use');

  const hash = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await createUser({ 
    name, 
    email, 
    password: hash,
    professionalType: professionalType || 'ADMINISTRATIVO',
    professionalId,
    professionalState,
    specialty,
  });

  // remove senha antes de retornar
  // @ts-ignore
  const { password: _p, ...rest } = user;
  return rest;
};

export const loginUser = async ({ email, password }: { email: string; password: string }) => {
  const user = await findUserByEmail(email);
  if (!user) throw new Error('Invalid credentials');

  const ok = await bcrypt.compare(password, user.password);
  if (!ok) throw new Error('Invalid credentials');

  const token = signToken({ sub: user.id, email: user.email }, { expiresIn: '7d' } as any);
  return token;
};
