// =============================================================================
// Testes de integração — permissões de funções SECURITY DEFINER via PostgREST
// TASK #253 / PBI #243
//
// Valida o artefato da migration 20260612100000_fix_security_advisor_warnings:
// funções SECURITY DEFINER não devem ser executáveis via /rest/v1/rpc/* pelos
// papéis `anon`/`authenticated`, exceto `search_patients_for_prescription`,
// que mantém GRANT para `authenticated` (uso intencional pelo app Flutter).
//
// Ambiente: requer um PostgREST real (stack `supabase start` local ou projeto
// Supabase remoto). Variáveis necessárias — sem nenhum segredo hardcoded:
//   SUPABASE_URL        ex.: http://127.0.0.1:54321
//   SUPABASE_ANON_KEY   apikey pública (papel anon)
//   SUPABASE_JWT_SECRET segredo HS256 para cunhar o JWT `authenticated`
//   SUPABASE_DB_URL     Postgres SERVIDO pelo PostgREST acima (setup/seed/
//                       catálogo). Fallback: DATABASE_URL — conveniente no
//                       uso local onde ambos apontam para o mesmo banco.
//                       No CI são bancos distintos (container efêmero vs.
//                       projeto Supabase), por isso a variável dedicada.
// Quando ausentes (ex.: container PostgreSQL puro do CI, sem PostgREST), a
// suíte inteira é pulada sem falhar o pipeline.
//
// Estratégia em duas camadas por função:
//   1. HTTP: chamada RPC real via PostgREST. Funções RETURNS trigger nem
//      entram no schema cache do PostgREST (404); quando expostas, o REVOKE
//      produz 42501 → 401/403. O invariante testado é: NUNCA 2xx.
//   2. Catálogo: has_function_privilege() valida o REVOKE/GRANT diretamente —
//      pega regressão de permissão mesmo quando o HTTP responderia 404.
//
// Setup idempotente (apenas em banco descartável — nunca sobrescreve função
// existente): instala as definições versionadas de handle_new_user e
// search_patients_for_prescription (migration split_user_patients_
// professionals) e um stub de rls_auto_enable (função criada diretamente no
// banco remoto, SEM definição versionada — gap documentado no PBI #245).
// Em seguida aplica a migration fix_security_advisor_warnings inteira, que é
// idempotente (CREATE OR REPLACE + REVOKE/GRANT).
// =============================================================================

import { randomUUID } from "node:crypto";
import { SignJWT } from "jose";
import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

import { readMigrationStatements } from "./helpers/sql.js";

const supabaseUrl = process.env.SUPABASE_URL ?? "";
const anonKey = process.env.SUPABASE_ANON_KEY ?? "";
const jwtSecret = process.env.SUPABASE_JWT_SECRET ?? "";
const securityDbUrl =
  process.env.SUPABASE_DB_URL ?? process.env.DATABASE_URL ?? "";

/** Suíte só roda quando há PostgREST acessível (ver cabeçalho). */
const hasPostgrestEnv =
  supabaseUrl.length > 0 &&
  anonKey.length > 0 &&
  jwtSecret.length > 0 &&
  securityDbUrl.length > 0;
const describeIfPostgrest = hasPostgrestEnv ? describe : describe.skip;

/**
 * Client Prisma próprio apontando para o banco do PostgREST (SUPABASE_DB_URL)
 * — independente do client compartilhado, que usa o DATABASE_URL dos demais
 * testes (no CI, o container efêmero). Instanciado no beforeAll para não
 * abrir conexão quando a suíte é pulada.
 */
let prisma: PrismaClient;

/** Sufixo único por execução — não colide com dados reais nem entre runs. */
const runId = randomUUID();

/** id do profissional seed — também é o `sub` do JWT authenticated. */
const professionalId = randomUUID();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Chama uma função via PostgREST RPC com o bearer token informado. */
function rpc(
  fn: string,
  token: string,
  body: Record<string, unknown> = {}
): Promise<Response> {
  return fetch(`${supabaseUrl}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${token}`,
      "Content-Type": "application/json",
      // Evita keep-alive do undici segurando handles abertos no Jest.
      Connection: "close",
    },
    body: JSON.stringify(body),
  });
}

/** Verifica no catálogo se um papel tem EXECUTE na função indicada. */
async function hasExecutePrivilege(
  role: "anon" | "authenticated",
  signature: string
): Promise<boolean> {
  const rows = await prisma.$queryRaw<Array<{ ok: boolean }>>`
    SELECT has_function_privilege(${role}::name, ${signature}, 'EXECUTE') AS "ok"`;
  return rows[0]?.ok === true;
}

/** Verifica se a função existe em public (qualquer assinatura). */
async function functionExists(name: string): Promise<boolean> {
  const rows = await prisma.$queryRaw<Array<{ exists: boolean }>>`
    SELECT EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = ${name}
    ) AS "exists"`;
  return rows[0]?.exists === true;
}

