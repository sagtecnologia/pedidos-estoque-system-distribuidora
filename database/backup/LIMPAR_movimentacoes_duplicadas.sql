-- =====================================================
-- LIMPAR MOVIMENTAÇÕES DUPLICADAS E INCORRETAS
-- =====================================================
-- Remove movimentações duplicadas e mantém apenas:
-- - ENTRADA para pedidos de COMPRA
-- - SAÍDA para pedidos de VENDA
-- =====================================================

BEGIN;

SELECT '
╔═══════════════════════════════════════════════════════════╗
║     🧹 LIMPEZA DE MOVIMENTAÇÕES DUPLICADAS                ║
╚═══════════════════════════════════════════════════════════╝
' as "INÍCIO";

-- =====================================================
-- ETAPA 1: DIAGNÓSTICO ANTES DA LIMPEZA
-- =====================================================

SELECT '📊 DIAGNÓSTICO ANTES DA LIMPEZA' as "ANÁLISE";

WITH valores_antes AS (
    SELECT 
        COUNT(*) as total_produtos,
        ROUND(SUM(estoque_atual)::numeric, 2) as estoque_total,
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda,
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as negativos
    FROM produtos
    WHERE active = true
)
SELECT 
    total_produtos as "Total Produtos",
    negativos as "Produtos Negativos",
    estoque_total as "Estoque Total (UN)",
    valor_compra as "Valor Compra (R$)",
    valor_venda as "Valor Venda (R$)"
FROM valores_antes;

-- =====================================================
-- ETAPA 2: IDENTIFICAR MOVIMENTAÇÕES PROBLEMÁTICAS
-- =====================================================

SELECT '🔍 MOVIMENTAÇÕES COM TIPO ERRADO' as "ANÁLISE";

-- Pedidos de COMPRA que geraram SAÍDA (ERRADO!)
SELECT 
    'COMPRA gerando SAÍDA (ERRADO!)' as "Problema",
    COUNT(*) as "Quantidade",
    ROUND(SUM(quantidade)::numeric, 2) as "Total Unidades"
FROM estoque_movimentacoes
WHERE observacao ILIKE '%pedido compra%'
  AND tipo = 'SAIDA';

-- Pedidos de VENDA que geraram ENTRADA (ERRADO!)
SELECT 
    'VENDA gerando ENTRADA (ERRADO!)' as "Problema",
    COUNT(*) as "Quantidade",
    ROUND(SUM(quantidade)::numeric, 2) as "Total Unidades"
FROM estoque_movimentacoes
WHERE observacao ILIKE '%pedido venda%'
  AND tipo = 'ENTRADA';

SELECT '🔍 MOVIMENTAÇÕES DUPLICADAS' as "ANÁLISE";

WITH duplicadas AS (
    SELECT 
        produto_id,
        pedido_id,
        tipo,
        quantidade,
        DATE(created_at) as data,
        COUNT(*) as total_duplicadas,
        ARRAY_AGG(id ORDER BY created_at) as ids
    FROM estoque_movimentacoes
    WHERE pedido_id IS NOT NULL
    GROUP BY produto_id, pedido_id, tipo, quantidade, DATE(created_at)
    HAVING COUNT(*) > 1
)
SELECT 
    COUNT(*) as "Grupos Duplicados",
    SUM(total_duplicadas) as "Total Movimentações Duplicadas",
    SUM(total_duplicadas - 1) as "Movimentações a Remover"
FROM duplicadas;

-- =====================================================
-- ETAPA 3: BACKUP DAS MOVIMENTAÇÕES
-- =====================================================

SELECT '💾 CRIANDO BACKUP' as "STATUS";

DROP TABLE IF EXISTS backup_movimentacoes_limpeza;

CREATE TEMP TABLE backup_movimentacoes_limpeza AS
SELECT * FROM estoque_movimentacoes;

SELECT COUNT(*) as "Movimentações Salvadas" 
FROM backup_movimentacoes_limpeza;

-- =====================================================
-- ETAPA 4: REMOVER MOVIMENTAÇÕES COM TIPO ERRADO
-- =====================================================

SELECT '🧹 REMOVENDO MOVIMENTAÇÕES COM TIPO ERRADO' as "STATUS";

-- Remover COMPRAS que geraram SAÍDA (errado!)
WITH removidas AS (
    DELETE FROM estoque_movimentacoes
    WHERE observacao ILIKE '%pedido compra%'
      AND tipo = 'SAIDA'
    RETURNING id
)
SELECT 
    'COMPRA → SAÍDA removidas' as "Tipo",
    COUNT(*) as "Quantidade Removida"
FROM removidas;

-- Remover VENDAS que geraram ENTRADA (errado!)
WITH removidas AS (
    DELETE FROM estoque_movimentacoes
    WHERE observacao ILIKE '%pedido venda%'
      AND tipo = 'ENTRADA'
    RETURNING id
)
SELECT 
    'VENDA → ENTRADA removidas' as "Tipo",
    COUNT(*) as "Quantidade Removida"
FROM removidas;

