# 📱 E-ReceitaSUS

> Plataforma full-stack de prescrição médica digital para o SUS — médicos e dentistas emitem receitas diretamente no sistema, pacientes acompanham seu histórico e solicitam renovações, com fluxo de triagem pelo enfermeiro e autorização obrigatória do médico.

## 💡 Sobre o Projeto

O **E-ReceitaSUS** é uma aplicação desenvolvida para modernizar o processo de prescrição médica no contexto do SUS. O sistema **não digitaliza receitas físicas**: em vez disso, disponibiliza formulários digitais para que o **médico ou dentista** possa emitir novas prescrições ou renovar receitas existentes diretamente no sistema.

Do lado do paciente, a plataforma permite **solicitar a renovação de uma receita** por meio de um formulário dedicado, bem como **acompanhar o histórico completo de suas prescrições**. As solicitações de renovação passam por um fluxo estruturado de triagem — enfermeiro avalia a necessidade clínica e, se confirmada, encaminha ao médico responsável pela UBS para autorização final.

A autenticação é delegada ao **Supabase Auth** (BaaS), e o backend atua como **resource server**, validando tokens JWT via JWKS remoto (RS256/ES256) — sem armazenar ou conhecer segredos de sessão.

### 🎯 Problema Resolvido

Elimina papéis físicos e filas desnecessárias, garante rastreabilidade das prescrições, organiza o histórico de medicamentos do paciente SUS e estrutura a comunicação entre pacientes, enfermeiros e médicos dentro da UBS.

---

## 📑 Índice

