# Autenticação e Autorização

A autenticação é delegada ao Supabase Auth. O backend Express atua como resource server e valida tokens JWT por JWKS remoto, sem armazenar segredos de sessão (`README.md`, linhas 11–12 e 250–258).

## Fluxo

1. Usuário faz login no Flutter via Supabase Auth.
2. Supabase retorna um access token JWT.
3. O token é armazenado com `flutter_secure_storage`.
4. O Flutter envia chamadas autenticadas com `Authorization: Bearer <token>`.
5. O backend valida o token via JWKS e injeta `req.userId`.

## Backend

- `backend/src/app.ts` registra rotas de autenticação legadas e rota de usuário (`backend/src/app.ts`, linhas 50–55).
- `backend/src/routes/user.routes.ts` protege `GET /me` com `authenticateToken`.
- `GET /health-units` é **público** (sem `authenticateToken`): a lista de UBS é informação pública (sem PII) e precisa carregar na tela de cadastro, antes de existir sessão Supabase. O Flutter envia o `Bearer` apenas quando há sessão (token opcional).
- Endpoints `/auth/register` e `/auth/login` são legados e retornam 410 Gone.

## Segurança

- Tokens não devem ser salvos em `SharedPreferences` (usar `flutter_secure_storage`).
- `service_role` nunca deve ser usada no frontend.
- As policies RLS isolam dados por `auth.uid()`.
- JWT validado **só** com `jose` (JWKS); algoritmos restritos a `ES256`/`RS256` — deps `bcrypt`/`jsonwebtoken` removidas.

Hardening aplicado nesta camada (resumo): INSERT de `prescriptions` exige papel de prescritor; RLS do enfermeiro corrigida + `WITH CHECK`; `legacy_users` removida (LGPD); webhook de push exige segredo via Vault. Modelo completo em [[Segurança|Seguranca]] (relatório em `docs/auditoria-seguranca-e-receitasus.md`).