/**
 * Definição versionada de handle_new_user (migration
 * 20260421000000_split_user_patients_professionals, PASSO 9), sem o trigger
 * em auth.users — aqui interessa apenas a superfície de permissão da função.
 */
const HANDLE_NEW_USER_SQL = `
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_type  TEXT;
  v_fname TEXT;
  v_lname TEXT;
  v_name  TEXT;
BEGIN
  v_type  := COALESCE(NULLIF(NEW.raw_user_meta_data->>'professional_type', ''), 'ADMINISTRATIVO');
  v_fname := NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), '');
  v_lname := NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), '');
  v_name  := COALESCE(
    NULLIF(TRIM(NEW.raw_user_meta_data->>'name'), ''),
    TRIM(COALESCE(v_fname, '') || ' ' || COALESCE(v_lname, ''))
  );

  IF v_type = 'PACIENTE' THEN
    INSERT INTO public.patients (id, email, name, "firstName", "lastName", "updatedAt")
    VALUES (NEW.id::TEXT, NEW.email, v_name, v_fname, v_lname, NOW())
    ON CONFLICT (id) DO NOTHING;
  ELSE
    INSERT INTO public.professionals (id, email, name, "firstName", "lastName", "professionalType", "updatedAt")
    VALUES (NEW.id::TEXT, NEW.email, v_name, v_fname, v_lname, v_type::"ProfessionalType", NOW())
    ON CONFLICT (id) DO NOTHING;
  END IF;

  RETURN NEW;
END;
$$`;

/**
 * Stub de rls_auto_enable: a função real é um event trigger criado
 * diretamente no banco remoto e NÃO possui definição versionada em
 * prisma/migrations (gap a documentar — PBI #245). O corpo nunca executa
 * nos testes; apenas a superfície de permissão (REVOKE) é exercitada.
 */
const RLS_AUTO_ENABLE_STUB_SQL = `
CREATE FUNCTION public.rls_auto_enable()
RETURNS event_trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  NULL;
END;
$$`;

/**
 * Definição versionada de search_patients_for_prescription (migration
 * 20260421000000_split_user_patients_professionals, PASSO 12).
 */
const SEARCH_PATIENTS_SQL = `
CREATE OR REPLACE FUNCTION public.search_patients_for_prescription(name_query TEXT)
RETURNS TABLE (
  id       TEXT,
  full_name TEXT,
  cpf      TEXT,
  address  TEXT,
  city     TEXT,
  age_text TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER SET search_path TO 'public'
AS $$
DECLARE
  v_caller_unit UUID;
BEGIN
  SELECT p."healthUnitId" INTO v_caller_unit
  FROM public.professionals p
  WHERE p.id = auth.uid()::TEXT
    AND p."professionalType" IN (
      'MEDICO', 'DENTISTA', 'ENFERMEIRO', 'FARMACEUTICO',
      'PSICOLOGO', 'NUTRICIONISTA', 'FISIOTERAPEUTA', 'ASSISTENTE_SOCIAL'
    );

  IF v_caller_unit IS NULL THEN
    RAISE EXCEPTION
      'Acesso negado: apenas profissionais vinculados a uma UBS podem buscar pacientes.';
  END IF;

  RETURN QUERY
  SELECT
    pt.id,
    COALESCE(pt."socialName", pt.name),
    pt.cpf,
    CASE WHEN pt.street IS NOT NULL THEN
      pt.street
        || COALESCE(', ' || pt."streetNumber", '')
        || COALESCE(' - ' || pt.district, '')
    ELSE NULL END,
    pt."addressCity",
    CASE WHEN pt."birthDate" IS NOT NULL THEN
      EXTRACT(YEAR FROM AGE(pt."birthDate"))::TEXT || ' anos'
    ELSE NULL END
  FROM public.patients pt
  WHERE pt."healthUnitId" = v_caller_unit
    AND (
      pt.name        ILIKE '%' || name_query || '%'
      OR pt."socialName" ILIKE '%' || name_query || '%'
    )
  ORDER BY pt.name
  LIMIT 10;
END;
$$`;

/**
 * Instala as funções ausentes (somente em banco descartável) e aplica a
 * migration fix_security_advisor_warnings — o artefato sob teste.
 */
async function ensureSecurityArtifactsInstalled(): Promise<void> {
  if (!(await functionExists("handle_new_user"))) {
    await prisma.$executeRawUnsafe(HANDLE_NEW_USER_SQL);
  }
  if (!(await functionExists("rls_auto_enable"))) {
    await prisma.$executeRawUnsafe(RLS_AUTO_ENABLE_STUB_SQL);
  }
  if (!(await functionExists("search_patients_for_prescription"))) {
    await prisma.$executeRawUnsafe(SEARCH_PATIENTS_SQL);
  }

  // Migration sob teste — idempotente (CREATE OR REPLACE + REVOKE/GRANT).
  const statements = readMigrationStatements(
    "20260612100000_fix_security_advisor_warnings"
  );
  for (const statement of statements) {
    await prisma.$executeRawUnsafe(statement);
  }

  // PostgREST recarrega o schema cache sob demanda via NOTIFY.
  await prisma.$executeRawUnsafe("NOTIFY pgrst, 'reload schema'");
  await new Promise((resolve) => setTimeout(resolve, 1500));
}

