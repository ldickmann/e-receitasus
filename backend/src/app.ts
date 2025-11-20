// Importações de bibliotecas externas
import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';

// Importações locais (extensão .js obrigatória com moduleResolution: nodenext)
import authRoutes from './routes/auth.routes.js';

// Carrega variáveis de ambiente do arquivo .env
dotenv.config();

// Cria instância da aplicação Express
export const app = express();

// Middleware CORS para permitir requisições de diferentes origens
app.use(cors());

// Middleware para parsing de JSON nas requisições
app.use(express.json());

// Rotas de autenticação
app.use('/auth', authRoutes);

// Endpoint de health check para monitoramento
app.get('/health', (_, res) => res.json({ 
  status: 'ok',
  timestamp: new Date().toISOString()
}));

// Exporta a aplicação como default
export default app;
