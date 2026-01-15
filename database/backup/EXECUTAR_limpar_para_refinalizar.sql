-- =====================================================
-- LIMPAR TUDO PARA REFINALIZAR PEDIDOS
-- =====================================================
-- Este script limpa movimentações e sabores
-- Para você reabrir pedidos e finalizar novamente
-- =====================================================

DO $$
DECLARE
    v_movs_deletadas INTEGER;
    v_sabores_deletados INTEGER;
    v_produtos_zerados INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  🧹 LIMPANDO PARA REFINALIZAR PEDIDOS                    ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';

    -- 1. Contar o que vai ser deletado
    SELECT COUNT(*) INTO v_movs_deletadas
    FROM estoque_movimentacoes;
    
    SELECT COUNT(*) INTO v_sabores_deletados
    FROM produto_sabores;

    SELECT COUNT(*) INTO v_produtos_zerados
    FROM produtos
    WHERE estoque_atual != 0;

    RAISE NOTICE '📊 O que será limpo:';
    RAISE NOTICE '   • % movimentações de estoque', v_movs_deletadas;
    RAISE NOTICE '   • % sabores', v_sabores_deletados;
    RAISE NOTICE '   • % produtos com estoque para zerar', v_produtos_zerados;
    RAISE NOTICE '';

    -- 2. Deletar todas as movimentações de estoque
    DELETE FROM estoque_movimentacoes;
    RAISE NOTICE '✅ Movimentações deletadas: %', v_movs_deletadas;

    -- 3. Zerar quantidade de todos os sabores (mantém os sabores cadastrados)
    UPDATE produto_sabores
    SET quantidade = 0;
    RAISE NOTICE '✅ Sabores zerados (mantidos os cadastros): %', v_sabores_deletados;

    -- 4. Zerar estoque de todos os produtos
    UPDATE produtos
    SET estoque_atual = 0
    WHERE estoque_atual != 0;
    RAISE NOTICE '✅ Produtos com estoque zerado: %', v_produtos_zerados;

    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  ✅ LIMPEZA CONCLUÍDA                                     ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
    RAISE NOTICE '📋 PRÓXIMOS PASSOS:';
    RAISE NOTICE '   1. Reabra os pedidos de COMPRA para rascunho';
    RAISE NOTICE '   2. Reabra os pedidos de VENDA para rascunho';
    RAISE NOTICE '   3. Finalize os pedidos de COMPRA novamente';
    RAISE NOTICE '   4. Finalize os pedidos de VENDA novamente';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  As movimentações e sabores serão recriados automaticamente!';
    RAISE NOTICE '';

END $$;

-- Verificar resultado
SELECT '📊 VERIFICAÇÃO PÓS-LIMPEZA' as "STATUS";

SELECT 
    (SELECT COUNT(*) FROM estoque_movimentacoes) as "Movimentações",
    (SELECT COUNT(*) FROM produto_sabores) as "Sabores",
    (SELECT COUNT(*) FROM produtos WHERE estoque_atual != 0) as "Produtos c/ Estoque";