-- =====================================================
-- ETAPA 5: REMOVER DUPLICADAS (manter apenas a primeira)
-- =====================================================

SELECT '🧹 REMOVENDO DUPLICADAS' as "STATUS";

WITH duplicadas AS (
    SELECT 
        id,
        ROW_NUMBER() OVER (
            PARTITION BY produto_id, pedido_id, tipo, quantidade, DATE(created_at)
            ORDER BY created_at, id
        ) as rn
    FROM estoque_movimentacoes
    WHERE pedido_id IS NOT NULL
),
removidas AS (
    DELETE FROM estoque_movimentacoes
    WHERE id IN (
        SELECT id FROM duplicadas WHERE rn > 1
    )
    RETURNING id
)
SELECT 
    'Duplicadas removidas' as "Tipo",
    COUNT(*) as "Quantidade Removida"
FROM removidas;

-- =====================================================
-- ETAPA 6: REMOVER MOVIMENTAÇÕES SEM PEDIDO ASSOCIADO
-- =====================================================

SELECT '🧹 REMOVENDO MOVIMENTAÇÕES SEM PEDIDO' as "STATUS";

WITH removidas AS (
    DELETE FROM estoque_movimentacoes
    WHERE pedido_id IS NULL
      AND observacao NOT ILIKE '%ajuste%'
      AND observacao NOT ILIKE '%inventário%'
      AND observacao NOT ILIKE '%inicial%'
    RETURNING id
)
SELECT 
    'Movimentações órfãs removidas' as "Tipo",
    COUNT(*) as "Quantidade Removida"
FROM removidas;

-- =====================================================
-- ETAPA 7: REPROCESSAR ESTOQUE APÓS LIMPEZA
-- =====================================================

SELECT '🔄 REPROCESSANDO ESTOQUE' as "STATUS";

-- Zerar estoque
UPDATE produtos
SET estoque_atual = 0
WHERE active = true;

-- Recalcular baseado nas movimentações limpas
WITH estoque_limpo AS (
    SELECT 
        produto_id,
        SUM(CASE WHEN tipo = 'ENTRADA' THEN quantidade ELSE -quantidade END) as estoque_calculado
    FROM estoque_movimentacoes
    GROUP BY produto_id
)
UPDATE produtos p
SET estoque_atual = el.estoque_calculado,
    updated_at = NOW()
FROM estoque_limpo el
WHERE p.id = el.produto_id;

-- =====================================================
-- ETAPA 8: RECALCULAR estoque_anterior e estoque_novo
-- =====================================================

SELECT '🔄 RECALCULANDO HISTÓRICO' as "STATUS";

WITH movimentacoes_ordenadas AS (
    SELECT 
        em.id,
        em.produto_id,
        em.tipo,
        em.quantidade,
        ROW_NUMBER() OVER (PARTITION BY em.produto_id ORDER BY em.created_at, em.id) as ordem
    FROM estoque_movimentacoes em
),
cardex AS (
    SELECT 
        mo.id,
        mo.produto_id,
        -- Estoque anterior = soma de todas movimentações anteriores
        COALESCE(
            (SELECT SUM(CASE WHEN mo2.tipo = 'ENTRADA' THEN mo2.quantidade ELSE -mo2.quantidade END)
             FROM movimentacoes_ordenadas mo2
             WHERE mo2.produto_id = mo.produto_id
               AND mo2.ordem < mo.ordem
            ), 0
        ) as estoque_anterior,
        -- Estoque novo = estoque anterior + movimentação atual
        COALESCE(
            (SELECT SUM(CASE WHEN mo2.tipo = 'ENTRADA' THEN mo2.quantidade ELSE -mo2.quantidade END)
             FROM movimentacoes_ordenadas mo2
             WHERE mo2.produto_id = mo.produto_id
               AND mo2.ordem <= mo.ordem
            ), 0
        ) as estoque_novo
    FROM movimentacoes_ordenadas mo
)
UPDATE estoque_movimentacoes em
SET 
    estoque_anterior = c.estoque_anterior,
    estoque_novo = c.estoque_novo
FROM cardex c
WHERE em.id = c.id;

-- =====================================================
-- ETAPA 9: RELATÓRIO APÓS LIMPEZA
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            📊 RELATÓRIO APÓS LIMPEZA                      ║
╚═══════════════════════════════════════════════════════════╝
' as "RELATÓRIO";

SELECT '📋 COMPARAÇÃO: ANTES x DEPOIS' as "ANÁLISE";

WITH antes AS (
    SELECT 
        COUNT(*) as total_movimentacoes,
        ROUND(SUM(CASE WHEN tipo = 'ENTRADA' THEN quantidade ELSE 0 END)::numeric, 2) as total_entradas,
        ROUND(SUM(CASE WHEN tipo = 'SAIDA' THEN quantidade ELSE 0 END)::numeric, 2) as total_saidas
    FROM backup_movimentacoes_limpeza
),
depois AS (
    SELECT 
        COUNT(*) as total_movimentacoes,
        ROUND(SUM(CASE WHEN tipo = 'ENTRADA' THEN quantidade ELSE 0 END)::numeric, 2) as total_entradas,
        ROUND(SUM(CASE WHEN tipo = 'SAIDA' THEN quantidade ELSE 0 END)::numeric, 2) as total_saidas
    FROM estoque_movimentacoes
)
SELECT 
    'ANTES' as "Momento",
    a.total_movimentacoes as "Total Movimentações",
    a.total_entradas as "Total Entradas",
    a.total_saidas as "Total Saídas"
