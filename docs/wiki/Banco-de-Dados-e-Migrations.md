# Banco de Dados e Migrations

O backend usa Prisma ORM para as entidades gerenciadas localmente (diretório `backend/prisma/`). Algumas tabelas sensíveis ao BaaS do Supabase (notadamente `prescriptions`) são gerenciadas fora do Prisma e requerem migrations SQL específicas do Supabase.

## Estrutura

* Schema Prisma: `backend/prisma/schema.prisma` (models: `Patient`, `Professional`, `HealthUnit`, `RenewalRequest`, etc.).
* Migrations Prisma: `backend/prisma/migrations/` (history versionada).
* Tabelas BaaS / PostgREST: `prescriptions` (gerenciada por SQL + RLS no Supabase).

## Histórico de migrations

As migrations do projeto estão versionadas em `backend/prisma/migrations/`. O repositório documenta **38 migrations** históricas, de `init` e `create_prescription_table` (base), passando por `add_renewal_requests`, `rls_prescriptions_baas` e `split_user_patients_professionals`, até as mais recentes de notificações, segurança e correção de cadastro (abaixo).

### Migrations recentes (27–38)

**Notificações push / Realtime:**

- `add_block_duplicate_renewal_trigger` — trigger anti-duplicidade de pedidos de renovação.
- `add_fcm_token_to_users` — coluna `fcmToken` em `patients`/`professionals`.
- `add_realtime_publication_tables` — publica `RenewalRequest`/`prescriptions` no Realtime.
- `add_push_notification_webhook` — trigger `notify_renewal_status_change` (`pg_net`) que chama a Edge Function de push.

**Hardening de segurança** (ver [[Segurança|Seguranca]]):

- `fix_security_advisor_warnings` — ajustes apontados pelo Security Advisor do Supabase.
- `fix_rls_nurse_policies_renewal_request` + `add_with_check_rls_update_policies` — RLS do enfermeiro corrigida + `WITH CHECK` nos UPDATEs.
- `rls_prescriptions_insert_require_prescriber` — INSERT de `prescriptions` exige `MEDICO`/`DENTISTA`.
- `escape_like_search_patients_rpc` — escape de curingas `LIKE` na RPC de busca.
- `webhook_secret_from_vault` — segredos do webhook lidos do **Supabase Vault** (remove `anon key` hard-coded).
- `drop_legacy_users` — remove a tabela `legacy_users` (minimização LGPD). ⚠️ **Destrutiva** — backup antes de aplicar em produção.

**Correção de cadastro:**

- `fix_patients_street_number_type` — realinha `patients."streetNumber"` para `TEXT` (drift que quebrava **todo** signup de paciente; passa a aceitar `"S/N"`, `"120-A"`).

### Extensões e segredos

- O webhook de push usa a extensão **`pg_net`** (`net.http_post`, assíncrono) e lê segredos do **Supabase Vault** (`edge_anon_key`, `edge_webhook_secret`). Configuração em [[Notificações Push|Notificacoes-Push]].
- Triggers de `RenewalRequest`: `block_duplicate_renewal` (anti-duplicidade) e `notify_renewal_status_change` (push). São PL/pgSQL, fora do schema Prisma.

## Comandos úteis (desenvolvimento)

Para trabalhar localmente:

```bash
cd backend
npm install
npm run prisma:generate   # gera Prisma Client
npm run prisma:migrate    # cria/aplica migrations em ambiente local (migrate dev)
npm run prisma:studio     # abre Prisma Studio
```

Para aplicar migrations em produção (CI):

```bash
cd backend
npm run prisma:generate
npm run prisma:migrate:deploy  # ou o script mapeado para `prisma migrate deploy`
```

> No workflow `main.yml` do CI, usamos `prisma migrate deploy` apontando para o `DATABASE_URL` provido via Secret.

## Tabelas gerenciadas pelo Supabase (BaaS)

Algumas tabelas (ex.: `prescriptions`) e policies RLS são mantidas diretamente no Supabase. Para alterar essas tabelas:

1. Produza uma migration SQL com a alteração (DDL) e versioná‑a no repositório de migrations usado para deploy (documente o arquivo SQL).
2. Atualize/valide as policies RLS e triggers (ex.: roteamento de usuários para `patients`/`professionals`).
3. Teste em ambiente de staging antes do deploy em produção.

## Backups e recomendações

* Sempre backup antes de rodar migrations destrutivas. Use `pg_dump` ou snapshots do Supabase.
* Para alterações em policies RLS, prefira deploy incremental e verificação pós-deploy com contas de teste.
