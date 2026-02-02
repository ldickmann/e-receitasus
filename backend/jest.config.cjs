/**
 * Configuração do Jest para TypeScript com ES Modules
 *
 * Este arquivo usa CommonJS (.cjs) para compatibilidade com Jest,
 * enquanto o projeto principal usa ES Modules (type: "module" no package.json)
 *
 * @see https://jestjs.io/docs/configuration
 * @see https://kulshekhar.github.io/ts-jest/docs/getting-started/presets
 */

module.exports = {
  // ============================================================
  // PRESET E AMBIENTE
  // ============================================================

  /**
   * Preset do ts-jest otimizado para ES Modules
   * Configura automaticamente o Jest para trabalhar com TypeScript e ESM
   */
  preset: "ts-jest/presets/default-esm",

  /**
   * Ambiente de execução dos testes
   * "node" simula ambiente Node.js (backend)
   */
  testEnvironment: "node",

  // ============================================================
  // DESCOBERTA DE TESTES
  // ============================================================

  /**
   * Padrão glob para localizar arquivos de teste
   * Procura por arquivos .test.ts dentro da pasta tests/
   */
  testMatch: ["**/tests/**/*.test.ts"],

  /**
   * Timeout máximo para cada teste individual (em ms)
   * Ajuste conforme necessidade dos testes (ex: testes E2E podem precisar de mais tempo)
   */
  testTimeout: 10000,

  // ============================================================
  // CONFIGURAÇÃO DE MOCKS E LIMPEZA
  // ============================================================

  /**
   * Limpa automaticamente todos os mocks entre testes
   * Previne vazamento de estado entre testes
   */
  clearMocks: true,

  /**
   * Restaura mocks ao estado original após cada teste
   */
  restoreMocks: true,

  /**
   * Reseta módulos entre testes para evitar cache indesejado
   */
  resetModules: true,

  // ============================================================
  // ES MODULES
  // ============================================================

  /**
   * Extensões de arquivo que devem ser tratadas como ES Modules
   * Necessário para que o Jest processe imports/exports corretamente
   */
  extensionsToTreatAsEsm: [".ts"],

  // ============================================================
  // TRANSFORMAÇÃO DE CÓDIGO
  // ============================================================

  /**
   * Configuração do ts-jest para transpilar TypeScript
   *
   * IMPORTANTE: A configuração foi movida para dentro do array
   * ao invés de usar 'globals' (depreciado desde ts-jest v29)
   */
  transform: {
    "^.+\\.tsx?$": [
      "ts-jest",
      {
        // Habilita suporte a ES Modules
        useESM: true,

        // Configurações do TypeScript para compilação dos testes
        tsconfig: {
          // Usa ES Modules ao invés de CommonJS
          module: "ESNext",

          // Resolução de módulos no estilo Node
          moduleResolution: "node",

          // Permite importações default de módulos CommonJS
          esModuleInterop: true,

          // Permite imports sintéticos (compatibilidade)
          allowSyntheticDefaultImports: true,

          // Permite JavaScript nos arquivos de teste
          allowJs: true,

          // Tipo de saída do compilador
          outDir: "./dist",

          // Diretório raiz dos arquivos TypeScript
          rootDir: "./",
        },

        // Desabilita verificação de tipos para acelerar testes
        // (use 'tsc --noEmit' em CI para validação de tipos)
        isolatedModules: true,
      },
    ],
  },

  // ============================================================
  // MAPEAMENTO DE MÓDULOS
  // ============================================================

  /**
   * Resolve problemas com extensões .js em imports TypeScript
   * e garante que o Prisma Client seja encontrado corretamente
   *
   * Exemplos:
   * - import { User } from './models/user.js' → './models/user'
   * - import { PrismaClient } from '@prisma/client' → node_modules/.prisma/client
   */
  moduleNameMapper: {
    // Remove extensão .js de imports relativos
    "^(\\.\\.?\\/.+)\\.js$": "$1",

    // Mapeia @prisma/client para o client gerado
    "^@prisma/client$": "<rootDir>/node_modules/.prisma/client/index.js",
  },

  // ============================================================
  // EXCLUSÕES E INCLUSÕES
  // ============================================================

  /**
   * Padrões de arquivos/pastas a serem ignorados na transformação
   *
   * Por padrão, node_modules é ignorado, MAS precisamos processar:
   * - .prisma/ (Prisma Client gerado)
   * - @prisma/ (pacotes do Prisma)
   *
   * Regex negativo: ignora tudo EXCETO esses padrões
   */
  transformIgnorePatterns: ["node_modules/(?!(\\.prisma|@prisma)/)"],

  /**
   * Pastas a serem ignoradas completamente pelo Jest
   */
  testPathIgnorePatterns: ["/node_modules/", "/dist/", "/.next/"],

  // ============================================================
  // COBERTURA DE CÓDIGO
  // ============================================================

  /**
   * Arquivos incluídos no relatório de cobertura
   */
  collectCoverageFrom: [
    "src/**/*.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/server.ts",
    "!src/**/*.interface.ts",
    "!src/**/*.type.ts",
  ],

  /**
   * Diretório de saída dos relatórios de cobertura
   */
  coverageDirectory: "coverage",

  /**
   * Formatos de relatório de cobertura
   */
  coverageReporters: ["text", "text-summary", "html", "lcov"],

  /**
   * Limites mínimos de cobertura (opcional)
   * Descomente para forçar cobertura mínima em CI
   */
  // coverageThreshold: {
  //   global: {
  //     branches: 80,
  //     functions: 80,
  //     lines: 80,
  //     statements: 80,
  //   },
  // },

  // ============================================================
  // CONFIGURAÇÕES AVANÇADAS
  // ============================================================

  /**
   * Força o Jest a sair após todos os testes
   * Útil quando há handles abertos (conexões de DB, timers, etc.)
   */
  forceExit: false,

  /**
   * Detecta handles abertos (conexões, timers) que impedem o Jest de finalizar
   * Use com --detectOpenHandles no CLI para depuração
   */
  detectOpenHandles: true,

  /**
   * Máximo de workers paralelos
   * "50%" = usa metade dos cores da CPU
   */
  maxWorkers: "50%",

  /**
   * Modo de exibição dos resultados
   * "verbose" mostra cada teste individual
   */
  verbose: true,

  // ============================================================
  // SETUP/TEARDOWN
  // ============================================================

  /**
   * Arquivos executados ANTES de todos os testes
   * Útil para configurar variáveis de ambiente, mocks globais, etc.
   */
  // setupFiles: ["<rootDir>/tests/setup.ts"],

  /**
   * Arquivos executados APÓS configurar o ambiente de teste
   * Útil para configurar bibliotecas de teste (jest-extended, etc.)
   */
  // setupFilesAfterEnv: ["<rootDir>/tests/setupAfterEnv.ts"],

  /**
   * Arquivo executado ANTES de cada teste
   */
  // globalSetup: "<rootDir>/tests/globalSetup.ts",

  /**
   * Arquivo executado APÓS todos os testes
   * Útil para limpar recursos (fechar DB, etc.)
   */
  // globalTeardown: "<rootDir>/tests/globalTeardown.ts",
};
