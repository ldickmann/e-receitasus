import { ProfessionalType, type User } from '@prisma/client';
import { prisma } from '../utils/prismaClient.js';

/**
 * Dados aceitos para sincronizacao/atualizacao do perfil publico.
 * Nao contem senha, pois credenciais sao responsabilidade do Supabase Auth.
 *
 * Os campos abaixo de `specialty` sao exclusivos do tipo PACIENTE e sao
 * opcionais para manter compatibilidade com os demais perfis profissionais.
 */
export interface UpsertPublicUserData {
  id: string;
  name: string;
  email: string;
  professionalType?: ProfessionalType;
  professionalId?: string | null;
  professionalState?: string | null;
  specialty?: string | null;

  // --- Campos exclusivos do perfil PACIENTE ---

  /** Cartao Nacional de Saude — max 15 caracteres */
  cns?: string | null;
  /** CPF — 11 digitos sem formatacao */
  cpf?: string | null;
  /** Nome Social — opcional, nao substitui nome civil em documentos */
  socialName?: string | null;
  /** Nome da mae ou, na ausencia, do pai/responsavel legal */
  motherParentName?: string | null;
  /** Cidade de nascimento */
  birthCity?: string | null;
  /** UF de nascimento — 2 caracteres */
  birthState?: string | null;
  /** Sexo conforme declarado pelo paciente */
  gender?: string | null;
  /** Raca/Cor conforme classificacao IBGE */
  ethnicity?: string | null;
  /** Estado civil */
  maritalStatus?: string | null;
  /** Celular com DDD — 11 digitos */
  phone?: string | null;
  /** Escolaridade */
  education?: string | null;
  /** CEP — 8 digitos sem hifen */
  zipCode?: string | null;
  /** Logradouro */
  street?: string | null;
  /** Numero do endereco */
  streetNumber?: string | null;
  /** Complemento opcional */
  complement?: string | null;
  /** Bairro */
  district?: string | null;
  /** Cidade do endereco atual */
  addressCity?: string | null;
  /** UF do endereco atual — 2 caracteres */
  addressState?: string | null;
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
      // Campos de paciente — enviados apenas quando professionalType === PACIENTE
      cns: sanitizeOptionalText(data.cns),
      cpf: sanitizeOptionalText(data.cpf),
      socialName: sanitizeOptionalText(data.socialName),
      motherParentName: sanitizeOptionalText(data.motherParentName),
      birthCity: sanitizeOptionalText(data.birthCity),
      birthState: sanitizeOptionalText(data.birthState),
      gender: sanitizeOptionalText(data.gender),
      ethnicity: sanitizeOptionalText(data.ethnicity),
      maritalStatus: sanitizeOptionalText(data.maritalStatus),
      phone: sanitizeOptionalText(data.phone),
      education: sanitizeOptionalText(data.education),
      zipCode: sanitizeOptionalText(data.zipCode),
      street: sanitizeOptionalText(data.street),
      streetNumber: sanitizeOptionalText(data.streetNumber),
      complement: sanitizeOptionalText(data.complement),
      district: sanitizeOptionalText(data.district),
      addressCity: sanitizeOptionalText(data.addressCity),
      addressState: sanitizeOptionalText(data.addressState),
    },
    create: {
      id: normalizedId,
      name: normalizedName,
      email: normalizedEmail,
      professionalType: data.professionalType ?? ProfessionalType.ADMINISTRATIVO,
      professionalId: sanitizeOptionalText(data.professionalId),
      professionalState: sanitizeOptionalText(data.professionalState),
      specialty: sanitizeOptionalText(data.specialty),
      // Campos de paciente — presentes apenas quando professionalType === PACIENTE
      cns: sanitizeOptionalText(data.cns),
      cpf: sanitizeOptionalText(data.cpf),
      socialName: sanitizeOptionalText(data.socialName),
      motherParentName: sanitizeOptionalText(data.motherParentName),
      birthCity: sanitizeOptionalText(data.birthCity),
      birthState: sanitizeOptionalText(data.birthState),
      gender: sanitizeOptionalText(data.gender),
      ethnicity: sanitizeOptionalText(data.ethnicity),
      maritalStatus: sanitizeOptionalText(data.maritalStatus),
      phone: sanitizeOptionalText(data.phone),
      education: sanitizeOptionalText(data.education),
      zipCode: sanitizeOptionalText(data.zipCode),
      street: sanitizeOptionalText(data.street),
      streetNumber: sanitizeOptionalText(data.streetNumber),
      complement: sanitizeOptionalText(data.complement),
      district: sanitizeOptionalText(data.district),
      addressCity: sanitizeOptionalText(data.addressCity),
      addressState: sanitizeOptionalText(data.addressState),
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