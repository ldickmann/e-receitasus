import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import authRoutes from './routes/auth.routes.js';

dotenv.config();

export const app = express();
app.use(cors());
app.use(express.json());

app.use('/auth', authRoutes);

// health
app.get('/health', (_, res) => res.json({ status: 'ok' }));

export default app;
