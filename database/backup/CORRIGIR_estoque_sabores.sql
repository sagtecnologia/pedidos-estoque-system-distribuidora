-- =====================================================
-- RECALCULAR E CORRIGIR ESTOQUE DE SABORES
-- =====================================================
-- Este script CORRIGE o estoque atual baseado nas movimentações
-- NÃO exclui nada, apenas ajusta as quantidades incorretas

-- =====================================================
-- PASSO 1: DIAGNÓSTICO DO PROBLEMA
-- =====================================================

-- Ver sabores com estoque NEGATIVO
SELECT 
    ps.id,
    p.codigo,
    p.nome as produto,
    ps.sabor,
    ps.quantidade as estoque_atual,
    COALESCE(
        SUM(CASE 
            WHEN em.tipo = 'ENTRADA' THEN em.quantidade 
            WHEN em.tipo = 'SAIDA' THEN -em.quantidade 
            ELSE 0 
        END), 0
    ) as estoque_calculado_movimentacoes,
    (ps.quantidade - COALESCE(
        SUM(CASE 
            WHEN em.tipo = 'ENTRADA' THEN em.quantidade 
            WHEN em.tipo = 'SAIDA' THEN -em.quantidade 
            ELSE 0 
        END), 0
    )) as diferenca
FROM produto_sabores ps
JOIN produtos p ON p.id = ps.produto_id
LEFT JOIN estoque_movimentacoes em ON em.sabor_id = ps.id
GROUP BY ps.id, p.codigo, p.nome, ps.sabor, ps.quantidade
HAVING ps.quantidade < 0
ORDER BY ps.quantidade;

-- Ver todos os sabores com divergência entre estoque e movimentações
SELECT 
    ps.id,
    p.codigo,
    p.nome as produto,
    ps.sabor,
    ps.quantidade as estoque_registrado,
    COALESCE(
        SUM(CASE 
            WHEN em.tipo = 'ENTRADA' THEN em.quantidade 
            WHEN em.tipo = 'SAIDA' THEN -em.quantidade 
            ELSE 0 
        END), 0
    ) as estoque_pelas_movimentacoes,
    (ps.quantidade - COALESCE(
        SUM(CASE 
            WHEN em.tipo = 'ENTRADA' THEN em.quantidade 
            WHEN em.tipo = 'SAIDA' THEN -em.quantidade 
            ELSE 0 
        END), 0
    )) as diferenca
FROM produto_sabores ps
JOIN produtos p ON p.id = ps.produto_id
LEFT JOIN estoque_movimentacoes em ON em.sabor_id = ps.id
GROUP BY ps.id, p.codigo, p.nome, ps.sabor, ps.quantidade
HAVING ABS(ps.quantidade - COALESCE(
    SUM(CASE 
        WHEN em.tipo = 'ENTRADA' THEN em.quantidade 
        WHEN em.tipo = 'SAIDA' THEN -em.quantidade 
        ELSE 0 
    END), 0
)) > 0
ORDER BY diferenca DESC;

-- Ver movimentações duplicadas de cancelamento
SELECT 
    p.numero as pedido,
    pd.status,
    ps.sabor,
    em.tipo,
    em.quantidade,
    em.observacao,
    em.created_at,
    COUNT(*) OVER (PARTITION BY em.pedido_id, em.sabor_id, em.tipo) as vezes_registrado
FROM estoque_movimentacoes em
JOIN pedidos pd ON pd.id = em.pedido_id
JOIN pedidos p ON p.id = em.pedido_id
JOIN produto_sabores ps ON ps.id = em.sabor_id
WHERE em.observacao LIKE '%Cancelamento%'
   OR em.observacao LIKE '%Devolução%'
   OR em.observacao LIKE '%Reabertura%'
ORDER BY em.pedido_id, em.sabor_id, em.created_at;

-- =====================================================
-- OPÇÃO 1: RECALCULAR ESTOQUE COM BASE NAS MOVIMENTAÇÕES
-- =====================================================
-- Ajusta o estoque de TODOS os sabores baseado no histórico de movimentações

