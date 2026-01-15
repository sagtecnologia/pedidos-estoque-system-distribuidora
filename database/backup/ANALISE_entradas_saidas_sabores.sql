-- =====================================================
-- ANÁLISE: ENTRADAS E SAÍDAS DE SABORES
-- =====================================================
-- Data: 2026-01-09
-- Objetivo: Somar quantidades de sabores em COMPRAS e VENDAS
-- Fonte: Tabelas pedidos e pedido_itens (SEM movimentações)
-- =====================================================

-- =====================================================
-- 🎯 RESUMO GERAL - TOTAIS DE ENTRADAS E SAÍDAS
-- =====================================================
-- Esta é a consulta principal que mostra os totais gerais

WITH entradas AS (
    SELECT 
        COUNT(DISTINCT p.id) as total_pedidos,
        COUNT(DISTINCT pi.id) as total_itens,
        SUM(pi.quantidade) as quantidade
    FROM pedidos p
    INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
    WHERE p.tipo_pedido = 'COMPRA'
    AND p.status = 'FINALIZADO'
),
saidas AS (
    SELECT 
        COUNT(DISTINCT p.id) as total_pedidos,
        COUNT(DISTINCT pi.id) as total_itens,
        SUM(pi.quantidade) as quantidade
    FROM pedidos p
    INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
    WHERE p.tipo_pedido = 'VENDA'
    AND p.status = 'FINALIZADO'
)
SELECT 
    '📥 ENTRADAS (COMPRAS)' as tipo,
    (SELECT total_pedidos FROM entradas) as pedidos,
    (SELECT total_itens FROM entradas) as itens,
    (SELECT quantidade FROM entradas) as quantidade
UNION ALL
SELECT 
    '📤 SAÍDAS (VENDAS)' as tipo,
    (SELECT total_pedidos FROM saidas) as pedidos,
    (SELECT total_itens FROM saidas) as itens,
    (SELECT quantidade FROM saidas) as quantidade
UNION ALL
SELECT 
    '📊 SALDO TEÓRICO' as tipo,
    NULL as pedidos,
    NULL as itens,
    (SELECT quantidade FROM entradas) - (SELECT quantidade FROM saidas) as quantidade
UNION ALL
SELECT 
    '📦 ESTOQUE ATUAL' as tipo,
    NULL as pedidos,
    NULL as itens,
    (SELECT SUM(quantidade) FROM vw_estoque_sabores) as quantidade
UNION ALL
SELECT 
    '⚠️  DIFERENÇA' as tipo,
    NULL as pedidos,
    NULL as itens,
    ((SELECT quantidade FROM entradas) - (SELECT quantidade FROM saidas) - (SELECT SUM(quantidade) FROM vw_estoque_sabores)) as quantidade;

-- =====================================================
-- 1. TOTAL DE SABORES ENTRADOS (COMPRAS)
-- =====================================================

SELECT 
    'ENTRADAS (COMPRAS)' as tipo,
    COUNT(DISTINCT pi.id) as total_itens,
    COUNT(DISTINCT p.id) as total_pedidos,
    SUM(pi.quantidade) as quantidade_total
FROM pedidos p
INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
WHERE p.tipo_pedido = 'COMPRA'
AND p.status = 'FINALIZADO'; -- Apenas pedidos finalizados

-- =====================================================
-- 2. TOTAL DE SABORES SAÍDOS (VENDAS)
-- =====================================================

SELECT 
    'SAÍDAS (VENDAS)' as tipo,
    COUNT(DISTINCT pi.id) as total_itens,
    COUNT(DISTINCT p.id) as total_pedidos,
    SUM(pi.quantidade) as quantidade_total
FROM pedidos p
INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
WHERE p.tipo_pedido = 'VENDA'
AND p.status = 'FINALIZADO'; -- Apenas pedidos finalizados

-- =====================================================
-- 3. RESUMO GERAL (ENTRADAS vs SAÍDAS)
-- =====================================================

WITH entradas AS (
    SELECT 
        SUM(pi.quantidade) as total
    FROM pedidos p
    INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
    WHERE p.tipo_pedido = 'COMPRA'
    AND p.status = 'FINALIZADO'
),
saidas AS (
    SELECT 
        SUM(pi.quantidade) as total
    FROM pedidos p
    INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
    WHERE p.tipo_pedido = 'VENDA'
    AND p.status = 'FINALIZADO'
)
SELECT 
    (SELECT total FROM entradas) as total_entradas,
    (SELECT total FROM saidas) as total_saidas,
    (SELECT total FROM entradas) - (SELECT total FROM saidas) as saldo_teorico,
    (SELECT SUM(quantidade) FROM vw_estoque_sabores) as estoque_atual,
    (
        (SELECT total FROM entradas) - 
        (SELECT total FROM saidas) - 
        (SELECT SUM(quantidade) FROM vw_estoque_sabores)
    ) as diferenca;

-- =====================================================
-- 4. ENTRADAS POR MARCA
-- =====================================================

SELECT 
    pr.marca,
    COUNT(DISTINCT pi.id) as total_itens,
    SUM(pi.quantidade) as quantidade_total
FROM pedidos p
INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
INNER JOIN produtos pr ON pr.id = pi.produto_id
WHERE p.tipo_pedido = 'COMPRA'
AND p.status = 'FINALIZADO'
GROUP BY pr.marca
ORDER BY quantidade_total DESC;

-- =====================================================
-- 5. SAÍDAS POR MARCA
-- =====================================================

SELECT 
    pr.marca,
    COUNT(DISTINCT pi.id) as total_itens,
    SUM(pi.quantidade) as quantidade_total
