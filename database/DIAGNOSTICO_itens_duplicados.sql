-- =====================================================
-- DIAGNÓSTICO: Itens Duplicados na Venda
-- =====================================================
-- Se não há movimentações mas dá erro de duplicação,
-- o problema é: PRODUTO DUPLICADO NOS ITENS DA VENDA
-- =====================================================

-- PASSO 1: VERIFICAR ITENS DA VENDA

SELECT 
    '📦 ITENS DA VENDA' as "ANÁLISE";

SELECT 
    pi.id as "ID Item",
    p.codigo as "Código Produto",
    p.nome as "Nome Produto",
    ps.sabor as "Sabor",
    pi.quantidade as "Quantidade",
    pi.valor_unitario as "Valor Unit.",
    pi.subtotal as "Subtotal"
FROM pedido_itens pi
LEFT JOIN produtos p ON p.id = pi.produto_id
LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
WHERE pi.pedido_id = (
    SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005'
)
ORDER BY p.codigo, ps.sabor;

-- PASSO 2: DETECTAR PRODUTOS/SABORES DUPLICADOS

SELECT 
    '🔍 PRODUTOS DUPLICADOS NOS ITENS' as "PROBLEMA";

WITH itens_agrupados AS (
    SELECT 
        pi.produto_id,
        pi.sabor_id,
        p.codigo as codigo_produto,
        ps.sabor as sabor_nome,
        COUNT(*) as vezes_no_pedido,
        STRING_AGG(pi.id::TEXT, ', ') as ids_itens,
        SUM(pi.quantidade) as quantidade_total
    FROM pedido_itens pi
    LEFT JOIN produtos p ON p.id = pi.produto_id
    LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
    WHERE pi.pedido_id = (
        SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005'
    )
    GROUP BY pi.produto_id, pi.sabor_id, p.codigo, ps.sabor
)
SELECT 
    codigo_produto as "Código",
    sabor_nome as "Sabor",
    vezes_no_pedido as "Vezes Repetido",
    quantidade_total as "Qtd Total",
    CASE 
        WHEN vezes_no_pedido > 1 THEN '⚠️  DUPLICADO - ESTE É O PROBLEMA!'
        ELSE '✅ OK'
    END as "Status"
FROM itens_agrupados
ORDER BY vezes_no_pedido DESC;

-- PASSO 3: ANÁLISE DETALHADA DO PRODUTO PROBLEMÁTICO (IGN-0010)

SELECT 
    '🎯 ANÁLISE DO PRODUTO IGN-0010' as "FOCO";

SELECT 
    pi.id as "ID do Item",
    p.codigo as "Código",
    p.nome as "Nome",
    ps.sabor as "Sabor",
    pi.quantidade as "Qtd",
    pi.valor_unitario as "Vlr Unit",
    pi.subtotal as "Subtotal",
    TO_CHAR(pi.created_at, 'DD/MM/YYYY HH24:MI:SS') as "Data Criação"
FROM pedido_itens pi
LEFT JOIN produtos p ON p.id = pi.produto_id
LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
WHERE pi.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
AND p.codigo = 'IGN-0010'
ORDER BY pi.created_at;

-- =====================================================
-- EXPLICAÇÃO DO PROBLEMA
-- =====================================================

SELECT 
    '💡 EXPLICAÇÃO' as "INFO";

SELECT 
    'O erro ocorre porque o produto IGN-0010 aparece MAIS DE UMA VEZ
    nos itens da venda (provavelmente com sabores diferentes ou 
    adicionado duas vezes por engano).
    
    Quando o sistema tenta finalizar, ele percorre TODOS os itens
    e tenta criar uma movimentação para cada um. Como o produto
    está duplicado, ele tenta criar movimentações duplicadas,
    e a proteção do banco impede isso.
    
    SOLUÇÕES POSSÍVEIS:
    
    1. CONSOLIDAR ITENS (Recomendado)
       - Manter apenas 1 item por produto/sabor
       - Somar as quantidades dos itens duplicados
       
    2. REMOVER DUPLICATAS
       - Deletar os itens extras
       - Manter apenas o primeiro ou o mais recente' as "Explicação";

-- =====================================================
-- SOLUÇÃO: CONSOLIDAR ITENS DUPLICADOS
-- =====================================================

SELECT 
    '🔧 SOLUÇÃO: Consolidar itens duplicados' as "AÇÃO";

