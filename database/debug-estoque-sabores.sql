-- =====================================================
-- DEBUG: Verificar se sabor_id está sendo salvo
-- =====================================================

-- 1. Verificar pedidos recentes com sabor_id
SELECT 
    p.numero as pedido,
    p.tipo_pedido,
    p.status,
    pi.quantidade,
    prod.nome as produto,
    pi.sabor_id,
    ps.sabor,
    ps.quantidade as estoque_sabor
FROM pedidos p
JOIN pedido_itens pi ON p.id = pi.pedido_id
JOIN produtos prod ON pi.produto_id = prod.id
LEFT JOIN produto_sabores ps ON pi.sabor_id = ps.id
ORDER BY p.created_at DESC
LIMIT 10;

-- 2. Verificar estoque atual dos sabores
SELECT 
    p.nome as produto,
    p.codigo,
    ps.sabor,
    ps.quantidade as estoque_sabor,
    ps.ativo,
    p.estoque_atual as estoque_total_produto
FROM produtos p
JOIN produto_sabores ps ON p.id = ps.produto_id
WHERE p.marca = 'IGNITE'
ORDER BY p.nome, ps.sabor;

-- 3. Verificar movimentações de estoque com sabor_id
SELECT 
    em.created_at,
    em.tipo,
    em.quantidade,
    p.nome as produto,
    em.sabor_id,
    ps.sabor,
    em.observacao
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
LEFT JOIN produto_sabores ps ON em.sabor_id = ps.id
ORDER BY em.created_at DESC
LIMIT 20;

-- 4. Se sabor_id estiver NULL nos pedidos, o problema está no frontend
-- Se sabor_id estiver preenchido mas quantidade não baixou, o problema está na função