- [📱 E-ReceitaSUS](#-e-receitasus)
  - [💡 Sobre o Projeto](#-sobre-o-projeto)
    - [🎯 Problema Resolvido](#-problema-resolvido)
  - [📑 Índice](#-índice)
  - [✨ Principais Funcionalidades](#-principais-funcionalidades)
    - [👨‍⚕️ Médico / Dentista (Prescritor)](#️-médico--dentista-prescritor)
    - [🩺 Enfermeiro (Triagem)](#-enfermeiro-triagem)
    - [🧑‍🤝‍🧑 Paciente](#-paciente)
    - [🔐 Infraestrutura](#-infraestrutura)
  - [🔄 Fluxo de Renovação de Receitas](#-fluxo-de-renovação-de-receitas)
    - [📊 Status do Fluxo de Renovação](#-status-do-fluxo-de-renovação)
  - [🛠 Stack Tecnológico](#-stack-tecnológico)
    - [Backend](#backend)
    - [Frontend](#frontend)
    - [Qualidade e Engenharia](#qualidade-e-engenharia)
  - [🏗 Arquitetura](#-arquitetura)
  - [🔐 Autenticação](#-autenticação)
  - [🌐 API — Endpoints](#-api--endpoints)
  - [🧩 Modelagem de Dados](#-modelagem-de-dados)
    - [Entidade `User`](#entidade-user)
    - [Entidade `Prescription`](#entidade-prescription)
    - [Enums](#enums)
    - [Histórico de Migrations (11)](#histórico-de-migrations-11)
  - [⚙️ CI/CD Pipeline](#️-cicd-pipeline)
    - [`ci.yml` — Integração Contínua](#ciyml--integração-contínua)
    - [`main.yml` — Entrega Contínua](#mainyml--entrega-contínua)
    - [Secrets Necessários](#secrets-necessários)
  - [📝 Padrão de Commits](#-padrão-de-commits)
    - [Formato](#formato)
    - [Tipos Aceitos](#tipos-aceitos)
    - [Exemplos](#exemplos)
  - [📂 Estrutura do Projeto](#-estrutura-do-projeto)
  - [🚀 Como Executar](#-como-executar)
    - [Pré-requisitos](#pré-requisitos)
    - [Variáveis de Ambiente — Backend](#variáveis-de-ambiente--backend)
    - [Backend (API)](#backend-api)
    - [Frontend (App Flutter)](#frontend-app-flutter)
  - [🧪 Testes](#-testes)
    - [Backend (Testes)](#backend-testes)
    - [Frontend (Testes)](#frontend-testes)
  - [📜 Scripts do Backend](#-scripts-do-backend)
  - [🎓 Contexto Acadêmico](#-contexto-acadêmico)
  - [👨‍💻 Aluno e Desenvolvedor](#-aluno-e-desenvolvedor)

---

## ✨ Principais Funcionalidades

### 👨‍⚕️ Médico / Dentista (Prescritor)

- Emissão de **novas receitas digitais** com formulário completo conforme padrões ANVISA.
- **Renovação de receitas** existentes: cria uma nova prescrição com os mesmos dados e a data atualizada.
- Visualização em tempo real de todas as receitas emitidas pelo profissional autenticado.
- **Autorização obrigatória** de todas as solicitações de renovação encaminhadas pelo enfermeiro.

### 🩺 Enfermeiro (Triagem)

- Recebimento das solicitações de renovação enviadas pelos pacientes.
- **Triagem clínica**: avalia se a renovação é de fato necessária antes de encaminhar ao médico.
- Encaminhamento da solicitação ao médico responsável pela UBS quando confirmada a necessidade.

### 🧑‍🤝‍🧑 Paciente

- **Solicitação de renovação de receita** via formulário dedicado (restrita a receitas com status elegível).
- Acompanhamento do **status da solicitação** em tempo real.
- **Histórico completo de prescrições** com filtro por status.

### 🔐 Infraestrutura

- Autenticação e autorização com **Supabase Auth** — tokens JWT validados no backend via **JWKS** (RS256/ES256).
- Cadastro separado para **profissionais de saúde** e **pacientes SUS** (com dados como CNS, CPF, nome social, endereço etc.).
- Suporte a todos os **4 tipos de receita regulamentados pela ANVISA**: Branca, Controle Especial, Notificação A (Amarela) e Notificação B (Azul).
- Cancelamento de receita restrito ao médico prescritor.
- Perfis de acesso distintos: Médico, Dentista, Enfermeiro, Paciente e demais profissionais.
- Regras de domínio com tipagem forte no backend (TypeScript + Prisma) e no frontend (Dart).

---

## 🔄 Fluxo de Renovação de Receitas

O processo de renovação é o fluxo central do sistema e envolve **três atores** em sequência obrigatória:

```text
Paciente                 Enfermeiro (UBS)              Médico (UBS)
   │                           │                            │
   │── Solicita renovação ────►│                            │
   │   (formulário digital)    │                            │
   │                           │── Avalia necessidade       │
   │                           │   clínica (triagem)        │
   │                           │                            │
   │                  [Não necessário]                       │
   │◄──────────────── Rejeita ─┤                            │
   │                           │                            │
   │                  [Necessário]                           │
   │                           │── Encaminha ao médico ────►│
   │                           │                            │── Analisa e decide
   │                           │                            │
   │                           │             [Rejeita] ─────►│ RENEWAL_REJECTED
   │                           │                            │
   │                           │             [Aprova] ──────►│ Nova receita ACTIVE
   │◄─────────────────────────────────────── Notifica ──────│
```

### 📊 Status do Fluxo de Renovação

| Status             | Descrição                                                                       | Próxima Ação               |
| ------------------ | ------------------------------------------------------------------------------- | -------------------------- |
| `PENDING_TRIAGE`   | Solicitação enviada pelo paciente, aguardando avaliação do enfermeiro           | Enfermeiro avalia          |
| `PENDING_RENEWAL`  | Triagem aprovada pelo enfermeiro, aguardando autorização do médico              | Médico autoriza ou rejeita |
| `RENEWAL_REJECTED` | Solicitação rejeitada (pelo enfermeiro ou pelo médico)                          | Paciente é notificado      |
| `ACTIVE`           | Médico autorizou — nova prescrição criada com dados idênticos e data atualizada | —                          |

> **Regras de negócio:**
>
> - A renovação **sempre** exige autorização do médico — sem exceções.
> - O médico vinculado ao paciente é o da **UBS (Unidade Básica de Saúde)** onde ele está cadastrado.
> - A renovação gera uma **nova prescrição** (novo `id`, nova `issuedAt`, nova `validUntil`) com os mesmos dados clínicos da original.
> - Apenas receitas com status elegível podem ser alvo de solicitação de renovação pelo paciente.
> - Somente **médicos** e **dentistas** têm autoridade legal para emitir e renovar prescrições (Lei Federal).

---

## 🛠 Stack Tecnológico

### Backend

| Tecnologia               | Versão         | Papel                         |
| ------------------------ | -------------- | ----------------------------- |
| **Node.js**              | 22 LTS         | Runtime                       |
| **TypeScript**           | ^5.9           | Tipagem estática              |
| **Express.js**           | ^4.21          | Framework HTTP                |
| **Prisma ORM**           | ^7.7           | Acesso ao banco               |
| **PostgreSQL**           | (via Supabase) | Banco de dados                |
| **@prisma/adapter-pg**   | ^7.7           | Adapter para conexão direta   |
| **jose**                 | ^6.2           | Validação JWT/JWKS            |
| **Jest** + **Supertest** | ^29 / ^7       | Testes de integração          |
| **@swc/jest**            | ^0.2           | Compilação rápida em CI       |
| **tsx**                  | ^4.19          | Hot reload em desenvolvimento |

### Frontend

| Tecnologia                     | Versão      | Papel                          |
| ------------------------------ | ----------- | ------------------------------ |
| **Flutter** + **Dart**         | SDK ≥ 3.4.0 | Framework mobile               |
| **supabase_flutter**           | ^2.0.0      | Autenticação BaaS              |
| **Provider**                   | 6.1.1       | Gerenciamento de estado        |
| **http**                       | ^1.6.0      | Requisições HTTP à API         |
| **flutter_secure_storage**     | ^4.2.1      | Armazenamento seguro de tokens |
| **shared_preferences**         | 2.2.2       | Preferências locais            |
| **jwt_decoder**                | 2.0.1       | Decodificação de payload JWT   |
| **mockito** + **build_runner** | ^5.4 / ^2.4 | Mocks para TDD                 |

### Qualidade e Engenharia

- **TDD** (Test-Driven Development) no backend e no frontend
- **TypeScript strict mode** com `noUncheckedIndexedAccess` e `exactOptionalPropertyTypes`
- **Migrations versionadas** com Prisma (11 migrations)
- **Arquitetura em camadas** (Presentation → Business → Data → Database)
- **GitHub Actions** com pipelines de CI e CD separados

---

## 🏗 Arquitetura

O projeto segue arquitetura em camadas, garantindo separação de responsabilidades, testabilidade e manutenibilidade:

| Camada           | Componentes                        |
| ---------------- | ---------------------------------- |
| **Presentation** | Rotas, Controllers, Middlewares    |
| **Business**     | Services, regras de domínio        |
| **Data**         | Repositories, Prisma Client        |
| **Database**     | PostgreSQL (hospedado no Supabase) |

**Fluxo de uma requisição autenticada:**

```text
Flutter App
  └─► POST /prescriptions  (Bearer JWT)
        └─► authenticateToken middleware
              └─► jwtVerify via JWKS remoto (Supabase)
                    └─► PrescriptionController
                          └─► Prisma Client → PostgreSQL (Supabase)
```

**Telas por perfil de acesso:**

| Perfil                | Telas disponíveis                                                                                            |
| --------------------- | ------------------------------------------------------------------------------------------------------------ |
| **Médico / Dentista** | Splash → Login → DoctorHomeScreen → PrescriptionTypeScreen → PrescriptionFormScreen → PrescriptionViewScreen |
| **Enfermeiro**        | Splash → Login → NurseHomeScreen (triagem de renovações)                                                     |
| **Paciente**          | Splash → Login / Register → HomeScreen → HistoryScreen → PrescriptionViewScreen                              |

---

## 🔐 Autenticação

- O frontend autentica o usuário via **Supabase Auth** e recebe um access token JWT.
- O backend **não armazena** segredos de sessão — valida o token consultando o endpoint público JWKS do Supabase (`/auth/v1/.well-known/jwks.json`).
- O resolver JWKS é **cacheado em memória** para evitar requisições redundantes.
- O middleware injeta `req.userId` (claim `sub` do token) para uso nos controllers.
- Endpoints legados em `/auth/register` e `/auth/login` retornam `410 Gone`, orientando a migração para o fluxo Supabase.

---

## 🌐 API — Endpoints

**Base URL (desenvolvimento):** `http://localhost:3333`

| Método  | Rota                              | Autenticação | Descrição                                  |
| ------- | --------------------------------- | :----------: | ------------------------------------------ |
| `GET`   | `/health`                         |      ❌      | Health check da API                        |
| `POST`  | `/auth/register`                  |      ❌      | ⚠️ Legado — retorna 410                    |
| `POST`  | `/auth/login`                     |      ❌      | ⚠️ Legado — retorna 410                    |
| `GET`   | `/user/me`                        |      ✅      | Retorna perfil do usuário autenticado      |
| `POST`  | `/prescriptions`                  |      ✅      | Cria receita (apenas MEDICO ou DENTISTA)   |
| `GET`   | `/prescriptions`                  |      ✅      | Lista todas as receitas (administrativo)   |
| `GET`   | `/prescriptions/my`               |      ✅      | Lista receitas do paciente autenticado     |
| `GET`   | `/prescriptions/my?status=ACTIVE` |      ✅      | Filtra receitas por status                 |
| `GET`   | `/prescriptions/:id`              |      ✅      | Retorna receita do paciente autenticado    |
| `PATCH` | `/prescriptions/:id/cancel`       |      ✅      | Cancela receita (apenas médico prescritor) |
| `GET`   | `/history`                        |      ❌      | Histórico de prescrições                   |

> **Status válidos para filtro:** `ACTIVE` · `EXPIRED` · `CANCELLED` · `PENDING_TRIAGE` · `PENDING_RENEWAL` · `RENEWAL_REJECTED`

---

## 🧩 Modelagem de Dados

### Entidade `User`

Concentra profissionais de saúde e pacientes SUS em uma única tabela, diferenciados pelo campo `professionalType`.

| Grupo                   | Campos                                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------------------ |
| **Identificação**       | `id`, `firstName`, `lastName`, `name`, `email`, `birthDate`                                                  |
| **Dados profissionais** | `professionalType`, `professionalId`, `professionalState`, `specialty`                                       |
| **Dados do paciente**   | `cns`, `cpf`, `socialName`, `motherParentName`, `gender`, `ethnicity`, `maritalStatus`, `phone`, `education` |
| **Endereço**            | `zipCode`, `street`, `streetNumber`, `complement`, `district`, `addressCity`, `addressState`                 |
| **Metadados**           | `createdAt`, `updatedAt`                                                                                     |

### Entidade `Prescription`

| Campo                     | Tipo                 | Descrição                           |
| ------------------------- | -------------------- | ----------------------------------- |
| `id`                      | `UUID`               | Identificador único                 |
| `medicine`                | `String`             | Nome do medicamento                 |
| `description`             | `String?`            | Posologia / instruções              |
| `doctorName`              | `String?`            | Nome formatado do médico prescritor |
| `status`                  | `PrescriptionStatus` | Estado atual da receita             |
| `patientId`               | `UUID`               | FK → User (paciente)                |
| `doctorId`                | `UUID?`              | FK → User (médico)                  |
| `createdAt` / `updatedAt` | `DateTime`           | Metadados de auditoria              |

### Enums

**`ProfessionalType`**

`MEDICO` · `DENTISTA` · `ENFERMEIRO` · `FARMACEUTICO` · `PSICOLOGO` · `NUTRICIONISTA` · `FISIOTERAPEUTA` · `ASSISTENTE_SOCIAL` · `ADMINISTRATIVO` · `OUTROS` · `PACIENTE`

> Apenas `MEDICO` e `DENTISTA` têm permissão legal para emitir e renovar prescrições.

**`PrescriptionStatus`**

| Valor              | Contexto   | Descrição                                                           |
| ------------------ | ---------- | ------------------------------------------------------------------- |
| `ACTIVE`           | Prescrição | Receita ativa e dentro da validade                                  |
| `EXPIRED`          | Prescrição | Receita com prazo de validade vencido                               |
| `CANCELLED`        | Prescrição | Receita cancelada pelo médico prescritor                            |
| `PENDING_TRIAGE`   | Renovação  | Solicitação enviada pelo paciente, aguardando triagem do enfermeiro |
| `PENDING_RENEWAL`  | Renovação  | Triagem aprovada, aguardando autorização do médico                  |
| `RENEWAL_REJECTED` | Renovação  | Solicitação rejeitada pelo enfermeiro ou pelo médico                |

### Histórico de Migrations (11)

| #   | Migration                           |
| --- | ----------------------------------- |
| 1   | `init`                              |
| 2   | `create_prescription_table`         |
| 3   | `add_crm_specialty_to_user`         |
| 4   | `add_professional_type`             |
| 5   | `add_prescription_patient_relation` |
| 6   | `auth_transition`                   |
| 7   | `add_user_identity_fields`          |
| 8   | `add_patient_type_and_fields`       |
| 9   | `supabase_baas_trigger_and_rls`     |
| 10  | `fix_trigger_professional_type_key` |
| 11  | `fix_trigger_include_updated_at`    |

---

## ⚙️ CI/CD Pipeline

O projeto utiliza **dois workflows** independentes no GitHub Actions, com responsabilidades bem definidas:

### `ci.yml` — Integração Contínua

**Gatilho:** `push` e `pull_request` na branch `develop`

Executa **dois jobs em paralelo** para maior velocidade:

| Job               | Responsabilidade                                                                                |
| ----------------- | ----------------------------------------------------------------------------------------------- |
| **test-backend**  | Sobe PostgreSQL 16 via service container, executa `prisma db push` e roda a suíte Jest completa |
| **test-frontend** | Instala Flutter SDK (canal stable) e executa `flutter test --reporter=expanded`                 |

> Os testes de backend usam banco temporário isolado do Supabase. O `jwtVerify` é completamente mockado via `jest.unstable_mockModule`.

### `main.yml` — Entrega Contínua

**Gatilho:** `push` nas branches `develop` e `main` (após merge de PR)

Executa **três jobs em sequência**:

| Job                   | Responsabilidade                                       | Branches           |
| --------------------- | ------------------------------------------------------ | ------------------ |
| **setup-environment** | Instala Node.js 22 e Supabase CLI                      | `develop` + `main` |
| **sync-database**     | Executa `prisma migrate deploy` no banco Supabase      | `develop` + `main` |
| **deploy-functions**  | Publica Edge Functions via `supabase functions deploy` | `main` apenas      |

### Secrets Necessários

| Secret                  | Uso                                        |
| ----------------------- | ------------------------------------------ |
| `DATABASE_URL`          | Conexão direta (porta 5432, sem PgBouncer) |
| `SUPABASE_ACCESS_TOKEN` | Autenticação no Supabase CLI               |
| `SUPABASE_PROJECT_ID`   | Project ref do projeto Supabase            |

> Nenhuma credencial é exposta no código-fonte. O backend valida tokens via JWKS público, sem necessidade de `SUPABASE_JWT_SECRET`.

---

## 📝 Padrão de Commits

Este projeto segue o padrão **Conventional Commits** combinado com a referência `AB#<número>` do **Azure DevOps**, que cria vínculo automático entre o commit e o Work Item no Azure Boards.

### Formato

```text
<tipo>(escopo): <descrição resumida> AB#<número-da-task>
```

### Tipos Aceitos

| Tipo       | Quando usar                                             |
| ---------- | ------------------------------------------------------- |
| `feat`     | Nova funcionalidade para o usuário                      |
| `fix`      | Correção de bug                                         |
| `ci`       | Mudanças em arquivos de CI/CD (`.github/`, pipelines)   |
| `chore`    | Tarefas de manutenção que não afetam código de produção |
| `docs`     | Alterações apenas em documentação                       |
| `test`     | Adição ou correção de testes                            |
| `refactor` | Refatoração sem mudança de comportamento                |
| `perf`     | Melhoria de performance                                 |

### Exemplos

```bash
feat(prescription): adicionar endpoint de cancelamento de receita AB#90
fix(auth): corrigir validação de JWT expirado AB#91
ci: implementar sincronização Prisma e deploy de Edge Functions AB#86
fix(ci): corrigir indentação dos jobs no workflow AB#86
docs: atualizar README com seção de CI/CD e padrão de commits AB#87
```

---

## 📂 Estrutura do Projeto

```text
e-receitasus/
├── .github/
│   └── workflows/
│       ├── ci.yml                  # Pipeline CI: testes backend + frontend
│       └── main.yml                # Pipeline CD: sync banco + deploy functions
│
├── backend/
│   ├── src/
│   │   ├── controllers/
│   │   │   ├── auth.controller.ts
│   │   │   ├── history.controller.ts
│   │   │   └── prescription.controller.ts
│   │   ├── middlewares/
│   │   │   └── auth.middleware.ts  # Validação JWT via JWKS
│   │   ├── repositories/
│   │   │   └── user.repository.ts
│   │   ├── routes/
│   │   │   ├── auth.routes.ts
│   │   │   ├── history.routes.ts
│   │   │   ├── prescription.routes.ts
│   │   │   └── user.routes.ts
│   │   ├── services/
│   │   │   └── auth.service.ts
│   │   ├── utils/
│   │   │   ├── jwt.util.ts
│   │   │   └── prismaClient.ts
│   │   ├── app.ts                  # Configuração do Express
│   │   └── server.ts               # Ponto de entrada
│   ├── prisma/
│   │   ├── schema.prisma
│   │   └── migrations/             # 11 migrations versionadas
│   ├── tests/
│   │   ├── auth.test.ts
│   │   └── prescription.test.ts
│   ├── jest.config.cjs
│   ├── prisma.config.ts
│   ├── tsconfig.json
│   └── package.json
│
└── frontend/
    ├── lib/
    │   ├── models/
    │   │   ├── prescription_model.dart
    │   │   ├── prescription_type.dart
    │   │   ├── professional_type.dart
    │   │   └── user_model.dart
    │   ├── providers/
    │   │   └── auth_provider.dart
    │   ├── screens/
    │   │   ├── splash_screen.dart
    │   │   ├── login_screen.dart
    │   │   ├── register_screen.dart
    │   │   ├── patient_register_screen.dart
    │   │   ├── home_screen.dart
    │   │   ├── doctor_home_screen.dart
    │   │   ├── nurse_home_screen.dart
    │   │   ├── history_screen.dart
    │   │   ├── prescription_type_screen.dart
    │   │   ├── prescription_form_screen.dart
    │   │   └── prescription_view_screen.dart
    │   ├── services/
    │   │   ├── auth_service.dart
    │   │   └── prescription_service.dart
    │   ├── theme/
    │   │   ├── app_colors.dart
    │   │   ├── app_text_styles.dart
    │   │   └── app_theme.dart
    │   ├── widgets/
    │   │   └── prescription_card.dart
    │   └── main.dart
    ├── test/                        # 9 arquivos de teste (TDD)
    └── pubspec.yaml
```

---

## 🚀 Como Executar

### Pré-requisitos

- Node.js 22+
- PostgreSQL 14+ (ou projeto Supabase configurado)
- Flutter SDK 3.4+

Dependências extras para build Linux (quando necessário):

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libjsoncpp-dev
```

### Variáveis de Ambiente — Backend

Crie o arquivo `backend/.env`:

```env
DATABASE_URL="postgresql://USER:PASSWORD@HOST:5432/DATABASE"
DIRECT_URL="postgresql://USER:PASSWORD@HOST:5432/DATABASE"
SUPABASE_URL="https://<project-ref>.supabase.co"
PORT=3333
```

### Backend (API)

```bash
cd backend
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

### Frontend (App Flutter)

```bash
cd frontend
flutter pub get
flutter run
```

---

## 🧪 Testes

### Backend (Testes)

```bash
cd backend
npm test
```

A suíte Jest cobre testes de integração com banco real (PostgreSQL temporário). O Jest usa `@swc/jest` para compilação TypeScript via Rust, evitando consumo excessivo de heap.

### Frontend (Testes)

```bash
cd frontend
flutter test
```

O frontend possui **9 arquivos de teste** cobrindo: `AuthProvider`, `AuthService`, `LoginScreen`, cadastro de paciente (CEP e validações), `PrescriptionCard` e `ProfessionalType`. Os mocks são gerados com `mockito` + `build_runner`.

---

## 📜 Scripts do Backend

| Script                    | Descrição                                           |
| ------------------------- | --------------------------------------------------- |
| `npm run dev`             | Inicia servidor com hot reload (`tsx watch`)        |
| `npm run build`           | Compila TypeScript para JavaScript (`dist/`)        |
| `npm run start`           | Executa o build de produção                         |
| `npm test`                | Executa todos os testes de integração               |
| `npm run test:watch`      | Testes em modo watch                                |
| `npm run test:coverage`   | Gera relatório de cobertura                         |
| `npm run prisma:generate` | Gera o Prisma Client tipado                         |
| `npm run prisma:migrate`  | Aplica migrations no ambiente local (`migrate dev`) |
| `npm run prisma:studio`   | Abre interface visual do banco de dados             |

---

## 🎓 Contexto Acadêmico

**Disciplina:** Hands On Work IX  
**Professor:** Mestre [Ewerton Eyre](https://www.linkedin.com/in/ewertoneyre/)  
**Curso:** Análise e Desenvolvimento de Sistemas  
**Instituição:** UNIVALI – Universidade do Vale do Itajaí  
**Desenvolvedor:** Lucas Elias Dickmann

---

## 👨‍💻 Aluno e Desenvolvedor

[![LinkedIn](https://img.shields.io/badge/LinkedIn-lucasdickmann-blue?logo=linkedin)](https://linkedin.com/in/lucasdickmann)
[![GitHub](https://img.shields.io/badge/GitHub-ldickmann-black?logo=github)](https://github.com/ldickmann)
[![E-mail](https://img.shields.io/badge/E--mail-ldickmann12%40gmail.com-red?logo=gmail)](mailto:ldickmann12@gmail.com)
[![E-mail Acadêmico](https://img.shields.io/badge/E--mail%20Acad%C3%AAmico-lucas.8315540%40edu.univali.br-red?logo=gmail)](mailto:lucas.8315540@edu.univali.br)

---

> Desenvolvido com TypeScript, Flutter e boas práticas de engenharia de software — arquitetura em camadas, TDD, type safety end-to-end e CI/CD automatizado.
