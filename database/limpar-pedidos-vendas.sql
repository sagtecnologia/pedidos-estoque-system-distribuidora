-- =====================================================
-- SCRIPT DE LIMPEZA - PEDIDOS DE COMPRA E VENDAS
-- =====================================================
-- Este script remove TODOS os pedidos de compra, vendas e movimentações
-- ⚠️ ATENÇÃO: Esta operação é IRREVERSÍVEL!
-- ⚠️ Faça backup antes de executar!
-- =====================================================

-- Iniciar transação para garantir atomicidade
BEGIN;

-- =====================================================
-- 1. REMOVER MOVIMENTAÇÕES DE ESTOQUE
-- =====================================================
DO $$
DECLARE
    v_count_mov INTEGER;
BEGIN
    -- Contar movimentações
    SELECT COUNT(*) INTO v_count_mov FROM estoque_movimentacoes;
    RAISE NOTICE '📊 Movimentações de estoque encontradas: %', v_count_mov;
    
    -- Deletar todas as movimentações
    DELETE FROM estoque_movimentacoes;
    
    RAISE NOTICE '✅ Movimentações de estoque removidas: %', v_count_mov;
END $$;

-- =====================================================
-- 2. REMOVER ITENS DE PEDIDOS DE COMPRA
-- =====================================================
DO $$
DECLARE
    v_count_itens INTEGER;
BEGIN
    -- Contar itens
    SELECT COUNT(*) INTO v_count_itens FROM pedido_compra_itens;
    RAISE NOTICE '📊 Itens de pedidos de compra encontrados: %', v_count_itens;
    
    -- Deletar todos os itens
    DELETE FROM pedido_compra_itens;
    
    RAISE NOTICE '✅ Itens de pedidos de compra removidos: %', v_count_itens;
END $$;

-- =====================================================
-- 3. REMOVER PEDIDOS DE COMPRA
-- =====================================================
DO $$
DECLARE
    v_count_pedidos INTEGER;
BEGIN
    -- Contar pedidos
    SELECT COUNT(*) INTO v_count_pedidos FROM pedidos_compra;
    RAISE NOTICE '📊 Pedidos de compra encontrados: %', v_count_pedidos;
    
    -- Deletar todos os pedidos
    DELETE FROM pedidos_compra;
    
    RAISE NOTICE '✅ Pedidos de compra removidos: %', v_count_pedidos;
END $$;

-- =====================================================
-- 4. REMOVER COMANDAS (tem FK para vendas)
-- =====================================================
DO $$
DECLARE
    v_count_comandas INTEGER;
BEGIN
    -- Contar comandas
    SELECT COUNT(*) INTO v_count_comandas FROM comandas;
    RAISE NOTICE '📊 Comandas encontradas: %', v_count_comandas;
    
    -- Deletar todas as comandas
    DELETE FROM comandas;
    
    RAISE NOTICE '✅ Comandas removidas: %', v_count_comandas;
END $$;

-- =====================================================
-- 5. REMOVER ITENS DE VENDAS
-- =====================================================
DO $$
DECLARE
    v_count_itens_venda INTEGER;
BEGIN
    -- Contar itens de vendas
    SELECT COUNT(*) INTO v_count_itens_venda FROM venda_itens;
    RAISE NOTICE '📊 Itens de vendas encontrados: %', v_count_itens_venda;
    
    -- Deletar todos os itens de vendas
    DELETE FROM venda_itens;
    
    RAISE NOTICE '✅ Itens de vendas removidos: %', v_count_itens_venda;
END $$;

-- =====================================================
-- 6. REMOVER VENDAS
-- =====================================================
DO $$
DECLARE
    v_count_vendas INTEGER;
BEGIN
    -- Contar vendas
    SELECT COUNT(*) INTO v_count_vendas FROM vendas;
    RAISE NOTICE '📊 Vendas encontradas: %', v_count_vendas;
    
    -- Deletar todas as vendas
    DELETE FROM vendas;
    
    RAISE NOTICE '✅ Vendas removidas: %', v_count_vendas;
END $$;

-- =====================================================
-- 7. RESETAR ESTOQUE DOS PRODUTOS (OPCIONAL)
-- =====================================================
-- Descomente as linhas abaixo se quiser zerar o estoque de todos os produtos

-- DO $$
-- DECLARE
--     v_count_produtos INTEGER;
-- BEGIN
--     -- Contar produtos
--     SELECT COUNT(*) INTO v_count_produtos FROM produtos WHERE estoque_atual > 0;
--     RAISE NOTICE '📊 Produtos com estoque encontrados: %', v_count_produtos;
--     
--     -- Resetar estoque para zero
--     UPDATE produtos SET estoque_atual = 0;
--     
--     RAISE NOTICE '✅ Estoque dos produtos resetado para zero';
-- END $$;

-- =====================================================
-- 8. REMOVER MOVIMENTAÇÕES DE CAIXA (OPCIONAL)
-- =====================================================
-- Descomente as linhas abaixo se quiser remover também movimentações de caixa

-- DO $$
-- DECLARE
--     v_count_mov_caixa INTEGER;
-- BEGIN
--     -- Contar movimentações de caixa
--     SELECT COUNT(*) INTO v_count_mov_caixa FROM movimentacao_caixa;
--     RAISE NOTICE '📊 Movimentações de caixa encontradas: %', v_count_mov_caixa;
--     
--     -- Deletar movimentações de caixa
--     DELETE FROM movimentacao_caixa;
--     
--     RAISE NOTICE '✅ Movimentações de caixa removidas: %', v_count_mov_caixa;
-- END $$;

-- =====================================================
-- RESUMO FINAL
-- =====================================================
DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ LIMPEZA CONCLUÍDA COM SUCESSO!';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Dados removidos:';
    RAISE NOTICE '  ✓ Movimentações de estoque';
    RAISE NOTICE '  ✓ Itens de pedidos de compra';
    RAISE NOTICE '  ✓ Pedidos de compra';
    RAISE NOTICE '  ✓ Comandas';
    RAISE NOTICE '  ✓ Itens de vendas';
    RAISE NOTICE '  ✓ Vendas';
    RAISE NOTICE '========================================';
END $$;

-- Confirmar transação
COMMIT;

-- =====================================================
-- VERIFICAÇÃO PÓS-LIMPEZA
-- =====================================================
SELECT 
    'estoque_movimentacoes' as tabela,
    COUNT(*) as registros_restantes
FROM estoque_movimentacoes
UNION ALL
SELECT 
    'pedido_compra_itens' as tabela,
    COUNT(*) as registros_restantes
FROM pedido_compra_itens
UNION ALL
SELECT 
    'pedidos_compra' as tabela,
    COUNT(*) as registros_restantes
FROM pedidos_compra
UNION ALL
SELECT 
    'comandas' as tabela,
    COUNT(*) as registros_restantes
FROM comandas
UNION ALL
SELECT 
    'venda_itens' as tabela,
    COUNT(*) as registros_restantes
FROM venda_itens
UNION ALL
SELECT 
    'vendas' as tabela,
    COUNT(*) as registros_restantes
FROM vendas;