-- ⚠️ DESCOMENTE PARA EXECUTAR
-- BEGIN;
-- 
-- UPDATE produto_sabores ps
-- SET quantidade = COALESCE(
--     (SELECT SUM(CASE 
--         WHEN em.tipo = 'ENTRADA' THEN em.quantidade 
--         WHEN em.tipo = 'SAIDA' THEN -em.quantidade 
--         ELSE 0 
--     END)
--     FROM estoque_movimentacoes em
--     WHERE em.sabor_id = ps.id
--     ), 0
-- );
-- 
-- COMMIT;
-- SELECT '✅ Estoque recalculado com base nas movimentações!' as resultado;

-- =====================================================
-- OPÇÃO 2: ZERAR ESTOQUE NEGATIVO
-- =====================================================
-- Define estoque mínimo de 0 para todos os sabores negativos

-- ⚠️ DESCOMENTE PARA EXECUTAR
-- UPDATE produto_sabores 
-- SET quantidade = 0 
-- WHERE quantidade < 0;
-- 
-- SELECT '✅ Estoques negativos ajustados para zero!' as resultado;

-- =====================================================
-- OPÇÃO 3: AJUSTAR ESTOQUE MANUALMENTE (SABOR ESPECÍFICO)
-- =====================================================
-- Define quantidade específica para um sabor

-- Exemplo: Ajustar sabor específico para 100 unidades
-- UPDATE produto_sabores 
-- SET quantidade = 100 
-- WHERE id = 'UUID-DO-SABOR-AQUI';

-- =====================================================
-- OPÇÃO 4: REMOVER MOVIMENTAÇÕES DUPLICADAS DE CANCELAMENTO
-- =====================================================
-- Remove apenas as movimentações DUPLICADAS de cancelamento
-- mantendo a primeira ocorrência de cada cancelamento

-- Ver duplicatas primeiro
WITH duplicatas AS (
    SELECT 
        em.id,
        em.pedido_id,
        em.sabor_id,
        em.tipo,
        em.quantidade,
        em.observacao,
        em.created_at,
        ROW_NUMBER() OVER (
            PARTITION BY em.pedido_id, em.sabor_id, em.tipo, em.observacao 
            ORDER BY em.created_at
        ) as numero_ocorrencia
    FROM estoque_movimentacoes em
    WHERE em.observacao LIKE '%Cancelamento%'
       OR em.observacao LIKE '%Devolução%'
       OR em.observacao LIKE '%Reabertura%'
)
SELECT 
    p.numero as pedido,
    ps.sabor,
    d.tipo,
    d.quantidade,
    d.observacao,
    d.created_at,
    d.numero_ocorrencia
FROM duplicatas d
JOIN pedidos p ON p.id = d.pedido_id
JOIN produto_sabores ps ON ps.id = d.sabor_id
WHERE d.numero_ocorrencia > 1
ORDER BY p.numero, ps.sabor, d.created_at;

-- Excluir duplicatas (mantém apenas a primeira)
-- ⚠️ DESCOMENTE PARA EXECUTAR
-- BEGIN;
-- 
-- WITH duplicatas AS (
--     SELECT 
--         em.id,
--         ROW_NUMBER() OVER (
--             PARTITION BY em.pedido_id, em.sabor_id, em.tipo, em.observacao 
--             ORDER BY em.created_at
--         ) as numero_ocorrencia
--     FROM estoque_movimentacoes em
--     WHERE em.observacao LIKE '%Cancelamento%'
--        OR em.observacao LIKE '%Devolução%'
--        OR em.observacao LIKE '%Reabertura%'
-- )
-- DELETE FROM estoque_movimentacoes
-- WHERE id IN (
--     SELECT id FROM duplicatas WHERE numero_ocorrencia > 1
-- );
-- 
-- COMMIT;
-- SELECT '✅ Movimentações duplicadas de cancelamento removidas!' as resultado;

-- =====================================================
-- OPÇÃO 5: CORREÇÃO COMPLETA (RECOMENDADO)
-- =====================================================
-- 1. Remove duplicatas de cancelamento
-- 2. Recalcula estoque baseado nas movimentações restantes

