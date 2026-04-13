# 📱 E-ReceitaSUS

> Sistema completo de gestão e digitalização de prescrições médicas com autenticação segura, histórico de receitas e rastreamento em tempo real.

## 💡 Sobre o Projeto

O **E-ReceitaSUS** é uma solução full-stack desenvolvida para modernizar e digitalizar o processo de prescrição e revalidação de receitas médicas. O sistema oferece uma plataforma robusta para profissionais de saúde gerenciarem prescrições digitalmente, enquanto pacientes acompanham todo o histórico de suas receitas de forma centralizada e segura.

### 🎯 Problema Resolvido

Elimina a necessidade de receitas físicas, reduz erros de prescrição, facilita o rastreamento de medicamentos e melhora a comunicação entre profissionais de saúde e pacientes.

---

## 📑 Índice

- [📱 E-ReceitaSUS](#-e-receitasus)
  - [💡 Sobre o Projeto](#-sobre-o-projeto)
    - [🎯 Problema Resolvido](#-problema-resolvido)
  - [📑 Índice](#-índice)
  - [✨ Principais Funcionalidades](#-principais-funcionalidades)
  - [🛠 Stack Tecnológico](#-stack-tecnológico)
    - [Backend](#backend)
    - [Frontend](#frontend)
    - [Qualidade e Engenharia](#qualidade-e-engenharia)
  - [🏗 Arquitetura](#-arquitetura)
  - [🔐 Autenticação](#-autenticação)
  - [🧩 Modelagem de Dados](#-modelagem-de-dados)
  - [⚙️ CI/CD Pipeline](#️-cicd-pipeline)
    - [Jobs executados em sequência](#jobs-executados-em-sequência)
    - [Segurança](#segurança)
  - [📂 Estrutura do Projeto](#-estrutura-do-projeto)
  - [🚀 Como Executar](#-como-executar)
    - [Pré-requisitos](#pré-requisitos)
    - [Backend (API)](#backend-api)
    - [Frontend (App Flutter)](#frontend-app-flutter)
  - [🧪 Testes](#-testes)
    - [Backend (Testes)](#backend-testes)
    - [Frontend (Testes)](#frontend-testes)
  - [📜 Scripts do Backend](#-scripts-do-backend)
  - [🎓 Contexto Acadêmico](#-contexto-acadêmico)
  - [👨‍💻 Aluno e Desenvolvedor](#-aluno-e-desenvolvedor)
    - [Desenvolvido com TypeScript, Flutter e boas práticas de engenharia de software, seguindo princípios de arquitetura em camadas, TDD e garantindo qualidade e manutenibilidade do código](#desenvolvido-com-typescript-flutter-e-boas-práticas-de-engenharia-de-software-seguindo-princípios-de-arquitetura-em-camadas-tdd-e-garantindo-qualidade-e-manutenibilidade-do-código)

---

## ✨ Principais Funcionalidades

- Autenticação e autorização com **Supabase Auth** e validação de token no backend via **JWKS**.
- CRUD completo de prescrições médicas.
- Associação entre paciente e profissional de saúde com integridade referencial.
- Histórico de prescrições por usuário.
- Atualização em tempo real no app Flutter (stream/realtime).
- Regras de domínio com tipagem forte no backend (TypeScript + Prisma) e frontend (Dart).

---

## 🛠 Stack Tecnológico

### Backend

- **Node.js 22 LTS** + **TypeScript**
- **Express.js**
- **Prisma ORM** + **PostgreSQL**
- **jose** (validação JWT/JWKS)
- **Jest** + **Supertest** (testes)

### Frontend

- **Flutter** + **Dart**
- **Provider**
- **supabase_flutter**
- **http**
- **flutter_secure_storage**
- **shared_preferences**

### Qualidade e Engenharia

- **TDD** (Test-Driven Development)
- **Type Safety end-to-end**
- **Migrations versionadas com Prisma**
- **Separação de responsabilidades em camadas**
- **GitHub Actions** (CI/CD automatizado)

---

## 🏗 Arquitetura

O projeto segue princípios de arquitetura em camadas, facilitando manutenção, escalabilidade e testabilidade:

- **Presentation Layer**: rotas, controllers e middlewares.
- **Business Layer**: serviços e regras de negócio.
- **Data Layer**: Prisma Client e repositórios.
- **Database Layer**: PostgreSQL.

Fluxo resumido:

1. Frontend autentica via Supabase.
2. Frontend consome API protegida com JWT.
3. Backend valida token via JWKS.
4. Backend persiste e consulta dados via Prisma/PostgreSQL.
5. Frontend recebe atualizações em tempo real quando aplicável.

---

## 🔐 Autenticação

- O fluxo oficial de autenticação é via **Supabase Auth** no frontend.
- O backend atua como **resource server**, validando JWT nas rotas protegidas.
- Endpoints legados de auth local podem existir por compatibilidade, mas o fluxo principal atual é Supabase.

---

## 🧩 Modelagem de Dados

Principais entidades:

- **User**
  - Campos de identificação e dados profissionais.
  - Enum de tipo profissional (`ProfessionalType`).
- **Prescription**
  - Dados da prescrição, status (`PrescriptionStatus`) e relacionamentos.
  - Relação com paciente (obrigatória) e profissional prescritor (opcional).

Enums utilizados:

- `ProfessionalType`: médico, enfermeiro, farmacêutico, psicólogo, nutricionista, fisioterapeuta, dentista, assistente social, administrativo e outros.
- `PrescriptionStatus`: ativa, expirada, cancelada.

---

## ⚙️ CI/CD Pipeline

O projeto utiliza **GitHub Actions** para automatizar a validação, sincronização do banco e deploy de funções a cada push na branch `develop`.

### Jobs executados em sequência

| Job                            | Responsabilidade                                     | Gatilho                                          |
| ------------------------------ | ---------------------------------------------------- | ------------------------------------------------ |
| **Configurar Ambiente**        | Instala Node.js 22 e Supabase CLI                    | `push` e `pull_request`                          |
| **Sincronizar Banco de Dados** | Executa `npx prisma db push` contra o banco Supabase | Apenas `push`                                    |
| **Deploy Edge Functions**      | Executa `supabase functions deploy`                  | Apenas `push` (se `supabase/functions/` existir) |

### Segurança

Todas as credenciais são injetadas via **GitHub Secrets** — nenhuma é exposta no código-fonte:

| Secret                  | Uso                                                    |
| ----------------------- | ------------------------------------------------------ |
| `DATABASE_URL`          | Conexão direta com o banco (porta 5432, sem PgBouncer) |
| `SUPABASE_ACCESS_TOKEN` | Autenticação no Supabase CLI                           |
| `SUPABASE_PROJECT_ID`   | Referência do projeto Supabase                         |

---

## 📂 Estrutura do Projeto

```text
e-receitasus/
├── .github/
│   └── workflows/
│       └── main.yml          # Pipeline de CI/CD
├── backend/
│   ├── src/
│   │   ├── controllers/
│   │   ├── middlewares/
│   │   ├── repositories/
│   │   ├── routes/
│   │   ├── services/
│   │   └── utils/
│   ├── prisma/
│   │   ├── schema.prisma
│   │   └── migrations/
│   ├── tests/
│   └── package.json
└── frontend/
    ├── lib/
    │   ├── models/
    │   ├── providers/
    │   ├── screens/
    │   └── services/
    ├── test/
    └── pubspec.yaml
```

---

## 🚀 Como Executar

### Pré-requisitos

- Node.js 22+
- PostgreSQL 14+
- Flutter SDK 3.4+

Dependências extras para build Linux (quando necessário):

```bash
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev libjsoncpp-dev
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

### Frontend (Testes)

```bash
cd frontend
flutter test
```

---

## 📜 Scripts do Backend

- `npm run dev`: inicia servidor em desenvolvimento com hot reload.
- `npm run build`: compila TypeScript para JavaScript.
- `npm run start`: executa build de produção.
- `npm run test`: executa testes.
- `npm run test:watch`: executa testes em modo watch.
- `npm run test:coverage`: gera cobertura.
- `npm run prisma:generate`: gera Prisma Client.
- `npm run prisma:migrate`: aplica migrations no ambiente local.
- `npm run prisma:studio`: abre interface visual do banco.

---

## 🎓 Contexto Acadêmico

**Disciplina:** Hands On Work IX  
**Professor:** Mestre [LinkedIn: Professor Ewerton Eyre](https://www.linkedin.com/in/ewertoneyre/)  
**Curso:** Análise e Desenvolvimento de Sistemas  
**Instituição:** UNIVALI – Universidade do Vale do Itajaí  
**Desenvolvedor:** Lucas Elias Dickmann

---

## 👨‍💻 Aluno e Desenvolvedor

Lucas Elias Dickmann

[![LinkedIn](https://img.shields.io/badge/LinkedIn-lucasdickmann-blue?logo=linkedin)](https://linkedin.com/in/lucasdickmann)

[![GitHub](https://img.shields.io/badge/GitHub-ldickmann-black?logo=github)](https://github.com/ldickmann)

[![E-mail](https://img.shields.io/badge/E--mail-ldickmann12%40gmail.com-red?logo=gmail)](mailto:ldickmann12@gmail.com)

[![E-mail Acadêmico](https://img.shields.io/badge/E--mail%20Acad%C3%AAmico-lucas.8315540%40edu.univali.br-red?logo=gmail)](mailto:lucas.8315540@edu.univali.br)

---

### Desenvolvido com TypeScript, Flutter e boas práticas de engenharia de software, seguindo princípios de arquitetura em camadas, TDD e garantindo qualidade e manutenibilidade do código
