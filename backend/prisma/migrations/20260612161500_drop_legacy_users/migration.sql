-- =============================================================================
-- Remove a tabela public.legacy_users (hardening #6 — minimização LGPD)
--
-- Problema: a migration 20260421000000 renomeou "User" → legacy_users (em vez de
-- remover) "para rollback seguro... pode ser dropada em migration futura". Ela
-- mantém uma CÓPIA INTEGRAL de PII/PHI (CPF, CNS, endereço) de todos os usuários
-- migrados, contrariando o princípio de minimização de dados (LGPD art. 6, III).
--
-- Solução: remover a tabela. Os dados vivos estão em public.patients e
-- public.professionals desde 2026-04-21, tornando a cópia legada desnecessária.
--
-- ATENÇÃO: operação DESTRUTIVA e irreversível. Garanta backup auditado antes de
-- aplicar em produção, caso a política de retenção/contingência exija.
-- =============================================================================

DROP TABLE IF EXISTS public.legacy_users;