FROM antes a
UNION ALL
SELECT 
    'DEPOIS' as "Momento",
    d.total_movimentacoes as "Total Movimentações",
    d.total_entradas as "Total Entradas",
    d.total_saidas as "Total Saídas"
FROM depois d;

SELECT '💰 VALORES APÓS LIMPEZA' as "ANÁLISE";

WITH valores_depois AS (
    SELECT 
        COUNT(*) as total_produtos,
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as negativos,
        COUNT(CASE WHEN estoque_atual = 0 THEN 1 END) as zerados,
        COUNT(CASE WHEN estoque_atual > 0 THEN 1 END) as positivos,
        ROUND(SUM(estoque_atual)::numeric, 2) as estoque_total,
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda,
        ROUND(SUM(estoque_atual * (preco_venda - preco_compra))::numeric, 2) as margem
    FROM produtos
    WHERE active = true
)
SELECT 
    total_produtos as "Total Produtos",
    positivos as "✅ Positivos",
    zerados as "⚪ Zerados",
    negativos as "❌ Negativos",
    estoque_total as "Estoque Total (UN)",
    valor_compra as "Valor Compra (R$)",
    valor_venda as "Valor Venda (R$)",
    margem as "Margem Lucro (R$)",
    CASE 
        WHEN valor_venda > 0 THEN ROUND((margem / valor_venda * 100)::numeric, 2)
        ELSE 0
    END as "Margem (%)"
FROM valores_depois;

SELECT '✅ MOVIMENTAÇÕES POR TIPO DE PEDIDO' as "ANÁLISE";

SELECT 
    CASE 
        WHEN observacao ILIKE '%pedido compra%' THEN 'COMPRA'
        WHEN observacao ILIKE '%pedido venda%' THEN 'VENDA'
        ELSE 'OUTROS'
    END as "Tipo Pedido",
    tipo as "Tipo Movimentação",
    COUNT(*) as "Quantidade",
    ROUND(SUM(quantidade)::numeric, 2) as "Total Unidades"
FROM estoque_movimentacoes
WHERE pedido_id IS NOT NULL
GROUP BY 
    CASE 
        WHEN observacao ILIKE '%pedido compra%' THEN 'COMPRA'
        WHEN observacao ILIKE '%pedido venda%' THEN 'VENDA'
        ELSE 'OUTROS'
    END,
    tipo
ORDER BY 1, 2;

-- =====================================================
-- VERIFICAÇÃO FINAL
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            ✅ VERIFICAÇÃO FINAL                           ║
╚═══════════════════════════════════════════════════════════╝
' as "VERIFICAÇÃO";

WITH verificacao AS (
    SELECT 
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as tem_negativos,
        SUM(estoque_atual * preco_compra) as valor_compra_total,
        SUM(estoque_atual * preco_venda) as valor_venda_total,
        -- Verificar se ainda há movimentações com tipo errado
        (SELECT COUNT(*) FROM estoque_movimentacoes
         WHERE (observacao ILIKE '%pedido compra%' AND tipo = 'SAIDA')
            OR (observacao ILIKE '%pedido venda%' AND tipo = 'ENTRADA')
        ) as movimentacoes_erradas
    FROM produtos
    WHERE active = true
)
SELECT 
    CASE 
        WHEN tem_negativos = 0 AND valor_compra_total >= 0 AND valor_venda_total >= 0 AND movimentacoes_erradas = 0
        THEN '✅ LIMPEZA BEM SUCEDIDA!'
        WHEN tem_negativos > 0 
        THEN '⚠️ Ainda há ' || tem_negativos || ' produto(s) com estoque negativo'
        WHEN valor_compra_total < 0 OR valor_venda_total < 0
        THEN '⚠️ Valores monetários ainda estão negativos'
        WHEN movimentacoes_erradas > 0
        THEN '⚠️ Ainda há ' || movimentacoes_erradas || ' movimentações com tipo errado'
        ELSE '✅ Verificação OK'
    END as "Status Final",
    tem_negativos as "Produtos Negativos",
    ROUND(valor_compra_total::numeric, 2) as "Valor Total Compra (R$)",
    ROUND(valor_venda_total::numeric, 2) as "Valor Total Venda (R$)",
    movimentacoes_erradas as "Movimentações Erradas"
FROM verificacao;

-- =====================================================
-- DECISÃO
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            ⚠️ DECISÃO                                     ║
╚═══════════════════════════════════════════════════════════╝

Revise os relatórios acima.

✅ Se a limpeza foi BEM SUCEDIDA:
   Digite: COMMIT;

❌ Se ainda há problemas:
   Digite: ROLLBACK;

╚═══════════════════════════════════════════════════════════╝
' as "DECISÃO";
