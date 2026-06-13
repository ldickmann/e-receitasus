# API REST

O backend Express expõe apenas endpoints que encapsulam lógica de negócio não coberta pelo PostgREST do Supabase. Operações de prescrições e renovação (rota principal do domínio) são realizadas diretamente pelo frontend via Supabase (PostgREST + Realtime) e protegidas por RLS.

## Base URL (desenvolvimento)

http://localhost:3333

## Endpoints disponíveis (resumo)

| Método | Rota | Autenticação | Descrição |
|---|---:|:---:|---|
| GET | `/health` | Não | Health check — retorna `{ status, timestamp }` |
| POST | `/auth/register` | Não | Legado — retorna `410 Gone` (mover para Supabase Auth) |
| POST | `/auth/login` | Não | Legado — retorna `410 Gone` |
| GET | `/user/me` | Sim (Bearer JWT) | Retorna perfil do usuário autenticado (Patient ou Professional)
| GET | `/health-units` | **Não (público)** | Lista UBS por município (`city` obrigatório, `state` opcional). Dado público sem PII — carrega na tela de cadastro antes da sessão. Retorna `id/name/district/city/state`; `400` se inválido |

Exemplo: obter perfil autenticado:

```bash
curl -H "Authorization: Bearer <ACCESS_TOKEN>" http://localhost:3333/user/me
```

## Integrações diretas pelo Flutter (Supabase)

O aplicativo Flutter usa o SDK `supabase_flutter` para acessar recursos protegidos por RLS. Operações típicas realizadas diretamente do frontend:

| Operação | Recurso |
|---|---|
| Listar / Stream de prescrições | `prescriptions` (PostgREST + Realtime) |
| Criar prescrição | `prescriptions` |
| Solicitar renovação | `renewal_requests` |
| Triagem / Atualizar status | `renewal_requests` |
| Buscar pacientes | RPC `search_patients_for_prescription()` |
| Stream realtime de renovações (notificações in-app) | `RenewalRequest` |

Regras importantes:

* O frontend nunca usa `service_role` key.
* As policies RLS exigem `auth.uid()` compatível com `patient_user_id` ou `doctor_user_id`.

## Edge Functions (Supabase)

Funções serverless em Deno (`supabase/functions/`), **não** chamadas diretamente pelo app:

| Método | Rota | Autenticação | Descrição |
|---|---|---|---|
| POST | `/functions/v1/send-push-notification` | `x-webhook-secret` | Acionada **só** pelo Database Webhook em `RenewalRequest` (UPDATE); envia push FCM. Relê a linha no banco e ignora o corpo do request. Ver [[Notificações Push\|Notificacoes-Push]] |
| GET | `/functions/v1/health-check` | — | Sonda de disponibilidade das Edge Functions |

## Observações

* Endpoints legados em `/auth/*` estão marcados como `410 Gone` para direcionar a migração ao Supabase Auth.\\
* Use o backend para operações que necessitem de lógica adicional (ex.: agregações, auditoria, chamadas externas que não devem ser feitas pelo cliente).
