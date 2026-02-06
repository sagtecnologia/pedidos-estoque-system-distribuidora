-- ============================================================
-- QUERIES DE DIAGNÓSTICO - Reprocessamento de Estoque
-- Úteis para validar dados ANTES e DEPOIS do reprocessamento
-- ============================================================

-- 1️⃣ DIAGNÓSTICO INICIAL - Verificar estado atual

-- Pedidos pendentes vs recebidos
SELECT 
    status,
    COUNT(*) as quantidade,
    SUM(COALESCE((SELECT SUM(quantidade) FROM pedido_compra_itens WHERE pedido_id = pedidos_compra.id), 0)) as total_itens
FROM public.pedidos_compra
GROUP BY status
ORDER BY status;

-- Vendas por status
SELECT 
    status_venda,
    COUNT(*) as quantidade,
    SUM(COALESCE((SELECT SUM(quantidade) FROM vendas_itens WHERE venda_id = vendas.id), 0)) as total_itens
FROM public.vendas
GROUP BY status_venda
ORDER BY status_venda;

-- Total de estoque por produto
SELECT 
    p.id,
    p.nome,
    p.sku,
    p.estoque_atual,
    COUNT(DISTINCT pl.id) as total_lotes,
    SUM(pl.quantidade_atual) as soma_lotes
FROM public.produtos p
LEFT JOIN public.produto_lotes pl ON p.id = pl.produto_id
WHERE p.estoque_atual > 0
GROUP BY p.id, p.nome, p.sku, p.estoque_atual
ORDER BY p.nome;

-- ============================================================

-- 2️⃣ ANÁLISE DE ENTRADAS

-- Pedidos recebidos e seus itens
SELECT 
    pc.numero,
    pc.data_recebimento,
    f.nome as fornecedor,
    COUNT(pci.id) as total_itens,
    SUM(pci.quantidade) as total_quantidade,
    SUM(pci.quantidade * pci.preco_unitario) as total_valor
FROM public.pedidos_compra pc
LEFT JOIN public.fornecedores f ON pc.fornecedor_id = f.id
LEFT JOIN public.pedido_compra_itens pci ON pc.id = pci.pedido_id
WHERE pc.status = 'RECEBIDO'
GROUP BY pc.id, pc.numero, pc.data_recebimento, f.nome
ORDER BY pc.data_recebimento DESC
LIMIT 20;

-- Entradas por produto (agregado)
SELECT 
    p.nome,
    p.sku,
    SUM(pci.quantidade) as total_entrada,
    COUNT(DISTINCT pc.id) as num_pedidos,
    MIN(pc.data_recebimento) as primeira_entrada,
    MAX(pc.data_recebimento) as ultima_entrada
FROM public.produtos p
LEFT JOIN public.pedido_compra_itens pci ON p.id = pci.produto_id
LEFT JOIN public.pedidos_compra pc ON pci.pedido_id = pc.id AND pc.status = 'RECEBIDO'
GROUP BY p.id, p.nome, p.sku
HAVING SUM(pci.quantidade) > 0
ORDER BY p.nome;

-- ============================================================

-- 3️⃣ ANÁLISE DE SAÍDAS

-- Vendas finalizadas e seus itens
SELECT 
    v.numero_nfce,
    v.data_venda,
    c.nome as cliente,
    COUNT(vi.id) as total_itens,
    SUM(vi.quantidade) as total_quantidade,
    SUM(vi.total) as total_valor
FROM public.vendas v
LEFT JOIN public.clientes c ON v.cliente_id = c.id
LEFT JOIN public.vendas_itens vi ON v.id = vi.venda_id
WHERE v.status_venda = 'FINALIZADA'
GROUP BY v.id, v.numero_nfce, v.data_venda, c.nome
ORDER BY v.data_venda DESC
LIMIT 20;

-- Saídas por produto (agregado)
SELECT 
    p.nome,
    p.sku,
    SUM(vi.quantidade) as total_saida,
    COUNT(DISTINCT v.id) as num_vendas,
    MIN(v.data_venda) as primeira_saida,
    MAX(v.data_venda) as ultima_saida
FROM public.produtos p
LEFT JOIN public.vendas_itens vi ON p.id = vi.produto_id
LEFT JOIN public.vendas v ON vi.venda_id = v.id AND v.status_venda = 'FINALIZADA'
GROUP BY p.id, p.nome, p.sku
HAVING SUM(vi.quantidade) > 0
ORDER BY p.nome;

-- ============================================================

-- 4️⃣ COMPARAÇÃO: Calculado vs Real

