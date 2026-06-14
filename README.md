# 📱 E-ReceitaSUS

> Plataforma full-stack de prescrição médica digital para o SUS — médicos e dentistas emitem receitas diretamente no sistema, pacientes acompanham seu histórico e solicitam renovações, com fluxo de triagem pelo enfermeiro e autorização obrigatória do médico.

## 💡 Sobre o Projeto

O **E-ReceitaSUS** é uma aplicação desenvolvida para modernizar o processo de prescrição médica no contexto do SUS. O sistema disponibiliza formulários digitais para que o **médico ou dentista** emita novas prescrições ou renove receitas existentes diretamente no aplicativo.

Do lado do paciente, a plataforma permite **solicitar a renovação de uma receita** por meio de um formulário dedicado, bem como **acompanhar o histórico completo de suas prescrições em tempo real**. As solicitações de renovação passam por um fluxo estruturado: o **enfermeiro** avalia clinicamente a necessidade e, se confirmada, encaminha ao **médico responsável pela UBS** para autorização final.

A autenticação é delegada ao **Supabase Auth** (BaaS), e o backend Express atua como **resource server**, validando tokens JWT via JWKS remoto (RS256/ES256) — sem armazenar nem conhecer segredos de sessão. As prescrições e renovações são lidas/escritas diretamente pelo Flutter via **Supabase PostgREST + Realtime**, com isolamento garantido por **Row Level Security (RLS)**.

### 🎯 Problema Resolvido

Elimina papéis físicos e filas desnecessárias, garante rastreabilidade das prescrições, organiza o histórico de medicamentos do paciente SUS e estrutura a comunicação entre pacientes, enfermeiros e médicos dentro da UBS.

***

## 📑 Índice

