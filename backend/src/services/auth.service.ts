import bcrypt from 'bcrypt';
import { createUser, findUserByEmail } from '../repositories/user.repository.js';
import { signToken } from '../utils/jwt.util.js';

const SALT_ROUNDS = 10;

export const registerUser = async ({ name, email, password }: { name: string; email: string; password: string }) => {
  const existing = await findUserByEmail(email);
  if (existing) throw new Error('Email already in use');

  const hash = await bcrypt.hash(password, SALT_ROUNDS);
  const user = await createUser({ name, email, password: hash });

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
