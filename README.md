# 📱 E-ReceitaSUS

> Plataforma full-stack de prescrição médica digital para o SUS — médicos e dentistas emitem receitas diretamente no sistema, pacientes acompanham seu histórico e solicitam renovações, com fluxo de triagem pelo enfermeiro e autorização obrigatória do médico.

## 💡 Sobre o Projeto

O **E-ReceitaSUS** é uma aplicação desenvolvida para modernizar o processo de prescrição médica no contexto do SUS. O sistema disponibiliza formulários digitais para que o **médico ou dentista** emita novas prescrições ou renove receitas existentes diretamente no aplicativo.

Do lado do paciente, a plataforma permite **solicitar a renovação de uma receita** por meio de um formulário dedicado, bem como **acompanhar o histórico completo de suas prescrições em tempo real**. As solicitações de renovação passam por um fluxo estruturado: o **enfermeiro** avalia clinicamente a necessidade e, se confirmada, encaminha ao **médico responsável pela UBS** para autorização final.

A autenticação é delegada ao **Supabase Auth** (BaaS), e o backend Express atua como **resource server**, validando tokens JWT via JWKS remoto (RS256/ES256) — sem armazenar nem conhecer segredos de sessão. As prescrições e renovações são lidas/escritas diretamente pelo Flutter via **Supabase PostgREST + Realtime**, com isolamento garantido por **Row Level Security (RLS)**.

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
    - [Backend (Express)](#backend-express)
    - [Frontend (Flutter)](#frontend-flutter)
    - [Fluxo híbrido de dados](#fluxo-híbrido-de-dados)
    - [Telas por perfil de acesso](#telas-por-perfil-de-acesso)
  - [🔐 Autenticação](#-autenticação)
  - [🌐 API REST — Backend Express](#-api-rest--backend-express)
  - [🗄 Acesso Direto ao Supabase (BaaS)](#-acesso-direto-ao-supabase-baas)
  - [🧩 Modelagem de Dados](#-modelagem-de-dados)
    - [Entidade `Patient`](#entidade-patient)
    - [Entidade `Professional`](#entidade-professional)
    - [Entidade `HealthUnit`](#entidade-healthunit)
    - [Entidade `prescriptions` (BaaS)](#entidade-prescriptions-baas)
    - [Entidade `RenewalRequest`](#entidade-renewalrequest)
    - [Enums](#enums)
    - [Histórico de Migrations (20)](#histórico-de-migrations-20)
  - [⚙️ CI/CD Pipeline](#️-cicd-pipeline)
    - [`ci.yml` — Integração Contínua](#ciyml--integração-contínua)
    - [`main.yml` — Entrega Contínua](#mainyml--entrega-contínua)
    - [`release.yml` — Release Android](#releaseyml--release-android)
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
    - [Backend (Express)](#backend-express-1)
    - [Frontend (Flutter Test)](#frontend-flutter-test)
  - [📜 Scripts do Backend](#-scripts-do-backend)
  - [🎓 Contexto Acadêmico](#-contexto-acadêmico)
  - [👨‍💻 Aluno e Desenvolvedor](#-aluno-e-desenvolvedor)

---

## ✨ Principais Funcionalidades

### 👨‍⚕️ Médico / Dentista (Prescritor)

- Emissão de **novas receitas digitais** com formulário completo conforme padrões ANVISA.
- **Renovação de receitas** existentes: cria uma nova prescrição com os mesmos dados clínicos e data atualizada.
- Visualização em tempo real (Supabase Realtime) de todas as receitas emitidas pelo profissional autenticado.
- **Autorização obrigatória** das solicitações de renovação encaminhadas pelo enfermeiro.

### 🩺 Enfermeiro (Triagem)

- Recebimento das solicitações de renovação enviadas pelos pacientes.
- **Triagem clínica**: avalia se a renovação é de fato necessária antes de encaminhar ao médico.
- Encaminhamento da solicitação ao médico responsável pela UBS quando confirmada a necessidade.

### 🧑‍🤝‍🧑 Paciente

- **Solicitação de renovação de receita** via formulário dedicado (restrita a receitas com status elegível).
- Acompanhamento do **status da solicitação** em tempo real.
- **Histórico completo de prescrições** com filtro por status.

### 🔐 Infraestrutura

- Autenticação com **Supabase Auth** — tokens JWT validados no backend via **JWKS** (RS256/ES256).
- **Cadastro distinto** para profissionais de saúde e pacientes SUS, com roteamento automático por trigger SQL para as tabelas `professionals` ou `patients`.
- **Vínculo automático à UBS** baseado no bairro do endereço informado.
- Suporte aos **4 tipos de receita ANVISA**: Branca, Controle Especial, Notificação A (Amarela) e Notificação B (Azul).
- **Row Level Security** habilitado em todas as tabelas sensíveis.
- Cancelamento de receita restrito ao médico prescritor.

---

## 🔄 Fluxo de Renovação de Receitas

O processo de renovação é o fluxo central do sistema e envolve **três atores** em sequência obrigatória:

```text
Paciente                 Enfermeiro (UBS)              Médico (UBS)
   │                           │                            │
   │── Solicita renovação ────►│                            │
   │      (PENDING_TRIAGE)     │                            │
   │                           │── Avalia clinicamente ───  │
   │                           │                            │
   │                           │── Aprova ─────────────────►│
   │                           │      (TRIAGED)             │
   │                           │── Rejeita ─────►(REJECTED) │
   │                           │                            │
   │                           │                            │── Autoriza ──► Nova prescrição
   │                           │                            │      (PRESCRIBED)
   │                           │                            │── Rejeita ──► (REJECTED)
   │                           │                            │
   │◄─────────────────────────────────────── Notifica ──────│ Nova prescrição criada
```

### 📊 Status do Fluxo de Renovação

| Status           | Descrição                                                                       | Próxima Ação               |
| ---------------- | ------------------------------------------------------------------------------- | -------------------------- |
| `PENDING_TRIAGE` | Solicitação enviada pelo paciente, aguardando avaliação do enfermeiro           | Enfermeiro avalia          |
| `TRIAGED`        | Triagem aprovada pelo enfermeiro, aguardando autorização do médico              | Médico autoriza ou rejeita |
| `PRESCRIBED`     | Médico autorizou — nova prescrição criada com dados idênticos e data atualizada | —                          |
| `REJECTED`       | Solicitação rejeitada pelo enfermeiro ou pelo médico                            | Paciente é notificado      |

> **Regras de negócio:**
>
> - A renovação **sempre** exige autorização do médico — sem exceções.
> - O médico vinculado ao paciente é o da **UBS (Unidade Básica de Saúde)** onde ele está cadastrado.
> - A renovação gera uma **nova prescrição** (novo `id`, nova `issued_at`, nova `valid_until`) com os mesmos dados clínicos da original.
> - Apenas receitas com status elegível podem ser alvo de solicitação de renovação pelo paciente.
> - Somente **médicos** e **dentistas** têm autoridade legal para emitir e renovar prescrições (Lei Federal).

---

## 🛠 Stack Tecnológico

### Backend

| Tecnologia               | Versão         | Papel                              |
| ------------------------ | -------------- | ---------------------------------- |
| **Node.js**              | 22 LTS         | Runtime                            |
| **TypeScript**           | ^5.9           | Tipagem estática                   |
| **Express.js**           | ^4.21          | Framework HTTP                     |
| **Prisma ORM**           | ^7.7           | Acesso ao banco e migrations       |
| **PostgreSQL**           | (via Supabase) | Banco de dados                     |
| **@prisma/adapter-pg**   | ^7.7           | Adapter de conexão direta          |
| **jose**                 | ^6.2           | Validação JWT/JWKS                 |
| **Jest** + **Supertest** | ^29 / ^7       | Testes de integração               |
| **@swc/jest**            | ^0.2           | Compilação TS rápida (Rust) em CI  |
| **tsx**                  | ^4.19          | Hot reload em desenvolvimento      |
| **supabase CLI**         | ^2.84          | Migrations e Edge Functions remoto |

### Frontend

| Tecnologia                     | Versão      | Papel                                              |
| ------------------------------ | ----------- | -------------------------------------------------- |
| **Flutter** + **Dart**         | SDK ≥ 3.4.0 | Framework multiplataforma                          |
| **supabase_flutter**           | ^2.0.0      | Auth + PostgREST + Realtime                        |
| **Provider**                   | 6.1.1       | Gerenciamento de estado                            |
| **http**                       | ^1.6.0      | Requisições HTTP ao backend Express                |
| **flutter_secure_storage**     | ^9.2.2      | Armazenamento seguro de tokens (Keychain/Keystore) |
| **cupertino_icons**            | ^1.0.6      | Ícones iOS                                         |
| **mockito** + **build_runner** | ^5.4 / ^2.4 | Mocks para TDD                                     |
| **flutter_launcher_icons**     | ^0.14.3     | Geração de ícones de launcher                      |

### Qualidade e Engenharia

- **TDD** (Test-Driven Development) no backend e no frontend — toda service Dart expõe interface abstrata para mockagem.
- **TypeScript strict mode** — proibido `any`; uso de `unknown` com type narrowing.
- **20 migrations versionadas** com Prisma + RLS aplicado via SQL nativo.
- **Arquitetura em camadas** (Presentation → Business → Data → Database).
- **GitHub Actions** com pipelines de CI, CD e Release Android separados.

---

## 🏗 Arquitetura

O projeto segue arquitetura em camadas estrita, garantindo separação de responsabilidades, testabilidade e manutenibilidade.

### Backend (Express)

| Camada           | Componentes                                         |
| ---------------- | --------------------------------------------------- |
| **Presentation** | Routes, Controllers, Middlewares (`auth`, `logger`) |
| **Business**     | Services (regras de domínio)                        |
| **Data**         | Repositories (único acesso ao Prisma Client)        |
| **Database**     | PostgreSQL hospedado no Supabase                    |

> Apenas a camada `repositories/` acessa o `PrismaClient`. Routes nunca chamam services diretamente sem passar por controllers.

### Frontend (Flutter)

| Camada        | Componentes                                                  |
| ------------- | ------------------------------------------------------------ |
| **Screens**   | UI declarativa (Stateless por padrão)                        |
| **Providers** | Estado via `ChangeNotifier` (Provider 6.x)                   |
| **Services**  | Integração externa (Supabase Auth/PostgREST/Realtime + REST) |
| **Models**    | Data classes tipadas + enums                                 |

> Screens **nunca** acessam services diretamente — sempre via providers. Toda service expõe interface abstrata (`IXxxService`) para permitir mocks no TDD.

### Fluxo híbrido de dados

```text
┌────────────────────────┐
│      Flutter App       │
└──┬─────────────────┬───┘
   │                 │
   │ Auth + Realtime │ HTTP (Bearer JWT)
   ▼                 ▼
┌──────────┐    ┌─────────────┐
│ Supabase │    │  Backend    │
│ PostgREST│    │  Express    │
│  + RLS   │    │             │
└────┬─────┘    └──────┬──────┘
     │                 │
     │ Valida JWT      │
     │ via JWKS        │
     │◄────────────────┤
     ▼                 ▼
  ┌────────────────────────┐
  │ PostgreSQL (Supabase)  │
  └────────────────────────┘
```

### Telas por perfil de acesso

| Perfil                | Telas disponíveis                                                                                                                                  |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Médico / Dentista** | Splash → Login → `DoctorHomeScreen` → `PrescriptionTypeScreen` → `PrescriptionFormScreen` → `RenewalPrescriptionScreen` → `PrescriptionViewScreen` |
| **Enfermeiro**        | Splash → Login → `NurseHomeScreen` → `TriageDetailScreen`                                                                                          |
| **Paciente**          | Splash → Login / Register → `PatientRegisterScreen` → `HomeScreen` → `RequestRenewalScreen` → `HistoryScreen` → `PrescriptionViewScreen`           |

---

## 🔐 Autenticação

- O frontend autentica o usuário via **Supabase Auth** e recebe um access token JWT.
- O token é armazenado com **`flutter_secure_storage`** (Keychain no iOS, Keystore no Android) — **nunca** em `SharedPreferences`.
- O backend **não armazena** segredos de sessão — valida o token consultando o endpoint público JWKS do Supabase (`/auth/v1/.well-known/jwks.json`).
- O resolver JWKS é **cacheado em memória** para evitar requisições redundantes.
- O middleware `auth.middleware.ts` injeta `req.userId` (claim `sub` do token) para uso nos controllers.
- Endpoints legados em `/auth/register` e `/auth/login` retornam **`HTTP 410 Gone`**, orientando a migração para o fluxo Supabase.

---

## 🌐 API REST — Backend Express

**Base URL (desenvolvimento):** `http://localhost:3333`

| Método | Rota             | Autenticação | Descrição                                                         |
| ------ | ---------------- | :----------: | ----------------------------------------------------------------- |
| `POST` | `/auth/register` |      ❌      | ⚠️ Legado — retorna `410 Gone`                                    |
| `POST` | `/auth/login`    |      ❌      | ⚠️ Legado — retorna `410 Gone`                                    |
| `GET`  | `/users/me`      |      ✅      | Retorna o perfil do usuário autenticado (Patient ou Professional) |

> **Por que o backend tem poucos endpoints?** O fluxo de prescrições e renovações é gerenciado **diretamente via Supabase PostgREST** (com RLS), aproveitando Realtime para atualização imediata no app. O backend Express atua como **resource server complementar**, expondo apenas endpoints que exigem lógica de negócio fora do alcance do PostgREST.

---

## 🗄 Acesso Direto ao Supabase (BaaS)

As operações abaixo são executadas pelo Flutter **sem passar pelo backend Express**, usando o SDK `supabase_flutter` com isolamento garantido por **Row Level Security**:

| Operação                       | Tabela / Recurso    | Origem (Flutter)            |
| ------------------------------ | ------------------- | --------------------------- |
| Listar prescrições do paciente | `prescriptions`     | `prescription_service.dart` |
| Stream realtime de prescrições | `prescriptions`     | `home_screen.dart`          |
| Emitir nova prescrição         | `prescriptions`     | `prescription_service.dart` |
| Solicitar renovação            | `renewal_requests`  | `renewal_service.dart`      |
| Triagem pelo enfermeiro        | `renewal_requests`  | `triage_provider.dart`      |
| Buscar pacientes (RPC)         | `search_patients()` | `renewal_service.dart`      |

> Todas as policies RLS exigem `auth.uid()` correspondente ao `patient_user_id` ou `doctor_user_id`. A `service_role` key **nunca** é usada no frontend.

---

## 🧩 Modelagem de Dados

O banco separa **pacientes SUS** e **profissionais de saúde** em tabelas distintas, roteados automaticamente por trigger ao cadastro via Supabase Auth. A tabela `prescriptions` é gerenciada como **tabela BaaS** via SQL direto (PostgREST + RLS), fora do escopo do Prisma.

### Entidade `Patient`

Usuário SUS receptor de prescrições. Contém dados sensíveis de saúde (CPF, CNS) isolados por LGPD.

| Grupo              | Campos                                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------------------------ |
| **Identificação**  | `id`, `firstName`, `lastName`, `name`, `email`, `birthDate`                                                  |
| **Dados de saúde** | `cns`, `cpf`, `socialName`, `motherParentName`, `gender`, `ethnicity`, `maritalStatus`, `phone`, `education` |
| **Nascimento**     | `birthCity`, `birthState`                                                                                    |
| **Endereço**       | `zipCode`, `street`, `streetNumber`, `complement`, `district`, `addressCity`, `addressState`                 |
| **Vínculo**        | `healthUnitId` — FK para `HealthUnit`, atribuída automaticamente pelo bairro via trigger                     |
| **Metadados**      | `createdAt`, `updatedAt`                                                                                     |

### Entidade `Professional`

Profissional de saúde ou administrativo vinculado à UBS. **Nunca** contém `professionalType = PACIENTE`.

| Grupo                   | Campos                                                                                       |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| **Identificação**       | `id`, `firstName`, `lastName`, `name`, `email`, `birthDate`                                  |
| **Dados profissionais** | `professionalType`, `professionalId`, `professionalState`, `specialty`                       |
| **Endereço**            | `zipCode`, `street`, `streetNumber`, `complement`, `district`, `addressCity`, `addressState` |
| **Vínculo**             | `healthUnitId` — FK para `HealthUnit` (máx. 3 profissionais por UBS, garantido por trigger)  |
| **Metadados**           | `createdAt`, `updatedAt`                                                                     |

### Entidade `HealthUnit`

Unidade Básica de Saúde — atende exatamente um bairro de uma cidade. Pacientes e profissionais são vinculados automaticamente ao cadastro.

| Campo              | Tipo      | Descrição                                      |
| ------------------ | --------- | ---------------------------------------------- |
| `id`               | `UUID`    | Identificador único                            |
| `name`             | `String`  | Nome da UBS (ex: "UBS Centro")                 |
| `district`         | `String`  | Bairro atendido — único dentro da mesma cidade |
| `city`             | `String`  | Cidade da UBS                                  |
| `state`            | `Char(2)` | UF (ex: "SC")                                  |
| `maxProfessionals` | `Int`     | Limite de profissionais vinculados (padrão: 3) |

### Entidade `prescriptions` (BaaS)

Gerenciada diretamente via SQL e exposta pelo **PostgREST do Supabase** com RLS. **Não** é modelada pelo Prisma ORM.

| Campo           | Tipo                 | Descrição                           |
| --------------- | -------------------- | ----------------------------------- |
| `id`            | `UUID`               | Identificador único                 |
| `medicine_name` | `String`             | Nome do medicamento                 |
| `description`   | `String?`            | Posologia / instruções              |
| `type`          | `PrescriptionType`   | Tipo ANVISA da receita              |
| `doctor_name`   | `String?`            | Nome formatado do médico prescritor |
| `status`        | `PrescriptionStatus` | Estado atual da receita             |
| `patient_id`    | `UUID`               | FK → `patients.id`                  |
| `doctor_id`     | `UUID?`              | FK → `professionals.id`             |
| `issued_at`     | `Timestamptz`        | Data de emissão                     |
| `valid_until`   | `Timestamptz?`       | Data de validade                    |
| `created_at`    | `Timestamptz`        | Metadado de auditoria               |
| `updated_at`    | `Timestamptz`        | Metadado de auditoria               |

### Entidade `RenewalRequest`

Pedido de renovação de prescrição. Percorre o ciclo `PENDING_TRIAGE → TRIAGED → PRESCRIBED` (ou `REJECTED`).

| Campo                   | Tipo            | Descrição                                                |
| ----------------------- | --------------- | -------------------------------------------------------- |
| `id`                    | `UUID`          | Identificador único                                      |
| `prescriptionId`        | `UUID`          | FK para a prescrição original (`prescriptions.id`)       |
| `patientUserId`         | `String`        | FK → `patients.id` — paciente solicitante                |
| `doctorUserId`          | `String?`       | FK → `professionals.id` — médico designado               |
| `nurseUserId`           | `String?`       | FK → `professionals.id` — enfermeiro responsável         |
| `status`                | `RenewalStatus` | Estado atual do pedido                                   |
| `patientNotes`          | `String?`       | Observações opcionais do paciente                        |
| `nurseNotes`            | `String?`       | Notas do enfermeiro (obrigatórias ao rejeitar)           |
| `renewedPrescriptionId` | `UUID?`         | ID da nova prescrição emitida (preenchido em PRESCRIBED) |
| `createdAt`             | `DateTime`      | Metadado de auditoria                                    |
| `updatedAt`             | `DateTime`      | Metadado de auditoria                                    |

### Enums

**`ProfessionalType`**

`MEDICO` · `DENTISTA` · `ENFERMEIRO` · `FARMACEUTICO` · `PSICOLOGO` · `NUTRICIONISTA` · `FISIOTERAPEUTA` · `ASSISTENTE_SOCIAL` · `ADMINISTRATIVO` · `OUTROS` · `PACIENTE`

> Apenas `MEDICO` e `DENTISTA` têm permissão legal para emitir e renovar prescrições. `PACIENTE` nunca aparece na tabela `professionals` — o roteamento é feito por trigger.

**`RenewalStatus`**

| Valor            | Descrição                                            |
| ---------------- | ---------------------------------------------------- |
| `PENDING_TRIAGE` | Aguardando avaliação do enfermeiro                   |
| `TRIAGED`        | Triagem aprovada pelo enfermeiro; aguardando médico  |
| `PRESCRIBED`     | Médico emitiu a nova prescrição                      |
| `REJECTED`       | Solicitação rejeitada pelo enfermeiro ou pelo médico |

**`PrescriptionStatus`** _(tabela BaaS)_

| Valor       | Descrição                                |
| ----------- | ---------------------------------------- |
| `ACTIVE`    | Receita ativa e dentro da validade       |
| `EXPIRED`   | Receita com prazo de validade vencido    |
| `CANCELLED` | Receita cancelada pelo médico prescritor |

### Histórico de Migrations (20)

| #   | Migration                                       |
| --- | ----------------------------------------------- |
| 1   | `init`                                          |
| 2   | `create_prescription_table`                     |
| 3   | `add_crm_specialty_to_user`                     |
| 4   | `add_professional_type`                         |
| 5   | `add_prescription_patient_relation`             |
| 6   | `auth_transition`                               |
| 7   | `add_user_identity_fields`                      |
| 8   | `add_patient_type_and_fields`                   |
| 9   | `supabase_baas_trigger_and_rls`                 |
| 10  | `fix_trigger_professional_type_key`             |
| 11  | `fix_trigger_include_updated_at`                |
| 12  | `add_renewal_requests`                          |
| 13  | `rls_renewal_request`                           |
| 14  | `search_patients_rpc`                           |
| 15  | `create_prescriptions_baas_table`               |
| 16  | `rls_prescriptions_baas`                        |
| 17  | `drop_prescription_table_unify_baas`            |
| 18  | `add_health_units_and_backfill_users`           |
| 19  | `split_user_patients_professionals`             |
| 20  | `rls_update_own_profile_patients_professionals` |

---

## ⚙️ CI/CD Pipeline

O projeto utiliza **três workflows** independentes no GitHub Actions, com responsabilidades bem definidas.

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

### `release.yml` — Release Android

**Gatilho:** `push` de tag no formato `v*.*.*` (ex: `v1.0.3`)

| Job                   | Responsabilidade                                                                                 |
| --------------------- | ------------------------------------------------------------------------------------------------ |
| **build-and-release** | Decodifica keystore, gera `key.properties`, builda APK release assinado e publica GitHub Release |

> O job declara `permissions: contents: write` para que o `GITHUB_TOKEN` consiga criar a release e fazer upload do APK.

### Secrets Necessários

| Secret                  | Workflow      | Uso                                        |
| ----------------------- | ------------- | ------------------------------------------ |
| `DATABASE_URL`          | `main.yml`    | Conexão direta (porta 5432, sem PgBouncer) |
| `SUPABASE_ACCESS_TOKEN` | `main.yml`    | Autenticação no Supabase CLI               |
| `SUPABASE_PROJECT_ID`   | `main.yml`    | Project ref do projeto Supabase            |
| `KEYSTORE_BASE64`       | `release.yml` | Keystore Android codificado em base64      |
| `KEY_ALIAS`             | `release.yml` | Alias da chave de assinatura               |
| `STORE_PASSWORD`        | `release.yml` | Senha do keystore                          |
| `KEY_PASSWORD`          | `release.yml` | Senha da chave                             |

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
fix(ci): adicionar contents:write para publicar GitHub Release
docs: atualizar README com seção de CI/CD e padrão de commits AB#87
```

---

## 📂 Estrutura do Projeto

```text
e-receitasus/
├── .github/
│   └── workflows/
│       ├── ci.yml              # CI: testes backend + frontend
│       ├── main.yml            # CD: sync banco + deploy functions
│       └── release.yml         # Release Android (APK assinado)
│
├── backend/
│   ├── src/
│   │   ├── middlewares/
│   │   │   ├── auth.middleware.ts        # Validação JWT via JWKS
│   │   │   └── request-logger.middleware.ts
│   │   ├── repositories/
│   │   │   └── user.repository.ts        # Único acesso ao Prisma Client
│   │   ├── routes/
│   │   │   ├── auth.routes.ts            # ⚠️ Legado (410 Gone)
│   │   │   └── user.routes.ts            # GET /users/me
│   │   ├── services/
│   │   │   └── auth.service.ts
│   │   ├── utils/
│   │   │   └── prismaClient.ts
│   │   ├── app.ts                        # Configuração Express
│   │   └── server.ts                     # Bootstrap HTTP
│   ├── prisma/
│   │   ├── schema.prisma                 # Patient, Professional, HealthUnit, RenewalRequest
│   │   └── migrations/                   # 20 migrations versionadas
│   ├── tests/
│   │   └── auth.test.ts
│   ├── jest.config.cjs
│   ├── prisma.config.ts
│   ├── tsconfig.json
│   └── package.json
│
└── frontend/
    ├── lib/
    │   ├── main.dart                     # Bootstrap + Supabase.initialize
    │   ├── models/                       # 9 data classes (Patient, Professional, Prescription, RenewalRequest, HealthUnit, ...)
    │   ├── providers/                    # AuthProvider, RenewalProvider, TriageProvider
    │   ├── services/                     # AuthService, PrescriptionService, RenewalService (com interfaces abstratas)
    │   ├── screens/                      # 14 telas (Splash, Login, Register, Patient/Doctor/NurseHome, Triage, ...)
    │   ├── widgets/                      # PrescriptionCard
    │   └── theme/                        # AppColors, AppTextStyles, AppTheme
    ├── test/                             # 10 arquivos de teste (services, providers, screens, models)
    ├── android/
    ├── ios/
    ├── web/
    ├── linux/
    ├── macos/
    ├── windows/
    ├── analysis_options.yaml
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

### Backend (Express)

```bash
cd backend
npm test
```

A suíte Jest cobre testes de integração com banco real (PostgreSQL temporário). O Jest usa `@swc/jest` para compilação TypeScript via Rust, evitando consumo excessivo de heap.

### Frontend (Flutter Test)

```bash
cd frontend
flutter test
```

O frontend possui **10 arquivos de teste** cobrindo: `AuthProvider`, `AuthService`, `LoginScreen`, cadastro de paciente (CEP e validações), `PrescriptionCard`, `PrescriptionModel`, `ProfessionalType`, `RenewalProvider` e `TriageProvider`. Toda service expõe interface abstrata para mockagem com **Mockito**:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📜 Scripts do Backend

| Script                    | Descrição                                           |
| ------------------------- | --------------------------------------------------- |
| `npm run dev`             | Inicia servidor com hot reload (`tsx watch`)        |
| `npm run build`           | Compila TypeScript para JavaScript (`dist/`)        |
| `npm start`               | Executa o build de produção                         |
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
