import { Router } from 'express';
import { login, register } from '../controllers/auth.controller.js';

const router = Router();

/**
 * Rotas legadas de autenticacao local.
 * Permanecem publicadas para retornar 410 e orientar migracao.
 */
router.post('/register', register);
router.post('/login', login);

export default router;