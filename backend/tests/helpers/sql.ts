// =============================================================================
// Helpers de SQL para testes de integração (PBI #243)
//
// O Prisma executa apenas um statement por chamada raw ($executeRawUnsafe),
// mas as migrations manuais do projeto contêm múltiplos statements e corpos
// PL/pgSQL dollar-quoted ($$ ... $$) cujos `;` internos não delimitam
// statements. Estes helpers fazem o split correto e a leitura das migrations
// versionadas para aplicação idempotente nos bancos descartáveis (CI/local).
// =============================================================================

import { readFileSync } from "node:fs";
import { join } from "node:path";

/**
 * Divide um arquivo SQL em statements individuais respeitando blocos
 * dollar-quoted ($$ ... $$) e comentários de linha (-- ...).
 */
export function splitSqlStatements(sql: string): string[] {
  const statements: string[] = [];
  let current = "";
  let inDollarBlock = false;
  let inLineComment = false;

  for (let i = 0; i < sql.length; i++) {
    const char = sql[i];
    const pair = sql.slice(i, i + 2);

    if (inLineComment) {
      current += char;
      if (char === "\n") inLineComment = false;
      continue;
    }
    if (pair === "--" && !inDollarBlock) {
      inLineComment = true;
      current += char;
      continue;
    }
    if (pair === "$$") {
      inDollarBlock = !inDollarBlock;
      current += pair;
      i++;
      continue;
    }
    if (char === ";" && !inDollarBlock) {
      if (current.trim().length > 0) statements.push(current.trim());
      current = "";
      continue;
    }
    current += char;
  }
  if (current.trim().length > 0) statements.push(current.trim());
  return statements;
}

/**
 * Lê uma migration versionada em prisma/migrations/<pasta>/migration.sql e
 * devolve seus statements individuais, prontos para $executeRawUnsafe.
 * Assume cwd = backend/ (como o Jest roda via npm test).
 */
export function readMigrationStatements(migrationFolder: string): string[] {
  const migrationPath = join(
    process.cwd(),
    "prisma",
    "migrations",
    migrationFolder,
    "migration.sql"
  );
  return splitSqlStatements(readFileSync(migrationPath, "utf-8"));
}
