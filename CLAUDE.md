# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**E-ReceitaSUS** is a digital prescription management system for Brazil's public health network (SUS). It manages continuous-use prescriptions with three user roles: Médico/Dentista (issues/renews prescriptions), Enfermeiro (triages renewal requests), and Paciente (requests renewals, tracks status).

Renewal flow: `Paciente → PENDING_TRIAGE → Enfermeiro → TRIAGED → Médico → PRESCRIBED` (or `REJECTED` at either step).

---

## Commands

### Backend (`cd backend`)

```bash
npm run dev           # Hot reload with tsx
npm run build         # Compile TypeScript → dist/
npm test              # Run all Jest integration tests
npm run test:watch    # Watch mode
npm run test:coverage # With coverage report

npx prisma generate   # Regenerate Prisma client after schema changes
npx prisma migrate dev        # Run migrations against local/dev DB
npx prisma studio     # Visual DB browser
```

Run a single test file:
```bash
npm test -- --testPathPattern="healthUnit.routes"
```

### Frontend (`cd frontend`)

```bash
flutter pub get       # Install dependencies
flutter test          # Run all tests
flutter test --reporter=expanded  # Verbose test output
flutter run           # Run on connected device/emulator

# After adding new @GenerateMocks annotations:
dart run build_runner build --delete-conflicting-outputs
```

Run a single test file:
```bash
flutter test test/auth_provider_test.dart
```

---

## Architecture

### Monorepo Structure

```
backend/    Node.js + TypeScript + Express + Prisma
frontend/   Flutter/Dart mobile app
docs/wiki/  Architecture documentation (Portuguese)
```

### Backend

Layered Express app: `routes → services → repositories → Prisma`.

- **`src/app.ts`** — Express setup, CORS (env `ALLOWED_ORIGINS`), route registration.
- **`src/middlewares/auth.middleware.ts`** — Validates Supabase JWTs via JWKS (`SUPABASE_URL`); injects `req.userId` (the Supabase `auth.uid()`).
- **`src/routes/`** — `auth.routes.ts` (legacy, returns 410), `user.routes.ts` (`GET /user/me`), `healthUnit.routes.ts`.
- **`src/repositories/user.repository.ts`** — Queries `public.patients` first, then `public.professionals`, returning a unified `PublicProfile` shape. Write operations are done entirely by the Flutter app via Supabase SDK (BaaS pattern).

**Backend `.env` required variables:**
```
DATABASE_URL=           # PgBouncer pooling URL (port 6543)
DIRECT_URL=             # Direct Postgres URL for migrations (port 5432)
SUPABASE_URL=           # https://<ref>.supabase.co
SUPABASE_JWT_SECRET=    # From Supabase Settings > API
ALLOWED_ORIGINS=        # Comma-separated allowed CORS origins
```

### Frontend

Flutter app using the **Provider** pattern for state management.

- **`lib/main.dart`** — Entry point; initializes Supabase, registers all `ChangeNotifierProvider`s, defines named routes.
- **`lib/providers/`** — `AuthProvider`, `PrescriptionProvider`, `RenewalProvider`, `TriageProvider`, `ThemeProvider`. Each wraps a corresponding service.
- **`lib/services/`** — All implement abstract interfaces (e.g., `IPrescriptionService`, `IAuthService`, `IViaCepService`) to support Mockito mocks in tests.
- **`lib/screens/`** — Role-specific home screens: `HomeScreen` (router), `DoctorHomeScreen`, `NurseHomeScreen`.
- **`lib/config/api_config.dart`** — Backend URL configuration.

**Data access split:**
- Prescriptions and renewal requests: Flutter ↔ **Supabase SDK directly** (PostgREST + Realtime), RLS enforces access.
- User profile (`GET /user/me`) and health units: Flutter ↔ **Express backend** with Bearer JWT.

### Database (Supabase / PostgreSQL)

Key tables with RLS enabled:
- `public.patients` — SUS patients (contains CPF, CNS, health data — LGPD sensitive).
- `public.professionals` — Health professionals and administrative staff.
- `public.prescriptions` — Prescriptions (BaaS only; no backend REST endpoint).
- `public.RenewalRequest` — Renewal requests with status machine.
- `public.health_units` — Health units (UBS) with `max_professionals` capacity.

**Supabase trigger `handle_new_user`**: fires on `auth.users` insert → routes new user to `patients` or `professionals` based on `raw_user_meta_data.professional_type`.

**RPC `search_patients_for_prescription`**: SECURITY DEFINER function; verifies caller is a professional with a `healthUnitId` before returning patient data.

### Testing Strategy

**Backend**: Integration tests in `backend/tests/` hit a real PostgreSQL instance (test container in CI, local DB in dev). JWT verification is mocked via `jest.unstable_mockModule`. Transformer: `@swc/jest` (not ts-jest) — required to avoid OOM in CI.

**Frontend**: Unit + widget tests in `frontend/test/`. Uses `Mockito`-generated mocks (`.mocks.dart` files). `FakeAuthService`/mock services used instead of real Supabase connections. After modifying `@GenerateMocks` annotations, regenerate with `build_runner`.

---

## Commit Convention

Format: `<type>(scope): <description> AB#<task-number>`

Types: `feat`, `fix`, `ci`, `chore`, `docs`, `test`, `refactor`, `perf`

Example: `feat(prescription): adicionar endpoint de cancelamento AB#90`
