-- =====================================================
-- CORREÇÃO COMPLETA: ESTOQUE + VALORES MONETÁRIOS
-- =====================================================
-- Este script corrige tanto o estoque físico quanto
-- recalcula os valores monetários
-- =====================================================
-- ⚠️ IMPORTANTE: Execute DIAGNOSTICO_PROFUNDO_valores.sql primeiro
-- =====================================================

BEGIN;

-- =====================================================
-- ETAPA 1: BACKUP
-- =====================================================

DROP TABLE IF EXISTS backup_correcao_completa;

CREATE TEMP TABLE backup_correcao_completa AS
SELECT 
    id,
    codigo,
    nome,
    estoque_atual,
    preco_compra,
    preco_venda,
    NOW() as backup_data
FROM produtos;

SELECT '✅ ETAPA 1: Backup criado' as "STATUS";

-- =====================================================
-- ETAPA 2: ZERAR ESTOQUE DE PRODUTOS NEGATIVOS
-- =====================================================

SELECT '🔄 ETAPA 2: Zerando estoque de produtos negativos...' as "STATUS";

-- Mostrar produtos que serão zerados
SELECT 
    codigo,
    nome,
    estoque_atual as "Estoque Atual (Negativo)",
    'SERÁ ZERADO' as "Ação"
FROM produtos
WHERE estoque_atual < 0 AND active = true;

-- Zerar produtos negativos
UPDATE produtos
SET estoque_atual = 0,
    updated_at = NOW()
WHERE estoque_atual < 0 AND active = true;

SELECT '✅ ETAPA 2: Produtos negativos zerados' as "STATUS";

-- =====================================================
-- ETAPA 3: RECALCULAR ESTOQUE BASEADO NAS MOVIMENTAÇÕES
-- =====================================================

SELECT '🔄 ETAPA 3: Recalculando estoque de todos os produtos...' as "STATUS";

DROP TABLE IF EXISTS estoque_recalculado;

CREATE TEMP TABLE estoque_recalculado AS
SELECT 
    p.id as produto_id,
    p.codigo,
    p.nome,
    p.estoque_atual as estoque_atual_sistema,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado_movimentacoes,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as total_entradas,
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as total_saidas,
    p.preco_compra,
    p.preco_venda
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.active = true
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual, p.preco_compra, p.preco_venda;

-- Mostrar diferenças
SELECT 
    codigo,
    nome,
    estoque_atual_sistema as "Estoque Sistema",
    estoque_calculado_movimentacoes as "Estoque Calculado",
    (estoque_calculado_movimentacoes - estoque_atual_sistema) as "Diferença",
    CASE 
        WHEN estoque_calculado_movimentacoes < 0 THEN '❌ CALCULADO É NEGATIVO'
        WHEN estoque_calculado_movimentacoes = 0 THEN '⚠️ SEM MOVIMENTAÇÕES'
        ELSE '✅ POSITIVO'
    END as "Status",
    total_entradas,
    total_saidas
FROM estoque_recalculado
WHERE ABS(estoque_calculado_movimentacoes - estoque_atual_sistema) > 0.01
ORDER BY ABS(estoque_calculado_movimentacoes - estoque_atual_sistema) DESC;

-- =====================================================
-- ETAPA 4: DECISÃO DE CORREÇÃO
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            ⚠️ ANÁLISE DE CORREÇÃO                         ║
╚═══════════════════════════════════════════════════════════╝
' as "ANÁLISE";

-- Verificar se o estoque calculado é confiável
WITH analise AS (
    SELECT 
        COUNT(*) as total_produtos,
        COUNT(CASE WHEN estoque_calculado_movimentacoes < 0 THEN 1 END) as calculado_negativo,
        COUNT(CASE WHEN estoque_calculado_movimentacoes = 0 AND total_entradas = 0 AND total_saidas = 0 THEN 1 END) as sem_movimentacoes,
        COUNT(CASE WHEN estoque_calculado_movimentacoes > 0 THEN 1 END) as calculado_positivo
    FROM estoque_recalculado
)
SELECT 
    total_produtos as "Total de Produtos",
    calculado_positivo as "Estoque Calculado Positivo",
    calculado_negativo as "Estoque Calculado Negativo",
    sem_movimentacoes as "Sem Movimentações",
    CASE 
        WHEN calculado_negativo > (total_produtos * 0.3) THEN 
            '❌ MUITOS PRODUTOS NEGATIVOS - As movimentações estão erradas!'
        WHEN calculado_negativo > 0 THEN 
            '⚠️ Alguns produtos ficaram negativos - Verifique!'
        ELSE 
            '✅ Estoque calculado é confiável'
    END as "Diagnóstico"
FROM analise;

-- =====================================================
-- ETAPA 5: APLICAR CORREÇÃO (escolher uma opção)
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            🔧 ESCOLHA A CORREÇÃO                          ║
╚═══════════════════════════════════════════════════════════╝

OPÇÃO A: Aplicar Estoque Calculado (se confiável)
  → Usa as movimentações para calcular estoque correto
  → Substitui estoque negativo por calculado
  
OPÇÃO B: Zerar Produtos Negativos (se movimentações erradas)
  → Mantém produtos positivos
  → Zera apenas os negativos
  
