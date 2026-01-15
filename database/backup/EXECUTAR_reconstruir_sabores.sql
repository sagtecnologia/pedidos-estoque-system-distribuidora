-- =====================================================
-- RECONSTRUIR PRODUTO_SABORES
-- =====================================================
-- Este script recria os sabores para produtos com estoque
-- =====================================================

-- Criar função temporária com permissões elevadas
CREATE OR REPLACE FUNCTION temp_reconstruir_sabores()
RETURNS TABLE(
    codigo TEXT,
    nome TEXT,
    sabor TEXT,
    quantidade DECIMAL,
    valor_compra DECIMAL,
    valor_venda DECIMAL
)
SECURITY DEFINER
LANGUAGE plpgsql
AS $$
DECLARE
    v_produto RECORD;
    v_sabor_count INTEGER;
BEGIN
    -- Para cada produto ativo com estoque != 0
    FOR v_produto IN 
        SELECT id, codigo, nome, estoque_atual
        FROM produtos
        WHERE active = true 
          AND estoque_atual != 0
        ORDER BY codigo
    LOOP
        -- Verificar quantos sabores existem
        SELECT COUNT(*) INTO v_sabor_count
        FROM produto_sabores
        WHERE produto_id = v_produto.id
          AND ativo = true;

        IF v_sabor_count = 0 THEN
            -- Criar sabor padrão MIX com todo o estoque
            INSERT INTO produto_sabores (produto_id, sabor, quantidade, ativo)
            VALUES (v_produto.id, 'MIX', v_produto.estoque_atual, true);
        ELSE
            -- Distribuir estoque igualmente entre sabores existentes
            UPDATE produto_sabores
            SET quantidade = v_produto.estoque_atual / v_sabor_count
            WHERE produto_id = v_produto.id
              AND ativo = true;
        END IF;
    END LOOP;

    -- Retornar resultado
    RETURN QUERY
    SELECT 
        p.codigo::TEXT,
        p.nome::TEXT,
        ps.sabor::TEXT,
        ps.quantidade,
        ROUND((ps.quantidade * p.preco_compra)::numeric, 2),
        ROUND((ps.quantidade * p.preco_venda)::numeric, 2)
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true
    ORDER BY p.codigo, ps.sabor;
END;
$$;

-- Executar a função
DO $$
DECLARE
    v_count INTEGER;
    v_valor_compra DECIMAL;
    v_valor_venda DECIMAL;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '╔═══════════════════════════════════════════════════════════╗';
    RAISE NOTICE '║  🔧 RECONSTRUINDO PRODUTO_SABORES                        ║';
    RAISE NOTICE '╚═══════════════════════════════════════════════════════════╝';
    RAISE NOTICE '';

    -- Executar reconstrução
    PERFORM temp_reconstruir_sabores();

    -- Contar sabores criados
    SELECT COUNT(*) INTO v_count
    FROM produto_sabores
    WHERE ativo = true;

    -- Calcular valores
    SELECT 
        COALESCE(SUM(ps.quantidade * p.preco_compra), 0),
        COALESCE(SUM(ps.quantidade * p.preco_venda), 0)
    INTO v_valor_compra, v_valor_venda
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true;

    RAISE NOTICE '✅ Sabores processados: %', v_count;
    RAISE NOTICE '';
    RAISE NOTICE '💰 Valor Total Compra: R$ %', ROUND(v_valor_compra, 2);
    RAISE NOTICE '💰 Valor Total Venda: R$ %', ROUND(v_valor_venda, 2);
    RAISE NOTICE '';
    RAISE NOTICE '✅ COMMIT executado com sucesso!';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  IMPORTANTE: Atualize a página de estoque (F5) para ver os novos valores!';
END $$;

-- Limpar função temporária
DROP FUNCTION IF EXISTS temp_reconstruir_sabores();

-- Mostrar resultado final
SELECT '📊 SABORES CRIADOS' as "STATUS";

SELECT 
    p.codigo as "Código",
    p.nome as "Produto",
    ps.sabor as "Sabor",
    ps.quantidade as "Quantidade",
    p.preco_compra as "Preço Compra",
    ROUND((ps.quantidade * p.preco_compra)::numeric, 2) as "Valor Compra (R$)",
    ROUND((ps.quantidade * p.preco_venda)::numeric, 2) as "Valor Venda (R$)"
FROM produto_sabores ps
JOIN produtos p ON ps.produto_id = p.id
WHERE ps.ativo = true
ORDER BY p.codigo, ps.sabor;

SELECT '💰 TOTAIS' as "STATUS";

SELECT 
    ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as "Valor Total Compra (R$)",
    ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as "Valor Total Venda (R$)",
    COUNT(*) as "Total Sabores"
FROM produto_sabores ps
JOIN produtos p ON ps.produto_id = p.id
WHERE ps.ativo = true;
