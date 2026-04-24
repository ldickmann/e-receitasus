-- Migration: 20260424140000_increase_max_professionals_per_ubs
-- Motivo: O CHECK constraint original limitava max_professionals a no máximo 3,
-- bloqueando o cadastro de novos profissionais em UBSs que já atingiram esse teto.
-- Como a UBS não é escolhida manualmente pelo profissional (é auto-atribuída pelo
-- trigger trg_auto_assign_professional_health_unit com base no bairro/cidade),
-- o limite de 3 era restritivo demais para uso real.
-- A solução mantém o trigger de limite (trg_enforce_max_professionals_per_unit),
-- mas aumenta o valor padrão e atual para 20 profissionais por UBS.
-- Passo 1: Remove o CHECK constraint antigo (limite máximo de 3)
ALTER TABLE
  public.health_units DROP CONSTRAINT health_units_max_professionals_check;

-- Passo 2: Adiciona novo CHECK sem teto superior (apenas >= 1)
ALTER TABLE
  public.health_units
ADD
  CONSTRAINT health_units_max_professionals_check CHECK (max_professionals >= 1);

-- Passo 3: Atualiza o default da coluna para 20
ALTER TABLE
  public.health_units
ALTER COLUMN
  max_professionals
SET
  DEFAULT 20;

-- Passo 4: Atualiza todas as UBSs existentes para o novo limite
UPDATE
  public.health_units
SET
  max_professionals = 20;