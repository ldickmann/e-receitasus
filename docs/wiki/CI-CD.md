# CI/CD e Deploy

Este projeto usa GitHub Actions com três workflows principais localizados em `.github/workflows/`:

* `ci.yml` — Integração contínua (tests backend + frontend)
* `main.yml` — Entrega contínua (sincronização de DB e deploy de Edge Functions)
* `release.yml` — Release Android (build e publicação de APK assinado)

## Visão resumida dos workflows

### `ci.yml`

* Gatilho: `push` e `pull_request` na branch `develop`.
* Jobs:
  * `test-backend`: sobe um serviço PostgreSQL (containers) e executa `prisma db push` + suíte Jest.
  * `test-frontend`: instala Flutter (canal `stable`) e executa `flutter test --reporter=expanded`.

### `main.yml`

* Gatilho: `push` nas branches `develop` e `main`.
* Pipeline em sequência:
  1. `setup-environment`: prepara Node.js 22 e ferramentas (Supabase CLI).
  2. `sync-database`: executa `prisma migrate deploy` contra o banco configurado (variáveis de ambiente obrigatórias).
  3. `deploy-functions`: publica Edge Functions via `supabase functions deploy` (apenas na `main`).

### `release.yml`

* Gatilho: push de tags no formato `v*.*.*` (ex: `v1.0.3`).
* Constrói APK de release, decodifica `KEYSTORE_BASE64`, gera `key.properties` e publica um GitHub Release.

## Variáveis/Secrets necessárias

Configure os seguintes secrets no repositório (Settings → Secrets):

| Secret | Workflow / Uso |
|---|---|
| `DATABASE_URL` | `main.yml` — conexão do deploy de migrations (string de conexão PostgreSQL)
| `SUPABASE_ACCESS_TOKEN` | `main.yml` — autenticação com Supabase CLI
| `SUPABASE_PROJECT_ID` | `main.yml` — project ref do Supabase
| `KEYSTORE_BASE64` | `release.yml` — keystore Android codificado em base64
| `KEY_ALIAS` | `release.yml` — alias da chave de assinatura
| `STORE_PASSWORD` | `release.yml` — senha do keystore
| `KEY_PASSWORD` | `release.yml` — senha da chave

Observações de segurança:

* Nunca exponha secrets em fluxos de trabalho; use apenas o sistema de Secrets do GitHub.
* Para testes em CI que exigem dados, prefira banco efêmero ou mockar integrações (o projeto já mocka validação de JWT nos testes backend).

## Recomendações locais

* Para validar as migrations localmente antes de um push: `cd backend && npm run prisma:migrate`.
* Para publicar Functions localmente (teste): instale `supabase` CLI e use `supabase functions deploy --project-ref $SUPABASE_PROJECT_ID`.

## Checklist para release (manual)

1. Atualizar `CHANGELOG.md` / versão do app.
2. Gerar tag `vX.Y.Z` e dar push da tag.
3. Verificar que `main` passou nos checks do `ci.yml`.
4. Confirmar secrets e permissões do `GITHUB_TOKEN`.

***

Conteúdo alinhado ao `README.md` e às configurações de workflow do repositório.
