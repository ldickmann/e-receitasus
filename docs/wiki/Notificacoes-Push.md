# Notificações Push

O E-ReceitaSUS notifica os usuários por **dois canais complementares**, ambos disparados por mudanças na tabela `RenewalRequest`. Nenhum dado clínico trafega na notificação (LGPD).

## Canal 1 — In-app (Supabase Realtime)

`NotificationProvider` → `NotificationService` assina o Realtime sobre `RenewalRequest` (WebSocket). O enum `NotificationAudience` define o que cada perfil observa:

| Perfil | Observa |
|---|---|
| Paciente | Mudança de status dos próprios pedidos (UPDATE) |
| Enfermeiro | Novas solicitações chegando para triagem (INSERT) |
| Médico | Pedidos triados atribuídos a ele |

O evento (`RenewalNotification`) carrega apenas `renewalRequestId`, `status` e a natureza do evento — nada de PII. O widget `notification_bell.dart` exibe o badge in-app. A inscrição (`start`) é disparada pelas telas após o login (`home_screen`, `doctor_home_screen`, `nurse_home_screen`).

## Canal 2 — Push em background (FCM)

Quando o app está fechado, um **Database Webhook** entrega o push:

```text
UPDATE em RenewalRequest
   │  (trigger notify_renewal_status_change)
   ▼
net.http_post (pg_net)  ──►  Edge Function send-push-notification (Deno)
   │  headers: Authorization (anon, via Vault) + x-webhook-secret (via Vault)
   ▼
relê a linha no banco (service role) ──► resolve 1 destinatário ──► FCM HTTP v1
```

### Regras de roteamento (por status)

| Transição    | Destinatário               | Token lido de            |
| ------------ | -------------------------- | ------------------------ |
| `→ TRIAGED`  | Médico (`doctorUserId`)    | `professionals.fcmToken` |
| `→ PRESCRIBED` | Paciente (`patientUserId`) | `patients.fcmToken`      |
| `→ REJECTED` | Paciente (`patientUserId`) | `patients.fcmToken`      |
| demais       | — (ignorado; o in-app cobre) | —                      |

### Registro do token FCM

`FcmTokenService` (injetado no `AuthProvider`) registra o token do dispositivo após o login, na coluna `fcmToken` de `patients`/`professionals`. O Firebase é inicializado **apenas em Android** no `main.dart`, dentro de `try/catch` — uma falha de configuração nunca impede o app de subir (Web/desktop são alvos de desenvolvimento sem Firebase).

## Garantias de segurança e LGPD

- **Segredo obrigatório:** a Edge Function exige `x-webhook-secret`; sem ele responde `401` (hardening #3 — ver [[Segurança|Seguranca]]).
- **Fonte da verdade no banco:** status e destinatário são relidos da linha pelo `id` (service role) — o corpo do request **não** é confiável.
- **Minimização:** corpo genérico (sem nome de medicamento ou dado clínico); lê o token de **um único** destinatário.
- **Robustez:** destinatário sem token → `200` (skip), nunca erro `500`; falta de segredo no Vault → push não entregue, mas o `UPDATE` da renovação **nunca** é bloqueado (chamada assíncrona via `pg_net`).

## Configuração (operacional)

Segredos — nunca versionados:

```bash
# Supabase Vault (lidos pelo webhook em runtime — migration webhook_secret_from_vault)
select vault.create_secret('<ANON_KEY>',      'edge_anon_key');
select vault.create_secret('<WEBHOOK_SECRET>', 'edge_webhook_secret');

# Edge Function (Supabase Secrets)
supabase secrets set WEBHOOK_SECRET=<igual ao edge_webhook_secret>
supabase secrets set FIREBASE_SERVICE_ACCOUNT="$(cat service-account.json)"
```

Pré-requisitos: extensão `pg_net` habilitada no projeto; `google-services.json` presente no app Android (`frontend/android/app/`). `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` são injetados automaticamente no runtime da function.

> Sem o Vault/secret configurados, o push apenas deixa de ser entregue (`401`) — o fluxo de renovação continua funcionando, com o canal in-app (Realtime) cobrindo o usuário com o app aberto.

## Migrations relacionadas

`add_fcm_token_to_users` · `add_realtime_publication_tables` · `add_push_notification_webhook` · `webhook_secret_from_vault`. Ver [[Banco de Dados e Migrations|Banco-de-Dados-e-Migrations]].

---

Relacionado: [[Arquitetura|Arquitetura]] · [[Segurança|Seguranca]] · [[API REST|API-REST]].