-- Estoque esperado vs real por produto
WITH entradas AS (
    SELECT 
        p.id,
        COALESCE(SUM(pci.quantidade), 0) as total_entrada
    FROM public.produtos p
    LEFT JOIN public.pedido_compra_itens pci ON p.id = pci.produto_id
    LEFT JOIN public.pedidos_compra pc ON pci.pedido_id = pc.id AND pc.status = 'RECEBIDO'
    GROUP BY p.id
),
saidas AS (
    SELECT 
        p.id,
        COALESCE(SUM(vi.quantidade), 0) as total_saida
    FROM public.produtos p
    LEFT JOIN public.vendas_itens vi ON p.id = vi.produto_id
    LEFT JOIN public.vendas v ON vi.venda_id = v.id AND v.status_venda = 'FINALIZADA'
    GROUP BY p.id
),
lotes_iniciais AS (
    SELECT 
        p.id,
        COALESCE(SUM(pl.quantidade_inicial), 0) as total_inicial
    FROM public.produtos p
    LEFT JOIN public.produto_lotes pl ON p.id = pl.produto_id
    GROUP BY p.id
)
SELECT 
    p.id,
    p.nome,
    p.sku,
    p.estoque_atual as real_db,
    COALESCE(li.total_inicial, 0) as inicial_lotes,
    e.total_entrada as entradas,
    s.total_saida as saidas,
    (COALESCE(li.total_inicial, 0) + e.total_entrada - s.total_saida) as calculado,
    (p.estoque_atual - (COALESCE(li.total_inicial, 0) + e.total_entrada - s.total_saida)) as diferenca,
    CASE 
        WHEN p.estoque_atual = (COALESCE(li.total_inicial, 0) + e.total_entrada - s.total_saida) THEN 'OK'
        ELSE 'DIVERGÊNCIA'
    END as status
FROM public.produtos p
LEFT JOIN entradas e ON p.id = e.id
LEFT JOIN saidas s ON p.id = s.id
LEFT JOIN lotes_iniciais li ON p.id = li.id
WHERE p.estoque_atual > 0 
   OR e.total_entrada > 0 
   OR s.total_saida > 0
ORDER BY p.nome;

-- ============================================================

-- 5️⃣ ANÁLISE DE LOTES COM VENCIMENTO

-- Lotes próximos do vencimento
SELECT 
    pl.id,
    pl.numero_lote,
    p.nome as produto,
    pl.data_fabricacao,
    pl.data_vencimento,
    pl.quantidade_inicial,
    pl.quantidade_atual,
    (pl.quantidade_inicial - pl.quantidade_atual) as quantidade_saida,
    DATE_PART('day', pl.data_vencimento - CURRENT_DATE) as dias_para_vencer,
    CASE 
        WHEN pl.data_vencimento < CURRENT_DATE THEN '🔴 VENCIDO'
        WHEN DATE_PART('day', pl.data_vencimento - CURRENT_DATE) <= 7 THEN '🟡 PRÓXIMO (7 dias)'
        WHEN DATE_PART('day', pl.data_vencimento - CURRENT_DATE) <= 30 THEN '🟡 ATENÇÂO (30 dias)'
        ELSE '🟢 OK'
    END as alerta
FROM public.produto_lotes pl
JOIN public.produtos p ON pl.produto_id = p.id
WHERE pl.quantidade_atual > 0
ORDER BY pl.data_vencimento ASC;

-- ============================================================

-- 6️⃣ PROBLEMAS COMUNS - Detecção

-- Produtos sem lote mas com vencimento ativado
SELECT 
    p.id,
    p.nome,
    p.controla_validade,
    COUNT(pl.id) as total_lotes,
    SUM(pl.quantidade_atual) as quantidade_em_lotes
FROM public.produtos p
LEFT JOIN public.produto_lotes pl ON p.id = pl.produto_id
WHERE p.controla_validade = true
GROUP BY p.id, p.nome, p.controla_validade
HAVING COUNT(pl.id) = 0
ORDER BY p.nome;

-- Movimentações órfãs (referência_id não existe)
SELECT 
    em.id,
    em.tipo_movimento,
    em.referencia_tipo,
    em.referencia_id,
    p.nome as produto,
    em.quantidade,
    em.created_at
FROM public.estoque_movimentacoes em
JOIN public.produtos p ON em.produto_id = p.id
WHERE em.referencia_id NOT IN (
    SELECT id FROM public.vendas 
    UNION
    SELECT id FROM public.pedidos_compra
)
LIMIT 10;

-- Vendas sem itens
SELECT 
    v.id,
    v.numero_nfce,
    v.data_venda,
    v.status_venda,
    COUNT(vi.id) as total_itens
FROM public.vendas v
LEFT JOIN public.vendas_itens vi ON v.id = vi.venda_id
GROUP BY v.id, v.numero_nfce, v.data_venda, v.status_venda
HAVING COUNT(vi.id) = 0
AND v.status_venda = 'FINALIZADA'
LIMIT 10;

-- ============================================================

-- 7️⃣ RELATÓRIO EXECUTIVO

-- Sumário geral
SELECT 
    'Produtos Ativos' as metrica,
    COUNT(*)::TEXT as valor
FROM public.produtos
WHERE estoque_atual > 0
UNION ALL
SELECT 'Pedidos Recebidos', COUNT(*)::TEXT FROM public.pedidos_compra WHERE status = 'RECEBIDO'
UNION ALL
SELECT 'Vendas Finalizadas', COUNT(*)::TEXT FROM public.vendas WHERE status_venda = 'FINALIZADA'
UNION ALL
SELECT 'Estoque Total (un)', ROUND(SUM(estoque_atual))::TEXT FROM public.produtos
UNION ALL
SELECT 'Lotes Ativos', COUNT(*)::TEXT FROM public.produto_lotes WHERE quantidade_atual > 0
UNION ALL
SELECT 'Lotes Vencidos', COUNT(*)::TEXT FROM public.produto_lotes WHERE data_vencimento < CURRENT_DATE AND quantidade_atual > 0;

-- ============================================================
-- FIM DAS QUERIES DE DIAGNÓSTICO
-- ============================================================
