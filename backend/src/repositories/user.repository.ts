import { prisma } from '../utils/prismaClient.js';

// =============================================================================
// ARQUITETURA BaaS (Backend as a Service)
//
// A tabela publica "User" foi separada em duas tabelas:
//   - public.patients      → professionalType = PACIENTE
//   - public.professionals → todos os demais tipos
//
// Este repositório consulta ambas as tabelas quando necessário.
// Operações de escrita continuam no lado BaaS (PostgREST + RLS via Flutter SDK).
// =============================================================================

/**
 * Campos do perfil público comuns a pacientes e profissionais.
 * Representa o shape retornado pelo endpoint GET /user/me.
 */
export interface PublicProfile {
  id: string;
  firstName: string | null;
  lastName: string | null;
  name: string;
  birthDate: Date | null;
  email: string;
  /** Para pacientes, sempre 'PACIENTE' (derivado, não armazenado na tabela). */
  professionalType: string;
  /** Número de registro no conselho — apenas profissionais. */
  professionalId: string | null;
  /** UF do conselho — apenas profissionais. */
  professionalState: string | null;
  /** Especialidade clínica — apenas profissionais. */
  specialty: string | null;
  /** UBS vinculada — presente em ambos os perfis. */
  healthUnitId: string | null;
  createdAt: Date;
  updatedAt: Date;
}

// Campos comuns retornados pelas duas tabelas. Centralizar o select reduz
// duplicação e garante que ambas exponham o mesmo shape básico (LGPD: sem
// over-fetching de dados sensíveis como CPF/CNS).
const BASE_PROFILE_SELECT = {
  id: true,
  firstName: true,
  lastName: true,
  name: true,
  birthDate: true,
  email: true,
  healthUnitId: true,
  createdAt: true,
  updatedAt: true,
} as const;

const PROFESSIONAL_PROFILE_SELECT = {
  ...BASE_PROFILE_SELECT,
  professionalType: true,
  professionalId: true,
  professionalState: true,
  specialty: true,
} as const;

/**
 * Tipo do registro retornado por patient.findUnique com select base.
 */
type PatientRow = {
  id: string;
  firstName: string | null;
  lastName: string | null;
  name: string;
  birthDate: Date | null;
  email: string;
  healthUnitId: string | null;
  createdAt: Date;
  updatedAt: Date;
};

/**
 * Tipo do registro retornado por professional.findUnique com select estendido.
 */
type ProfessionalRow = PatientRow & {
  professionalType: string;
  professionalId: string | null;
  professionalState: string | null;
  specialty: string | null;
};

/**
 * Converte registro de paciente em PublicProfile.
 * professionalType é derivado: pacientes não armazenam o tipo na tabela.
 */
function toPatientProfile(row: PatientRow): PublicProfile {
  return {
    ...row,
    professionalType: 'PACIENTE',
    professionalId: null,
    professionalState: null,
    specialty: null,
  };
}

/**
 * Converte registro de profissional em PublicProfile.
 */
function toProfessionalProfile(row: ProfessionalRow): PublicProfile {
  return row;
}

/**
 * Busca o perfil público do usuário autenticado.
 *
 * Consulta primeiro `patients` (tabela mais restrita por RLS); se não encontrar,
 * consulta `professionals`. Retorna shape normalizado com professionalType
 * sempre presente.
 *
 * @param id UUID textual do usuário (claim sub do JWT Supabase).
 * @returns Perfil público normalizado ou null se trigger ainda não sincronizou.
 */
export async function findPublicUserById(id: string): Promise<PublicProfile | null> {
  const patient = await prisma.patient.findUnique({
    where: { id },
    select: BASE_PROFILE_SELECT,
  });
  if (patient) return toPatientProfile(patient);

  const professional = await prisma.professional.findUnique({
    where: { id },
    select: PROFESSIONAL_PROFILE_SELECT,
  });
  if (professional) return toProfessionalProfile(professional);

  return null;
}
