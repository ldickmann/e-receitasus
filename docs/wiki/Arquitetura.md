## Arquitetura

O projeto adota uma arquitetura em camadas e um fluxo híbrido de dados: o *frontend* (Flutter) interage diretamente com o Supabase para operações que usam RLS (prescrições, renovação via PostgREST + Realtime), enquanto o *backend* (Express + Prisma) expõe lógica complementar e endpoints que demandam regras de negócio específicas.

### Backend (responsabilidades e localização)

* Código: `backend/src/`
* Camadas:
  * Presentation: rotas e middlewares (`backend/src/routes`, `backend/src/middlewares`)
  * Business: services com regras de domínio (`backend/src/services`)
  * Data: repositórios que encapsulam o `PrismaClient` (`backend/src/repositories`)

Arquivos-chave:

* `backend/src/app.ts` — configuração do Express, middlewares, CORS e health check.
* `backend/src/server.ts` — bootstrap do servidor HTTP.
* `backend/src/middlewares/auth.middleware.ts` — validação de JWT via JWKS e injeção de `req.userId`.
* `backend/src/repositories/*` — único ponto que acessa `PrismaClient`.

Observação prática: alterações nas tabelas gerenciadas pelo Supabase BaaS (ex.: `prescriptions`) não devem ser aplicadas pelo Prisma — documente e aplique via migrations SQL do Supabase.

### Frontend (responsabilidades e localização)

* Código: `frontend/lib/`
* Camadas e pastas principais: `models/`, `providers/`, `services/`, `screens/`, `widgets/`.
* `services/` expõe interfaces (`IXxxService`) para permitir injeção de dependência e facilitar testes com fakes/mocks.

Padrão de injeção: cada service define uma interface e a implementação real é usada por padrão, permitindo sobrescrever em testes (ex.: `IViaCepService`).

### Edge Functions (Deno)

Terceiro runtime, além do Express e do Flutter: funções serverless em `supabase/functions/`.

* `send-push-notification` — acionada por um Database Webhook (`pg_net`, trigger `notify_renewal_status_change`) a cada `UPDATE` em `RenewalRequest`; envia push via FCM. Exige `x-webhook-secret` e relê a linha no banco (service role) — não confia no corpo.
* `health-check` — sonda de disponibilidade.

### Notificações (dois canais)

* **In-app:** `NotificationProvider` → `NotificationService` assina o Supabase Realtime sobre `RenewalRequest`.
* **Push (background):** `RenewalRequest` (UPDATE) → `pg_net` → Edge Function → FCM. O token do dispositivo é registrado por `FcmTokenService`, injetado no `AuthProvider` após o login.

Detalhes em [[Notificações Push|Notificacoes-Push]].

### Fluxo híbrido de dados (resumo)

1. Autenticação e leitura/escrita de prescrições: Flutter ↔ Supabase PostgREST + Realtime (RLS garante isolamento por `auth.uid()`).
2. Endpoints complementares (perfil do usuário, listagem de UBS) e tarefas administrativas: Flutter → Backend (Bearer JWT validado via JWKS).

### Onde fazer mudanças

* Alterações de modelo Prisma: atualizar `backend/prisma/schema.prisma` e criar migration via `prisma migrate`.
* Alterações em tabelas BaaS / RLS (e.g., `prescriptions`): aplicar via SQL migrations do Supabase e documentar no repositório `supabase`/migrations ou na wiki.

***

Consulte também `docs/wiki/Modelagem-de-Dados.md` e `docs/wiki/Banco-de-Dados-e-Migrations.md` para detalhes sobre entidades, enums e caminhos de migration.
