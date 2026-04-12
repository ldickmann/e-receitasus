import { ProfessionalType, type User } from '@prisma/client';
import { prisma } from '../utils/prismaClient.js';

/**
 * Dados aceitos para sincronizacao/atualizacao do perfil publico.
 * Nao contem senha, pois credenciais sao responsabilidade do Supabase Auth.
 */
export interface UpsertPublicUserData {
  id: string;
  name: string;
  email: string;
  professionalType?: ProfessionalType;
  professionalId?: string | null;
  professionalState?: string | null;
  specialty?: string | null;
}

/**
 * Normaliza texto obrigatorio.
 *
 * @param value Valor recebido.
 * @param fieldName Nome do campo para mensagem de erro.
 * @returns Texto normalizado.
 * @throws Error quando valor vier vazio.
 */
function sanitizeRequiredText(value: string, fieldName: string): string {
  const normalized = value.trim();

  if (normalized.length === 0) {
    throw new Error('Campo obrigatorio invalido: ' + fieldName + '.');
  }

  return normalized;
}

/**
 * Normaliza texto opcional.
 *
 * @param value Valor opcional.
 * @returns Texto trimado ou null.
 */
function sanitizeOptionalText(value: string | null | undefined): string | null {
  if (typeof value !== 'string') {
    return null;
  }

  const normalized = value.trim();
  return normalized.length > 0 ? normalized : null;
}

/**
 * Busca usuario publico por id.
 *
 * @param id UUID textual do usuario.
 * @returns Usuario encontrado ou null.
 */
export async function findPublicUserById(id: string): Promise<User | null> {
  return prisma.user.findUnique({
    where: { id },
  });
}

/**
 * Busca usuario publico por email.
 *
 * @param email Email do usuario.
 * @returns Usuario encontrado ou null.
 */
export async function findPublicUserByEmail(email: string): Promise<User | null> {
  return prisma.user.findUnique({
    where: { email: email.trim().toLowerCase() },
  });
}

/**
 * Cria ou atualiza o perfil publico espelhado do Supabase Auth.
 *
 * @param data Payload de sincronizacao.
 * @returns Registro persistido.
 */
export async function upsertPublicUser(data: UpsertPublicUserData): Promise<User> {
  const normalizedId = sanitizeRequiredText(data.id, 'id');
  const normalizedName = sanitizeRequiredText(data.name, 'name');
  const normalizedEmail = sanitizeRequiredText(data.email, 'email').toLowerCase();

  return prisma.user.upsert({
    where: { id: normalizedId },
    update: {
      name: normalizedName,
      email: normalizedEmail,
      professionalType: data.professionalType ?? ProfessionalType.ADMINISTRATIVO,
      professionalId: sanitizeOptionalText(data.professionalId),
      professionalState: sanitizeOptionalText(data.professionalState),
      specialty: sanitizeOptionalText(data.specialty),
    },
    create: {
      id: normalizedId,
      name: normalizedName,
      email: normalizedEmail,
      professionalType: data.professionalType ?? ProfessionalType.ADMINISTRATIVO,
      professionalId: sanitizeOptionalText(data.professionalId),
      professionalState: sanitizeOptionalText(data.professionalState),
      specialty: sanitizeOptionalText(data.specialty),
    },
  });
}

/**
 * Limpa usuarios da tabela publica.
 * Uso principal: testes automatizados.
 */
export async function deleteAllUsers(): Promise<void> {
  await prisma.user.deleteMany();
}