-- ⚠️ DESCOMENTE PARA EXECUTAR A CORREÇÃO COMPLETA
-- BEGIN;
-- 
-- -- 1. Remover movimentações duplicadas
-- WITH duplicatas AS (
--     SELECT 
--         em.id,
--         ROW_NUMBER() OVER (
--             PARTITION BY em.pedido_id, em.sabor_id, em.tipo, em.observacao 
--             ORDER BY em.created_at
--         ) as numero_ocorrencia
--     FROM estoque_movimentacoes em
--     WHERE (em.observacao LIKE '%Cancelamento%'
--        OR em.observacao LIKE '%Devolução%'
--        OR em.observacao LIKE '%Reabertura%')
--        AND em.pedido_id IS NOT NULL
-- )
-- DELETE FROM estoque_movimentacoes
-- WHERE id IN (
--     SELECT id FROM duplicatas WHERE numero_ocorrencia > 1
-- );
-- 
-- -- 2. Recalcular estoque de todos os sabores
-- UPDATE produto_sabores ps
-- SET quantidade = GREATEST(0, COALESCE(
--     (SELECT SUM(CASE 
--         WHEN em.tipo = 'ENTRADA' THEN em.quantidade 
--         WHEN em.tipo = 'SAIDA' THEN -em.quantidade 
--         ELSE 0 
--     END)
--     FROM estoque_movimentacoes em
--     WHERE em.sabor_id = ps.id
--     ), 0
-- ));
-- 
-- COMMIT;
-- SELECT '✅ Correção completa aplicada! Duplicatas removidas e estoque recalculado.' as resultado;

-- =====================================================
-- OPÇÃO 6: CORREÇÃO ESPECÍFICA POR PEDIDO
-- =====================================================
-- Remove movimentações duplicadas de um pedido específico

-- Ver movimentações de um pedido específico
-- SELECT 
--     em.id,
--     ps.sabor,
--     em.tipo,
--     em.quantidade,
--     em.observacao,
--     em.created_at
-- FROM estoque_movimentacoes em
-- JOIN produto_sabores ps ON ps.id = em.sabor_id
-- WHERE em.pedido_id = 'UUID-DO-PEDIDO-AQUI'
-- ORDER BY em.created_at;

-- Excluir movimentações duplicadas de um pedido específico
-- DELETE FROM estoque_movimentacoes 
-- WHERE pedido_id = 'UUID-DO-PEDIDO-AQUI'
--   AND id NOT IN (
--       SELECT MIN(id) 
--       FROM estoque_movimentacoes 
--       WHERE pedido_id = 'UUID-DO-PEDIDO-AQUI'
--       GROUP BY sabor_id, tipo, observacao
--   );

-- =====================================================
-- VERIFICAÇÕES PÓS-CORREÇÃO
-- =====================================================

-- Verificar se ainda há estoques negativos
SELECT 
    p.codigo,
    p.nome,
    ps.sabor,
    ps.quantidade
FROM produto_sabores ps
JOIN produtos p ON p.id = ps.produto_id
WHERE ps.quantidade < 0
ORDER BY ps.quantidade;

-- Verificar total de movimentações por sabor
SELECT 
    p.codigo,
    p.nome,
    ps.sabor,
    ps.quantidade as estoque_atual,
    COUNT(em.id) as total_movimentacoes,
    COUNT(em.id) FILTER (WHERE em.tipo = 'ENTRADA') as entradas,
    COUNT(em.id) FILTER (WHERE em.tipo = 'SAIDA') as saidas
FROM produto_sabores ps
JOIN produtos p ON p.id = ps.produto_id
LEFT JOIN estoque_movimentacoes em ON em.sabor_id = ps.id
GROUP BY p.codigo, p.nome, ps.sabor, ps.quantidade
ORDER BY p.codigo, ps.sabor;

-- Resumo geral
SELECT 
    COUNT(*) as total_sabores,
    COUNT(*) FILTER (WHERE quantidade < 0) as negativos,
    COUNT(*) FILTER (WHERE quantidade = 0) as zerados,
    COUNT(*) FILTER (WHERE quantidade > 0) as positivos,
    SUM(quantidade) as estoque_total
FROM produto_sabores;

SELECT '📋 Script de correção carregado. Execute o diagnóstico e depois descomente a opção desejada.' as info;
