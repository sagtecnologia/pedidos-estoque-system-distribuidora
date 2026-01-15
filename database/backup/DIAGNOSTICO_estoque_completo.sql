-- =====================================================
-- DIAGNÓSTICO COMPLETO DO ESTOQUE
-- =====================================================
-- Execute este script para ver o estado atual do estoque
-- antes de reprocessar as movimentações
-- =====================================================

-- 1️⃣ RESUMO GERAL
SELECT 
    '🔍 RESUMO GERAL DO ESTOQUE' as "DIAGNÓSTICO";

SELECT 
    COUNT(DISTINCT p.id) as "Total de Produtos",
    COUNT(em.id) as "Total de Movimentações",
    SUM(CASE WHEN em.tipo = 'ENTRADA' THEN 1 ELSE 0 END) as "Entradas",
    SUM(CASE WHEN em.tipo = 'SAIDA' THEN 1 ELSE 0 END) as "Saídas"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id;

-- 2️⃣ PRODUTOS COM ESTOQUE NEGATIVO (Problema!)
SELECT 
    '⚠️ PRODUTOS COM ESTOQUE NEGATIVO' as "ALERTA";

SELECT 
    p.codigo,
    p.nome,
    p.estoque_atual as "Estoque Registrado",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as "Total Entradas",
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as "Total Saídas",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Estoque Calculado",
    p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Diferença"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.active = true
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
HAVING p.estoque_atual < 0
ORDER BY p.estoque_atual;

-- 3️⃣ PRODUTOS COM ESTOQUE DESATUALIZADO (Diferença entre registrado e calculado)
SELECT 
    '📊 PRODUTOS COM ESTOQUE DESATUALIZADO' as "ANÁLISE";

SELECT 
    p.codigo,
    p.nome,
    p.estoque_atual as "Estoque Registrado",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as "Total Entradas",
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as "Total Saídas",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Estoque Calculado",
    p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Diferença",
    CASE 
        WHEN ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) > 0.01 THEN '❌ INCONSISTENTE'
        ELSE '✅ OK'
    END as "Status"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.active = true
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
HAVING ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) > 0.01
ORDER BY ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) DESC;

-- 4️⃣ MOVIMENTAÇÕES SUSPEITAS (Cancelamentos duplicados)
SELECT 
    '🔍 MOVIMENTAÇÕES SUSPEITAS - POSSÍVEIS DUPLICATAS' as "ANÁLISE";

SELECT 
    p.codigo,
    p.nome,
    em.tipo,
    em.quantidade,
    em.observacao,
    em.created_at,
    COUNT(*) OVER (PARTITION BY em.pedido_id, em.produto_id, em.tipo, em.quantidade, DATE(em.created_at)) as "Duplicatas no Mesmo Dia"
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
WHERE em.observacao LIKE '%Cancelamento%' 
   OR em.observacao LIKE '%Estorno%'
   OR em.observacao LIKE '%Reversão%'
ORDER BY em.pedido_id, em.created_at;

-- 5️⃣ PEDIDOS COM MÚLTIPLAS MOVIMENTAÇÕES (Finalizações/Cancelamentos duplicados)
SELECT 
    '🔍 PEDIDOS COM MÚLTIPLAS MOVIMENTAÇÕES' as "ANÁLISE";

SELECT 
    ped.numero as "Número Pedido",
    ped.tipo_pedido as "Tipo",
    ped.status as "Status Atual",
    p.codigo as "Produto",
    p.nome as "Nome Produto",
    em.tipo as "Tipo Movimentação",
    COUNT(*) as "Quantidade de Movimentações",
    SUM(em.quantidade) as "Total Movimentado",
    STRING_AGG(DISTINCT em.observacao, ' | ') as "Observações",
    MIN(em.created_at) as "Primeira Movimentação",
    MAX(em.created_at) as "Última Movimentação"
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
JOIN pedidos ped ON em.pedido_id = ped.id
GROUP BY ped.numero, ped.tipo_pedido, ped.status, p.codigo, p.nome, em.tipo, em.pedido_id, em.produto_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC, ped.numero;

-- 6️⃣ HISTÓRICO DE STATUS DOS PEDIDOS COM PROBLEMAS
SELECT 
    '📋 PEDIDOS FINALIZADOS/CANCELADOS COM MÚLTIPLAS MOVIMENTAÇÕES' as "ANÁLISE";

SELECT DISTINCT
    ped.numero as "Número Pedido",
    ped.tipo_pedido as "Tipo",
    ped.status as "Status Atual",
    ped.total as "Valor Total",
    ped.data_finalizacao as "Data Finalização",
    COUNT(DISTINCT em.id) as "Total de Movimentações",
    COUNT(DISTINCT CASE WHEN em.observacao LIKE '%Cancelamento%' THEN em.id END) as "Movimentações de Cancelamento",
    COUNT(DISTINCT CASE WHEN em.observacao LIKE '%Finalização%' THEN em.id END) as "Movimentações de Finalização"
FROM pedidos ped
JOIN estoque_movimentacoes em ON ped.id = em.pedido_id
WHERE ped.status IN ('FINALIZADO', 'CANCELADO')
GROUP BY ped.id, ped.numero, ped.tipo_pedido, ped.status, ped.total, ped.data_finalizacao
HAVING COUNT(DISTINCT em.id) > (
    SELECT COUNT(*) FROM pedido_itens WHERE pedido_id = ped.id
)
ORDER BY COUNT(DISTINCT em.id) DESC;

-- 7️⃣ RESUMO DE INCONSISTÊNCIAS
SELECT 
    '📊 RESUMO DE INCONSISTÊNCIAS ENCONTRADAS' as "RESUMO";

WITH inconsistencias AS (
    SELECT 
        p.id,
        p.codigo,
        p.nome,
        p.estoque_atual,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
)
SELECT 
    COUNT(*) as "Total de Produtos com Inconsistência",
    SUM(CASE WHEN estoque_atual < 0 THEN 1 ELSE 0 END) as "Produtos com Estoque Negativo",
    SUM(CASE WHEN ABS(estoque_atual - estoque_calculado) > 0.01 THEN 1 ELSE 0 END) as "Produtos com Estoque Desatualizado",
    ROUND(SUM(ABS(estoque_atual - estoque_calculado))::numeric, 2) as "Total de Diferença Acumulada"
FROM inconsistencias
WHERE ABS(estoque_atual - estoque_calculado) > 0.01 OR estoque_atual < 0;

-- 8️⃣ PRODUTOS MAIS AFETADOS (TOP 10)
SELECT 
    '🎯 TOP 10 PRODUTOS MAIS AFETADOS' as "ANÁLISE";

SELECT 
    p.codigo,
    p.nome,
    p.estoque_atual as "Estoque Registrado",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Estoque Calculado",
    ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) as "Diferença Absoluta",
    COUNT(em.id) as "Total de Movimentações"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.active = true
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
ORDER BY ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) DESC
LIMIT 10;

SELECT '
=====================================================
✅ DIAGNÓSTICO CONCLUÍDO!
=====================================================
Revise os resultados acima para identificar:
1. Produtos com estoque negativo
2. Produtos com estoque desatualizado
3. Movimentações duplicadas ou suspeitas
4. Pedidos com problemas

Se encontrou inconsistências, execute:
👉 REPROCESSAR_estoque_completo.sql

=====================================================
' as "PRÓXIMOS PASSOS";
