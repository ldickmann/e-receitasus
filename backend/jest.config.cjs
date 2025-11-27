// Configuração do Jest para TypeScript com ES Modules (arquivo .cjs para compatibilidade)

module.exports = {
  // Preset recomendado do ts-jest com suporte a ESM
  preset: "ts-jest/presets/default-esm",

  // Ambiente de teste
  testEnvironment: "node",

  // Padrão para descobrir testes
  testMatch: ["**/tests/**/*.test.ts"],

  // Limpa mocks entre testes
  clearMocks: true,

  // Não força o processo a sair (ajuda na depuração)
  forceExit: false,

  // Tratar .ts como ESM
  extensionsToTreatAsEsm: [".ts"],

  // Transpila TypeScript usando ts-jest em modo ESM
  transform: {
    "^.+\\.tsx?$": [
      "ts-jest",
      {
        useESM: true,
        tsconfig: "tsconfig.json",
      },
    ],
  },

  // Mapeamentos úteis:
  // - converte imports relativos terminados em .js para sem extensão (evita erro de extensão)
  // - garante que @prisma/client aponte para o client gerado (ESM)
  moduleNameMapper: {
    "^(\\..*/.*)\\.js$": "$1",
    "^@prisma/client$": "<rootDir>/node_modules/.prisma/client/index.js",
  },

  // Não ignorar totalmente o Prisma (o client gerado é ESM e precisa ser transformado)
  // Permite que node_modules/.prisma e @prisma sejam processados pelo transform.
  transformIgnorePatterns: ["node_modules/(?!(\\.prisma|@prisma)/)"],

  // Timeout razoável para testes (ajuste conforme necessário)
  testTimeout: 10000,

  // Diagnósticos do ts-jest desabilitados para acelerar em CI; habilite localmente se precisar
  globals: {
    "ts-jest": {
      diagnostics: false,
      useESM: true,
    },
  },
};
