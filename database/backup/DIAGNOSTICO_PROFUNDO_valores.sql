-- =====================================================
-- DIAGNÓSTICO PROFUNDO: ESTOQUE + VALORES MONETÁRIOS
-- =====================================================
-- Este script analisa tanto estoque físico quanto valores
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║     🔍 DIAGNÓSTICO PROFUNDO DO SISTEMA                    ║
╚═══════════════════════════════════════════════════════════╝
' as "INÍCIO";

-- =====================================================
-- 1. PRODUTOS COM ESTOQUE NEGATIVO
-- =====================================================

SELECT '📊 1. PRODUTOS COM ESTOQUE NEGATIVO' as "ANÁLISE";

SELECT 
    codigo,
    nome,
    estoque_atual,
    preco_compra,
    preco_venda,
    (estoque_atual * preco_compra) as "Valor Total Compra",
    (estoque_atual * preco_venda) as "Valor Total Venda"
FROM produtos
WHERE estoque_atual < 0 AND active = true
ORDER BY estoque_atual;

-- =====================================================
-- 2. PRODUTOS COM PREÇOS ZERADOS OU NEGATIVOS
-- =====================================================

SELECT '💰 2. PRODUTOS COM PREÇOS PROBLEMÁTICOS' as "ANÁLISE";

SELECT 
    codigo,
    nome,
    estoque_atual,
    preco_compra,
    preco_venda,
    CASE 
        WHEN preco_compra <= 0 THEN '❌ Preço de compra inválido'
        WHEN preco_venda <= 0 THEN '❌ Preço de venda inválido'
        WHEN preco_venda < preco_compra THEN '⚠️ Venda menor que compra'
        ELSE '✅ OK'
    END as "Status"
FROM produtos
WHERE active = true
  AND (preco_compra <= 0 OR preco_venda <= 0 OR preco_venda < preco_compra)
ORDER BY codigo;

-- =====================================================
-- 3. ANÁLISE DE MOVIMENTAÇÕES POR TIPO
-- =====================================================

SELECT '📦 3. MOVIMENTAÇÕES - VISÃO GERAL' as "ANÁLISE";

SELECT 
    tipo,
    COUNT(*) as "Total Movimentações",
    ROUND(SUM(quantidade)::numeric, 2) as "Quantidade Total",
    COUNT(DISTINCT produto_id) as "Produtos Afetados",
    COUNT(DISTINCT pedido_id) as "Pedidos Relacionados"
FROM estoque_movimentacoes
GROUP BY tipo
ORDER BY tipo;

-- =====================================================
-- 4. MOVIMENTAÇÕES SEM PEDIDO (Ajustes Manuais)
-- =====================================================

SELECT '🔧 4. MOVIMENTAÇÕES MANUAIS (SEM PEDIDO)' as "ANÁLISE";

SELECT 
    p.codigo,
    p.nome,
    em.tipo,
    em.quantidade,
    em.observacao,
    em.created_at,
    u.full_name as "Usuário"
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
LEFT JOIN users u ON em.usuario_id = u.id
WHERE em.pedido_id IS NULL
ORDER BY em.created_at DESC
LIMIT 20;

-- =====================================================
-- 5. VERIFICAR ESTOQUE CALCULADO vs REGISTRADO
-- =====================================================

SELECT '🔍 5. COMPARAÇÃO ESTOQUE CALCULADO vs REGISTRADO' as "ANÁLISE";

WITH estoque_calculado AS (
    SELECT 
        p.id,
        p.codigo,
        p.nome,
        p.estoque_atual as registrado,
        p.preco_compra,
        p.preco_venda,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as calculado,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as total_entradas,
        COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as total_saidas
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome, p.estoque_atual, p.preco_compra, p.preco_venda
)
SELECT 
    codigo,
    nome,
    registrado as "Estoque Registrado",
    calculado as "Estoque Calculado",
    (calculado - registrado) as "Diferença",
    total_entradas as "Total Entradas",
    total_saidas as "Total Saídas",
    preco_compra as "Preço Compra",
    preco_venda as "Preço Venda",
    (registrado * preco_compra) as "Valor Compra Registrado",
    (calculado * preco_compra) as "Valor Compra Calculado"
FROM estoque_calculado
WHERE ABS(calculado - registrado) > 0.01
ORDER BY ABS(calculado - registrado) DESC;

-- =====================================================
-- 6. ANÁLISE DOS VALORES TOTAIS
-- =====================================================

SELECT '💰 6. VALORES TOTAIS DO ESTOQUE' as "ANÁLISE";

SELECT 
    COUNT(*) as "Total de Produtos",
    ROUND(SUM(estoque_atual)::numeric, 2) as "Estoque Total (Unidades)",
    ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as "Valor Total Compra",
    ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as "Valor Total Venda",
    ROUND(SUM(estoque_atual * (preco_venda - preco_compra))::numeric, 2) as "Margem Potencial",
    CASE 
        WHEN SUM(estoque_atual * preco_compra) < 0 THEN '❌ VALOR DE COMPRA NEGATIVO!'
        WHEN SUM(estoque_atual * preco_venda) < 0 THEN '❌ VALOR DE VENDA NEGATIVO!'
        ELSE '✅ Valores Positivos'
    END as "Status"
