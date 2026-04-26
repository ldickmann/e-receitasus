import {
  findHealthUnitsByCity,
  type HealthUnitListItem,
} from '../repositories/healthUnit.repository.js';

// =============================================================================
// HealthUnitService — regras de negócio para listagem de UBS
//
// Camada intermediária entre route/controller e repository. Concentra
// validação de input vinda da borda HTTP (boundary validation) para que
// o repository receba apenas dados já normalizados.
// =============================================================================

/**
 * Erro de service com status HTTP associado, idêntico ao padrão usado em
 * `auth.service.ts`. Permite que a route traduza diretamente em resposta
 * HTTP sem precisar inspecionar tipos de erro do Prisma (defesa em
 * profundidade contra vazamento de stack trace — OWASP A05/LGPD).
 */
export class HealthUnitServiceError extends Error {
  public readonly statusCode: number;

  constructor(message: string, statusCode: number) {
    super(message);
    this.name = 'HealthUnitServiceError';
    this.statusCode = statusCode;
  }
}

/**
 * Normaliza um valor textual vindo da query string.
 * Retorna `undefined` para strings vazias ou só de espaços, evitando que
 * o repository receba filtros inúteis (ex: `where: { state: '' }`).
 */
function sanitizeOptional(value: string | undefined): string | undefined {
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

/**
 * Lista UBS pertencentes a uma cidade — usado pela tela de cadastro de
 * profissional e pelas telas de prescrição (4 tipos ANVISA) para popular
 * o `DropdownButtonFormField`.
 *
 * Validação na borda: `city` é obrigatório e não pode ser string vazia
 * após trim. Caso contrário a query traria a tabela inteira (problema de
 * performance e potencial vazamento de UBS de outros municípios).
 *
 * @param city Município obrigatório (vem do `addressCity` do profissional).
 * @param state UF opcional com 2 caracteres (sempre normalizada para uppercase).
 * @returns Lista de UBS ordenada por nome.
 * @throws HealthUnitServiceError 400 quando `city` for vazio/whitespace.
 */
export async function listHealthUnitsByCity(
  city: string,
  state?: string
): Promise<HealthUnitListItem[]> {
  // Boundary validation: o filtro por cidade é obrigatório porque é a
  // única garantia de que o profissional não veja UBS de outras cidades
  // (defesa em profundidade — a UI também filtra, mas confiar na UI é
  // anti-pattern de segurança).
  const sanitizedCity = sanitizeOptional(city);
  if (!sanitizedCity) {
    throw new HealthUnitServiceError(
      'O parametro "city" e obrigatorio para listar UBS.',
      400
    );
  }

  // UF normalizada para uppercase porque o schema usa CHAR(2) e o BD
  // armazena sempre em maiúsculas (convenção brasileira de UF).
  const sanitizedState = sanitizeOptional(state)?.toUpperCase();

  return findHealthUnitsByCity(sanitizedCity, sanitizedState);
}