FROM pedidos p
INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
INNER JOIN produtos pr ON pr.id = pi.produto_id
WHERE p.tipo_pedido = 'VENDA'
AND p.status = 'FINALIZADO'
GROUP BY pr.marca
ORDER BY quantidade_total DESC;

-- =====================================================
-- 6. ENTRADAS POR PRODUTO E SABOR
-- =====================================================

SELECT 
    pr.marca,
    pr.nome as produto,
    s.sabor,
    COUNT(pi.id) as vezes_comprado,
    SUM(pi.quantidade) as quantidade_total
FROM pedidos p
INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
INNER JOIN produtos pr ON pr.id = pi.produto_id
INNER JOIN produto_sabores s ON s.id = pi.sabor_id
WHERE p.tipo_pedido = 'COMPRA'
AND p.status = 'FINALIZADO'
GROUP BY pr.marca, pr.nome, pr.id, s.sabor, s.id
ORDER BY pr.marca, pr.nome, s.sabor;

-- =====================================================
-- 7. SAÍDAS POR PRODUTO E SABOR
-- =====================================================

SELECT 
    pr.marca,
    pr.nome as produto,
    s.sabor,
    COUNT(pi.id) as vezes_vendido,
    SUM(pi.quantidade) as quantidade_total
FROM pedidos p
INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
INNER JOIN produtos pr ON pr.id = pi.produto_id
INNER JOIN produto_sabores s ON s.id = pi.sabor_id
WHERE p.tipo_pedido = 'VENDA'
AND p.status = 'FINALIZADO'
GROUP BY pr.marca, pr.nome, pr.id, s.sabor, s.id
ORDER BY pr.marca, pr.nome, s.sabor;

-- =====================================================
-- 8. COMPARAÇÃO: ENTRADAS vs SAÍDAS vs ESTOQUE ATUAL
-- =====================================================

WITH movimentacao AS (
    SELECT 
        pr.marca,
        pr.nome as produto,
        s.sabor,
        pi.produto_id,
        pi.sabor_id,
        SUM(CASE WHEN p.tipo_pedido = 'COMPRA' THEN pi.quantidade ELSE 0 END) as total_compras,
        SUM(CASE WHEN p.tipo_pedido = 'VENDA' THEN pi.quantidade ELSE 0 END) as total_vendas
    FROM pedidos p
    INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
    INNER JOIN produtos pr ON pr.id = pi.produto_id
    INNER JOIN produto_sabores s ON s.id = pi.sabor_id
    WHERE p.status = 'FINALIZADO'
    GROUP BY pr.marca, pr.nome, s.sabor, pi.produto_id, pi.sabor_id
)
SELECT 
    m.marca,
    m.produto,
    m.sabor,
    m.total_compras as entradas,
    m.total_vendas as saidas,
    (m.total_compras - m.total_vendas) as saldo_teorico,
    COALESCE(e.quantidade, 0) as estoque_atual,
    (m.total_compras - m.total_vendas) - COALESCE(e.quantidade, 0) as diferenca
FROM movimentacao m
LEFT JOIN vw_estoque_sabores e ON e.produto_id = m.produto_id AND e.sabor_id = m.sabor_id
ORDER BY m.marca, m.produto, m.sabor;

-- =====================================================
-- 9. SABORES COM DIFERENÇA (possíveis inconsistências)
-- =====================================================

WITH movimentacao AS (
    SELECT 
        pr.marca,
        pr.nome as produto,
        s.sabor,
        pi.produto_id,
        pi.sabor_id,
        SUM(CASE WHEN p.tipo_pedido = 'COMPRA' THEN pi.quantidade ELSE 0 END) as total_compras,
        SUM(CASE WHEN p.tipo_pedido = 'VENDA' THEN pi.quantidade ELSE 0 END) as total_vendas
    FROM pedidos p
    INNER JOIN pedido_itens pi ON pi.pedido_id = p.id
    INNER JOIN produtos pr ON pr.id = pi.produto_id
    INNER JOIN produto_sabores s ON s.id = pi.sabor_id
    WHERE p.status = 'FINALIZADO'
    GROUP BY pr.marca, pr.nome, s.sabor, pi.produto_id, pi.sabor_id
)
SELECT 
    m.marca,
    m.produto,
    m.sabor,
    m.total_compras as entradas,
    m.total_vendas as saidas,
    (m.total_compras - m.total_vendas) as saldo_teorico,
    COALESCE(e.quantidade, 0) as estoque_atual,
    (m.total_compras - m.total_vendas) - COALESCE(e.quantidade, 0) as diferenca
FROM movimentacao m
LEFT JOIN vw_estoque_sabores e ON e.produto_id = m.produto_id AND e.sabor_id = m.sabor_id
WHERE (m.total_compras - m.total_vendas) != COALESCE(e.quantidade, 0)
ORDER BY ABS((m.total_compras - m.total_vendas) - COALESCE(e.quantidade, 0)) DESC;

-- =====================================================
-- INSTRUÇÕES DE USO
-- =====================================================

-- Execute cada consulta separadamente no Supabase SQL Editor:
-- 
-- Consulta 1-2: Totais gerais de entradas e saídas
-- Consulta 3: Resumo comparando entradas, saídas e estoque
-- Consulta 4-5: Entradas e saídas agrupadas por marca
-- Consulta 6-7: Detalhamento por produto e sabor
-- Consulta 8: Comparação completa (a mais importante!)
-- Consulta 9: Apenas sabores com inconsistências
--
-- A consulta 8 mostra tudo e permite identificar onde há diferenças
-- A consulta 9 mostra apenas os problemas
