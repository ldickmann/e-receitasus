# Segurança

O E-ReceitaSUS passou por uma auditoria de segurança documentada em `docs/auditoria-seguranca-e-receitasus.md` (relatório completo, com PoCs de exploração — mantido fora desta wiki por conter exemplos ofensivos e a `anon key` pública do projeto). Esta página resume o **modelo de segurança** e o **hardening aplicado**.

## Perímetros

| Perímetro | O que cobre | Avaliação |
|---|---|---|
| Backend Express + Prisma | JWKS, CORS, rotas REST, repositórios | Sólido — sem SQL raw, sem vazamento de stack |
| BaaS (Supabase) | RLS nas migrations Prisma, triggers de Auth, RPCs | Foco do hardening — as falhas críticas estavam aqui |
| Edge Functions (Deno) | `send-push-notification`, `health-check` | Endurecido (segredo obrigatório + releitura no banco) |

> Achado estrutural: o backend Express é robusto; o risco real migrou para a camada BaaS (trigger de Auth + RLS + Edge Function). Como as migrations vivem em `backend/prisma/`, elas pertencem ao backend.

## Hardening aplicado

| # | Sev. | Achado | Correção | Onde |
|---|---|---|---|---|
| #2 | Crítico | INSERT de `prescriptions` não exigia papel de prescritor | RLS exige `professionalType IN ('MEDICO','DENTISTA')` | migration `20260612160000` |
| #3 | Alto | Edge Function de push com `WEBHOOK_SECRET` opcional e confiando no corpo | Segredo obrigatório (`401` sem ele) + releitura da linha no banco (service role) | `send-push-notification/index.ts` |
| #4 | Médio | `anon key` hard-coded na migration do webhook | Segredos lidos do **Supabase Vault** em runtime | migration `20260612161000` |
| #5 | Médio | RLS do enfermeiro referenciava tabela renomeada | Policies apontam para `professionals` + `WITH CHECK` | migrations `20260612120000` / `…130000` |
| #6 | Médio | `legacy_users` retinha cópia integral de PII/PHI (LGPD) | `DROP TABLE legacy_users` (minimização de dados) | migration `20260612161500` |
| #7 | Baixo | Dependências mortas `bcrypt`/`jsonwebtoken` | Removidas — JWT validado só com `jose` | `backend/package.json` |
| #8 | Baixo | Wildcards `LIKE` não escapados na RPC de busca | `ILIKE ... ESCAPE` — escapa curingas `%` `_` `\` | migration `20260612160500` |

## Risco aceito (decisão de produto — MVP acadêmico)

O auto-cadastro permite que o usuário declare o próprio `professional_type` (inclusive `MEDICO`), pois o trigger `handle_new_user` confia no `raw_user_meta_data`. Para o MVP acadêmico o risco foi **formalmente aceito**. Mitigação recomendada ao sair do MVP:

- Ler o papel de `app_metadata` (definível só por `service_role`); cadastro público sempre vira `PACIENTE`; **ou**
- Gate de aprovação de profissional por admin (profissional nasce inativo até aprovação).

## Endpoint público consciente

`GET /health-units` **não** exige JWT: a lista de UBS é informação pública (sem PII) e precisa carregar na tela de cadastro, antes de o usuário ter sessão Supabase. O Flutter `HealthUnitService` envia o header `Authorization: Bearer` apenas quando há sessão (token opcional). Ver [[API REST|API-REST]] e [[Autenticação e Autorização|Autenticacao-e-Autorizacao]].

## Itens verificados como seguros

| Item | Resultado |
|---|---|
| Algoritmo JWT `none` | Bloqueado — `jose` restrito a `['ES256','RS256']` |
| Claims `sub`/`aud`/`exp` | Verificados (`aud=authenticated`; `exp`/`iss` pelo `jwtVerify`) |
| BOLA/IDOR no Express | `/user/me` usa `req.userId` do token; `/health-units` é dado público sem PII |
| `$queryRaw` / `$executeRaw` | Inexistentes no código de produção |
| Stack trace em erros | Handlers logam só `error.message` |
| `.env` versionado | Apenas `.env.example`; `.env` no `.gitignore` |

## CORS

Fail-closed por allowlist (`ALLOWED_ORIGINS`): sem origem permitida, nenhuma origem é aceita. A sugestão de `credentials:false` da auditoria **não** foi aplicada (quebra o teste intencional do PBI #178 em `cors.test.ts` e arrisca o cliente Flutter Web, para ganho ínfimo).

---

Relacionado: [[Autenticação e Autorização|Autenticacao-e-Autorizacao]] · [[Notificações Push|Notificacoes-Push]] · [[Banco de Dados e Migrations|Banco-de-Dados-e-Migrations]].
