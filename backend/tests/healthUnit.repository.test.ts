import { jest } from '@jest/globals';

// =============================================================================
// Testes do healthUnit.repository — TASK #211 / PBI #198
//
// Mockamos `prismaClient` via `jest.unstable_mockModule` (mesmo padrão do
// auth.test.ts) para isolar a camada de repository sem precisar de banco
// real. Validamos:
//   1. Filtro por city + state quando ambos vêm preenchidos.
//   2. Filtro só por city quando state é omitido (Prisma ignora `undefined`).
//   3. Select explícito (sem `*`) — defesa contra over-fetching.
//   4. Ordenação por name ASC.
// =============================================================================

const findManyMock = jest.fn<
  (args: unknown) => Promise<Array<Record<string, unknown>>>
>();

jest.unstable_mockModule('../src/utils/prismaClient.js', () => ({
  prisma: {
    healthUnit: {
      findMany: findManyMock,
    },
  },
}));

// Import dinâmico APÓS o mock — garante que o módulo resolve o prisma falso.
const { findHealthUnitsByCity } = await import(
  '../src/repositories/healthUnit.repository.js'
);

describe('healthUnit.repository — findHealthUnitsByCity', () => {
  beforeEach(() => {
    findManyMock.mockReset();
  });

  it('chama prisma.healthUnit.findMany com city + state e select explícito', async () => {
    findManyMock.mockResolvedValueOnce([
      {
        id: 'unit-1',
        name: 'UBS Centro',
        district: 'Centro',
        city: 'Navegantes',
        state: 'SC',
      },
    ]);

    const result = await findHealthUnitsByCity('Navegantes', 'SC');

    expect(findManyMock).toHaveBeenCalledTimes(1);
    expect(findManyMock).toHaveBeenCalledWith({
      where: { city: 'Navegantes', state: 'SC' },
      // Garante que o select continua explícito — qualquer mudança aqui
      // é review obrigatória (LGPD: anti over-fetching).
      select: {
        id: true,
        name: true,
        district: true,
        city: true,
        state: true,
      },
      orderBy: { name: 'asc' },
    });
    expect(result).toHaveLength(1);
    expect(result[0]?.name).toBe('UBS Centro');
  });

  it('omite state na query quando não fornecido', async () => {
    findManyMock.mockResolvedValueOnce([]);

    await findHealthUnitsByCity('Navegantes');

    // Prisma trata `undefined` como "ignorar campo", então enviamos
    // explicitamente para refletir o comportamento real do código.
    expect(findManyMock).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { city: 'Navegantes', state: undefined },
        orderBy: { name: 'asc' },
      })
    );
  });

  it('retorna lista vazia quando nenhuma UBS é encontrada', async () => {
    findManyMock.mockResolvedValueOnce([]);

    const result = await findHealthUnitsByCity('CidadeInexistente', 'SC');

    expect(result).toEqual([]);
  });
});
