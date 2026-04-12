import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';

/**
 * Payload minimo esperado para token de acesso do Supabase.
 */
export interface SupabaseJwtPayload extends JWTPayload {
  sub: string;
  email?: string;
  aud?: string | string[];
  role?: string;
}

/**
 * Cache do resolvedor JWKS remoto.
 */
let jwksResolver: ReturnType<typeof createRemoteJWKSet> | null = null;
let cachedIssuer: string | null = null;

/**
 * Normaliza e valida URL base do Supabase.
 *
 * @param rawUrl Valor bruto da variavel de ambiente.
 * @returns URL validada sem barra final.
 * @throws Error quando formato estiver incorreto.
 */
function normalizeSupabaseUrl(rawUrl: string): string {
  const normalized = rawUrl.trim().replace(/\/+$/, '');

  if (!/^https:\/\/[a-z0-9-]+\.supabase\.co$/i.test(normalized)) {
    throw new Error('SUPABASE_URL invalida. Use: https://<project-ref>.supabase.co');
  }

  return normalized;
}

/**
 * Monta issuer esperado no token do Supabase.
 *
 * @returns Issuer completo.
 * @throws Error quando SUPABASE_URL nao estiver definida.
 */
function getSupabaseIssuer(): string {
  const supabaseUrl = process.env.SUPABASE_URL;

  if (!supabaseUrl) {
    throw new Error('SUPABASE_URL nao configurada no ambiente.');
  }

  return normalizeSupabaseUrl(supabaseUrl) + '/auth/v1';
}

/**
 * Retorna resolvedor JWKS com cache em memoria.
 *
 * @returns Resolvedor para verificacao de assinatura.
 */
function getJwksResolver() {
  const issuer = getSupabaseIssuer();

  if (!jwksResolver || cachedIssuer !== issuer) {
    jwksResolver = createRemoteJWKSet(new URL(issuer + '/.well-known/jwks.json'));
    cachedIssuer = issuer;
  }

  return jwksResolver;
}

/**
 * Valida audience do token.
 *
 * @param aud Claim aud.
 * @returns true quando audiencia incluir authenticated.
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
 * Verifica token emitido pelo Supabase usando JWKS.
 *
 * @param token Access token enviado pelo cliente.
 * @returns Payload validado ou null quando invalido.
 */
export async function verifyToken(token: string): Promise<SupabaseJwtPayload | null> {
  if (typeof token !== 'string' || token.trim().length === 0) {
    return null;
  }

  try {
    const issuer = getSupabaseIssuer();

    const { payload } = await jwtVerify(token, getJwksResolver(), {
      issuer,
      algorithms: ['ES256', 'RS256'],
    });

    if (typeof payload.sub !== 'string' || payload.sub.trim().length === 0) {
      return null;
    }

    if (!isValidAudience(payload.aud)) {
      return null;
    }

    return payload as SupabaseJwtPayload;
  } catch {
    return null;
  }
}

/**
 * Emissao local de JWT foi removida.
 * Tokens devem ser emitidos exclusivamente pelo Supabase Auth.
 */
export function signToken(): never {
  throw new Error('signToken desativado. Use Supabase Auth para emissao de tokens.');
}