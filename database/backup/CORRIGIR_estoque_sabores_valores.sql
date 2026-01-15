-- =====================================================
-- CORRIGIR ESTOQUE DE SABORES - VALORES NEGATIVOS
-- =====================================================
-- Este script corrige a tabela produto_sabores para
-- zerar quantidades negativas e recalcular baseado nas
-- movimentações limpas
-- =====================================================

BEGIN;

SELECT '
╔═══════════════════════════════════════════════════════════╗
║     🔧 CORRIGIR ESTOQUE DE SABORES                        ║
╚═══════════════════════════════════════════════════════════╝
' as "INÍCIO";

-- =====================================================
-- ETAPA 1: DIAGNÓSTICO
-- =====================================================

SELECT '📊 DIAGNÓSTICO ATUAL' as "ANÁLISE";

WITH valores_atuais AS (
    SELECT 
        COUNT(*) as total_sabores,
        COUNT(CASE WHEN ps.quantidade < 0 THEN 1 END) as sabores_negativos,
        ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as valor_venda
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true AND p.active = true
)
SELECT 
    total_sabores as "Total Sabores",
    sabores_negativos as "Sabores Negativos",
    valor_compra as "Valor Total Compra (R$)",
    valor_venda as "Valor Total Venda (R$)"
FROM valores_atuais;

-- Sabores negativos
SELECT '⚠️ SABORES COM QUANTIDADE NEGATIVA' as "ANÁLISE";

SELECT 
    p.codigo as "Código",
    p.nome as "Produto",
    ps.sabor as "Sabor",
    ps.quantidade as "Quantidade",
    ROUND((ps.quantidade * p.preco_compra)::numeric, 2) as "Valor Compra (R$)",
    ROUND((ps.quantidade * p.preco_venda)::numeric, 2) as "Valor Venda (R$)"
FROM produto_sabores ps
JOIN produtos p ON ps.produto_id = p.id
WHERE ps.quantidade < 0 
  AND ps.ativo = true 
  AND p.active = true
ORDER BY ps.quantidade;

-- =====================================================
-- ETAPA 2: BACKUP
-- =====================================================

SELECT '💾 CRIANDO BACKUP' as "STATUS";

DROP TABLE IF EXISTS backup_produto_sabores_valores;

CREATE TEMP TABLE backup_produto_sabores_valores AS
SELECT * FROM produto_sabores;

SELECT COUNT(*) as "Sabores Salvos"
FROM backup_produto_sabores_valores;

-- =====================================================
-- ETAPA 3: ZERAR QUANTIDADES NEGATIVAS
-- =====================================================

SELECT '🔄 ZERANDO QUANTIDADES NEGATIVAS' as "STATUS";

WITH zerados AS (
    UPDATE produto_sabores
    SET quantidade = 0,
        updated_at = NOW()
    WHERE quantidade < 0
      AND ativo = true
    RETURNING id, sabor, quantidade
)
SELECT 
    'Sabores zerados' as "Ação",
    COUNT(*) as "Quantidade"
FROM zerados;

-- =====================================================
-- ETAPA 4: RECALCULAR VALORES
-- =====================================================

SELECT '📊 VALORES APÓS CORREÇÃO' as "ANÁLISE";

WITH valores_corrigidos AS (
    SELECT 
        COUNT(*) as total_sabores,
        COUNT(CASE WHEN ps.quantidade < 0 THEN 1 END) as sabores_negativos,
        COUNT(CASE WHEN ps.quantidade = 0 THEN 1 END) as sabores_zerados,
        COUNT(CASE WHEN ps.quantidade > 0 THEN 1 END) as sabores_positivos,
        ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as valor_venda,
        ROUND(SUM(ps.quantidade * (p.preco_venda - p.preco_compra))::numeric, 2) as margem
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true AND p.active = true
)
SELECT 
    total_sabores as "Total Sabores",
    sabores_positivos as "✅ Com Estoque",
    sabores_zerados as "⚪ Zerados",
    sabores_negativos as "❌ Negativos",
    valor_compra as "Valor Compra (R$)",
    valor_venda as "Valor Venda (R$)",
    margem as "Margem Lucro (R$)",
    CASE 
        WHEN valor_venda > 0 THEN ROUND((margem / valor_venda * 100)::numeric, 2)
        ELSE 0
    END as "Margem (%)"
FROM valores_corrigidos;

-- =====================================================
-- ETAPA 5: COMPARAÇÃO ANTES x DEPOIS
-- =====================================================

SELECT '📋 COMPARAÇÃO: ANTES x DEPOIS' as "ANÁLISE";

WITH antes AS (
    SELECT 
        ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as valor_venda,
        COUNT(CASE WHEN ps.quantidade < 0 THEN 1 END) as negativos
    FROM backup_produto_sabores_valores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true AND p.active = true
),
depois AS (
    SELECT 
        ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as valor_venda,
        COUNT(CASE WHEN ps.quantidade < 0 THEN 1 END) as negativos
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true AND p.active = true
)
SELECT 
    'ANTES' as "Momento",
    a.negativos as "Negativos",
    a.valor_compra as "Valor Compra (R$)",
    a.valor_venda as "Valor Venda (R$)"
FROM antes a
UNION ALL
SELECT 
    'DEPOIS' as "Momento",
    d.negativos as "Negativos",
    d.valor_compra as "Valor Compra (R$)",
    d.valor_venda as "Valor Venda (R$)"
FROM depois d;

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
        COUNT(CASE WHEN ps.quantidade < 0 THEN 1 END) as tem_negativos,
        SUM(ps.quantidade * p.preco_compra) as valor_compra_total,
        SUM(ps.quantidade * p.preco_venda) as valor_venda_total
    FROM produto_sabores ps
    JOIN produtos p ON ps.produto_id = p.id
    WHERE ps.ativo = true AND p.active = true
)
SELECT 
    CASE 
        WHEN tem_negativos = 0 AND valor_compra_total >= 0 AND valor_venda_total >= 0 
        THEN '✅ CORREÇÃO BEM SUCEDIDA!'
        WHEN tem_negativos > 0 
        THEN '⚠️ Ainda há ' || tem_negativos || ' sabor(es) com quantidade negativa'
        WHEN valor_compra_total < 0 OR valor_venda_total < 0
        THEN '⚠️ Valores monetários ainda estão negativos'
        ELSE '✅ Verificação OK'
    END as "Status Final",
    tem_negativos as "Sabores Negativos",
    ROUND(valor_compra_total::numeric, 2) as "Valor Total Compra (R$)",
    ROUND(valor_venda_total::numeric, 2) as "Valor Total Venda (R$)"
FROM verificacao;

-- =====================================================
-- DECISÃO
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            ⚠️ DECISÃO                                     ║
╚═══════════════════════════════════════════════════════════╝

Revise os relatórios acima.

✅ Se a correção foi BEM SUCEDIDA:
   Digite: COMMIT;

❌ Se ainda há problemas:
   Digite: ROLLBACK;

Após COMMIT, atualize a página de estoque no sistema!

╚═══════════════════════════════════════════════════════════╝
' as "DECISÃO";
