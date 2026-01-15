-- =====================================================
-- TESTES DE INTEGRIDADE DO SISTEMA DE ESTOQUE
-- =====================================================

-- TESTE 1: Verificar se há pedidos com múltiplas finalizações
SELECT 
    'TESTE 1: Pedidos com múltiplas finalizações' as teste,
    COUNT(DISTINCT pedido_id) as total_pedidos_afetados,
    SUM(total_movs) as total_movimentacoes_duplicadas
FROM (
    SELECT 
        pedido_id,
        COUNT(*) as total_movs
    FROM estoque_movimentacoes
    WHERE observacao LIKE '%Finalização%'
    GROUP BY pedido_id, produto_id, sabor_id, tipo, quantidade
    HAVING COUNT(*) > 1
) duplicadas;

-- TESTE 2: Verificar se há pedidos finalizados sem movimentações
SELECT 
    'TESTE 2: Pedidos finalizados SEM movimentações' as teste,
    COUNT(*) as total_pedidos
FROM pedidos p
WHERE p.status = 'FINALIZADO'
  AND NOT EXISTS (
    SELECT 1 FROM estoque_movimentacoes em 
    WHERE em.pedido_id = p.id 
    AND em.observacao LIKE '%Finalização%'
  );

-- TESTE 3: Verificar se há movimentações sem pedido associado
SELECT 
    'TESTE 3: Movimentações SEM pedido associado' as teste,
    COUNT(*) as total_movimentacoes
FROM estoque_movimentacoes
WHERE pedido_id IS NULL
  AND (observacao LIKE '%Finalização%' OR observacao LIKE '%Cancelamento%');

-- TESTE 4: Verificar inconsistências de tipo (COMPRA com SAIDA, VENDA com ENTRADA)
WITH movs_com_pedido AS (
    SELECT 
        em.*,
        p.tipo_pedido
    FROM estoque_movimentacoes em
    JOIN pedidos p ON p.id = em.pedido_id
    WHERE em.observacao LIKE '%Finalização%'
)
SELECT 
    'TESTE 4: Inconsistências de tipo' as teste,
    COUNT(*) as total_inconsistencias
FROM movs_com_pedido
WHERE (tipo_pedido = 'COMPRA' AND tipo = 'SAIDA' AND observacao LIKE '%Finalização pedido compra')
   OR (tipo_pedido = 'VENDA' AND tipo = 'ENTRADA' AND observacao LIKE '%Finalização pedido venda');

-- TESTE 5: Verificar estoque negativo
SELECT 
    'TESTE 5: Produtos com estoque NEGATIVO' as teste,
    COUNT(*) as total_produtos
FROM produto_sabores
WHERE quantidade < 0;

-- TESTE 6: Verificar diferença entre estoque atual e calculado
WITH estoques_calculados AS (
    SELECT 
        ps.id,
        ps.quantidade as estoque_atual,
        COALESCE(
            (SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA')
            -
            (SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA')
        , 0) as estoque_calculado
    FROM produto_sabores ps
)
SELECT 
    'TESTE 6: Produtos com estoque DIVERGENTE' as teste,
    COUNT(*) as total_produtos,
    SUM(ABS(estoque_atual - estoque_calculado)) as soma_diferencas
FROM estoques_calculados
WHERE ABS(estoque_atual - estoque_calculado) > 0.01;

-- TESTE 7: Verificar pedidos cancelados com movimentações de finalização
SELECT 
    'TESTE 7: Pedidos CANCELADOS com movimentações de finalização' as teste,
    COUNT(DISTINCT em.pedido_id) as total_pedidos
FROM estoque_movimentacoes em
JOIN pedidos p ON p.id = em.pedido_id
WHERE p.status = 'CANCELADO'
  AND em.observacao LIKE '%Finalização%';

-- TESTE 8: Verificar função finalizar_pedido tem proteções
SELECT 
    'TESTE 8: Função finalizar_pedido tem proteção contra duplicação' as teste,
    CASE 
        WHEN prosrc LIKE '%já foi finalizado%' OR prosrc LIKE '%FINALIZADO%' 
        THEN 'SIM ✅'
        ELSE 'NÃO ❌'
    END as tem_protecao
FROM pg_proc
WHERE proname = 'finalizar_pedido';

-- TESTE 9: Verificar política RLS em estoque_movimentacoes
SELECT 
    'TESTE 9: Políticas RLS em estoque_movimentacoes' as teste,
    COUNT(*) as total_policies
FROM pg_policies
WHERE tablename = 'estoque_movimentacoes';

-- TESTE 10: Verificar se existem triggers que podem causar duplicação
SELECT 
    'TESTE 10: Triggers em pedidos ou estoque' as teste,
    COUNT(*) as total_triggers
FROM pg_trigger
WHERE tgrelid IN (
    SELECT oid FROM pg_class 
    WHERE relname IN ('pedidos', 'pedido_itens', 'estoque_movimentacoes', 'produto_sabores')
)
AND tgname NOT LIKE 'RI_%'; -- Ignorar triggers de integridade referencial

-- RESUMO FINAL
SELECT 
    '═══════════════════════════════════════' as divisor
UNION ALL
SELECT 'RESUMO DOS TESTES' as divisor;
