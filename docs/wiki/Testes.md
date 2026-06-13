# Testes

O projeto adota TDD no backend e no frontend. As services do Flutter expõem interfaces para facilitar mockagem; o backend usa Jest + Supertest com `@swc/jest` para compilação rápida.

## Backend — executar testes

```bash
cd backend
npm install
npm test
npm run test:coverage
```

Notas:

* A suíte de integração usa um PostgreSQL efêmero em CI. O mock da validação de JWT é feito via `jest.unstable_mockModule` nas fixtures de teste.
* Para rodar um único teste em modo watch: `npm run test:watch`.
* Suítes recentes: `security.permissions.test.ts` (REVOKE/RLS via PostgREST), `renewalRequest.trigger.test.ts` (trigger anti-duplicidade) e o helper `tests/helpers/sql.ts`. `healthUnit.routes.test.ts` cobre a rota **pública** `/health-units`.

## Frontend — executar testes

```bash
cd frontend
flutter pub get
flutter test --reporter=expanded
```

O diretório `frontend/test/` contém unit e widget tests para `AuthProvider`, `AuthService`, `HealthUnitService`, telas de login/registro, fluxo de prescrição e renovação. Suítes recentes: `notification_provider_test.dart` (notificações in-app), `request_renewal_screen_duplicate_test.dart` (feedback de renovação duplicada) e `health_unit_service_test.dart` (token opcional, endpoint público).

## Gerar/atualizar mocks

Se o projeto usa Mockito para gerar mocks, atualize com:

```bash
cd frontend
flutter pub run build_runner build --delete-conflicting-outputs
```

## Dicas para integração/CI

* Em CI, prefira banco temporário (container) e evite conectar ao Supabase real para testes automatizados.
* Verifique que a mock do JWKS/JWT esteja ativa para evitar chamadas externas no teste unitário/integrado.
