import type { NextFunction, Request, Response } from 'express';
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';

/**
 * Interface de request autenticada.
 * O middleware injeta userId após validar o JWT emitido pelo Supabase.
 */
export interface AuthRequest extends Request {
  userId?: string;
}

/**
 * Payload esperado do access token do Supabase.
 * Mantemos tipagem explícita para facilitar regras de autorização futuras.
 */
interface SupabaseAccessTokenPayload extends JWTPayload {
  sub: string;
  email?: string;
  role?: string;
  aud?: string | string[];
}

/**
 * Erro de configuração de ambiente.
 * Separar este tipo ajuda a devolver HTTP 500 quando o backend está mal configurado.
 */
class AuthConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'AuthConfigurationError';
  }
}

/**
 * Monta o issuer esperado para os tokens do Supabase.
 * Valida formato da URL no boundary para falhar rapido em config errada.
 *
 * @returns Issuer completo no formato https://<project-ref>.supabase.co/auth/v1
 * @throws AuthConfigurationError quando SUPABASE_URL ausente ou malformada.
 */
function getSupabaseIssuer(): string {
  const rawSupabaseUrl = process.env.SUPABASE_URL;

  if (!rawSupabaseUrl) {
    throw new AuthConfigurationError(
      'SUPABASE_URL não configurada no ambiente do backend.'
    );
  }

  const normalized = rawSupabaseUrl.trim().replace(/\/+$/, '');

  if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(normalized)) {
    throw new AuthConfigurationError(
      'SUPABASE_URL inválida. Use o formato: https://<project-ref>.supabase.co'
    );
  }

  return `${normalized}/auth/v1`;
}

/**
 * Resolvedor JWKS com cache interno por issuer.
 * Encapsulado em IIFE para esconder estado mutável do escopo do módulo —
 * reduz superfície de bugs e elimina duas variáveis `let` globais.
 */
const getRemoteJwksResolver = (() => {
  let cache: { issuer: string; resolver: ReturnType<typeof createRemoteJWKSet> } | null = null;

  return (): ReturnType<typeof createRemoteJWKSet> => {
    const issuer = getSupabaseIssuer();
    if (cache?.issuer !== issuer) {
      const jwksUrl = new URL(`${issuer}/.well-known/jwks.json`);
      cache = { issuer, resolver: createRemoteJWKSet(jwksUrl) };
    }
    return cache.resolver;
  };
})();

/**
 * Extrai token Bearer de forma defensiva.
 *
 * @param authorizationHeader Valor do header Authorization.
 * @returns Token JWT ou null se formato inválido.
 */
function extractBearerToken(authorizationHeader: string | undefined): string | null {
  if (!authorizationHeader) {
    return null;
  }

  const [scheme, token] = authorizationHeader.split(' ');

  if (!scheme || !token) {
    return null;
  }

  if (scheme.toLowerCase() !== 'bearer') {
    return null;
  }

  const normalizedToken = token.trim();
  return normalizedToken.length > 0 ? normalizedToken : null;
}

/**
 * Valida audiência do token.
 * No fluxo padrão do Supabase Auth, esperamos aud contendo authenticated.
 *
 * @param aud Claim audience do token.
 * @returns true quando audiência é válida para chamadas autenticadas.
 */
function isValidAudience(aud: string | string[] | undefined): boolean {
  if (typeof aud === 'string') {
    return aud === 'authenticated';
  }

  if (Array.isArray(aud)) {
    return aud.includes('authenticated');
  }

  return false;
}

/**
 * Verifica assinatura e claims principais do token via JWKS do Supabase.
 *
 * @param token JWT recebido no header.
 * @returns Payload validado e tipado.
 * @throws Error quando token é inválido.
 */
async function verifySupabaseAccessToken(
  token: string
): Promise<SupabaseAccessTokenPayload> {
  const issuer = getSupabaseIssuer();

  const { payload } = await jwtVerify(token, getRemoteJwksResolver(), {
    issuer,
    algorithms: ['ES256', 'RS256'],
  });

  if (typeof payload.sub !== 'string' || payload.sub.trim().length === 0) {
    throw new Error('Token inválido: claim "sub" ausente ou malformado.');
  }

  if (!isValidAudience(payload.aud)) {
    throw new Error(
      'Token inválido: audiência não autorizada para acesso autenticado.'
    );
  }

  return payload as SupabaseAccessTokenPayload;
}

/**
 * Middleware de autenticação para arquitetura híbrida.
 *
 * Fluxo:
 * 1. Extrai Bearer token.
 * 2. Valida assinatura com JWKS do Supabase.
 * 3. Confere claims mínimas.
 * 4. Injeta req.userId para as camadas de controller/service.
 */
export const authenticateToken = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<Response | void> => {
  const token = extractBearerToken(req.headers.authorization);

  if (!token) {
    return res.status(401).json({
      error: 'Acesso negado',
      message:
        'Token de autenticação ausente ou header Authorization fora do padrão Bearer.',
    });
  }

  try {
    const decoded = await verifySupabaseAccessToken(token);

    req.userId = decoded.sub;
    return next();
  } catch (error) {
    if (error instanceof AuthConfigurationError) {
      console.error('[AuthMiddleware] Erro de configuração:', error.message);

      return res.status(500).json({
        error: 'Configuração inválida',
        message:
          'Backend sem configuração correta para validar JWT do Supabase.',
      });
    }

    console.error('[AuthMiddleware] Erro na validação do token JWT:', error);

    return res.status(403).json({
      error: 'Acesso não autorizado',
      message: 'A sessão expirou ou o token fornecido é inválido/corrompido.',
    });
  }
};