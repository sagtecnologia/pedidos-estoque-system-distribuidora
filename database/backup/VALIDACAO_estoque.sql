-- =====================================================
-- VALIDAÇÃO DO ESTOQUE APÓS REPROCESSAMENTO
-- =====================================================
-- Execute este script após REPROCESSAR_estoque_completo.sql
-- para validar que tudo foi corrigido corretamente
-- =====================================================

-- =====================================================
-- TESTE 1: VERIFICAR SE HÁ PRODUTOS COM ESTOQUE NEGATIVO
-- =====================================================

SELECT '
=====================================================
  🔍 TESTE 1: PRODUTOS COM ESTOQUE NEGATIVO
=====================================================
' as "TESTE";

SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ PASSOU - Nenhum produto com estoque negativo'
        ELSE '❌ FALHOU - Ainda há ' || COUNT(*) || ' produto(s) com estoque negativo'
    END as "Resultado"
FROM produtos
WHERE estoque_atual < 0 AND active = true;

-- Detalhes dos produtos com estoque negativo (se houver)
SELECT 
    codigo as "Código",
    nome as "Produto",
    estoque_atual as "Estoque",
    unidade as "Unidade"
FROM produtos
WHERE estoque_atual < 0 AND active = true
ORDER BY estoque_atual;

-- =====================================================
-- TESTE 2: VERIFICAR CONSISTÊNCIA ENTRE ESTOQUE E MOVIMENTAÇÕES
-- =====================================================

SELECT '
=====================================================
  🔍 TESTE 2: CONSISTÊNCIA ESTOQUE x MOVIMENTAÇÕES
=====================================================
' as "TESTE";

WITH validacao AS (
    SELECT 
        p.id,
        p.codigo,
        p.nome,
        p.estoque_atual,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado,
        ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) as diferenca
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
)
SELECT 
    CASE 
        WHEN COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) = 0 
        THEN '✅ PASSOU - Todos os estoques estão consistentes'
        ELSE '❌ FALHOU - ' || COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) || ' produto(s) com inconsistência'
    END as "Resultado",
    COUNT(*) as "Total de Produtos Verificados",
    COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) as "Produtos Inconsistentes",
    ROUND(MAX(diferenca)::numeric, 2) as "Maior Diferença Encontrada"
FROM validacao;

-- Detalhes dos produtos inconsistentes (se houver)
SELECT 
    codigo as "Código",
    nome as "Produto",
    estoque_atual as "Estoque Registrado",
    estoque_calculado as "Estoque Calculado",
    diferenca as "Diferença"
FROM (
    SELECT 
        p.id,
        p.codigo,
        p.nome,
        p.estoque_atual,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado,
        ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) as diferenca
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
) v
WHERE diferenca > 0.01
ORDER BY diferenca DESC;

-- =====================================================
-- TESTE 3: VERIFICAR SE HÁ MOVIMENTAÇÕES DUPLICADAS
-- =====================================================

SELECT '
=====================================================
  🔍 TESTE 3: MOVIMENTAÇÕES DUPLICADAS
=====================================================
' as "TESTE";

WITH duplicatas AS (
    SELECT 
        pedido_id,
        produto_id,
        tipo,
        quantidade,
        DATE(created_at) as data,
        COUNT(*) as ocorrencias
    FROM estoque_movimentacoes
    WHERE pedido_id IS NOT NULL
    GROUP BY pedido_id, produto_id, tipo, quantidade, DATE(created_at)
    HAVING COUNT(*) > 1
)
SELECT 
    CASE 
        WHEN COUNT(*) = 0 
        THEN '✅ PASSOU - Nenhuma movimentação duplicada encontrada'
        ELSE '❌ FALHOU - Encontradas ' || SUM(ocorrencias - 1) || ' movimentações duplicadas'
    END as "Resultado",
    COUNT(*) as "Grupos Duplicados",
    SUM(ocorrencias - 1) as "Total de Duplicatas"
FROM duplicatas;

-- Detalhes das duplicatas (se houver)
SELECT 
    ped.numero as "Pedido",
    p.codigo as "Produto",
    em.tipo as "Tipo",
    em.quantidade as "Quantidade",
    COUNT(*) as "Ocorrências",
    MIN(em.created_at) as "Primeira",
    MAX(em.created_at) as "Última"
FROM estoque_movimentacoes em
JOIN pedidos ped ON em.pedido_id = ped.id
JOIN produtos p ON em.produto_id = p.id
WHERE em.pedido_id IS NOT NULL
GROUP BY ped.numero, p.codigo, em.tipo, em.quantidade, em.pedido_id, em.produto_id, DATE(em.created_at)
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- =====================================================
-- TESTE 4: VERIFICAR PEDIDOS COM MÚLTIPLAS MOVIMENTAÇÕES SUSPEITAS
-- =====================================================

