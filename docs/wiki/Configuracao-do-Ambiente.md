# Configuração do Ambiente

## Pré-requisitos

- Node.js 22+
- PostgreSQL 14+ ou projeto Supabase configurado
- Flutter SDK 3.4+

Esses pré-requisitos estão documentados no `README.md`, linhas 571–583.

## Variáveis de ambiente do backend

Copie `backend/.env.example` para `backend/.env` e preencha:

- `DATABASE_URL`: conexão via PgBouncer, porta 6543 (`backend/.env.example`, linhas 7–8)
- `DIRECT_URL`: conexão direta, porta 5432 (`backend/.env.example`, linhas 10–11)
- `SUPABASE_JWT_SECRET`: secret JWT do Supabase (`backend/.env.example`, linhas 13–14)
- `SUPABASE_URL`: URL pública do projeto Supabase (`backend/.env.example`, linhas 16–17)
- `ALLOWED_ORIGINS`: origens permitidas para CORS (`backend/.env.example`, linhas 19–23)

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
