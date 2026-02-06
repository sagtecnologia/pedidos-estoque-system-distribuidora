-- =====================================================
-- MIGRAÇÃO: Garantir que vendas exijam caixa e movimentação
-- Descrição: Comandas seguem as mesmas regras do PDV - exigem caixa aberto
-- Data: 06/02/2026
-- =====================================================

-- IMPORTANTE: Comandas NÃO são vendas avulsas!
-- Devem seguir exatamente as mesmas regras do PDV:
-- 1. Exigir caixa aberto
-- 2. Criar movimentação no caixa
-- 3. Registrar saída de estoque
-- 4. Atualizar saldo do caixa

-- Garantir que caixa_id é obrigatório
ALTER TABLE vendas 
ALTER COLUMN caixa_id SET NOT NULL;

-- Garantir que movimentacao_caixa_id é obrigatório
ALTER TABLE vendas 
ALTER COLUMN movimentacao_caixa_id SET NOT NULL;

-- Comentários
COMMENT ON COLUMN vendas.caixa_id IS 'ID do caixa (obrigatório - todas as vendas devem ter caixa aberto)';
COMMENT ON COLUMN vendas.movimentacao_caixa_id IS 'ID da sessão do caixa (obrigatório - controla movimentação financeira)';

-- =====================================================
-- FIM DA MIGRAÇÃO
-- =====================================================

-- NOTA: Se houver vendas antigas sem caixa_id ou movimentacao_caixa_id,
-- esta migration falhará. Neste caso, você deve:
-- 1. Identificar as vendas problemáticas: SELECT id FROM vendas WHERE caixa_id IS NULL OR movimentacao_caixa_id IS NULL;
-- 2. Corrigir manualmente ou deletar essas vendas de teste
-- 3. Executar novamente esta migration