SELECT '
=====================================================
  🔍 TESTE 4: PEDIDOS COM MOVIMENTAÇÕES SUSPEITAS
=====================================================
' as "TESTE";

WITH pedidos_movimentacoes AS (
    SELECT 
        ped.id,
        ped.numero,
        ped.status,
        COUNT(DISTINCT em.id) as total_movimentacoes,
        COUNT(DISTINCT pi.id) as total_itens,
        COUNT(DISTINCT em.id) - COUNT(DISTINCT pi.id) as diferenca
    FROM pedidos ped
    LEFT JOIN pedido_itens pi ON ped.id = pi.pedido_id
    LEFT JOIN estoque_movimentacoes em ON ped.id = em.pedido_id
    WHERE ped.status IN ('FINALIZADO', 'CANCELADO')
    GROUP BY ped.id, ped.numero, ped.status
)
SELECT 
    CASE 
        WHEN COUNT(CASE WHEN diferenca > 0 THEN 1 END) = 0 
        THEN '✅ PASSOU - Nenhum pedido com movimentações excessivas'
        ELSE '⚠️ ATENÇÃO - ' || COUNT(CASE WHEN diferenca > 0 THEN 1 END) || ' pedido(s) com mais movimentações que itens'
    END as "Resultado",
    COUNT(*) as "Total de Pedidos Verificados",
    COUNT(CASE WHEN diferenca > 0 THEN 1 END) as "Pedidos com Movimentações Extras"
FROM pedidos_movimentacoes;

-- Detalhes dos pedidos suspeitos (se houver)
SELECT 
    numero as "Pedido",
    status as "Status",
    total_itens as "Itens do Pedido",
    total_movimentacoes as "Movimentações",
    diferenca as "Diferença",
    CASE 
        WHEN diferenca = total_itens THEN '⚠️ Possível cancelamento + finalização'
        WHEN diferenca > total_itens THEN '❌ Múltiplos cancelamentos/finalizações'
        ELSE '✅ OK'
    END as "Diagnóstico"
FROM (
    SELECT 
        ped.numero,
        ped.status,
        COUNT(DISTINCT em.id) as total_movimentacoes,
        COUNT(DISTINCT pi.id) as total_itens,
        COUNT(DISTINCT em.id) - COUNT(DISTINCT pi.id) as diferenca
    FROM pedidos ped
    LEFT JOIN pedido_itens pi ON ped.id = pi.pedido_id
    LEFT JOIN estoque_movimentacoes em ON ped.id = em.pedido_id
    WHERE ped.status IN ('FINALIZADO', 'CANCELADO')
    GROUP BY ped.id, ped.numero, ped.status
) pm
WHERE diferenca > 0
ORDER BY diferenca DESC;

-- =====================================================
-- TESTE 5: VERIFICAR LOG DE REPROCESSAMENTO
-- =====================================================

SELECT '
=====================================================
  📊 TESTE 5: HISTÓRICO DE REPROCESSAMENTO
=====================================================
' as "TESTE";

-- Verificar se a tabela de log existe
SELECT 
    CASE 
        WHEN EXISTS (SELECT FROM pg_tables WHERE schemaname = 'public' AND tablename = 'estoque_reprocessamento_log') 
        THEN '✅ PASSOU - Tabela de log existe (reprocessamento já foi executado)'
        ELSE '⚠️ INFO - Tabela de log não existe (execute REPROCESSAR_estoque_completo.sql primeiro)'
    END as "Resultado";

-- Nota: Se você executou o reprocessamento e este teste ainda mostra que a tabela não existe,
-- execute as próximas consultas comentadas abaixo para ver os logs:

/*
-- Descomente se a tabela existir e quiser ver os logs:

SELECT 
    CASE 
        WHEN COUNT(*) > 0 
        THEN '✅ Log encontrado - ' || COUNT(*) || ' produto(s) foram ajustados na última hora'
        ELSE '⚠️ Nenhum ajuste registrado na última hora'
    END as "Status Log"
FROM estoque_reprocessamento_log
WHERE reprocessado_em >= NOW() - INTERVAL '1 hour';

SELECT 
    codigo_produto as "Código",
    nome_produto as "Produto",
    estoque_anterior as "Antes",
    estoque_recalculado as "Depois",
    diferenca as "Ajuste",
    total_entradas as "Entradas",
    total_saidas as "Saídas",
    movimentacoes_duplicadas_removidas as "Duplicatas Removidas",
    reprocessado_em as "Data/Hora"
FROM estoque_reprocessamento_log
WHERE reprocessado_em >= NOW() - INTERVAL '24 hours'
ORDER BY reprocessado_em DESC, ABS(diferenca) DESC
LIMIT 20;
*/

