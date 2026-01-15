-- =====================================================
-- DIAGNÓSTICO: PRODUTO COM ESTOQUE NEGATIVO
-- =====================================================
-- Identifica o produto negativo e suas movimentações
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║     🔍 DIAGNÓSTICO: PRODUTO COM ESTOQUE NEGATIVO          ║
╚═══════════════════════════════════════════════════════════╝
' as "INÍCIO";

-- =====================================================
-- 1. IDENTIFICAR O PRODUTO NEGATIVO
-- =====================================================

SELECT '📋 PRODUTO COM ESTOQUE NEGATIVO' as "ANÁLISE";

WITH estoque_calculado AS (
    SELECT 
        p.id,
        p.codigo,
        p.nome,
        p.estoque_atual,
        p.preco_compra,
        p.preco_venda,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as total_entradas,
        COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as total_saidas,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome, p.estoque_atual, p.preco_compra, p.preco_venda
)
SELECT 
    codigo as "Código",
    nome as "Nome",
    estoque_atual as "Estoque Atual",
    estoque_calculado as "Estoque Calculado",
    total_entradas as "Total Entradas",
    total_saidas as "Total Saídas",
    (total_saidas - total_entradas) as "Diferença (Saída - Entrada)",
    ROUND((estoque_calculado * preco_compra)::numeric, 2) as "Valor Compra (R$)",
    ROUND((estoque_calculado * preco_venda)::numeric, 2) as "Valor Venda (R$)"
FROM estoque_calculado
WHERE estoque_calculado < 0
ORDER BY estoque_calculado;

-- =====================================================
-- 2. TODAS AS MOVIMENTAÇÕES DO PRODUTO NEGATIVO
-- =====================================================

SELECT '📦 MOVIMENTAÇÕES DO PRODUTO NEGATIVO (Ordem Cronológica)' as "ANÁLISE";

WITH produto_negativo AS (
    SELECT 
        p.id,
        p.codigo,
        p.nome,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome
    HAVING COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) < 0
    LIMIT 1
)
SELECT 
    em.created_at as "Data/Hora",
    em.tipo as "Tipo",
    em.quantidade as "Quantidade",
    em.estoque_anterior as "Estoque Antes",
    em.estoque_novo as "Estoque Depois",
    COALESCE(ped.id::text, 'SEM PEDIDO') as "Pedido ID",
    COALESCE(ped.status, 'N/A') as "Status Pedido",
    em.observacao as "Observação",
    em.id as "Movimentação ID"
FROM estoque_movimentacoes em
JOIN produto_negativo pn ON em.produto_id = pn.id
LEFT JOIN pedidos ped ON em.pedido_id = ped.id
ORDER BY em.created_at, em.id;

-- =====================================================
-- 3. VERIFICAR MOVIMENTAÇÕES DUPLICADAS
-- =====================================================

SELECT '🔍 MOVIMENTAÇÕES DUPLICADAS DO PRODUTO NEGATIVO' as "ANÁLISE";

WITH produto_negativo AS (
    SELECT 
        p.id
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id
    HAVING COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) < 0
    LIMIT 1
)
SELECT 
    COUNT(*) as "Total Duplicadas",
    tipo as "Tipo",
    quantidade as "Quantidade",
    DATE(created_at) as "Data",
    pedido_id as "Pedido ID",
    ARRAY_AGG(id ORDER BY created_at) as "IDs das Movimentações"
FROM estoque_movimentacoes em
JOIN produto_negativo pn ON em.produto_id = pn.id
GROUP BY tipo, quantidade, DATE(created_at), pedido_id
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- =====================================================
-- 4. PEDIDOS RELACIONADOS AO PRODUTO NEGATIVO
-- =====================================================

SELECT '📋 PEDIDOS RELACIONADOS AO PRODUTO NEGATIVO' as "ANÁLISE";

WITH produto_negativo AS (
    SELECT 
        p.id,
        p.codigo,
        p.nome
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome
    HAVING COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) < 0
    LIMIT 1
)
SELECT 
    ped.id as "Pedido ID",
    ped.status as "Status",
    ped.tipo as "Tipo",
    pi.quantidade as "Quantidade no Item",
    COUNT(em.id) as "Movimentações Geradas",
    STRING_AGG(em.tipo || ': ' || em.quantidade, ', ' ORDER BY em.created_at) as "Movimentações",
    ped.created_at as "Data Pedido",
    ped.finalizado_em as "Finalizado Em",
    ped.cancelado_em as "Cancelado Em"
