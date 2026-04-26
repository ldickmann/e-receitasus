# Visão Geral do Sistema

O **E-ReceitaSUS** é uma aplicação para gestão digital de prescrições de uso contínuo no SUS. O sistema reduz papel, melhora a rastreabilidade e organiza a comunicação entre pacientes, enfermeiros e médicos/dentistas (`README.md`, linhas 5–15).

## Perfis de usuário

### Médico / Dentista

- Emite novas receitas digitais.
- Renova receitas existentes criando uma nova prescrição.
- Visualiza prescrições em tempo real via Supabase Realtime.
- Autoriza solicitações de renovação após triagem (`README.md`, linhas 78–84).

### Enfermeiro

- Recebe solicitações de renovação.
- Avalia clinicamente a necessidade.
- Encaminha ao médico da UBS ou rejeita a solicitação (`README.md`, linhas 85–90).

### Paciente

- Solicita renovação de receita.
- Acompanha o status em tempo real.
- Visualiza histórico completo de prescrições (`README.md`, linhas 91–95).

## Fluxo de renovação

```text
Paciente → PENDING_TRIAGE → Enfermeiro avalia → TRIAGED → Médico autoriza → PRESCRIBED
                                               ↘ REJECTED              ↘ REJECTED
```

Status principais (`README.md`, linhas 130–137):

| Status | Significado |
|---|---|
| `PENDING_TRIAGE` | Solicitação aguardando avaliação do enfermeiro |
| `TRIAGED` | Triagem aprovada, aguardando médico |
| `PRESCRIBED` | Médico autorizou e nova prescrição foi criada |
| `REJECTED` | Solicitação rejeitada |

## Regras centrais

- Toda renovação exige autorização médica.
- O médico responsável é vinculado à UBS do paciente.
- A renovação gera uma nova prescrição com nova data de emissão e validade.
- Apenas médicos e dentistas podem emitir ou renovar prescrições (`README.md`, linhas 139–145).