-- =====================================================
-- RELATÓRIO FINAL DE VALIDAÇÃO
-- =====================================================

SELECT '
=====================================================
        🎯 RELATÓRIO FINAL DE VALIDAÇÃO
=====================================================
' as "RELATÓRIO";

WITH 
teste1 AS (
    SELECT COUNT(*) as falhas FROM produtos WHERE estoque_atual < 0 AND active = true
),
teste2 AS (
    SELECT COUNT(*) as falhas
    FROM (
        SELECT 
            p.id,
            ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) as diferenca
        FROM produtos p
        LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
        WHERE p.active = true
        GROUP BY p.id, p.estoque_atual
    ) v
    WHERE diferenca > 0.01
),
teste3 AS (
    SELECT COUNT(*) as falhas
    FROM (
        SELECT 
            pedido_id,
            produto_id,
            tipo,
            quantidade,
            DATE(created_at) as data,
            COUNT(*) as ocorrencias
        FROM estoque_movimentacoes
        WHERE pedido_id IS NOT NULL
        GROUP BY pedido_id, produto_id, tipo, quantidade, DATE(created_at)
        HAVING COUNT(*) > 1
    ) d
),
teste4 AS (
    SELECT COUNT(*) as falhas
    FROM (
        SELECT 
            ped.id,
            COUNT(DISTINCT em.id) - COUNT(DISTINCT pi.id) as diferenca
        FROM pedidos ped
        LEFT JOIN pedido_itens pi ON ped.id = pi.pedido_id
        LEFT JOIN estoque_movimentacoes em ON ped.id = em.pedido_id
        WHERE ped.status IN ('FINALIZADO', 'CANCELADO')
        GROUP BY ped.id
    ) pm
    WHERE diferenca > 0
)
SELECT 
    CASE 
        WHEN (SELECT falhas FROM teste1) + (SELECT falhas FROM teste2) + (SELECT falhas FROM teste3) = 0 
        THEN '✅ TODOS OS TESTES PASSARAM!'
        ELSE '⚠️ ALGUNS TESTES FALHARAM - VEJA DETALHES ACIMA'
    END as "Status Geral",
    (SELECT falhas FROM teste1) as "Teste 1: Estoque Negativo",
    (SELECT falhas FROM teste2) as "Teste 2: Inconsistências",
    (SELECT falhas FROM teste3) as "Teste 3: Duplicatas",
    (SELECT falhas FROM teste4) as "Teste 4: Movimentações Suspeitas";

-- =====================================================
-- ESTATÍSTICAS GERAIS DO ESTOQUE
-- =====================================================

SELECT '
=====================================================
    📊 ESTATÍSTICAS GERAIS DO ESTOQUE
=====================================================
' as "ESTATÍSTICAS";

SELECT 
    COUNT(*) as "Total de Produtos Ativos",
    COUNT(CASE WHEN estoque_atual = 0 THEN 1 END) as "Produtos Sem Estoque",
    COUNT(CASE WHEN estoque_atual > 0 AND estoque_atual <= estoque_minimo THEN 1 END) as "Produtos com Estoque Baixo",
    COUNT(CASE WHEN estoque_atual > estoque_minimo THEN 1 END) as "Produtos com Estoque Normal",
    ROUND(SUM(estoque_atual)::numeric, 2) as "Estoque Total (Unidades)",
    ROUND(AVG(estoque_atual)::numeric, 2) as "Média de Estoque por Produto"
FROM produtos
WHERE active = true;

SELECT 
    COUNT(*) as "Total de Movimentações",
    COUNT(CASE WHEN tipo = 'ENTRADA' THEN 1 END) as "Entradas",
    COUNT(CASE WHEN tipo = 'SAIDA' THEN 1 END) as "Saídas",
    ROUND(SUM(CASE WHEN tipo = 'ENTRADA' THEN quantidade ELSE 0 END)::numeric, 2) as "Total Entradas",
    ROUND(SUM(CASE WHEN tipo = 'SAIDA' THEN quantidade ELSE 0 END)::numeric, 2) as "Total Saídas"
FROM estoque_movimentacoes;

SELECT '
=====================================================
          ✅ VALIDAÇÃO CONCLUÍDA!
=====================================================

Se todos os testes passaram, seu estoque está
corrigido e sincronizado corretamente!

Se algum teste falhou, revise os detalhes acima
e execute novamente o reprocessamento se necessário.

=====================================================
' as "CONCLUSÃO";