FROM produtos
WHERE active = true;

-- =====================================================
-- 7. PRODUTOS QUE CAUSAM VALORES NEGATIVOS
-- =====================================================

SELECT '⚠️ 7. PRODUTOS QUE TORNAM OS VALORES NEGATIVOS' as "ANÁLISE";

SELECT 
    codigo,
    nome,
    estoque_atual,
    preco_compra,
    preco_venda,
    ROUND((estoque_atual * preco_compra)::numeric, 2) as "Contribuição Valor Compra",
    ROUND((estoque_atual * preco_venda)::numeric, 2) as "Contribuição Valor Venda",
    CASE 
        WHEN estoque_atual < 0 THEN '❌ Estoque Negativo'
        WHEN preco_compra <= 0 THEN '❌ Preço Compra Inválido'
        WHEN preco_venda <= 0 THEN '❌ Preço Venda Inválido'
        ELSE '⚠️ Outros'
    END as "Problema"
FROM produtos
WHERE active = true
  AND ((estoque_atual * preco_compra) < 0 OR (estoque_atual * preco_venda) < 0)
ORDER BY (estoque_atual * preco_compra);

-- =====================================================
-- 8. HISTÓRICO DE MOVIMENTAÇÕES DOS PRODUTOS NEGATIVOS
-- =====================================================

SELECT '📋 8. HISTÓRICO DOS PRODUTOS COM ESTOQUE NEGATIVO' as "ANÁLISE";

SELECT 
    p.codigo,
    p.nome,
    em.tipo,
    em.quantidade,
    em.estoque_anterior,
    em.estoque_novo,
    em.observacao,
    em.created_at,
    ped.numero as "Pedido",
    u.full_name as "Usuário"
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
LEFT JOIN pedidos ped ON em.pedido_id = ped.id
LEFT JOIN users u ON em.usuario_id = u.id
WHERE p.id IN (
    SELECT id FROM produtos WHERE estoque_atual < 0 AND active = true
)
ORDER BY p.codigo, em.created_at DESC
LIMIT 50;

-- =====================================================
-- 9. RESUMO DE PROBLEMAS ENCONTRADOS
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            📊 RESUMO DE PROBLEMAS ENCONTRADOS             ║
╚═══════════════════════════════════════════════════════════╝
' as "RESUMO";

WITH problemas AS (
    SELECT 
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as prod_negativos,
        COUNT(CASE WHEN preco_compra <= 0 THEN 1 END) as preco_compra_invalido,
        COUNT(CASE WHEN preco_venda <= 0 THEN 1 END) as preco_venda_invalido,
        COUNT(CASE WHEN preco_venda < preco_compra THEN 1 END) as venda_menor_compra,
        SUM(estoque_atual * preco_compra) as valor_compra_total,
        SUM(estoque_atual * preco_venda) as valor_venda_total
    FROM produtos
    WHERE active = true
)
SELECT 
    prod_negativos as "❌ Produtos com Estoque Negativo",
    preco_compra_invalido as "❌ Produtos com Preço Compra ≤ 0",
    preco_venda_invalido as "❌ Produtos com Preço Venda ≤ 0",
    venda_menor_compra as "⚠️ Produtos com Venda < Compra",
    ROUND(valor_compra_total::numeric, 2) as "💰 Valor Total Compra",
    ROUND(valor_venda_total::numeric, 2) as "💰 Valor Total Venda",
    CASE 
        WHEN valor_compra_total < 0 OR valor_venda_total < 0 
        THEN '❌ VALORES NEGATIVOS - REQUER CORREÇÃO'
        ELSE '✅ Valores OK'
    END as "Status Geral"
FROM problemas;

-- =====================================================
-- 10. RECOMENDAÇÕES
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║                  💡 RECOMENDAÇÕES                         ║
╚═══════════════════════════════════════════════════════════╝

Baseado nos problemas encontrados:

1️⃣ Se há PRODUTOS COM ESTOQUE NEGATIVO:
   → Execute: CORRIGIR_estoque_e_valores.sql
   
2️⃣ Se há PREÇOS ZERADOS OU NEGATIVOS:
   → Corrija os preços manualmente no sistema
   → Depois execute: RECALCULAR_valores_totais.sql

3️⃣ Se há MOVIMENTAÇÕES DUPLICADAS:
   → Já foram removidas no reprocessamento
   → Execute COMMIT se não fez ainda

4️⃣ Se VALORES TOTAIS estão NEGATIVOS:
   → Problema: Estoque negativo × Preço = Valor negativo
   → Solução: Corrigir o estoque primeiro (item 1)

═══════════════════════════════════════════════════════════
' as "PRÓXIMOS PASSOS";
