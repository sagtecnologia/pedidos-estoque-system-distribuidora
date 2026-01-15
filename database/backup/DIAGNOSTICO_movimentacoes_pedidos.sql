-- =====================================================
-- DIAGNÓSTICO: MOVIMENTAÇÕES E PEDIDOS
-- =====================================================
-- Verifica o que está acontecendo com as movimentações
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║     🔍 DIAGNÓSTICO COMPLETO                               ║
╚═══════════════════════════════════════════════════════════╝
' as "INÍCIO";

-- =====================================================
-- 1. PEDIDOS DE COMPRA FINALIZADOS
-- =====================================================

SELECT '📦 PEDIDOS DE COMPRA FINALIZADOS' as "ANÁLISE";

SELECT 
    ped.id::text as "ID Pedido",
    ped.status as "Status",
    ROUND(ped.total::numeric, 2) as "Valor Total (R$)",
    ped.data_finalizacao as "Finalizado Em",
    COUNT(pi.id) as "Itens no Pedido"
FROM pedidos ped
LEFT JOIN pedido_itens pi ON ped.id = pi.pedido_id
WHERE ped.status = 'FINALIZADO'
  AND ped.created_at >= '2026-01-06'
GROUP BY ped.id, ped.status, ped.total, ped.data_finalizacao
ORDER BY ped.data_finalizacao DESC;

-- =====================================================
-- 2. MOVIMENTAÇÕES DESSES PEDIDOS
-- =====================================================

SELECT '📊 MOVIMENTAÇÕES DOS PEDIDOS FINALIZADOS' as "ANÁLISE";

SELECT 
    ped.id::text as "ID Pedido",
    em.tipo as "Tipo Movimentação",
    COUNT(*) as "Quantidade Movimentações",
    ROUND(SUM(em.quantidade)::numeric, 2) as "Total Unidades",
    em.observacao as "Observação"
FROM pedidos ped
LEFT JOIN estoque_movimentacoes em ON ped.id = em.pedido_id
WHERE ped.status = 'FINALIZADO'
  AND ped.created_at >= '2026-01-06'
GROUP BY ped.id, em.tipo, em.observacao
ORDER BY ped.id;

-- =====================================================
-- 3. MOVIMENTAÇÕES TOTAIS POR TIPO
-- =====================================================

SELECT '📈 RESUMO DE MOVIMENTAÇÕES' as "ANÁLISE";

SELECT 
    tipo as "Tipo",
    COUNT(*) as "Quantidade",
    ROUND(SUM(quantidade)::numeric, 2) as "Total Unidades",
    ROUND(SUM(quantidade * preco_compra)::numeric, 2) as "Valor Estimado (R$)"
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
GROUP BY tipo
ORDER BY tipo;

-- =====================================================
-- 4. PRODUTOS SEM MOVIMENTAÇÕES DE ENTRADA
-- =====================================================

SELECT '⚠️ PRODUTOS SEM ENTRADA' as "ANÁLISE";

SELECT 
    p.codigo as "Código",
    p.nome as "Produto",
    p.estoque_atual as "Estoque Atual",
    COALESCE(COUNT(em.id), 0) as "Movimentações"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id AND em.tipo = 'ENTRADA'
WHERE p.active = true
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
HAVING COALESCE(COUNT(em.id), 0) = 0
  AND p.estoque_atual != 0
ORDER BY p.estoque_atual DESC
LIMIT 10;

-- =====================================================
-- 5. ITENS DE PEDIDOS SEM MOVIMENTAÇÕES
-- =====================================================

SELECT '🔍 ITENS DE PEDIDOS SEM MOVIMENTAÇÕES' as "ANÁLISE";

SELECT 
    ped.id::text as "ID Pedido",
    p.codigo as "Código Produto",
    p.nome as "Produto",
    pi.quantidade as "Qtd no Item",
    COUNT(em.id) as "Movimentações Geradas",
    ped.status as "Status Pedido"
FROM pedidos ped
JOIN pedido_itens pi ON ped.id = pi.pedido_id
JOIN produtos p ON pi.produto_id = p.id
LEFT JOIN estoque_movimentacoes em ON ped.id = em.pedido_id AND p.id = em.produto_id
WHERE ped.status = 'FINALIZADO'
  AND ped.created_at >= '2026-01-06'
GROUP BY ped.id, p.codigo, p.nome, pi.quantidade, ped.status
HAVING COUNT(em.id) = 0
ORDER BY ped.id
LIMIT 20;

-- =====================================================
-- 6. COMPARAÇÃO: PEDIDOS x MOVIMENTAÇÕES
-- =====================================================

SELECT '📊 COMPARAÇÃO: PEDIDOS x MOVIMENTAÇÕES' as "ANÁLISE";

WITH pedidos_compra AS (
    SELECT 
        COUNT(*) as total_pedidos,
        SUM(total) as valor_total_pedidos,
        COUNT(DISTINCT pi.produto_id) as produtos_diferentes
    FROM pedidos ped
    JOIN pedido_itens pi ON ped.id = pi.pedido_id
    WHERE ped.status = 'FINALIZADO'
      AND ped.created_at >= '2026-01-06'
),
movimentacoes_entrada AS (
    SELECT 
        COUNT(*) as total_movimentacoes,
        COUNT(DISTINCT produto_id) as produtos_diferentes,
        SUM(quantidade) as quantidade_total
    FROM estoque_movimentacoes
    WHERE tipo = 'ENTRADA'
      AND observacao ILIKE '%pedido compra%'
)
SELECT 
    'PEDIDOS FINALIZADOS' as "Origem",
    pc.total_pedidos as "Quantidade",
    ROUND(pc.valor_total_pedidos::numeric, 2) as "Valor (R$)",
    pc.produtos_diferentes as "Produtos"
FROM pedidos_compra pc
UNION ALL
SELECT 
    'MOVIMENTAÇÕES ENTRADA' as "Origem",
    me.total_movimentacoes as "Quantidade",
    me.quantidade_total as "Valor (R$)",
    me.produtos_diferentes as "Produtos"
FROM movimentacoes_entrada me;

-- =====================================================
-- 7. VERIFICAR OBSERVAÇÕES DAS MOVIMENTAÇÕES
-- =====================================================

SELECT '📝 OBSERVAÇÕES DAS MOVIMENTAÇÕES' as "ANÁLISE";

SELECT 
    observacao as "Observação",
    tipo as "Tipo",
    COUNT(*) as "Quantidade",
    ROUND(SUM(quantidade)::numeric, 2) as "Total Unidades"
FROM estoque_movimentacoes
GROUP BY observacao, tipo
ORDER BY COUNT(*) DESC
LIMIT 10;

SELECT '
╔═══════════════════════════════════════════════════════════╗
║  📋 CONCLUSÃO                                             ║
║                                                           ║
║  Verifique se:                                            ║
║  1. Pedidos finalizados TÊM movimentações                 ║
║  2. Tipo de movimentação está correto                     ║
║  3. Não foram removidas movimentações legítimas           ║
╚═══════════════════════════════════════════════════════════╝
' as "ORIENTAÇÃO";
