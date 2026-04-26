import { prisma } from '../utils/prismaClient.js';

// =============================================================================
// HealthUnitRepository — camada de acesso a `health_units`
//
// Única camada autorizada a tocar PrismaClient (regra arquitetural do projeto).
// Filtro principal: município do profissional autenticado (`addressCity`).
//
// Observação importante sobre o schema:
// O modelo Prisma `HealthUnit` usa as colunas físicas `city` (texto) e
// `state` (CHAR(2)), NÃO `city_code`. A descrição da TASK #211 cita
// "cityCode" como conceito, mas a tabela real (`@@map("health_units")`)
// não possui essa coluna. Por isso o filtro aqui usa `city` literal.
// Caso futuramente seja adotado um código IBGE (`city_code`), basta trocar
// o `where` mantendo a mesma assinatura pública.
// =============================================================================

/**
 * Shape público de uma UBS retornado para a camada de service.
 *
 * Mantemos apenas os campos necessários para o Dropdown do Flutter
 * (id como FK + name para exibição + district para diferenciar UBS
 * homônimas). LGPD: nenhum campo sensível existe nesta entidade,
 * mas o select explícito é mantido por princípio anti over-fetching.
 */
export interface HealthUnitListItem {
  id: string;
  name: string;
  district: string;
  city: string;
  state: string;
}

// Select centralizado — qualquer alteração de shape passa por aqui,
// evitando divergência entre métodos de leitura.
const HEALTH_UNIT_LIST_SELECT = {
  id: true,
  name: true,
  district: true,
  city: true,
  state: true,
} as const;

/**
 * Lista UBS de uma cidade, opcionalmente refinando por UF.
 *
 * O parâmetro `state` é opcional porque o MVP roda apenas em Navegantes/SC
 * — porém aceitar UF aqui já prepara o código para expansão multi-estado
 * sem mudar a assinatura. Quando ausente, traz todas as cidades
 * homônimas (ex: "São José" existe em SC e SP).
 *
 * Ordenação por `name ASC` é responsabilidade do repository (e não da UI),
 * para garantir consistência de resposta entre clientes (mobile, web, BFF).
 *
 * @param city Nome do município (case-sensitive — espelha `addressCity`).
 * @param state UF opcional com 2 caracteres (ex: "SC").
 * @returns Lista de UBS no formato {@link HealthUnitListItem}.
 */
export async function findHealthUnitsByCity(
  city: string,
  state?: string
): Promise<HealthUnitListItem[]> {
  // Monta o `where` dinamicamente para que UF só entre na query quando
  // realmente fornecida — Prisma trata `undefined` como "ignorar campo".
  return prisma.healthUnit.findMany({
    where: {
      city,
      state,
    },
    select: HEALTH_UNIT_LIST_SELECT,
    orderBy: { name: 'asc' },
  });
}
