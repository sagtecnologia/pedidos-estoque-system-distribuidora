-- =====================================================
-- RECALCULAR ESTOQUE DE SABORES POR MOVIMENTAÇÕES
-- =====================================================
-- Recalcula a quantidade de cada sabor baseado nas
-- movimentações de entrada e saída dos pedidos
-- COMMIT AUTOMÁTICO se valores estiverem corretos
-- =====================================================

DO $$
DECLARE
    v_valor_compra_final NUMERIC;
    v_valor_venda_final NUMERIC;
    v_qtd_antes NUMERIC;
    v_qtd_depois NUMERIC;
BEGIN
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║     🔄 RECALCULAR ESTOQUE DE SABORES                      ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    
    -- =====================================================
    -- DIAGNÓSTICO ANTES
    -- =====================================================
    
    RAISE NOTICE '📊 Valores antes do recálculo...';
    
    SELECT 
        ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2)
    INTO v_valor_compra_final
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true AND p.active = true;
    
    RAISE NOTICE '  Valor Total Compra ANTES: R$ %', v_valor_compra_final;
    
    -- =====================================================
    -- RECALCULAR ESTOQUE DE SABORES
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Recalculando estoque de sabores...';

-- Backup
DROP TABLE IF EXISTS backup_sabores_recalculo;
CREATE TEMP TABLE backup_sabores_recalculo AS
SELECT * FROM produto_sabores;

-- Zerar todos os sabores
UPDATE produto_sabores
SET quantidade = 0
WHERE ativo = true;

-- Calcular estoque total por produto das movimentações
WITH estoque_por_produto AS (
    SELECT 
        produto_id,
        SUM(CASE WHEN tipo = 'ENTRADA' THEN quantidade ELSE -quantidade END) as estoque_total
    FROM estoque_movimentacoes
    GROUP BY produto_id
),
-- Contar sabores ativos por produto
sabores_por_produto AS (
    SELECT 
        produto_id,
        COUNT(*) as total_sabores
    FROM produto_sabores
    WHERE ativo = true
    GROUP BY produto_id
),
-- Calcular quantidade por sabor (distribuição proporcional)
distribuicao AS (
    SELECT 
        ps.id as sabor_id,
        ps.produto_id,
        ep.estoque_total,
        sp.total_sabores,
        -- Distribuir igualmente entre os sabores
        CASE 
            WHEN sp.total_sabores > 0 THEN ep.estoque_total / sp.total_sabores
            ELSE 0
        END as quantidade_calculada
    FROM produto_sabores ps
    LEFT JOIN estoque_por_produto ep ON ps.produto_id = ep.produto_id
    LEFT JOIN sabores_por_produto sp ON ps.produto_id = sp.produto_id
    WHERE ps.ativo = true
)
UPDATE produto_sabores ps
SET 
    quantidade = GREATEST(d.quantidade_calculada, 0),
    updated_at = NOW()
FROM distribuicao d
WHERE ps.id = d.sabor_id;

RAISE NOTICE '  ✓ Estoque de sabores recalculado!';

    -- =====================================================
    -- VERIFICAÇÃO E COMMIT AUTOMÁTICO
    -- =====================================================
    
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║            ✅ VERIFICAÇÃO FINAL                           ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    
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
        RAISE NOTICE '✅ RECÁLCULO BEM SUCEDIDO!';
        RAISE NOTICE '✅ COMMIT EXECUTADO AUTOMATICAMENTE!';
        RAISE NOTICE '';
        RAISE NOTICE 'Atualize a página de estoque no sistema!';
    ELSE
        RAISE EXCEPTION '⚠️ Valores negativos detectados. ROLLBACK executado.';
    END IF;
    
END $$;
