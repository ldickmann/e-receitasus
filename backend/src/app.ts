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

// Lê as origens permitidas da variável de ambiente ALLOWED_ORIGINS (separadas por vírgula).
// Em produção, ALLOWED_ORIGINS deve conter apenas os domínios do frontend autorizado.
// Em desenvolvimento, se a variável não for definida, nenhuma origem é permitida por padrão —
// força o desenvolvedor a configurar explicitamente, evitando CORS aberto em staging/produção
// (OWASP A05:2021 — Security Misconfiguration).
const allowedOrigins = (process.env.ALLOWED_ORIGINS ?? '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

app.use(
  cors({
    /** Valida cada requisição cross-origin contra a lista de origens configurada. */
    origin: (origin, callback) => {
      // Requisições sem `Origin` (ex: Postman, curl, server-to-server) são permitidas
      // para não bloquear testes locais e chamadas de ferramentas internas.
      if (!origin || allowedOrigins.includes(origin)) {
        return callback(null, true);
      }
      // Origem não autorizada — rejeita sem expor detalhes internos
      callback(new Error('CORS: origem não autorizada'));
    },
    // Necessário para cookies/tokens em requisições cross-origin autenticadas
    credentials: true,
  })
);

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