# Manutenção da Wiki

A Wiki do GitHub é um repositório Git separado do código principal. Para este projeto, a URL esperada é:

```text
https://github.com/ldickmann/e-receitasus.wiki.git
```

## Habilitar Wiki no GitHub

1. Abrir `https://github.com/ldickmann/e-receitasus`.
2. Entrar em **Settings**.
3. Em **Features**, marcar **Wikis**.
4. A aba **Wiki** aparecerá no repositório.

## Publicar estas páginas na Wiki

```bash
git clone https://github.com/ldickmann/e-receitasus.wiki.git
cd e-receitasus.wiki
cp /caminho/para/e-receitasus/docs/wiki/*.md .
git add .
git commit -m "docs: publicar wiki inicial"
git push
```

## Convenções

- Idioma: português brasileiro.
- Um `# Título` por página.
- Nomes de arquivo com hífens, por exemplo `Configuracao-do-Ambiente.md`.
- Links internos no formato `[[Texto|Nome-da-Pagina]]`.
- Atualizar a Wiki quando houver mudança em migrations, APIs, telas, fluxos de negócio, CI/CD ou segurança.
