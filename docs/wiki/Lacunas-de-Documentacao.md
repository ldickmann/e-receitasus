# Lacunas de Documentação

As lacunas abaixo dependem de informações de ambiente e operação que não estão completamente presentes no repositório.

## Supabase

- Passo a passo para criar o projeto Supabase.
- Como localizar credenciais reais (`SUPABASE_URL`, connection strings, secrets).
- Como aplicar SQL nativo relacionado a `prescriptions`, triggers, RLS e RPCs.
- Como configurar `service_role` apenas em ambiente seguro.

## Produção

- Onde o backend Express é hospedado.
- URL de produção da API.
- Como o Flutter escolhe ambiente de dev/staging/prod.

## Android Release

- Como gerar keystore com `keytool`.
- Como transformar o keystore em `KEYSTORE_BASE64`.
- Procedimento de rotação/backup do keystore.

## Edge Functions

O workflow de CD menciona deploy de Supabase Edge Functions (`README.md`, linhas 446–450), mas o repositório atual não apresenta um diretório evidente de functions. O mantenedor deve esclarecer se esse passo é ativo, futuro ou legado.

## Cadastro de profissionais

O README descreve pacientes e profissionais, mas falta um fluxo operacional claro para cadastrar médicos, enfermeiros e dentistas em ambiente real.

## LGPD e privacidade

O projeto trata CPF, CNS e dados de saúde. Recomenda-se documentar política de privacidade, base legal, retenção de dados, controle de acesso e responsável pelo tratamento.