// ---------------------------------------------------------------------------
// Suíte
// ---------------------------------------------------------------------------

describeIfPostgrest("permissões de funções SECURITY DEFINER (PostgREST)", () => {
  let authenticatedJwt = "";
  let healthUnitId = "";

  beforeAll(async () => {
    prisma = new PrismaClient({
      adapter: new PrismaPg({ connectionString: securityDbUrl }),
    });

    await ensureSecurityArtifactsInstalled();

    // Seed: profissional MEDICO vinculado a uma UBS — pré-condição do guard
    // interno de search_patients_for_prescription.
    const unit = await prisma.healthUnit.create({
      data: {
        name: `UBS Teste Permissões ${runId}`,
        district: `bairro-teste-${runId}`,
        city: `cidade-teste-${runId}`,
        state: "SC",
      },
    });
    healthUnitId = unit.id;

    await prisma.professional.create({
      data: {
        id: professionalId,
        name: "Medico Teste Permissões",
        email: `security-test-${runId}@teste.local`,
        professionalType: "MEDICO",
        healthUnitId,
      },
    });

    // JWT authenticated cunhado com o segredo do projeto — mesmo formato dos
    // tokens do GoTrue (HS256, role + sub). Nenhum segredo hardcoded.
    authenticatedJwt = await new SignJWT({ role: "authenticated" })
      .setProtectedHeader({ alg: "HS256", typ: "JWT" })
      .setSubject(professionalId)
      .setAudience("authenticated")
      .setIssuedAt()
      .setExpirationTime("15m")
      .sign(new TextEncoder().encode(jwtSecret));
  }, 60000);

  afterAll(async () => {
    await prisma.professional.delete({ where: { id: professionalId } });
    await prisma.healthUnit.delete({ where: { id: healthUnitId } });
    await prisma.$disconnect();
  }, 30000);

  describe("funções de trigger não executáveis via RPC", () => {
    it("block_duplicate_renewal como anon é bloqueada (sem 2xx)", async () => {
      const res = await rpc("block_duplicate_renewal", anonKey);

      expect(res.status).toBeGreaterThanOrEqual(400);
      expect([401, 403, 404]).toContain(res.status);
      expect(
        await hasExecutePrivilege("anon", "public.block_duplicate_renewal()")
      ).toBe(false);
    });

    it("handle_new_user como authenticated é bloqueada (sem 2xx)", async () => {
      const res = await rpc("handle_new_user", authenticatedJwt);

      expect(res.status).toBeGreaterThanOrEqual(400);
      expect([401, 403, 404]).toContain(res.status);
      expect(
        await hasExecutePrivilege("authenticated", "public.handle_new_user()")
      ).toBe(false);
    });

    it("rls_auto_enable como authenticated é bloqueada (sem 2xx)", async () => {
      const res = await rpc("rls_auto_enable", authenticatedJwt);

      expect(res.status).toBeGreaterThanOrEqual(400);
      expect([401, 403, 404]).toContain(res.status);
      expect(
        await hasExecutePrivilege("authenticated", "public.rls_auto_enable()")
      ).toBe(false);
    });
  });

  describe("search_patients_for_prescription — RPC intencional do app", () => {
    it("como authenticated com UBS válida responde 200 com lista", async () => {
      const res = await rpc("search_patients_for_prescription", authenticatedJwt, {
        name_query: `sem-correspondencia-${runId}`,
      });

      expect(res.status).toBe(200);
      const body: unknown = await res.json();
      expect(Array.isArray(body)).toBe(true);
    });

    it("como anon é bloqueada (REVOKE anon/PUBLIC)", async () => {
      const res = await rpc("search_patients_for_prescription", anonKey, {
        name_query: "x",
      });

      expect(res.status).toBeGreaterThanOrEqual(400);
      expect([401, 403, 404]).toContain(res.status);
      expect(
        await hasExecutePrivilege(
          "anon",
          "public.search_patients_for_prescription(text)"
        )
      ).toBe(false);
    });

    it("authenticated mantém EXECUTE no catálogo (GRANT intencional)", async () => {
      expect(
        await hasExecutePrivilege(
          "authenticated",
          "public.search_patients_for_prescription(text)"
        )
      ).toBe(true);
    });
  });
});

// Quando o ambiente não tem PostgREST (CI com Postgres puro), registra um
// teste informativo para o skip ficar visível no relatório do Jest.
if (!hasPostgrestEnv) {
  describe("permissões de funções SECURITY DEFINER (PostgREST)", () => {
    it.skip("suíte pulada: defina SUPABASE_URL, SUPABASE_ANON_KEY e SUPABASE_JWT_SECRET", () => {
      // Intencionalmente vazio — documenta o motivo do skip.
    });
  });
}
