import { Router } from 'express';
import type { Request, Response } from 'express';

const router = Router();

// Endpoints legados de autenticacao local. Foram desativados quando o sistema
// migrou para Supabase Auth no frontend. Retornam 410 para sinalizar
// remocao permanente e orientar clientes antigos a atualizar a integracao.
// Handlers ficam inline porque sao triviais e nao justificam um controller
// dedicado — reduz a quantidade de arquivos sem perder clareza.
const LEGACY_MESSAGE =
  'A autenticacao local por senha foi removida. Use Supabase Auth no frontend e envie o access token no header Authorization nas rotas protegidas.';

/**
 * Retorna 410 com payload padronizado para qualquer endpoint legado.
 */
function respondLegacyDisabled(endpoint: string, res: Response): Response {
  return res.status(410).json({
    error: 'Endpoint desativado',
    endpoint,
    message: LEGACY_MESSAGE,
  });
}

router.post('/register', (_req: Request, res: Response) =>
  respondLegacyDisabled('/auth/register', res)
);

router.post('/login', (_req: Request, res: Response) =>
  respondLegacyDisabled('/auth/login', res)
);

export default router;