# CI/CD e Deploy

O projeto usa GitHub Actions com três workflows independentes, conforme `README.md`, linhas 423–460.

## `ci.yml`

Gatilho: `push` e `pull_request` na branch `develop`.

Jobs:

- `test-backend`: sobe PostgreSQL 16, aplica schema e roda Jest.
- `test-frontend`: instala Flutter stable e roda `flutter test --reporter=expanded`.

## `main.yml`

Gatilho: `push` nas branches `develop` e `main`.

Jobs:

1. `setup-environment`
2. `sync-database`
3. `deploy-functions` — apenas na `main`

## `release.yml`

Gatilho: tags `v*.*.*`, por exemplo `v1.0.7`.

Responsável por buildar APK release assinado e publicar GitHub Release.

## Secrets

| Secret | Uso |
|---|---|
| `DATABASE_URL` | Conexão direta ao banco |
| `SUPABASE_ACCESS_TOKEN` | Supabase CLI |
| `SUPABASE_PROJECT_ID` | Project ref Supabase |
| `KEYSTORE_BASE64` | Keystore Android codificado |
| `KEY_ALIAS` | Alias da chave |
| `STORE_PASSWORD` | Senha do keystore |
| `KEY_PASSWORD` | Senha da chave |

Lista baseada no `README.md`, linhas 462–474.
