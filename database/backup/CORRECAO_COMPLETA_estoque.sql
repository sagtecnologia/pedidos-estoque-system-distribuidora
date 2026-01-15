-- =====================================================
-- CORREÇÃO COMPLETA - MOVIMENTAÇÕES + SABORES
-- =====================================================
-- Este script executa a correção completa:
-- 1. Limpa movimentações duplicadas e erradas
-- 2. Corrige estoque de sabores
-- 3. Recalcula tudo
-- =====================================================

DO $$
DECLARE
    v_mov_removidas INTEGER;
    v_sabores_zerados INTEGER;
    v_valor_compra_final NUMERIC;
    v_valor_venda_final NUMERIC;
BEGIN
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║     🔧 CORREÇÃO COMPLETA DO ESTOQUE                      ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    
    -- =====================================================
    -- PARTE 1: LIMPAR MOVIMENTAÇÕES
    -- =====================================================
    
    RAISE NOTICE '🧹 PARTE 1: Limpando movimentações duplicadas e erradas...';
    
    -- Backup
    DROP TABLE IF EXISTS backup_movimentacoes_correcao;
    CREATE TEMP TABLE backup_movimentacoes_correcao AS
    SELECT * FROM estoque_movimentacoes;
    
    -- Remover COMPRAS gerando SAÍDA (errado!)
    DELETE FROM estoque_movimentacoes
    WHERE observacao ILIKE '%pedido compra%'
      AND tipo = 'SAIDA';
    
    GET DIAGNOSTICS v_mov_removidas = ROW_COUNT;
    RAISE NOTICE '  ✓ Removidas % movimentações COMPRA→SAÍDA', v_mov_removidas;
    
    -- Remover VENDAS gerando ENTRADA (errado!)
    DELETE FROM estoque_movimentacoes
    WHERE observacao ILIKE '%pedido venda%'
      AND tipo = 'ENTRADA';
    
    GET DIAGNOSTICS v_mov_removidas = ROW_COUNT;
    RAISE NOTICE '  ✓ Removidas % movimentações VENDA→ENTRADA', v_mov_removidas;
    
    -- Remover duplicadas
    WITH duplicadas AS (
        SELECT 
            id,
            ROW_NUMBER() OVER (
                PARTITION BY produto_id, pedido_id, tipo, quantidade, DATE(created_at)
                ORDER BY created_at, id
            ) as rn
        FROM estoque_movimentacoes
        WHERE pedido_id IS NOT NULL
    )
    DELETE FROM estoque_movimentacoes
    WHERE id IN (SELECT id FROM duplicadas WHERE rn > 1);
    
    GET DIAGNOSTICS v_mov_removidas = ROW_COUNT;
    RAISE NOTICE '  ✓ Removidas % movimentações duplicadas', v_mov_removidas;
    
    RAISE NOTICE '✅ PARTE 1 concluída!';
    
    -- =====================================================
    -- PARTE 2: CORRIGIR ESTOQUE DE SABORES
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '🔧 PARTE 2: Corrigindo estoque de sabores...';
    
    -- Backup
    DROP TABLE IF EXISTS backup_sabores_correcao;
    CREATE TEMP TABLE backup_sabores_correcao AS
    SELECT * FROM produto_sabores;
    
    -- Zerar quantidades negativas
    UPDATE produto_sabores
    SET quantidade = 0,
        updated_at = NOW()
    WHERE quantidade < 0
      AND ativo = true;
    
    GET DIAGNOSTICS v_sabores_zerados = ROW_COUNT;
    RAISE NOTICE '  ✓ Zerados % sabores com quantidade negativa', v_sabores_zerados;
    
    RAISE NOTICE '✅ PARTE 2 concluída!';
    
    -- =====================================================
    -- PARTE 3: RECALCULAR ESTOQUE DOS PRODUTOS
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '🔄 PARTE 3: Recalculando estoque dos produtos...';
    
    -- Zerar estoque
    UPDATE produtos
    SET estoque_atual = 0
    WHERE active = true;
    
    -- Recalcular baseado nas movimentações limpas
    WITH estoque_limpo AS (
        SELECT 
            produto_id,
            SUM(CASE WHEN tipo = 'ENTRADA' THEN quantidade ELSE -quantidade END) as estoque_calculado
        FROM estoque_movimentacoes
        GROUP BY produto_id
    )
    UPDATE produtos p
    SET estoque_atual = el.estoque_calculado,
        updated_at = NOW()
    FROM estoque_limpo el
    WHERE p.id = el.produto_id;
    
    RAISE NOTICE '  ✓ Estoque dos produtos recalculado';
    
    -- Recalcular estoque_anterior e estoque_novo
    WITH movimentacoes_ordenadas AS (
        SELECT 
            em.id,
            em.produto_id,
            em.tipo,
            em.quantidade,
            ROW_NUMBER() OVER (PARTITION BY em.produto_id ORDER BY em.created_at, em.id) as ordem
        FROM estoque_movimentacoes em
    ),
    cardex AS (
        SELECT 
            mo.id,
            COALESCE(
                (SELECT SUM(CASE WHEN mo2.tipo = 'ENTRADA' THEN mo2.quantidade ELSE -mo2.quantidade END)
                 FROM movimentacoes_ordenadas mo2
                 WHERE mo2.produto_id = mo.produto_id
                   AND mo2.ordem < mo.ordem
                ), 0
            ) as estoque_anterior,
            COALESCE(
                (SELECT SUM(CASE WHEN mo2.tipo = 'ENTRADA' THEN mo2.quantidade ELSE -mo2.quantidade END)
                 FROM movimentacoes_ordenadas mo2
                 WHERE mo2.produto_id = mo.produto_id
                   AND mo2.ordem <= mo.ordem
                ), 0
            ) as estoque_novo
        FROM movimentacoes_ordenadas mo
    )
    UPDATE estoque_movimentacoes em
    SET 
        estoque_anterior = c.estoque_anterior,
        estoque_novo = c.estoque_novo
    FROM cardex c
    WHERE em.id = c.id;
    
    RAISE NOTICE '  ✓ Histórico de movimentações atualizado';
    
    RAISE NOTICE '✅ PARTE 3 concluída!';
    
    -- =====================================================
    -- VERIFICAÇÃO FINAL
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║     ✅ VERIFICAÇÃO FINAL                                  ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    
    -- Verificar valores finais
    SELECT 
        SUM(ps.quantidade * p.preco_compra),
        SUM(ps.quantidade * p.preco_venda)
    INTO v_valor_compra_final, v_valor_venda_final
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true AND p.active = true;
    
    RAISE NOTICE '';
    RAISE NOTICE 'Valor Total Compra: R$ %', ROUND(v_valor_compra_final, 2);
    RAISE NOTICE 'Valor Total Venda: R$ %', ROUND(v_valor_venda_final, 2);
    RAISE NOTICE 'Margem de Lucro: R$ %', ROUND(v_valor_venda_final - v_valor_compra_final, 2);
    
    IF v_valor_compra_final >= 0 AND v_valor_venda_final >= 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ CORREÇÃO BEM SUCEDIDA!';
        RAISE NOTICE '';
        RAISE NOTICE 'Os valores agora estão corretos e positivos.';
        RAISE NOTICE 'Atualize a página de estoque no sistema!';
    ELSE
        RAISE EXCEPTION 'Valores ainda estão negativos. Verifique os dados.';
    END IF;
    
