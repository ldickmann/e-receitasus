// Configuração do Jest para TypeScript com ES modules
// Usa CommonJS (.cjs) para compatibilidade em projetos ES modules
module.exports = {
  // Preset para TypeScript com suporte completo a ES modules
  preset: "ts-jest/presets/default-esm",

  // Ambiente de teste Node.js
  testEnvironment: "node",

  // Padrão para encontrar arquivos de teste
  testMatch: ["**/tests/**/*.test.ts"],

  // Limpa mocks automaticamente entre os testes
  clearMocks: true,

  // Não força a saída do processo
  forceExit: false,

  // Trata arquivos .ts como ES modules
  extensionsToTreatAsEsm: [".ts"],

  // Configuração de transform para TypeScript com ES modules
  transform: {
    "^.+\\.tsx?$": [
      "ts-jest",
      {
        useESM: true,
      },
    ],
  },

  // Mapeia imports .js para .ts (resolve problema ES modules)
  moduleNameMapper: {
    "^(\\..*/.*)\\.js$": "$1",
  },
};
