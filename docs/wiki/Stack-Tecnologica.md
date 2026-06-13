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
| @prisma/adapter-pg + pg | Adapter de conexão direta ao Postgres |
| @swc/jest | Compilação TS rápida (Rust) na CI |
| supabase CLI ^2.84 | Migrations e deploy de Edge Functions |
| Deno (Supabase Edge) | Runtime das Edge Functions (`send-push-notification`, `health-check`) |

## Frontend

O frontend está em `frontend/` e usa Flutter/Dart. As dependências principais estão em `frontend/pubspec.yaml`, linhas 21–65.

| Tecnologia | Papel |
|---|---|
| Flutter SDK >= 3.4.0 | Framework multiplataforma |
| supabase_flutter | Auth, PostgREST e Realtime |
| firebase_core ^4.10 | Inicialização do Firebase (Android) |
| firebase_messaging ^16.3 | Recebimento de push (FCM) |
| Provider | Gerenciamento de estado |
| http | Chamadas REST ao backend |
| flutter_secure_storage | Armazenamento seguro de tokens |
| Mockito + build_runner | Mocks para TDD |
| flutter_launcher_icons | Geração de ícone do app |

## Infraestrutura

- Supabase Auth para autenticação.
- Supabase PostgREST + Realtime para prescrições e renovações.
- Row Level Security em tabelas sensíveis.
- Edge Functions (Deno) para push FCM e health-check.
- Firebase Cloud Messaging para notificações push em background.
- GitHub Actions para CI, CD e release Android.

## Integrações externas

| Integração | Papel |
|---|---|
| [ViaCEP](https://viacep.com.br/) | Auto-preenchimento de logradouro, bairro, cidade e UF a partir do CEP. Consumido pelo frontend via `IViaCepService` (`frontend/lib/services/via_cep_service.dart`) — interface abstrata para suportar mocks em testes. Em produção a implementação `ViaCepService` é injetada como `const`. |
| [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging) | Entrega de push (HTTP v1). A Edge Function `send-push-notification` assina o token com a conta de serviço (`FIREBASE_SERVICE_ACCOUNT`) e envia ao dispositivo. Ver [[Notificações Push\|Notificacoes-Push]]. |
