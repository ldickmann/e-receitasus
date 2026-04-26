# Padrão de Commits

O projeto usa Conventional Commits com referência a Azure Boards no formato `AB#<número>` (`README.md`, linhas 478–486).

## Formato

```text
<tipo>(escopo): <descrição resumida> AB#<número-da-task>
```

## Tipos aceitos

| Tipo | Uso |
|---|---|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `ci` | CI/CD |
| `chore` | Manutenção |
| `docs` | Documentação |
| `test` | Testes |
| `refactor` | Refatoração |
| `perf` | Performance |

Conforme `README.md`, linhas 488–499.

## Exemplos

```bash
feat(prescription): adicionar endpoint de cancelamento de receita AB#90
fix(auth): corrigir validação de JWT expirado AB#91
ci: implementar sincronização Prisma e deploy de Edge Functions AB#86
docs: atualizar README com seção de CI/CD e padrão de commits AB#87
```

Baseado em `README.md`, linhas 501–508.
