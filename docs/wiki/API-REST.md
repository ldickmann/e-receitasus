# API REST

O backend Express tem poucos endpoints porque prescrições e renovações são operadas diretamente no Supabase PostgREST com RLS (`README.md`, linhas 261–272).

## Base URL local

```text
http://localhost:3333
```

## Endpoints

| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/health` | Não | Health check (`backend/src/app.ts`, linhas 61–64) |
| POST | `/auth/register` | Não | Legado, retorna 410 Gone |
| POST | `/auth/login` | Não | Legado, retorna 410 Gone |
| GET | `/user/me` | Sim | Perfil do usuário autenticado (`backend/src/routes/user.routes.ts`, linhas 15–45) |

## Chamadas diretas ao Supabase

O Flutter acessa diretamente:

| Operação | Recurso |
|---|---|
| Listar prescrições | `prescriptions` |
| Stream realtime | `prescriptions` |
| Emitir prescrição | `prescriptions` |
| Solicitar renovação | `renewal_requests` |
| Triagem | `renewal_requests` |
| Buscar pacientes | RPC `search_patients()` |

Essas operações estão resumidas no `README.md`, linhas 275–287.
