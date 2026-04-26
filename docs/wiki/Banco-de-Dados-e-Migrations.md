# Banco de Dados e Migrations

O backend usa Prisma ORM com PostgreSQL hospedado no Supabase. O schema está em `backend/prisma/schema.prisma`; as migrations ficam em `backend/prisma/migrations/`.

## Migrations

O README lista 20 migrations versionadas, de `init` até `rls_update_own_profile_patients_professionals` (`README.md`, linhas 396–419). Elas cobrem criação de usuários, prescrições, autenticação, RLS, solicitações de renovação, RPC de busca de pacientes, UBSs e separação entre pacientes e profissionais.

## Comandos úteis

```bash
cd backend
npm run prisma:generate
npm run prisma:migrate
npm run prisma:studio
```

Scripts definidos em `backend/package.json`, linhas 14–16, e documentados no `README.md`, linhas 642–654.

## Produção

Em produção, o workflow `main.yml` executa `prisma migrate deploy` no banco Supabase conforme descrito no `README.md`, linhas 440–450.

## Observação sobre `prescriptions`

A tabela `prescriptions` é gerenciada como BaaS via Supabase/PostgREST e RLS, fora do Prisma (`README.md`, linhas 334–337). Por isso, mudanças nela precisam ser documentadas separadamente das migrations Prisma.