OPÇÃO C: Manter Como Está
  → Não faz alterações
  → Use ROLLBACK

⚠️ VEJA O DIAGNÓSTICO ACIMA PARA DECIDIR!

' as "OPÇÕES";

-- =====================================================
-- OPÇÃO A: APLICAR ESTOQUE CALCULADO
-- =====================================================
/*
-- Descomente para aplicar estoque calculado

UPDATE produtos p
SET 
    estoque_atual = CASE 
        WHEN er.estoque_calculado_movimentacoes < 0 THEN 0
        ELSE er.estoque_calculado_movimentacoes
    END,
    updated_at = NOW()
FROM estoque_recalculado er
WHERE p.id = er.produto_id
  AND ABS(er.estoque_calculado_movimentacoes - er.estoque_atual_sistema) > 0.01;

SELECT 'OPÇÃO A APLICADA: Estoque atualizado com valores calculados' as "RESULTADO";
*/

-- =====================================================
-- OPÇÃO B: APENAS ZERAR NEGATIVOS (já foi feito na ETAPA 2)
-- =====================================================

SELECT 'OPÇÃO B: Produtos negativos já foram zerados na ETAPA 2' as "INFO";

-- =====================================================
-- ETAPA 6: RECALCULAR VALORES MONETÁRIOS
-- =====================================================

SELECT '💰 ETAPA 6: Calculando valores monetários...' as "STATUS";

WITH valores_atualizados AS (
    SELECT 
        COUNT(*) as total_produtos,
        ROUND(SUM(estoque_atual)::numeric, 2) as estoque_total_unidades,
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda,
        ROUND(SUM(estoque_atual * (preco_venda - preco_compra))::numeric, 2) as margem_lucro,
        CASE 
            WHEN SUM(estoque_atual * preco_venda) > 0 THEN
                ROUND((SUM(estoque_atual * (preco_venda - preco_compra)) / SUM(estoque_atual * preco_venda) * 100)::numeric, 2)
            ELSE 0
        END as margem_percentual
    FROM produtos
    WHERE active = true
)
SELECT 
    total_produtos as "Total de Produtos",
    estoque_total_unidades as "Estoque Total (UN)",
    valor_compra as "Valor Total Compra (R$)",
    valor_venda as "Valor Total Venda (R$)",
    margem_lucro as "Margem de Lucro (R$)",
    margem_percentual as "Margem (%)",
    CASE 
        WHEN valor_compra < 0 OR valor_venda < 0 THEN '❌ AINDA HÁ VALORES NEGATIVOS'
        ELSE '✅ VALORES CORRETOS'
    END as "Status"
FROM valores_atualizados;

-- =====================================================
-- ETAPA 7: VERIFICAÇÃO FINAL
-- =====================================================

SELECT '🔍 ETAPA 7: Verificação final...' as "STATUS";

-- Produtos que ainda estão negativos
SELECT 
    'Produtos ainda negativos:' as "VERIFICAÇÃO";

SELECT 
    codigo,
    nome,
    estoque_atual,
    preco_compra,
    preco_venda
FROM produtos
WHERE estoque_atual < 0 AND active = true;

-- Se nenhum produto for retornado, está OK

-- =====================================================
-- RELATÓRIO FINAL
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            📊 RELATÓRIO FINAL                             ║
╚═══════════════════════════════════════════════════════════╝
' as "RELATÓRIO";

WITH antes AS (
    SELECT 
        ROUND(SUM(b.estoque_atual * b.preco_compra)::numeric, 2) as valor_compra_antes,
        ROUND(SUM(b.estoque_atual * b.preco_venda)::numeric, 2) as valor_venda_antes
    FROM backup_correcao_completa b
),
depois AS (
    SELECT 
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra_depois,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda_depois,
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as produtos_negativos
    FROM produtos
    WHERE active = true
)
SELECT 
    a.valor_compra_antes as "Valor Compra ANTES",
    d.valor_compra_depois as "Valor Compra DEPOIS",
    (d.valor_compra_depois - a.valor_compra_antes) as "Diferença Compra",
    a.valor_venda_antes as "Valor Venda ANTES",
    d.valor_venda_depois as "Valor Venda DEPOIS",
    (d.valor_venda_depois - a.valor_venda_antes) as "Diferença Venda",
    d.produtos_negativos as "Produtos Ainda Negativos",
    CASE 
        WHEN d.produtos_negativos = 0 AND d.valor_compra_depois >= 0 AND d.valor_venda_depois >= 0
        THEN '✅ CORREÇÃO BEM SUCEDIDA'
        WHEN d.produtos_negativos > 0
        THEN '⚠️ Ainda há produtos negativos'
        ELSE '❌ Problema persiste'
    END as "Status Final"
FROM antes a, depois d;

-- =====================================================
-- DECISÃO FINAL
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            ⚠️ DECISÃO FINAL                               ║
╚═══════════════════════════════════════════════════════════╝

Revise o RELATÓRIO FINAL acima.

Se os valores agora estão POSITIVOS e não há produtos negativos:
    ✅ COMMIT;

Se ainda há problemas:
    ❌ ROLLBACK;
    
Depois execute: VALIDACAO_estoque.sql

╔═══════════════════════════════════════════════════════════╝
' as "DECISÃO";
