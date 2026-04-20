import type { PublicProfile } from '../repositories/user.repository.js';
import { findPublicUserById } from '../repositories/user.repository.js';

/**
 * Erro de servico com status HTTP associado.
 */
export class AuthServiceError extends Error {
  public readonly statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = 'AuthServiceError';
    this.statusCode = statusCode;
  }
}

/**
 * Retorna perfil publico do usuario autenticado.
 * O middleware ja garante que userId é string não vazia validada via JWKS,
 * portanto não repetimos normalização aqui (boundary validation).
 *
 * @param userId Claim sub injetada no request pelo authenticateToken.
 * @returns Perfil normalizado com professionalType sempre presente.
 * @throws AuthServiceError 404 quando usuario nao estiver espelhado em nenhuma tabela publica.
 */
export async function getAuthenticatedUserProfile(userId: string): Promise<PublicProfile> {
  const user = await findPublicUserById(userId);

  if (!user) {
    throw new AuthServiceError(
      'Usuario autenticado nao encontrado nas tabelas publicas. Verifique a trigger de sincronizacao auth.users -> patients/professionals.',
      404
    );
  }

  return user;
}