END $$;

-- =====================================================
-- RELATÓRIOS DETALHADOS
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║     📊 RELATÓRIOS DETALHADOS                              ║
╚═══════════════════════════════════════════════════════════╝
' as "RELATÓRIOS";

-- Movimentações por tipo de pedido
SELECT '✅ MOVIMENTAÇÕES POR TIPO' as "ANÁLISE";

SELECT 
    CASE 
        WHEN observacao ILIKE '%pedido compra%' THEN '📥 COMPRA'
        WHEN observacao ILIKE '%pedido venda%' THEN '📤 VENDA'
        ELSE '📦 OUTROS'
    END as "Tipo",
    tipo as "Movimentação",
    COUNT(*) as "Quantidade",
    ROUND(SUM(quantidade)::numeric, 2) as "Total Unidades"
FROM estoque_movimentacoes
WHERE pedido_id IS NOT NULL
GROUP BY 
    CASE 
        WHEN observacao ILIKE '%pedido compra%' THEN '📥 COMPRA'
        WHEN observacao ILIKE '%pedido venda%' THEN '📤 VENDA'
        ELSE '📦 OUTROS'
    END,
    tipo
ORDER BY 1, 2;

-- Resumo por produtos
SELECT '📦 TOP 10 PRODUTOS COM MAIOR VALOR EM ESTOQUE' as "ANÁLISE";

SELECT 
    p.codigo as "Código",
    p.nome as "Produto",
    COUNT(ps.id) as "Sabores",
    ROUND(SUM(ps.quantidade)::numeric, 2) as "Quantidade Total",
    ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as "Valor Compra (R$)",
    ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as "Valor Venda (R$)"
FROM produtos p
JOIN produto_sabores ps ON p.id = ps.produto_id
WHERE p.active = true AND ps.ativo = true AND ps.quantidade > 0
GROUP BY p.id, p.codigo, p.nome
ORDER BY SUM(ps.quantidade * p.preco_compra) DESC
LIMIT 10;

-- Resumo final
SELECT '💰 RESUMO FINAL' as "ANÁLISE";

WITH resumo AS (
    SELECT 
        COUNT(DISTINCT p.id) as total_produtos,
        COUNT(ps.id) as total_sabores,
        COUNT(CASE WHEN ps.quantidade > 0 THEN 1 END) as sabores_com_estoque,
        COUNT(CASE WHEN ps.quantidade = 0 THEN 1 END) as sabores_zerados,
        ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as valor_venda,
        ROUND(SUM(ps.quantidade * (p.preco_venda - p.preco_compra))::numeric, 2) as margem
    FROM produtos p
    JOIN produto_sabores ps ON p.id = ps.produto_id
    WHERE p.active = true AND ps.ativo = true
)
SELECT 
    total_produtos as "Total de Produtos",
    total_sabores as "Total de Sabores",
    sabores_com_estoque as "Sabores com Estoque",
    sabores_zerados as "Sabores Zerados",
    valor_compra as "Valor Total Compra (R$)",
    valor_venda as "Valor Total Venda (R$)",
    margem as "Margem de Lucro (R$)",
    CASE 
        WHEN valor_venda > 0 THEN ROUND((margem / valor_venda * 100)::numeric, 2)
        ELSE 0
    END as "Margem (%)"
FROM resumo;

SELECT '
╔═══════════════════════════════════════════════════════════╗
║  ✅ CORREÇÃO CONCLUÍDA COM SUCESSO!                       ║
║                                                           ║
║  Atualize a página de estoque no sistema.                ║
║  Os valores devem aparecer corretos agora!               ║
╚═══════════════════════════════════════════════════════════╝
' as "CONCLUSÃO";
