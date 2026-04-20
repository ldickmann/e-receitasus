-- ---------------------------------------------------------------------------
-- Tabela: prescriptions (BaaS — usada pelo Flutter via Supabase SDK)
--
-- Tabela separada da "Prescription" do Prisma. Armazena prescrições completas
-- no padrão ANVISA (Portaria SVS/MS 344/98 e RDC 471/2021) com todos os
-- campos necessários para os 4 tipos de receita.
-- Colunas em snake_case conforme convenção PostgREST/Supabase.
-- ---------------------------------------------------------------------------
CREATE TABLE public.prescriptions (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type                        TEXT NOT NULL DEFAULT 'BRANCA',

  -- Dados do profissional prescritor
  doctor_name                 TEXT NOT NULL,
  doctor_council              TEXT NOT NULL,
  doctor_council_state        TEXT NOT NULL,
  doctor_specialty            TEXT,
  doctor_address              TEXT NOT NULL,
  doctor_city                 TEXT NOT NULL,
  doctor_state                TEXT NOT NULL,
  doctor_phone                TEXT,
  doctor_cnes                 TEXT,

  -- Dados do estabelecimento de saúde
  clinic_name                 TEXT,
  clinic_cnpj                 TEXT,

  -- Dados do paciente
  patient_name                TEXT NOT NULL,
  patient_cpf                 TEXT,
  patient_address             TEXT,
  patient_city                TEXT,
  patient_state               TEXT,
  patient_phone               TEXT,
  patient_age                 TEXT,

  -- Prescrição
  medicine_name               TEXT NOT NULL,
  dosage                      TEXT NOT NULL,
  pharmaceutical_form         TEXT,
  route                       TEXT,
  quantity                    TEXT NOT NULL,
  quantity_words              TEXT,
  instructions                TEXT NOT NULL,

  -- Notificação (Amarela/Azul)
  notification_number         TEXT,
  notification_uf             TEXT,

  -- Receita contínua (RDC 471/2021)
  is_continuous_use           BOOLEAN NOT NULL DEFAULT FALSE,
  continuous_validity_months  INTEGER,

  -- Status e metadados
  issued_at                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  valid_until                 TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  status                      TEXT NOT NULL DEFAULT 'ativa',

  -- Referências de usuários Supabase Auth
  doctor_user_id              UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  patient_user_id             UUID REFERENCES auth.users(id) ON DELETE CASCADE,

  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índices para queries frequentes do Flutter (stream e histórico)
CREATE INDEX idx_prescriptions_patient_user_id ON public.prescriptions(patient_user_id);
CREATE INDEX idx_prescriptions_doctor_user_id  ON public.prescriptions(doctor_user_id);
CREATE INDEX idx_prescriptions_status          ON public.prescriptions(status);
CREATE INDEX idx_prescriptions_issued_at       ON public.prescriptions(issued_at DESC);
CREATE INDEX idx_prescriptions_type            ON public.prescriptions(type);

-- Trigger para atualizar updated_at automaticamente
CREATE OR REPLACE FUNCTION public.set_prescriptions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prescriptions_updated_at
  BEFORE UPDATE ON public.prescriptions
  FOR EACH ROW
  EXECUTE FUNCTION public.set_prescriptions_updated_at();

-- RLS: habilita segurança por linha
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
