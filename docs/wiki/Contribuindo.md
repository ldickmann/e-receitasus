# Contribuindo

## Fluxo recomendado

1. Criar branch a partir de `develop`.
2. Implementar a mudança mantendo a arquitetura em camadas.
3. Rodar testes afetados.
4. Abrir Pull Request para `develop`.
5. Aguardar CI passar antes do merge.

## Regras técnicas

- Backend: TypeScript strict, sem uso desnecessário de `any`.
- Backend: acesso ao Prisma centralizado em repositories.
- Frontend: screens não devem acessar services diretamente; use providers.
- Frontend: services devem ter interface abstrata para facilitar mocks.
- Dados sensíveis devem continuar protegidos por RLS e armazenamento seguro.

Essas regras derivam da arquitetura descrita no `README.md`, linhas 180–214.

## Checklist de PR

- [ ] Testes relevantes executados.
- [ ] Nenhuma credencial adicionada ao repositório.
- [ ] Migrations documentadas quando houver mudança de banco.
- [ ] Wiki/README atualizados quando houver mudança de fluxo, endpoint ou tela.
