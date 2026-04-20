// Bibliotecas externas
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

// Imports locais (extensao .js obrigatoria com moduleResolution: nodenext)
import authRoutes from './routes/auth.routes.js';
import userRoutes from './routes/user.routes.js';
import { requestLogger } from './middlewares/request-logger.middleware.js';

// Carrega variaveis do .env antes de qualquer codigo que dependa de process.env
dotenv.config();

export const app = express();

// Logger de requisicoes registrado primeiro para capturar todas as rotas,
// inclusive preflight CORS (OPTIONS) e respostas 4xx/5xx.
app.use(requestLogger);

// CORS aberto: o frontend Flutter roda em portas dinamicas durante o desenvolvimento.
// Em producao, restringir origins via variavel de ambiente.
app.use(cors());

// Parse de JSON nas requisicoes
app.use(express.json());

// Rotas de autenticacao legadas (POST /auth/register e /auth/login retornam 410).
// O fluxo oficial de cadastro/login e via Supabase Auth no frontend.
app.use('/auth', authRoutes);

// Rotas de usuarios (perfil do usuario autenticado via JWKS)
app.use('/user', userRoutes);

// NOTA: Rotas /prescriptions e /history foram removidas. Toda a persistencia
// e leitura de prescricoes e feita pelo Flutter via Supabase SDK na tabela
// `prescriptions` (BaaS), com RLS controlando acesso por papel.

// Health check para monitoramento (probes externos / uptime)
app.get('/health', (_, res) =>
  res.json({ status: 'ok', timestamp: new Date().toISOString() })
);

export default app;