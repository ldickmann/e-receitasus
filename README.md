# 📱 E-ReceitaSUS

> Sistema completo de gestão e digitalização de prescrições médicas com autenticação segura, histórico de receitas e rastreamento em tempo real.

## 💡 Sobre o Projeto

O **E-ReceitaSUS** é uma solução full-stack desenvolvida para modernizar e digitalizar o processo de prescrição e revalidação de receitas médicas. O sistema oferece uma plataforma robusta para profissionais de saúde gerenciarem prescrições digitalmente, enquanto pacientes acompanham todo o histórico de suas receitas de forma centralizada e segura.

### 🎯 Problema Resolvido

Elimina a necessidade de receitas físicas, reduz erros de prescrição, facilita o rastreamento de medicamentos e melhora a comunicação entre profissionais de saúde e pacientes.

---

## 🚀 Stack Tecnológico

### Backend

- **Node.js** + **TypeScript** - Runtime JavaScript com tipagem estática
- **Express.js** - Framework web minimalista e robusto
- **Prisma ORM** - ORM moderno com type-safety e migrations automáticas
- **PostgreSQL** - Banco de dados relacional de alta performance
- **JWT (JSON Web Tokens)** - Autenticação stateless e segura
- **bcrypt** - Criptografia de senhas com salt

### Frontend

- **Flutter** - Framework multiplataforma (Android, iOS, Web, Windows, macOS, Linux)
- **Dart** - Linguagem otimizada para desenvolvimento mobile
- **Provider** - Gerenciamento de estado reativo
- **HTTP Client** - Integração com API REST

### Qualidade & DevOps

- **Jest** - Framework de testes com mocks e cobertura de código
- **ESLint** - Linter para manter código padronizado
- **TypeScript Compiler** - Verificação de tipos em tempo de desenvolvimento
- **Git** - Controle de versão com branches e commits semânticos

---

## ⚙️ Arquitetura & Design Patterns

### Clean Architecture

O projeto segue os princípios de **Clean Architecture** com separação clara de responsabilidades:

```text
┌─────────────────────────────────────────┐
│          Presentation Layer             │
│  (Routes, Controllers, Middlewares)     │
├─────────────────────────────────────────┤
│          Business Logic Layer           │
│         (Services, Use Cases)           │
├─────────────────────────────────────────┤
│          Data Access Layer              │
│    (Repositories, Prisma Client)        │
├─────────────────────────────────────────┤
│          Database Layer                 │
│      (PostgreSQL via Prisma)            │
└─────────────────────────────────────────┘
```

### Padrões Implementados

- **Repository Pattern** - Abstração da camada de dados
- **Dependency Injection** - Reduz acoplamento entre componentes
- **Middleware Pattern** - Validação e autenticação modular
- **DTO (Data Transfer Objects)** - Tipagem segura de requisições/respostas
- **JWT Strategy** - Autenticação stateless com tokens

### API RESTful

Endpoints seguindo convenções REST com verbos HTTP semânticos:

- `POST /api/auth/register` - Cadastro de usuários
- `POST /api/auth/login` - Autenticação com retorno de token
- `GET /api/prescriptions` - Listagem de prescrições
- `POST /api/prescriptions` - Criação de nova prescrição
- `GET /api/history/:userId` - Histórico completo do paciente

---

## 📂 Estrutura do Projeto

```text
e-receitasus/
├── backend/
│   ├── src/
│   │   ├── app.ts                    # Configuração do Express
│   │   ├── server.ts                 # Entry point da aplicação
│   │   ├── controllers/              # Controladores de requisições
│   │   │   ├── auth.controller.ts
│   │   │   ├── prescription.controller.ts
│   │   │   └── history.controller.ts
│   │   ├── services/                 # Regras de negócio
│   │   │   └── auth.service.ts
│   │   ├── repositories/             # Acesso a dados
│   │   │   └── user.repository.ts
│   │   ├── middlewares/              # Autenticação e validações
│   │   │   └── auth.middleware.ts
│   │   ├── routes/                   # Rotas da API
│   │   │   ├── auth.routes.ts
│   │   │   ├── prescription.routes.ts
│   │   │   ├── history.routes.ts
│   │   │   └── user.routes.ts
│   │   ├── utils/                    # Utilitários
│   │   │   ├── jwt.util.ts
│   │   │   └── prismaClient.ts
│   │   └── config/                   # Configurações
│   ├── prisma/
│   │   ├── schema.prisma             # Schema do banco de dados
│   │   └── migrations/               # Histórico de migrations
│   ├── tests/                        # Testes automatizados
│   │   ├── auth.test.ts
│   │   ├── auth-integration.test.ts
│   │   ├── prescription.test.ts
│   │   └── history.test.ts
│   ├── package.json
│   ├── tsconfig.json
│   └── jest.config.cjs
│
└── frontend/
    ├── lib/
    │   ├── main.dart                 # Entry point do app
    │   ├── screens/                  # Telas do aplicativo
    │   ├── services/                 # Integração com API
    │   ├── models/                   # Modelos de dados
    │   └── providers/                # Gerenciamento de estado
    ├── test/                         # Testes do Flutter
    │   ├── auth_service_test.dart
    │   ├── login_screen_test.dart
    │   ├── prescription_flow_test.dart
    │   └── history_flow_test.dart
    ├── pubspec.yaml
    └── analysis_options.yaml
```

