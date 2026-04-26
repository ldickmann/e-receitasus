# Arquitetura

O projeto segue arquitetura em camadas e um fluxo híbrido de dados: parte das operações passa pelo backend Express e parte é feita diretamente no Supabase pelo Flutter com RLS (`README.md`, linhas 190–238).

## Backend

Local: `backend/src/`

| Camada | Componentes |
|---|---|
| Presentation | Routes e middlewares |
| Business | Services |
| Data | Repositories |
| Database | PostgreSQL/Supabase |

Arquivos importantes:

- `backend/src/app.ts`: configura Express, CORS, JSON, rotas e health check (`backend/src/app.ts`, linhas 14–64).
- `backend/src/server.ts`: inicialização HTTP.
- `backend/src/middlewares/auth.middleware.ts`: autenticação JWT via JWKS.
- `backend/src/repositories/user.repository.ts`: acesso ao Prisma.
- `backend/src/routes/user.routes.ts`: rota `GET /user/me` (`backend/src/routes/user.routes.ts`, linhas 15–45).

## Frontend

Local: `frontend/lib/`

| Camada | Componentes |
|---|---|
| Screens | Telas declarativas |
| Providers | Estado com ChangeNotifier |
| Services | Supabase/Auth/PostgREST/REST |
| Models | Data classes tipadas |

Diretórios principais:

- `models/`: modelos como paciente, profissional, prescrição e renovação.
- `providers/`: `AuthProvider`, `PrescriptionProvider`, `RenewalProvider`, `TriageProvider`, `ThemeProvider`.
- `services/`: autenticação, prescrições e renovações.
- `screens/`: telas por perfil.

## Telas por perfil

Conforme `README.md`, linhas 240–246:

| Perfil | Telas |
|---|---|
| Médico/Dentista | Splash, Login, DoctorHome, PrescriptionType, PrescriptionForm, RenewalPrescription, PrescriptionView |
| Enfermeiro | Splash, Login, NurseHome, TriageDetail |
| Paciente | Splash, Login/Register, PatientRegister, Home, RequestRenewal, History, PrescriptionView |