FROM pedidos ped
JOIN pedido_itens pi ON ped.id = pi.pedido_id
JOIN produto_negativo pn ON pi.produto_id = pn.id
LEFT JOIN estoque_movimentacoes em ON ped.id = em.pedido_id AND em.produto_id = pn.id
GROUP BY ped.id, ped.status, ped.tipo, pi.quantidade, ped.created_at, ped.finalizado_em, ped.cancelado_em
ORDER BY ped.created_at;

-- =====================================================
-- 5. HISTÓRICO DE STATUS DO PEDIDO SUSPEITO
-- =====================================================

SELECT '🔄 PEDIDOS QUE FORAM CANCELADOS E REFINALIZADOS' as "ANÁLISE";

WITH produto_negativo AS (
    SELECT id FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id
    HAVING COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) < 0
    LIMIT 1
),
pedidos_suspeitos AS (
    SELECT DISTINCT ped.id
    FROM pedidos ped
    JOIN pedido_itens pi ON ped.id = pi.pedido_id
    JOIN produto_negativo pn ON pi.produto_id = pn.id
    WHERE ped.cancelado_em IS NOT NULL OR ped.finalizado_em IS NOT NULL
)
SELECT 
    ped.id as "Pedido ID",
    ped.tipo as "Tipo",
    ped.status as "Status Atual",
    ped.created_at as "Criado Em",
    ped.finalizado_em as "Finalizado Em",
    ped.cancelado_em as "Cancelado Em",
    CASE 
        WHEN ped.cancelado_em IS NOT NULL AND ped.finalizado_em IS NOT NULL THEN
            CASE 
                WHEN ped.cancelado_em < ped.finalizado_em THEN '⚠️ Cancelado depois Finalizado'
                ELSE '⚠️ Finalizado depois Cancelado'
            END
        WHEN ped.cancelado_em IS NOT NULL THEN '✅ Apenas Cancelado'
        WHEN ped.finalizado_em IS NOT NULL THEN '✅ Apenas Finalizado'
        ELSE 'Pendente'
    END as "Situação"
FROM pedidos ped
WHERE ped.id IN (SELECT id FROM pedidos_suspeitos)
ORDER BY ped.created_at;

-- =====================================================
-- 6. RESUMO E RECOMENDAÇÕES
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            💡 RESUMO E RECOMENDAÇÕES                      ║
╚═══════════════════════════════════════════════════════════╝
' as "RESUMO";

WITH produto_negativo AS (
    SELECT 
        p.codigo,
        p.nome,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as total_entradas,
        COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as total_saidas,
        COUNT(em.id) as total_movimentacoes,
        COUNT(DISTINCT em.pedido_id) as total_pedidos
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome
    HAVING COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) < 0
)
SELECT 
    '📌 Produto: ' || codigo || ' - ' || nome as "Informação",
    '📥 Total Entradas: ' || total_entradas || ' UN' as "Entradas",
    '📤 Total Saídas: ' || total_saidas || ' UN' as "Saídas",
    '⚖️ Diferença: ' || (total_saidas - total_entradas) || ' UN a mais de SAÍDA' as "Problema",
    '📦 Total Movimentações: ' || total_movimentacoes as "Movimentações",
    '🛒 Total Pedidos Envolvidos: ' || total_pedidos as "Pedidos"
FROM produto_negativo;

SELECT '
╔═══════════════════════════════════════════════════════════╗
║  📋 POSSÍVEIS CAUSAS                                      ║
║                                                           ║
║  1. Movimentações duplicadas de SAÍDA                     ║
║  2. Pedido cancelado que gerou SAÍDA indevida             ║
║  3. Pedido finalizado/cancelado múltiplas vezes           ║
║  4. Falta de ENTRADA inicial do produto                   ║
║                                                           ║
║  📝 PRÓXIMOS PASSOS                                       ║
║                                                           ║
║  A) Se há duplicadas: remover as duplicadas               ║
║  B) Se falta ENTRADA: adicionar entrada inicial           ║
║  C) Se há SAÍDA sem pedido: investigar a origem           ║
║                                                           ║
║  Execute: CORRIGIR_produto_negativo.sql                   ║
╚═══════════════════════════════════════════════════════════╝
' as "ORIENTAÇÕES";
