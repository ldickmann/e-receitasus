import type { User } from '@prisma/client';
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
 * Normaliza e valida userId recebido do middleware.
 *
 * @param userId ID vindo do token validado.
 * @returns ID normalizado.
 * @throws AuthServiceError quando invalido.
 */
function normalizeUserId(userId: string): string {
  if (typeof userId !== 'string') {
    throw new AuthServiceError('ID de usuario invalido.', 400);
  }

  const normalized = userId.trim();

  if (normalized.length === 0) {
    throw new AuthServiceError('ID de usuario vazio.', 400);
  }

  return normalized;
}

/**
 * Retorna perfil publico do usuario autenticado.
 * Este servico nao autentica senha e nao emite token.
 *
 * @param userId Claim sub injetada no request.
 * @returns Usuario da tabela publica.
 * @throws AuthServiceError quando usuario nao estiver espelhado na public.User.
 */
export async function getAuthenticatedUserProfile(userId: string): Promise<User> {
  const normalizedUserId = normalizeUserId(userId);

  const user = await findPublicUserById(normalizedUserId);

  if (!user) {
    throw new AuthServiceError(
      'Usuario autenticado nao encontrado na tabela publica. Verifique a trigger de sincronizacao auth.users -> public.User.',
      404
    );
  }

  return user;
}