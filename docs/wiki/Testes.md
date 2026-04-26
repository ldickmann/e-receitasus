# Testes

O projeto adota TDD no backend e no frontend. O README destaca que services Dart expõem interfaces abstratas para mockagem e que o backend usa Jest/Supertest (`README.md`, linhas 180–185 e 616–638).

## Backend

```bash
cd backend
npm test
npm run test:coverage
```

Scripts definidos em `backend/package.json`, linhas 11–13.

A suíte usa Jest com `@swc/jest`, Supertest e banco PostgreSQL temporário em CI (`README.md`, linhas 618–625).

## Frontend

```bash
cd frontend
flutter test
```

A pasta `frontend/test/` contém testes de providers, services, telas, modelos e widgets, incluindo autenticação, cadastro de paciente, prescrição, renovação e triagem.

## Mocks

Para atualizar mocks gerados:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```
