# Configuração do Ambiente

## Pré-requisitos

* Node.js 22+
* PostgreSQL 14+ ou projeto Supabase configurado
* Flutter SDK 3.4+

Esses pré-requisitos estão documentados no `README.md`, linhas 571–583.

## Variáveis de ambiente do backend

Copie `backend/.env.example` para `backend/.env` e preencha os valores necessários. Campos importantes:

* `DATABASE_URL`: string de conexão PostgreSQL usada em deploy (`postgresql://USER:PASS@HOST:5432/DB`).
* `DIRECT_URL`: conexão direta sem PgBouncer (quando aplicável).
* `SUPABASE_URL`: URL pública do projeto Supabase (`https://<project-ref>.supabase.co`).
* `ALLOWED_ORIGINS`: origens permitidas para CORS (ex: `http://localhost:8080,https://app.exemplo.com`).

Observação sobre JWT e JWKS:

* O backend **não** usa `SUPABASE_JWT_SECRET` localmente nem armazena segredos: a validação dos tokens é feita contra o endpoint JWKS público do Supabase (`/auth/v1/.well-known/jwks.json`). Não defina `SUPABASE_JWT_SECRET` — o middleware `auth.middleware.ts` resolve as chaves via JWKS.

Ferramentas úteis:

* `supabase` CLI: `npm i -g supabase` ou instalar via Homebrew. Use para deploy de functions e migrations (quando aplicável):

```bash
supabase login
supabase link --project-ref <project-ref>
```

\-- Para deploy de Edge Functions: `supabase functions deploy <name> --project-ref $SUPABASE_PROJECT_ID`.

## Rodar backend

```bash
cd backend
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

Conforme `README.md`, linhas 596–603.

## Rodar frontend

```bash
cd frontend
flutter pub get
flutter run
```

Conforme `README.md`, linhas 606–612.

## Gerar mocks Flutter

```bash
cd frontend
flutter pub run build_runner build --delete-conflicting-outputs
```

Conforme `README.md`, linhas 634–638.
