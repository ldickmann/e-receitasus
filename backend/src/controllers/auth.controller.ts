import type { Request, Response } from 'express';

/**
 * Retorno padrao para endpoints legados desativados.
 *
 * @param endpoint Nome do endpoint legado.
 * @returns Payload padrao de desativacao.
 */
function legacyAuthDisabledResponse(endpoint: string) {
  return {
    error: 'Endpoint desativado',
    endpoint,
    message:
      'A autenticacao local por senha foi removida. Use Supabase Auth no frontend e envie o access token no header Authorization nas rotas protegidas.',
  };
}

/**
 * Endpoint legado de registro.
 * Mantido apenas para compatibilidade retroativa com resposta explicita.
 */
export async function register(_req: Request, res: Response): Promise<Response> {
  return res.status(410).json(legacyAuthDisabledResponse('/auth/register'));
}

/**
 * Endpoint legado de login.
 * Mantido apenas para compatibilidade retroativa com resposta explicita.
 */
export async function login(_req: Request, res: Response): Promise<Response> {
  return res.status(410).json(legacyAuthDisabledResponse('/auth/login'));
}