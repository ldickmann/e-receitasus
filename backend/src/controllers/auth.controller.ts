import type { Request, Response } from 'express';
import { registerUser, loginUser } from '../services/auth.service.js';

export const register = async (req: Request, res: Response) => {
  try {
    const payload = req.body;
    const user = await registerUser(payload);
    return res.status(201).json(user);
  } catch (err: any) {
    return res.status(400).json({ message: err.message || 'Error' });
  }
};

export const login = async (req: Request, res: Response) => {
  try {
    const { email, password } = req.body;
    const token = await loginUser({ email, password });
    return res.status(200).json({ token });
  } catch (err: any) {
    return res.status(401).json({ message: err.message || 'Unauthorized' });
  }
};