* [📱 E-ReceitaSUS](#-e-receitasus)
  * [💡 Sobre o Projeto](#-sobre-o-projeto)
    * [🎯 Problema Resolvido](#-problema-resolvido)
  * [📑 Índice](#-índice)
  * [✨ Principais Funcionalidades](#-principais-funcionalidades)
    * [👨‍⚕️ Médico / Dentista (Prescritor)](#️-médico--dentista-prescritor)
    * [🩺 Enfermeiro (Triagem)](#-enfermeiro-triagem)
    * [🧑‍🤝‍🧑 Paciente](#-paciente)
    * [🔐 Infraestrutura](#-infraestrutura)
  * [🔄 Fluxo de Renovação de Receitas](#-fluxo-de-renovação-de-receitas)
    * [📊 Status do Fluxo de Renovação](#-status-do-fluxo-de-renovação)
  * [🛠 Stack Tecnológico](#-stack-tecnológico)
    * [Backend](#backend)
    * [Frontend](#frontend)
    * [Qualidade e Engenharia](#qualidade-e-engenharia)
  * [🏗 Arquitetura](#-arquitetura)
    * [Backend (Express)](#backend-express)
    * [Frontend (Flutter)](#frontend-flutter)
    * [Fluxo híbrido de dados](#fluxo-híbrido-de-dados)
    * [Telas por perfil de acesso](#telas-por-perfil-de-acesso)
  * [🔐 Autenticação](#-autenticação)
  * [🔐 Segurança](#-segurança)
  * [🌐 API REST — Backend Express](#-api-rest--backend-express)
  * [🗄 Acesso Direto ao Supabase (BaaS)](#-acesso-direto-ao-supabase-baas)
  * [🔔 Notificações (Push + In-App)](#-notificações-push--in-app)
  * [🧩 Modelagem de Dados](#-modelagem-de-dados)
    * [Entidade `Patient`](#entidade-patient)
    * [Entidade `Professional`](#entidade-professional)
    * [Entidade `HealthUnit`](#entidade-healthunit)
    * [Entidade `prescriptions` (BaaS)](#entidade-prescriptions-baas)
    * [Entidade `RenewalRequest`](#entidade-renewalrequest)
    * [Enums](#enums)
    * [Histórico de Migrations (38)](#histórico-de-migrations-38)
  * [⚙️ CI/CD Pipeline](#️-cicd-pipeline)
    * [`ci.yml` — Integração Contínua](#ciyml--integração-contínua)
    * [`main.yml` — Entrega Contínua](#mainyml--entrega-contínua)
    * [`release.yml` — Release Android](#releaseyml--release-android)
    * [Secrets Necessários](#secrets-necessários)
  * [📝 Padrão de Commits](#-padrão-de-commits)
    * [Formato](#formato)
    * [Tipos Aceitos](#tipos-aceitos)
    * [Exemplos](#exemplos)
  * [📂 Estrutura do Projeto](#-estrutura-do-projeto)
  * [🚀 Como Executar](#-como-executar)
    * [Pré-requisitos](#pré-requisitos)
    * [Variáveis de Ambiente — Backend](#variáveis-de-ambiente--backend)
    * [Backend (API)](#backend-api)
    * [Frontend (App Flutter)](#frontend-app-flutter)
  * [🧪 Testes](#-testes)
    * [Backend (Express) Tests](#backend-express-tests)
    * [Frontend (Flutter Test)](#frontend-flutter-test)
  * [📜 Scripts do Backend](#-scripts-do-backend)
  * [🎓 Contexto Acadêmico](#-contexto-acadêmico)
  * [👨‍💻 Aluno e Desenvolvedor](#-aluno-e-desenvolvedor)

***

## ✨ Principais Funcionalidades

### 👨‍⚕️ Médico / Dentista (Prescritor)

* Emissão de **novas receitas digitais** com formulário completo conforme padrões ANVISA.
* **Renovação de receitas** existentes: cria uma nova prescrição com os mesmos dados clínicos e data atualizada.
* Visualização em tempo real (Supabase Realtime) de todas as receitas emitidas pelo profissional autenticado.
* **Autorização obrigatória** das solicitações de renovação encaminhadas pelo enfermeiro.

### 🩺 Enfermeiro (Triagem)

* Recebimento das solicitações de renovação enviadas pelos pacientes.
* **Triagem clínica**: avalia se a renovação é de fato necessária antes de encaminhar ao médico.
* Encaminhamento da solicitação ao médico responsável pela UBS quando confirmada a necessidade.

### 🧑‍🤝‍🧑 Paciente

* **Solicitação de renovação de receita** via formulário dedicado (restrita a receitas com status elegível).
* Acompanhamento do **status da solicitação** em tempo real.
* **Histórico completo de prescrições** com filtro por status.

### 🔐 Infraestrutura

* Autenticação com **Supabase Auth** — tokens JWT validados no backend via **JWKS** (RS256/ES256).
* **Cadastro distinto** para profissionais de saúde e pacientes SUS, com roteamento automático por trigger SQL para as tabelas `professionals` ou `patients`.
* **Vínculo automático à UBS** baseado no bairro do endereço informado.
* Suporte aos **4 tipos de receita ANVISA**: Branca, Controle Especial, Notificação A (Amarela) e Notificação B (Azul).
* **Row Level Security** habilitado em todas as tabelas sensíveis.
* Cancelamento de receita restrito ao médico prescritor.
* **Notificações** ao paciente e ao profissional: push em background via **Firebase Cloud Messaging** (Edge Function) e atualização *in-app* em tempo real via **Supabase Realtime** — corpo genérico, sem dados clínicos (LGPD).

***

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
> * A renovação **sempre** exige autorização do médico — sem exceções.
> * O médico vinculado ao paciente é o da **UBS (Unidade Básica de Saúde)** onde ele está cadastrado.
> * A renovação gera uma **nova prescrição** (novo `id`, nova `issued_at`, nova `valid_until`) com os mesmos dados clínicos da original.
> * Apenas receitas com status elegível podem ser alvo de solicitação de renovação pelo paciente.
> * Somente **médicos** e **dentistas** têm autoridade legal para emitir e renovar prescrições (Lei Federal).

***

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
| **Deno**                 | (Supabase Edge)| Runtime das Edge Functions (`send-push-notification`, `health-check`) |

### Frontend

| Tecnologia                     | Versão      | Papel                                              |
| ------------------------------ | ----------- | -------------------------------------------------- |
| **Flutter** + **Dart**         | SDK ≥ 3.4.0 | Framework multiplataforma                          |
| **supabase\_flutter**           | ^2.0.0      | Auth + PostgREST + Realtime                        |
| **firebase\_core**              | ^4.10.0     | Inicialização do Firebase (Android) para push      |
| **firebase\_messaging**         | ^16.3.0     | Recebimento de notificações push (FCM)             |
| **Provider**                   | 6.1.1       | Gerenciamento de estado                            |
| **http**                       | ^1.6.0      | Requisições HTTP ao backend Express                |
| **flutter\_secure\_storage**     | ^9.2.2      | Armazenamento seguro de tokens (Keychain/Keystore) |
| **cupertino\_icons**            | ^1.0.6      | Ícones iOS                                         |
| **mockito** + **build\_runner** | ^5.4 / ^2.4 | Mocks para TDD                                     |
| **flutter\_launcher\_icons**     | ^0.14.3     | Geração de ícones de launcher                      |

### Qualidade e Engenharia

* **TDD** (Test-Driven Development) no backend e no frontend — toda service Dart expõe interface abstrata para mockagem.
* **TypeScript strict mode** — proibido `any`; uso de `unknown` com type narrowing.
* **38 migrations versionadas** com Prisma + RLS aplicado via SQL nativo.
* **Hardening de segurança auditado** (ver [Segurança](#-segurança)); JWT validado exclusivamente com `jose` — dependências legadas `bcrypt`/`jsonwebtoken` removidas.
* **Arquitetura em camadas** (Presentation → Business → Data → Database).
* **GitHub Actions** com pipelines de CI, CD e Release Android separados.

***

## 🏗 Arquitetura

O projeto segue arquitetura em camadas estrita, garantindo separação de responsabilidades, testabilidade e manutenibilidade.

### Backend (Express)

| Camada           | Componentes                                         |
| ---------------- | --------------------------------------------------- |
| **Presentation** | Routes (handlers inline), Middlewares (`auth`, `logger`) |
| **Business**     | Services (regras de domínio)                        |
| **Data**         | Repositories (único acesso ao Prisma Client)        |
| **Database**     | PostgreSQL hospedado no Supabase                    |

> Apenas a camada `repositories/` acessa o `PrismaClient`. As rotas chamam os services para execução da lógica de negócio.

### Frontend (Flutter)

| Camada        | Componentes                                                  |
| ------------- | ------------------------------------------------------------ |
| **Screens**   | UI declarativa (Stateless por padrão)                        |
| **Providers** | Estado via `ChangeNotifier` (Provider 6.x)                   |
| **Services**  | Integração externa (Supabase Auth/PostgREST/Realtime + REST) |
| **Models**    | Data classes tipadas + enums                                 |

> Screens **nunca** acessam services diretamente — sempre via providers. Toda service expõe interface abstrata (`IXxxService`) para permitir mocks no TDD.

### Edge Functions (Deno)

Além do backend Express e do app Flutter, o sistema tem um terceiro runtime: **Edge Functions** do Supabase, escritas em **Deno/TypeScript** (`supabase/functions/`).

| Function                 | Gatilho                                                  | Papel                                                                                              |
| ------------------------ | -------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| `send-push-notification` | Database Webhook (`pg_net`) em `RenewalRequest` (UPDATE) | Envia push via FCM ao mudar o status do pedido (ver [Notificações](#-notificações-push--in-app))   |
| `health-check`           | HTTP                                                     | Sonda de disponibilidade da camada de functions                                                    |

> A `send-push-notification` exige o header `x-webhook-secret` e **relê a linha no banco** (service role) antes de notificar — nunca confia no corpo do request. Detalhes em [Segurança](#-segurança).

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

| Perfil                | Telas disponíveis                                                                                                                                                  |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **Médico / Dentista** | Splash → Login → `DoctorHomeScreen` → `PrescriptionTypeScreen` → `PrescriptionFormScreen` → `RenewalPrescriptionScreen` → `PrescriptionViewScreen`                 |
| **Enfermeiro**        | Splash → Login → `NurseHomeScreen` → `TriageDetailScreen`                                                                                                          |
| **Paciente**          | Splash → Login / Register → `PatientRegisterScreen` → `HomeScreen` → `RequestRenewalScreen` → `RenewalTrackingScreen` → `HistoryScreen` → `PrescriptionViewScreen` |

> Todos os perfis compõem a UI a partir do tema central (`AppTheme`), com suporte a **tema claro e escuro** via `ThemeProvider` (alternado manualmente pelo usuário).

***

## 🔐 Autenticação

* O frontend autentica o usuário via **Supabase Auth** e recebe um access token JWT.
* O token é armazenado com **`flutter_secure_storage`** (Keychain no iOS, Keystore no Android) — **nunca** em `SharedPreferences`.
* O backend **não armazena** segredos de sessão — valida o token consultando o endpoint público JWKS do Supabase (`/auth/v1/.well-known/jwks.json`).
* O resolver JWKS é **cacheado em memória** para evitar requisições redundantes.
* O middleware `auth.middleware.ts` injeta `req.userId` (claim `sub` do token) para uso nos controllers.
* Endpoints legados em `/auth/register` e `/auth/login` retornam **`HTTP 410 Gone`**, orientando a migração para o fluxo Supabase.

***

## 🔐 Segurança

O projeto passou por uma **auditoria de segurança** (relatório completo em [`docs/auditoria-seguranca-e-receitasus.md`](docs/auditoria-seguranca-e-receitasus.md)). O backend Express mostrou-se sólido (JWKS, allowlist de algoritmos, CORS fail-closed, sem SQL raw); o foco do hardening foi a camada **BaaS** (RLS nas migrations + Edge Function). Correções aplicadas:

| Achado                                                    | Severidade | Status       | Onde                                                          |
| --------------------------------------------------------- | ---------- | ------------ | ------------------------------------------------------------- |
| INSERT de `prescriptions` não exigia papel de prescritor  | Crítico    | ✅ Corrigido | RLS `prescriptions_insert_doctor` (exige `MEDICO`/`DENTISTA`) |
| Edge Function de push com auth fraca + payload confiável  | Alto       | ✅ Corrigido | `WEBHOOK_SECRET` obrigatório + releitura da linha no banco    |
| `anon key` hard-coded na migration do webhook             | Médio      | ✅ Corrigido | Segredos lidos do **Supabase Vault**                          |
| Cópia integral de PII/PHI retida em `legacy_users` (LGPD) | Médio      | ✅ Corrigido | `DROP TABLE legacy_users` (minimização de dados)              |
| Wildcards `LIKE` não escapados na RPC de busca            | Baixo      | ✅ Corrigido | Escape de curingas na RPC (`ILIKE ... ESCAPE`)                |
| Dependências mortas `bcrypt`/`jsonwebtoken`               | Baixo      | ✅ Corrigido | Removidas — JWT validado só com `jose`                        |

> **Risco aceito (MVP acadêmico):** o auto-cadastro permite papel profissional auto-declarado (`professional_type`). Mitigação ao sair do MVP: provisionar profissionais via `service_role`/aprovação de admin, com cadastro público sempre virando `PACIENTE`.

> **Decisão consciente:** `GET /health-units` é **público** — a lista de UBS não contém PII e precisa carregar na tela de cadastro, antes de existir sessão.

Modelo de segurança completo na wiki: [`docs/wiki/Seguranca.md`](docs/wiki/Seguranca.md).

***

## 🌐 API REST — Backend Express

**Base URL (desenvolvimento):** `http://localhost:3333`

| Método | Rota             | Autenticação | Descrição                                                                 |
| ------ | ---------------- | :----------: | ------------------------------------------------------------------------- |
| `POST` | `/auth/register` |      ❌      | ⚠️ Legado — retorna `410 Gone`                                            |
| `POST` | `/auth/login`    |      ❌      | ⚠️ Legado — retorna `410 Gone`                                            |
| `GET`  | `/user/me`       |      ✅      | Retorna o perfil do usuário autenticado (Patient ou Professional)         |
| `GET`  | `/health-units`  |      ❌      | Lista UBS por município (`city` obrigatório, `state` opcional). **Público** — dado sem PII, usado na tela de cadastro antes da sessão |
| `GET`  | `/health`        |      ❌      | Health check para monitoramento/probes externos (`{ status, timestamp }`) |

> **Por que o backend tem poucos endpoints?** O fluxo de prescrições e renovações é gerenciado **diretamente via Supabase PostgREST** (com RLS), aproveitando Realtime para atualização imediata no app. O backend Express atua como **resource server complementar**, expondo apenas endpoints que exigem lógica de negócio fora do alcance do PostgREST.

### Edge Functions (Supabase)

Funções serverless em Deno, **não** chamadas diretamente pelo app:

| Método | Rota                                   | Autenticação       | Descrição                                                                |
| ------ | -------------------------------------- | ------------------ | ------------------------------------------------------------------------ |
| `POST` | `/functions/v1/send-push-notification` | `x-webhook-secret` | Acionada **só** pelo Database Webhook em `RenewalRequest`; envia push FCM |
| `GET`  | `/functions/v1/health-check`           | —                  | Sonda de disponibilidade das Edge Functions                              |

***

## 🗄 Acesso Direto ao Supabase (BaaS)

As operações abaixo são executadas pelo Flutter **sem passar pelo backend Express**, usando o SDK `supabase_flutter` com isolamento garantido por **Row Level Security**:

| Operação                       | Tabela / Recurso                     | Origem (Flutter)            |
| ------------------------------ | ------------------------------------ | --------------------------- |
| Listar prescrições do paciente | `prescriptions`                      | `prescription_service.dart` |
| Stream realtime de prescrições | `prescriptions`                      | `home_screen.dart`          |
| Emitir nova prescrição         | `prescriptions`                      | `prescription_service.dart` |
| Solicitar renovação            | `renewal_requests`                   | `renewal_service.dart`      |
| Triagem pelo enfermeiro        | `renewal_requests`                   | `triage_provider.dart`      |
| Buscar pacientes (RPC)         | `search_patients_for_prescription()` | `renewal_service.dart`      |
| Stream realtime de renovações  | `RenewalRequest`                     | `notification_service.dart` |

> Todas as policies RLS exigem `auth.uid()` correspondente ao `patient_user_id` ou `doctor_user_id`. A `service_role` key **nunca** é usada no frontend.

***

## 🔔 Notificações (Push + In-App)

O sistema notifica por **dois canais complementares**, ambos disparados por mudanças na tabela `RenewalRequest`:

**1. In-app (tempo real)** — `NotificationProvider` → `NotificationService` assina o **Supabase Realtime** sobre `RenewalRequest`. O enum `NotificationAudience` define o que cada perfil observa (paciente: status dos próprios pedidos; enfermeiro: novas solicitações; médico: pedidos triados atribuídos a ele). O widget `notification_bell.dart` exibe o badge in-app.

**2. Push em background (FCM)** — um **Database Webhook** (`pg_net`, função `notify_renewal_status_change`) chama a Edge Function `send-push-notification` a cada `UPDATE`, que envia push via **Firebase Cloud Messaging (HTTP v1)**:

| Transição de status | Destinatário               | Mensagem                      |
| ------------------- | -------------------------- | ----------------------------- |
| `→ TRIAGED`         | Médico (`doctorUserId`)    | "Nova renovação para avaliar" |
| `→ PRESCRIBED`      | Paciente (`patientUserId`) | "Renovação aprovada"          |
| `→ REJECTED`        | Paciente (`patientUserId`) | "Solicitação não aprovada"    |

O token FCM do dispositivo é registrado por `FcmTokenService` (injetado no `AuthProvider`) após o login, na coluna `fcmToken` de `patients`/`professionals`.

> **LGPD:** o corpo do push é **genérico** — nunca carrega nome de medicamento ou dado clínico. A Edge Function **relê a linha no banco** (service role) e resolve **um único destinatário**, ignorando o corpo do request. Destinatário sem token cadastrado resulta em *skip* (HTTP 200), nunca erro. Contrato e configuração detalhados na wiki: [`docs/wiki/Notificacoes-Push.md`](docs/wiki/Notificacoes-Push.md).

***

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
| **Push**           | `fcmToken` — token FCM do dispositivo (null sem permissão ou antes do 1º login no app)                       |
| **Metadados**      | `createdAt`, `updatedAt`                                                                                     |

### Entidade `Professional`

Profissional de saúde ou administrativo vinculado à UBS. **Nunca** contém `professionalType = PACIENTE`.

| Grupo                   | Campos                                                                                       |
| ----------------------- | -------------------------------------------------------------------------------------------- |
| **Identificação**       | `id`, `firstName`, `lastName`, `name`, `email`, `birthDate`                                  |
| **Dados profissionais** | `professionalType`, `professionalId`, `professionalState`, `specialty`                       |
| **Endereço**            | `zipCode`, `street`, `streetNumber`, `complement`, `district`, `addressCity`, `addressState` |
| **Vínculo**             | `healthUnitId` — FK para `HealthUnit` (máx. 3 profissionais por UBS, garantido por trigger)  |
| **Push**                | `fcmToken` — token FCM do dispositivo (null sem permissão ou antes do 1º login no app)       |
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

**`PrescriptionStatus`** *(tabela BaaS)*

| Valor       | Descrição                                |
| ----------- | ---------------------------------------- |
| `ACTIVE`    | Receita ativa e dentro da validade       |
| `EXPIRED`   | Receita com prazo de validade vencido    |
| `CANCELLED` | Receita cancelada pelo médico prescritor |

### Histórico de Migrations (38)

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
| 21  | `auto_assign_professional_health_unit`          |
| 22  | `seed_medico_address_for_autocomplete`          |
| 23  | `add_char2_constraint_professional_state`       |
| 24  | `increase_max_professionals_per_ubs`            |
| 25  | `renewal_request_defaults`                      |
| 26  | `seed_health_units_blumenau`                    |
| 27  | `add_block_duplicate_renewal_trigger`           |
| 28  | `fix_security_advisor_warnings`                 |
| 29  | `add_fcm_token_to_users`                        |
| 30  | `fix_rls_nurse_policies_renewal_request`        |
| 31  | `add_with_check_rls_update_policies`            |
| 32  | `add_realtime_publication_tables`               |
| 33  | `add_push_notification_webhook`                 |
| 34  | `rls_prescriptions_insert_require_prescriber`   |
| 35  | `escape_like_search_patients_rpc`               |
| 36  | `webhook_secret_from_vault`                     |
| 37  | `drop_legacy_users`                             |
| 38  | `fix_patients_street_number_type`               |

***

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

#### Segredos do Supabase (Edge Functions + Vault)

Os segredos abaixo **não** são GitHub Secrets — vivem no projeto Supabase e habilitam o push FCM (ver [Notificações](#-notificações-push--in-app)). Sem eles, o push apenas deixa de ser entregue (`401`), sem bloquear o fluxo de renovação.

| Segredo                    | Onde                   | Uso                                                             |
| -------------------------- | ---------------------- | --------------------------------------------------------------- |
| `FIREBASE_SERVICE_ACCOUNT` | Edge Function (secret) | JSON da conta de serviço do Firebase (assina o token FCM)       |
| `WEBHOOK_SECRET`           | Edge Function (secret) | Segredo compartilhado exigido no header `x-webhook-secret`      |
| `edge_anon_key`            | Supabase Vault         | `anon key` usada pelo webhook (lida em runtime, fora do código) |
| `edge_webhook_secret`      | Supabase Vault         | Espelho do `WEBHOOK_SECRET`, enviado pelo webhook               |

> `SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` são injetados automaticamente no runtime da Edge Function.

***

## Azure Boards

[![Board Status](https://dev.azure.com/LuksDickmannOrg/3875d22d-5c39-4cf3-bbc5-5aacc10584e0/47b8c04f-5b27-4e76-a77c-6c34aac29f88/_apis/work/boardbadge/41a4671e-43f5-4f82-afb2-b33d033a329b)](https://dev.azure.com/LuksDickmannOrg/3875d22d-5c39-4cf3-bbc5-5aacc10584e0/_boards/board/t/47b8c04f-5b27-4e76-a77c-6c34aac29f88/Backlog%20items/)

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

***

## 📂 Estrutura do Projeto

```text
e-receitasus/
├── .github/
│   └── workflows/
│       ├── ci.yml              # CI: testes backend + frontend
│       ├── main.yml            # CD: sync banco + deploy functions
│       └── release.yml         # Release Android (APK assinado)
│
├── supabase/
│   └── functions/                   # Edge Functions (Deno)
│       ├── send-push-notification/  # Push FCM no change de status (webhook)
│       ├── health-check/            # Sonda de disponibilidade
│       └── deno.json
│
├── backend/
│   ├── src/
│   │   ├── middlewares/
│   │   │   ├── auth.middleware.ts        # Validação JWT via JWKS
│   │   │   └── request-logger.middleware.ts
│   │   ├── repositories/
│   │   │   ├── user.repository.ts        # Único acesso ao Prisma Client
│   │   │   └── healthUnit.repository.ts  # Consulta de UBS por município
│   │   ├── routes/
│   │   │   ├── auth.routes.ts            # ⚠️ Legado (410 Gone)
│   │   │   ├── user.routes.ts            # GET /user/me
│   │   │   └── healthUnit.routes.ts      # GET /health-units
│   │   ├── services/
│   │   │   ├── auth.service.ts
│   │   │   └── healthUnit.service.ts
│   │   ├── utils/
│   │   │   └── prismaClient.ts
│   │   ├── app.ts                        # Configuração Express
│   │   └── server.ts                     # Bootstrap HTTP
│   ├── prisma/
│   │   ├── schema.prisma                 # Patient, Professional, HealthUnit, RenewalRequest
│   │   └── migrations/                   # 38 migrations versionadas
│   ├── tests/
│   │   ├── auth.test.ts
│   │   ├── cors.test.ts
│   │   ├── healthUnit.repository.test.ts
│   │   ├── healthUnit.routes.test.ts
│   │   └── healthUnit.service.test.ts
│   ├── jest.config.cjs
│   ├── prisma.config.ts
│   ├── tsconfig.json
│   └── package.json
│
└── frontend/
    ├── lib/
    │   ├── main.dart                     # Bootstrap + Supabase.initialize
    │   ├── models/                       # 9 data classes (Patient, Professional, Prescription, RenewalRequest, HealthUnit, PatientSearchResult, ...)
    │   ├── providers/                    # AuthProvider, PrescriptionProvider, RenewalProvider, TriageProvider, NotificationProvider, ThemeProvider
    │   ├── services/                     # AuthService, PrescriptionService, RenewalService, HealthUnitService, ViaCepService, NotificationService, FcmTokenService (com interfaces abstratas)
    │   ├── screens/                      # 15 telas (Splash, Login, Register, Patient/Doctor/NurseHome, Triage, RenewalTracking, ...)
    │   ├── widgets/                      # PrescriptionCard, NotificationBell
    │   └── theme/                        # AppColors, AppTextStyles, AppTheme
    ├── test/                             # Suíte de testes (services, providers, screens, models)
    ├── android/
    ├── ios/
    ├── web/
    ├── linux/
    ├── macos/
    ├── windows/
    ├── analysis_options.yaml
    └── pubspec.yaml
```

***

## ⚡ Quickstart (desenvolvimento local)

Siga estas etapas rápidas para subir o backend e o frontend em modo de desenvolvimento local (ambiente mínimo):

1. Configure variáveis de ambiente para o backend em `backend/.env` (veja a seção "Variáveis de Ambiente — Backend" abaixo).
2. No terminal 1 — iniciar backend em modo watch:

```bash
cd backend
npm install
npm run prisma:generate
npm run prisma:migrate
npm run dev
```

3. No terminal 2 — iniciar o app Flutter (emulador ou dispositivo):

```bash
cd frontend
flutter pub get
flutter run
```

Observações:

* Se estiver usando Supabase local ou remoto, ajuste `SUPABASE_URL` e `DATABASE_URL` no `backend/.env` conforme necessário.
* Para execução dos testes veja a seção `🧪 Testes` mais abaixo.

## 🚀 Como Executar

### Pré-requisitos

* Node.js 22+
* PostgreSQL 14+ (ou projeto Supabase configurado)
* Flutter SDK 3.4+

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
# Origens autorizadas para CORS (separadas por vírgula). Sem valor = nenhuma origem permitida.
ALLOWED_ORIGINS="http://localhost:8080,https://app.exemplo.com"
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

***

## 🧪 Testes

### Backend (Express) Tests

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

O frontend possui uma suíte de testes abrangente cobrindo: `AuthProvider`, `AuthService`, `HealthUnitService`, `LoginScreen`, cadastro de paciente (CEP, ViaCEP, UF e validações), vinculação de UBS no formulário de prescrição, busca de pacientes, `PrescriptionCard`, `PrescriptionModel`, `ProfessionalType`, `RenewalProvider`, `TriageProvider` e alternância de tema (`ThemeMode`). Toda service expõe interface abstrata para mockagem com **Mockito**:

```bash
dart run build_runner build
```

***

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

***

## 🎓 Contexto Acadêmico

**Disciplina:** Hands On Work X\
**Professor:** Mestre [Ewerton Eyre](https://www.linkedin.com/in/ewertoneyre/)\
**Curso:** Análise e Desenvolvimento de Sistemas\
**Instituição:** UNIVALI – Universidade do Vale do Itajaí\
**Desenvolvedor:** Lucas Elias Dickmann

***

## 👨‍💻 Aluno e Desenvolvedor

[![LinkedIn](https://img.shields.io/badge/LinkedIn-lucasdickmann-blue?logo=linkedin)](https://linkedin.com/in/lucasdickmann)
[![GitHub](https://img.shields.io/badge/GitHub-ldickmann-black?logo=github)](https://github.com/ldickmann)