-- ⚠️  DESCOMENTE PARA EXECUTAR:
/*
BEGIN;

-- Para o produto IGN-0010 especificamente:
-- (Ajuste para outros produtos se necessário)

-- 1. Encontrar itens duplicados
WITH itens_ign0010 AS (
    SELECT 
        pi.id,
        pi.produto_id,
        pi.sabor_id,
        pi.quantidade,
        pi.valor_unitario,
        pi.subtotal,
        ROW_NUMBER() OVER (
            PARTITION BY pi.produto_id, pi.sabor_id 
            ORDER BY pi.created_at
        ) as rn
    FROM pedido_itens pi
    INNER JOIN produtos p ON p.id = pi.produto_id
    WHERE pi.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
    AND p.codigo = 'IGN-0010'
),
primeiro_item AS (
    SELECT * FROM itens_ign0010 WHERE rn = 1
),
soma_quantidades AS (
    SELECT 
        produto_id,
        sabor_id,
        SUM(quantidade) as quantidade_total,
        SUM(subtotal) as subtotal_total
    FROM itens_ign0010
    GROUP BY produto_id, sabor_id
)
-- Atualizar o primeiro item com a soma de todas as quantidades
UPDATE pedido_itens pi
SET 
    quantidade = sq.quantidade_total,
    subtotal = sq.subtotal_total
FROM primeiro_item pr
INNER JOIN soma_quantidades sq 
    ON sq.produto_id = pr.produto_id 
    AND COALESCE(sq.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID) = 
        COALESCE(pr.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
WHERE pi.id = pr.id;

-- 2. Remover itens duplicados (mantém apenas o primeiro)
WITH itens_para_remover AS (
    SELECT pi.id
    FROM pedido_itens pi
    INNER JOIN produtos p ON p.id = pi.produto_id
    INNER JOIN (
        SELECT 
            pi2.produto_id,
            pi2.sabor_id,
            MIN(pi2.created_at) as primeira_criacao
        FROM pedido_itens pi2
        INNER JOIN produtos p2 ON p2.id = pi2.produto_id
        WHERE pi2.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
        AND p2.codigo = 'IGN-0010'
        GROUP BY pi2.produto_id, pi2.sabor_id
    ) primeiro ON primeiro.produto_id = pi.produto_id 
        AND COALESCE(primeiro.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID) = 
            COALESCE(pi.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
    WHERE pi.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
    AND p.codigo = 'IGN-0010'
    AND pi.created_at > primeiro.primeira_criacao
)
DELETE FROM pedido_itens
WHERE id IN (SELECT id FROM itens_para_remover);

-- 3. Recalcular total do pedido
UPDATE pedidos
SET total = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM pedido_itens
    WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
)
WHERE numero = 'VENDA-20260114-00005';

SELECT 
    'Itens consolidados! Agora você pode finalizar a venda.' as "RESULTADO";

-- IMPORTANTE: 
-- Se der tudo certo, execute: COMMIT;
-- Se algo der errado, execute: ROLLBACK;
*/

-- =====================================================
-- SOLUÇÃO ALTERNATIVA: Consolidar TODOS os itens duplicados
-- =====================================================

SELECT 
    '🔧 SOLUÇÃO ALTERNATIVA: Consolidar TODOS os itens duplicados da venda' as "AÇÃO";

-- ⚠️  DESCOMENTE PARA EXECUTAR (consolida TODOS os produtos, não só IGN-0010):
/*
BEGIN;

-- 1. Para cada produto/sabor duplicado, somar quantidades no primeiro item
WITH itens_numerados AS (
    SELECT 
        pi.id,
        pi.pedido_id,
        pi.produto_id,
        pi.sabor_id,
        pi.quantidade,
        pi.valor_unitario,
        pi.subtotal,
        ROW_NUMBER() OVER (
            PARTITION BY pi.pedido_id, pi.produto_id, pi.sabor_id 
            ORDER BY pi.created_at
        ) as rn
    FROM pedido_itens pi
    WHERE pi.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
),
primeiro_de_cada AS (
    SELECT * FROM itens_numerados WHERE rn = 1
),
soma_por_produto AS (
    SELECT 
        pedido_id,
        produto_id,
        sabor_id,
        SUM(quantidade) as quantidade_total,
        SUM(subtotal) as subtotal_total
    FROM itens_numerados
    GROUP BY pedido_id, produto_id, sabor_id
)
UPDATE pedido_itens pi
SET 
    quantidade = sp.quantidade_total,
    subtotal = sp.subtotal_total
FROM primeiro_de_cada pr
INNER JOIN soma_por_produto sp 
    ON sp.pedido_id = pr.pedido_id
    AND sp.produto_id = pr.produto_id 
    AND COALESCE(sp.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID) = 
        COALESCE(pr.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
WHERE pi.id = pr.id;

-- 2. Remover todos os itens duplicados (mantém apenas o primeiro de cada)
WITH itens_para_remover AS (
    SELECT id
    FROM pedido_itens pi
    WHERE pi.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
    AND pi.id NOT IN (
        SELECT MIN(pi2.id)
        FROM pedido_itens pi2
        WHERE pi2.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
        GROUP BY pi2.produto_id, pi2.sabor_id
    )
)
DELETE FROM pedido_itens
WHERE id IN (SELECT id FROM itens_para_remover);

-- 3. Recalcular total do pedido
UPDATE pedidos
SET total = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM pedido_itens
    WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
)
WHERE numero = 'VENDA-20260114-00005';

SELECT 
    'TODOS os itens duplicados foram consolidados!' as "RESULTADO";

-- IMPORTANTE: 
-- Se der tudo certo, execute: COMMIT;
-- Se algo der errado, execute: ROLLBACK;
*/

-- =====================================================
-- VERIFICAÇÃO FINAL
-- =====================================================

SELECT 
    '📊 VERIFICAÇÃO APÓS CONSOLIDAÇÃO' as "FINAL";

-- Verificar se ainda há itens duplicados
WITH verificacao AS (
    SELECT 
        pi.produto_id,
        pi.sabor_id,
        COUNT(*) as vezes
    FROM pedido_itens pi
    WHERE pi.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
    GROUP BY pi.produto_id, pi.sabor_id
    HAVING COUNT(*) > 1
)
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ Nenhum item duplicado encontrado!'
        ELSE '⚠️  Ainda existem ' || COUNT(*) || ' produtos duplicados'
    END as "Status"
FROM verificacao;

-- Total de itens após consolidação
SELECT 
    COUNT(*) as "Total de Itens",
    SUM(quantidade) as "Quantidade Total",
    SUM(subtotal) as "Valor Total"
FROM pedido_itens
WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005');

-- Total do pedido
SELECT 
    numero as "Número",
    status as "Status",
    total as "Total do Pedido"
FROM pedidos
WHERE numero = 'VENDA-20260114-00005';
