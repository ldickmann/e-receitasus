/**
 * Configuração do Jest para TypeScript com @swc/jest
 *
 * Este arquivo usa CommonJS (.cjs) para compatibilidade com Jest,
 * enquanto o projeto principal usa ES Modules (type: "module" no package.json).
 *
 * O @swc/jest substitui o ts-jest como transformador. Por ser escrito em Rust,
 * consome muito menos memória (~70-80% menos heap) e não requer
 * --experimental-vm-modules, resolvendo o OOM em ambientes de CI.
 *
 * @see https://jestjs.io/docs/configuration
 * @see https://swc.rs/docs/usage/jest
 */

module.exports = {
  // ============================================================
  // AMBIENTE
  // ============================================================

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
  // TRANSFORMAÇÃO DE CÓDIGO
  // ============================================================

  /**
   * Configuração do @swc/jest para transpilar TypeScript para CommonJS.
   *
   * Diferente do ts-jest com vm modules, o SWC compila diretamente para CJS
   * sem criar contextos V8 isolados por módulo — eliminando o consumo excessivo
   * de memória que causava OOM no CI.
   */
  transform: {
    "^.+\\.(t|j)sx?$": [
      "@swc/jest",
      {
        jsc: {
          // Habilita parser TypeScript com suporte a decorators
          parser: {
            syntax: "typescript",
            decorators: true,
          },
          // Alvo de saída compatível com Node.js 22
          target: "es2020",
        },
        // Saída em CommonJS — compatível com Jest sem experimental vm modules
        module: {
          type: "commonjs",
        },
      },
    ],
  },

  // ============================================================
  // MAPEAMENTO DE MÓDULOS
  // ============================================================

  /**
   * Resolve problemas com extensões .js em imports TypeScript (padrão NodeNext)
   * e garante que o Prisma Client seja encontrado corretamente.
   *
   * Exemplos:
   * - import { User } from './models/user.js' → './models/user'
   * - import { PrismaClient } from '@prisma/client' → node_modules/.prisma/client
   */
  moduleNameMapper: {
    // Remove extensão .js de imports relativos (convenção TypeScript NodeNext)
    "^(\\.\\.?\\/.+)\\.js$": "$1",

    // Mapeia @prisma/client para o client gerado
    "^@prisma/client$": "<rootDir>/node_modules/.prisma/client/index.js",
  },

  // ============================================================
  // EXCLUSÕES E INCLUSÕES
  // ============================================================

  /**
   * Padrões de arquivos/pastas a serem ignorados na transformação.
   *
   * Regex negativo: ignora tudo EXCETO os pacotes do Prisma,
   * que precisam ser processados pelo SWC.
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
   */
  forceExit: false,

  /**
   * Detecta handles abertos (conexões, timers) que impedem o Jest de finalizar
   */
  detectOpenHandles: true,

  /**
   * Máximo de workers paralelos.
   * Com @swc/jest o consumo de memória é baixo, então paralelismo é seguro.
   */
  maxWorkers: "50%",

  /**
   * Modo de exibição dos resultados
   */
  verbose: true,

  // ============================================================
  // SETUP/TEARDOWN
  // ============================================================

  // setupFiles: ["<rootDir>/tests/setup.ts"],
  // setupFilesAfterEnv: ["<rootDir>/tests/setupAfterEnv.ts"],
  // globalSetup: "<rootDir>/tests/globalSetup.ts",
  // globalTeardown: "<rootDir>/tests/globalTeardown.ts",
};