---

## 🔧 Funcionalidades Implementadas

### 🔐 Sistema de Autenticação

- ✅ Registro de usuários com validação de dados
- ✅ Login com geração de token JWT
- ✅ Middleware de proteção de rotas privadas
- ✅ Hash de senhas com bcrypt e salt
- ✅ Tipos de usuário (paciente, médico, nutricionista, etc.)
- ✅ Campos profissionais (CRM, especialidade)

### 💊 Gestão de Prescrições

- ✅ Criação de prescrições médicas completas
- ✅ Associação prescrição-paciente com integridade referencial
- ✅ Listagem e filtragem de prescrições
- ✅ Atualização e exclusão (CRUD completo)
- ✅ Validação de dados obrigatórios

### 📋 Histórico de Receitas

- ✅ Visualização completa do histórico do paciente
- ✅ Rastreamento temporal de todas prescrições
- ✅ Relacionamento entre profissional e paciente
- ✅ Consulta de receitas por usuário

### 🗃️ Banco de Dados

- ✅ Modelagem relacional normalizada
- ✅ Migrations versionadas (4 migrations aplicadas)
- ✅ Constraints de integridade referencial
- ✅ Índices para otimização de queries
- ✅ Prisma Client type-safe

### ✅ Qualidade de Código

- ✅ Testes unitários com mocks
- ✅ Testes de integração end-to-end
- ✅ Cobertura de casos críticos de autenticação
- ✅ Cobertura de fluxos de prescrição
- ✅ Testes de histórico e rastreamento
- ✅ TypeScript strict mode habilitado

---

## 🧪 Testes Implementados

### Backend (Jest)

```typescript
// Testes unitários de autenticação
✓ Validação de credenciais
✓ Geração de tokens JWT
✓ Hash de senhas

// Testes de integração
✓ Fluxo completo de registro
✓ Fluxo completo de login
✓ Criação de prescrições
✓ Consulta de histórico
```

### Frontend (Flutter)

```dart
// Testes de serviços
✓ Integração com API de auth
✓ Mocks de requisições HTTP

// Testes de telas
✓ Login screen widgets
✓ Fluxos de navegação

// Testes de funcionalidades
✓ Fluxo de prescrição
✓ Fluxo de histórico
✓ Fluxo de rastreamento
```

---

## 🛠️ Metodologia de Desenvolvimento

### Test-Driven Development (TDD)

- 🔴 **Red:** Escrever teste que falha
- 🟢 **Green:** Implementar código mínimo para passar
- 🔵 **Refactor:** Melhorar código mantendo testes passando

### Scrum

- **Sprints** organizadas por funcionalidades
- **User Stories** definindo requisitos
- **Retrospectivas** para melhoria contínua

---

## 🎓 Contexto Acadêmico

**Disciplina:** Hands on Work VIII  
**Curso:** Análise e Desenvolvimento de Sistemas  
**Instituição:** UNIVALI – Universidade do Vale do Itajaí  
**Desenvolvedor:** Lucas Elias Dickmann  
**Período:** 2025-2026

---

## 📈 Diferenciais Técnicos

✨ **Type Safety Total:** TypeScript no backend + Dart no frontend  
✨ **Multiplataforma:** Um código Flutter para 6 plataformas  
✨ **Segurança:** JWT + bcrypt + validações em múltiplas camadas  
✨ **Escalabilidade:** Arquitetura em camadas permite crescimento  
✨ **Manutenibilidade:** Clean Code, SOLID, padrões de design  
✨ **Testabilidade:** Cobertura de testes automatizados  
✨ **Versionamento:** Migrations do Prisma para evolução do schema

---

## 🚀 Como Executar

### Pré-requisitos

```bash
Node.js 18+
PostgreSQL 14+
Flutter SDK 3+
```

### Backend

```bash
cd backend
npm install
npx prisma migrate dev
npm run dev
```

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

### Testes

```bash
# Backend
npm test

# Frontend
flutter test
```

---

## 📞 Contato

**Desenvolvedor:** Lucas Elias Dickmann  
**LinkedIn:** [https://linkedin/in/lucasdickmann]  
**GitHub:** [github.com/ldickmann]  
**Email:** [ldickmann12@gmail.com]

---

---

### Desenvolvido usando TypeScript, Flutter e boas práticas de engenharia de software

---
