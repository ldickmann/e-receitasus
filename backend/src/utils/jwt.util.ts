import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret';

export const signToken = (payload: Record<string, unknown>, opts = {}) => {
  return jwt.sign(payload, JWT_SECRET, { ...(opts as object) });
};

export const verifyToken = (token: string) => {
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (err) {
    return null;
  }
};
