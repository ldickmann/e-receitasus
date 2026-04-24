-- ============================================================================
-- Migration: Seed de endereço para MEDICOs de teste — habilita autocomplete
-- Motivação: o trigger auto_assign_professional_health_unit já existe, mas
-- todos os MEDICOs do banco eram seeds sem district/addressCity, então
-- nenhum deles tinha healthUnitId e a RPC search_patients_for_prescription
-- retornava 'Acesso negado'. Esta migration popula endereço nos seeds
-- existentes e o trigger BEFORE UPDATE preenche healthUnitId automaticamente.
-- Restrita aos UUIDs conhecidos (idempotente; só atualiza se ainda NULL).
-- ============================================================================

UPDATE public.professionals
   SET district     = 'Centro',
       "addressCity"= 'Navegantes'
 WHERE id IN (
   'c32ffda4-9dc8-4dd7-b83f-03e787e8d128',
   '2ad0b78e-da47-4dea-8d72-08f0c606f730',
   'ccddee00-2222-2222-2222-000000000002',
   '42809160-1e2c-454f-9e15-6fd2a96c68de'
 )
   AND district IS NULL
   AND "addressCity" IS NULL;
