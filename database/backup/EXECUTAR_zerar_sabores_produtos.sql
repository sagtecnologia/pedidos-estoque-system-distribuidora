-- =====================================================
-- ZERAR ESTOQUE DOS SABORES E PRODUTOS
-- =====================================================
-- Executa após deletar as movimentações manualmente
-- =====================================================

DO $$
DECLARE
    v_sabores_zerados INTEGER;
    v_produtos_zerados INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  🔄 ZERANDO ESTOQUE DOS SABORES E PRODUTOS               ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';

    -- 1. Contar o que será zerado
    SELECT COUNT(*) INTO v_sabores_zerados
    FROM produto_sabores
    WHERE quantidade != 0;

    SELECT COUNT(*) INTO v_produtos_zerados
    FROM produtos
    WHERE estoque_atual != 0;

    RAISE NOTICE '📊 O que será zerado:';
    RAISE NOTICE '   • % sabores com quantidade > 0', v_sabores_zerados;
    RAISE NOTICE '   • % produtos com estoque > 0', v_produtos_zerados;
    RAISE NOTICE '';

    -- 2. Zerar quantidade de todos os sabores (mantém os sabores cadastrados)
    UPDATE produto_sabores
    SET quantidade = 0
    WHERE quantidade != 0;
    RAISE NOTICE '✅ Sabores zerados: %', v_sabores_zerados;

    -- 3. Zerar estoque de todos os produtos
    UPDATE produtos
    SET estoque_atual = 0
    WHERE estoque_atual != 0;
    RAISE NOTICE '✅ Produtos zerados: %', v_produtos_zerados;

    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  ✅ CONCLUÍDO                                             ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';
    RAISE NOTICE '📋 PRÓXIMOS PASSOS:';
    RAISE NOTICE '   1. Crie e finalize os pedidos de COMPRA';
    RAISE NOTICE '   2. Crie e finalize os pedidos de VENDA';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Os sabores e estoque serão recalculados automaticamente!';
    RAISE NOTICE '';

END $$;

-- Verificar resultado
SELECT '📊 VERIFICAÇÃO' as "STATUS";

SELECT 
    (SELECT COUNT(*) FROM estoque_movimentacoes) as "Movimentações",
    (SELECT COUNT(*) FROM produto_sabores WHERE quantidade > 0) as "Sabores c/ Quantidade",
    (SELECT COUNT(*) FROM produtos WHERE estoque_atual > 0) as "Produtos c/ Estoque";
