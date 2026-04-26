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
- `backend/src/routes/user.routes.ts` protege `GET /me` com `authenticateToken` (`backend/src/routes/user.routes.ts`, linhas 15–18).
- Endpoints `/auth/register` e `/auth/login` são legados e retornam 410 Gone (`README.md`, linhas 257–258).

## Segurança

- Tokens não devem ser salvos em `SharedPreferences`.
- `service_role` nunca deve ser usada no frontend.
- As policies RLS devem isolar dados por `auth.uid()` (`README.md`, linhas 275–288).
