import type { User } from '@prisma/client';
import { prisma } from '../utils/prismaClient.js';

// =============================================================================
// ARQUITETURA BaaS (Backend as a Service)
//
// Com a adoção do Supabase como BaaS, este repositório ficou enxuto de forma
// intencional. As operações antes feitas aqui agora são resolvidas pelo Supabase:
//
//   - Criação de User: trigger handle_new_user (migration 20260416212543)
//   - Atualização de campos de paciente: Flutter SDK → PostgREST + RLS
//   - Leitura de receitas: Flutter SDK → Supabase Realtime
//
// O Express permanece apenas para operações que exigem lógica server-side
// confiável (ex: POST /prescriptions com validação de canPrescribe).
// =============================================================================

/**
 * Busca usuario publico por id.
 * Utilizada pelo AuthService para retornar o perfil do usuario autenticado
 * a partir do claim `sub` do JWT validado pelo middleware JWKS.
 *
 * @param id UUID textual do usuario (claim sub do token Supabase).
 * @returns Usuario encontrado ou null quando o trigger ainda nao sincronizou.
 */
export async function findPublicUserById(id: string): Promise<User | null> {
  return prisma.user.findUnique({
    where: { id },
  });
}
