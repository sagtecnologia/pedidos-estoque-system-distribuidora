-- =====================================================
-- DIAGNÓSTICO: Problema ao Cancelar Compra
-- =====================================================

-- 1️⃣ VERIFICAR ESTOQUE ATUAL DO PRODUTO IGN-0006 (AÇAI ICE)
SELECT 
    p.codigo,
    p.nome,
    ps.sabor,
    ps.quantidade as estoque_atual,
    ps.id as sabor_id
FROM produtos p
JOIN produto_sabores ps ON ps.produto_id = p.id
WHERE p.codigo = 'IGN-0006'
ORDER BY ps.sabor;

-- 2️⃣ HISTÓRICO COMPLETO DE MOVIMENTAÇÕES (últimas 50)
SELECT 
    em.created_at,
    p.codigo,
    ps.sabor,
    em.tipo,
    em.quantidade,
    em.estoque_anterior,
    em.estoque_novo,
    em.observacao,
    ped.numero as pedido_numero,
    ped.tipo_pedido,
    ped.status as pedido_status
FROM estoque_movimentacoes em
JOIN produtos p ON p.id = em.produto_id
JOIN produto_sabores ps ON ps.id = em.sabor_id
LEFT JOIN pedidos ped ON ped.id = em.pedido_id
WHERE p.codigo = 'IGN-0006'
ORDER BY em.created_at DESC
LIMIT 50;

-- 3️⃣ VERIFICAR PEDIDOS FINALIZADOS COM ESTE PRODUTO
SELECT 
    p.numero,
    p.tipo_pedido,
    p.status,
    p.data_finalizacao,
    pi.quantidade,
    ps.sabor,
    pi.id as item_id
FROM pedidos p
JOIN pedido_itens pi ON pi.pedido_id = p.id
JOIN produtos prod ON prod.id = pi.produto_id
JOIN produto_sabores ps ON ps.id = pi.sabor_id
WHERE prod.codigo = 'IGN-0006'
  AND p.status = 'FINALIZADO'
ORDER BY p.data_finalizacao DESC;

-- 4️⃣ CALCULAR ESTOQUE BASEADO NAS MOVIMENTAÇÕES
SELECT 
    p.codigo,
    ps.sabor,
    ps.quantidade as estoque_tabela,
    (SELECT COALESCE(SUM(quantidade), 0) 
     FROM estoque_movimentacoes 
     WHERE sabor_id = ps.id AND tipo = 'ENTRADA') as total_entradas,
    (SELECT COALESCE(SUM(quantidade), 0) 
     FROM estoque_movimentacoes 
     WHERE sabor_id = ps.id AND tipo = 'SAIDA') as total_saidas,
    ((SELECT COALESCE(SUM(quantidade), 0) 
      FROM estoque_movimentacoes 
      WHERE sabor_id = ps.id AND tipo = 'ENTRADA') -
     (SELECT COALESCE(SUM(quantidade), 0) 
      FROM estoque_movimentacoes 
      WHERE sabor_id = ps.id AND tipo = 'SAIDA')) as estoque_calculado,
    ps.quantidade - 
    ((SELECT COALESCE(SUM(quantidade), 0) 
      FROM estoque_movimentacoes 
      WHERE sabor_id = ps.id AND tipo = 'ENTRADA') -
     (SELECT COALESCE(SUM(quantidade), 0) 
      FROM estoque_movimentacoes 
      WHERE sabor_id = ps.id AND tipo = 'SAIDA')) as diferenca
FROM produtos p
JOIN produto_sabores ps ON ps.produto_id = p.id
WHERE p.codigo = 'IGN-0006';

-- 5️⃣ DETECTAR MOVIMENTAÇÕES DUPLICADAS
SELECT 
    pedido_id,
    COUNT(*) as total_movimentacoes,
    STRING_AGG(DISTINCT tipo::text, ', ') as tipos,
    STRING_AGG(observacao, ' | ') as observacoes
FROM estoque_movimentacoes em
JOIN produtos p ON p.id = em.produto_id
WHERE p.codigo = 'IGN-0006'
  AND pedido_id IS NOT NULL
GROUP BY pedido_id
HAVING COUNT(*) > 2  -- Mais de 2 movimentações por pedido pode indicar duplicação
ORDER BY total_movimentacoes DESC;

-- 6️⃣ VERIFICAR SE HÁ MOVIMENTAÇÕES SEM PEDIDO ASSOCIADO
SELECT 
    em.created_at,
    p.codigo,
    ps.sabor,
    em.tipo,
    em.quantidade,
    em.observacao,
    em.pedido_id
FROM estoque_movimentacoes em
JOIN produtos p ON p.id = em.produto_id
JOIN produto_sabores ps ON ps.id = em.sabor_id
WHERE p.codigo = 'IGN-0006'
  AND em.pedido_id IS NULL
ORDER BY em.created_at DESC;
