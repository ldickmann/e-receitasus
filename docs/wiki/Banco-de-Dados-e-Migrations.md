# Banco de Dados e Migrations

O backend usa Prisma ORM para as entidades gerenciadas localmente (diretório `backend/prisma/`). Algumas tabelas sensíveis ao BaaS do Supabase (notadamente `prescriptions`) são gerenciadas fora do Prisma e requerem migrations SQL específicas do Supabase.

## Estrutura

* Schema Prisma: `backend/prisma/schema.prisma` (models: `Patient`, `Professional`, `HealthUnit`, `RenewalRequest`, etc.).
* Migrations Prisma: `backend/prisma/migrations/` (history versionada).
* Tabelas BaaS / PostgREST: `prescriptions` (gerenciada por SQL + RLS no Supabase).

## Histórico de migrations

As migrations do projeto estão versionadas em `backend/prisma/migrations/`. O repositório documenta 26 migrations históricas incluindo `init`, `create_prescription_table`, `add_renewal_requests`, `rls_prescriptions_baas`, `split_user_patients_professionals`, até `seed_health_units_blumenau`.

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
