# Stack Tecnológica

## Backend

O backend está em `backend/` e usa Node.js, TypeScript e Express. As dependências principais estão em `backend/package.json`, linhas 21–30.

| Tecnologia | Papel |
|---|---|
| Node.js 22 LTS | Runtime |
| TypeScript ^5.9 | Tipagem estática |
| Express ^4.21 | Servidor HTTP |
| Prisma ORM ^7.7 | Acesso ao PostgreSQL e migrations |
| PostgreSQL/Supabase | Banco de dados |
| jose ^6.2 | Validação JWT/JWKS |
| Jest + Supertest | Testes de integração |
| tsx | Hot reload em desenvolvimento |

## Frontend

O frontend está em `frontend/` e usa Flutter/Dart. As dependências principais estão em `frontend/pubspec.yaml`, linhas 21–65.

| Tecnologia | Papel |
|---|---|
| Flutter SDK >= 3.4.0 | Framework multiplataforma |
| supabase_flutter | Auth, PostgREST e Realtime |
| Provider | Gerenciamento de estado |
| http | Chamadas REST ao backend |
| flutter_secure_storage | Armazenamento seguro de tokens |
| Mockito + build_runner | Mocks para TDD |
| flutter_launcher_icons | Geração de ícone do app |

## Infraestrutura

- Supabase Auth para autenticação.
- Supabase PostgREST + Realtime para prescrições e renovações.
- Row Level Security em tabelas sensíveis.
- GitHub Actions para CI, CD e release Android (`README.md`, linhas 423–460).
