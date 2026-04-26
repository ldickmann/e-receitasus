import { jest } from '@jest/globals';

// =============================================================================
// Testes do healthUnit.service — TASK #211 / PBI #198
//
// Mockamos a função do repository para isolar o service. Validamos:
//   1. Delegação ao repository com argumentos sanitizados.
//   2. Validação de borda — city vazio/whitespace lança 400.
//   3. UF é normalizada para uppercase.
//   4. UF vazia (apenas espaços) é tratada como ausente.
// =============================================================================

const findHealthUnitsByCityMock = jest.fn<
  (city: string, state?: string) => Promise<Array<Record<string, unknown>>>
>();

jest.unstable_mockModule('../src/repositories/healthUnit.repository.js', () => ({
  findHealthUnitsByCity: findHealthUnitsByCityMock,
}));

const { listHealthUnitsByCity, HealthUnitServiceError } = await import(
  '../src/services/healthUnit.service.js'
);

describe('healthUnit.service — listHealthUnitsByCity', () => {
  beforeEach(() => {
    findHealthUnitsByCityMock.mockReset();
  });

  it('delega ao repository quando city é válido', async () => {
    const fakeRows = [
      { id: 'u1', name: 'UBS A', district: 'Centro', city: 'Navegantes', state: 'SC' },
    ];
    findHealthUnitsByCityMock.mockResolvedValueOnce(fakeRows);

    const result = await listHealthUnitsByCity('Navegantes', 'SC');

    expect(findHealthUnitsByCityMock).toHaveBeenCalledWith('Navegantes', 'SC');
    expect(result).toBe(fakeRows);
  });

  it('normaliza UF para uppercase', async () => {
    findHealthUnitsByCityMock.mockResolvedValueOnce([]);

    await listHealthUnitsByCity('Navegantes', 'sc');

    expect(findHealthUnitsByCityMock).toHaveBeenCalledWith('Navegantes', 'SC');
  });

  it('trata state apenas com espaços como ausente', async () => {
    findHealthUnitsByCityMock.mockResolvedValueOnce([]);

    await listHealthUnitsByCity('Navegantes', '   ');

    expect(findHealthUnitsByCityMock).toHaveBeenCalledWith('Navegantes', undefined);
  });

  it('faz trim em city antes de delegar', async () => {
    findHealthUnitsByCityMock.mockResolvedValueOnce([]);

    await listHealthUnitsByCity('  Navegantes  ', 'SC');

    expect(findHealthUnitsByCityMock).toHaveBeenCalledWith('Navegantes', 'SC');
  });

  it('lança HealthUnitServiceError 400 quando city é string vazia', async () => {
    await expect(listHealthUnitsByCity('')).rejects.toBeInstanceOf(
      HealthUnitServiceError
    );

    // Reseta para nova asserção do statusCode (a primeira já consumiu o assert).
    try {
      await listHealthUnitsByCity('');
    } catch (error) {
      expect(error).toBeInstanceOf(HealthUnitServiceError);
      expect((error as InstanceType<typeof HealthUnitServiceError>).statusCode).toBe(400);
    }

    // O repository NUNCA deve ser chamado com input inválido — defesa em profundidade.
    expect(findHealthUnitsByCityMock).not.toHaveBeenCalled();
  });

  it('lança HealthUnitServiceError 400 quando city é apenas whitespace', async () => {
    await expect(listHealthUnitsByCity('   ')).rejects.toMatchObject({
      statusCode: 400,
    });
    expect(findHealthUnitsByCityMock).not.toHaveBeenCalled();
  });
});
