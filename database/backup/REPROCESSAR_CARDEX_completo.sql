-- =====================================================
-- REPROCESSAMENTO TIPO CARDEX - DO ZERO
-- =====================================================
-- Este script reprocessa TODAS as movimentações na ordem
-- cronológica, como um cardex tradicional, para recalcular
-- o estoque e valores corretamente
-- =====================================================
-- ⚠️ ATENÇÃO: Este script zera e reprocessa TUDO
-- =====================================================

BEGIN;

SELECT '
╔═══════════════════════════════════════════════════════════╗
║         🔄 REPROCESSAMENTO TIPO CARDEX                    ║
║         Zerando e Reprocessando TUDO do Zero              ║
╚═══════════════════════════════════════════════════════════╝
' as "INÍCIO";

-- =====================================================
-- ETAPA 1: BACKUP COMPLETO
-- =====================================================

SELECT '💾 ETAPA 1: Criando backup completo...' as "STATUS";

DROP TABLE IF EXISTS backup_cardex_produtos;
DROP TABLE IF EXISTS backup_cardex_movimentacoes;

CREATE TEMP TABLE backup_cardex_produtos AS
SELECT * FROM produtos;

CREATE TEMP TABLE backup_cardex_movimentacoes AS
SELECT * FROM estoque_movimentacoes;

SELECT 
    (SELECT COUNT(*) FROM backup_cardex_produtos) as "Produtos Salvos",
    (SELECT COUNT(*) FROM backup_cardex_movimentacoes) as "Movimentações Salvas";

SELECT '✅ ETAPA 1: Backup completo criado' as "STATUS";

-- =====================================================
-- ETAPA 2: ZERAR ESTOQUE DE TODOS OS PRODUTOS
-- =====================================================

SELECT '🔄 ETAPA 2: Zerando estoque de TODOS os produtos...' as "STATUS";

UPDATE produtos
SET estoque_atual = 0,
    updated_at = NOW()
WHERE active = true;

SELECT 
    COUNT(*) as "Produtos Zerados"
FROM produtos
WHERE active = true;

SELECT '✅ ETAPA 2: Estoque zerado para reprocessamento' as "STATUS";

-- =====================================================
-- ETAPA 3: REPROCESSAR TODAS AS MOVIMENTAÇÕES
-- =====================================================

SELECT '🔄 ETAPA 3: Reprocessando todas as movimentações na ordem cronológica...' as "STATUS";

-- Criar tabela temporária para o reprocessamento
DROP TABLE IF EXISTS cardex_reprocessamento;

CREATE TEMP TABLE cardex_reprocessamento AS
SELECT 
    em.id,
    em.produto_id,
    p.codigo,
    p.nome,
    em.tipo,
    em.quantidade,
    em.created_at,
    em.observacao,
    ROW_NUMBER() OVER (ORDER BY em.created_at, em.id) as ordem
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
WHERE p.active = true
ORDER BY em.created_at, em.id;

SELECT 
    COUNT(*) as "Total de Movimentações",
    MIN(created_at) as "Primeira Movimentação",
    MAX(created_at) as "Última Movimentação"
FROM cardex_reprocessamento;

-- =====================================================
-- ETAPA 4: APLICAR MOVIMENTAÇÕES UMA POR UMA (CARDEX)
-- =====================================================

SELECT '📊 ETAPA 4: Aplicando movimentações uma por uma...' as "STATUS";

-- Atualizar estoque_movimentacoes com os valores corretos
WITH cardex_calculado AS (
    SELECT 
        cr.id as movimentacao_id,
        cr.produto_id,
        cr.tipo,
        cr.quantidade,
        -- Calcular estoque anterior baseado nas movimentações anteriores
        COALESCE(
            (SELECT 
                COALESCE(SUM(CASE WHEN cr2.tipo = 'ENTRADA' THEN cr2.quantidade ELSE -cr2.quantidade END), 0)
             FROM cardex_reprocessamento cr2
             WHERE cr2.produto_id = cr.produto_id
               AND cr2.ordem < cr.ordem
            ), 0
        ) as estoque_anterior,
        -- Calcular estoque novo
        COALESCE(
            (SELECT 
                COALESCE(SUM(CASE WHEN cr2.tipo = 'ENTRADA' THEN cr2.quantidade ELSE -cr2.quantidade END), 0)
             FROM cardex_reprocessamento cr2
             WHERE cr2.produto_id = cr.produto_id
               AND cr2.ordem <= cr.ordem
            ), 0
        ) as estoque_novo
    FROM cardex_reprocessamento cr
)
UPDATE estoque_movimentacoes em
SET 
    estoque_anterior = cc.estoque_anterior,
    estoque_novo = cc.estoque_novo
FROM cardex_calculado cc
WHERE em.id = cc.movimentacao_id;

SELECT '✅ ETAPA 4: Valores de estoque_anterior e estoque_novo atualizados' as "STATUS";

-- =====================================================
-- ETAPA 5: ATUALIZAR ESTOQUE ATUAL DOS PRODUTOS
-- =====================================================

SELECT '🔄 ETAPA 5: Calculando estoque final de cada produto...' as "STATUS";

WITH estoque_final AS (
    SELECT 
        p.id as produto_id,
        p.codigo,
        p.nome,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.codigo, p.nome
)
UPDATE produtos p
SET 
    estoque_atual = ef.estoque_calculado,
    updated_at = NOW()
FROM estoque_final ef
WHERE p.id = ef.produto_id;

SELECT '✅ ETAPA 5: Estoque atual atualizado' as "STATUS";

-- =====================================================
-- ETAPA 6: RELATÓRIO DE REPROCESSAMENTO
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            📊 RELATÓRIO DE REPROCESSAMENTO                ║
╚═══════════════════════════════════════════════════════════╝
' as "RELATÓRIO";

-- Comparação ANTES x DEPOIS
SELECT '📋 COMPARAÇÃO: ANTES x DEPOIS' as "ANÁLISE";

WITH antes AS (
    SELECT 
        COUNT(*) as total_produtos,
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as negativos,
        ROUND(SUM(estoque_atual)::numeric, 2) as estoque_total,
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda
    FROM backup_cardex_produtos
    WHERE active = true
),
depois AS (
    SELECT 
        COUNT(*) as total_produtos,
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as negativos,
        ROUND(SUM(estoque_atual)::numeric, 2) as estoque_total,
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda
    FROM produtos
    WHERE active = true
)
SELECT 
    'ANTES' as "Momento",
    a.total_produtos as "Total Produtos",
    a.negativos as "Produtos Negativos",
    a.estoque_total as "Estoque Total (UN)",
    a.valor_compra as "Valor Compra (R$)",
    a.valor_venda as "Valor Venda (R$)"
FROM antes a
UNION ALL
SELECT 
    'DEPOIS' as "Momento",
    d.total_produtos as "Total Produtos",
    d.negativos as "Produtos Negativos",
    d.estoque_total as "Estoque Total (UN)",
    d.valor_compra as "Valor Compra (R$)",
    d.valor_venda as "Valor Venda (R$)"
FROM depois d;

-- Produtos com maior diferença
SELECT '📊 TOP 10 PRODUTOS COM MAIOR ALTERAÇÃO' as "ANÁLISE";

SELECT 
    p.codigo,
    p.nome,
    b.estoque_atual as "Estoque ANTES",
    p.estoque_atual as "Estoque DEPOIS",
    (p.estoque_atual - b.estoque_atual) as "Diferença",
    ROUND((b.estoque_atual * p.preco_compra)::numeric, 2) as "Valor Antes (R$)",
    ROUND((p.estoque_atual * p.preco_compra)::numeric, 2) as "Valor Depois (R$)",
    CASE 
        WHEN p.estoque_atual >= 0 AND b.estoque_atual < 0 THEN '✅ Corrigido (era negativo)'
        WHEN p.estoque_atual < 0 THEN '❌ Ainda negativo'
        WHEN p.estoque_atual > b.estoque_atual THEN '📈 Aumentou'
        WHEN p.estoque_atual < b.estoque_atual THEN '📉 Diminuiu'
        ELSE '➡️ Igual'
    END as "Status"
FROM produtos p
JOIN backup_cardex_produtos b ON p.id = b.id
WHERE ABS(p.estoque_atual - b.estoque_atual) > 0.01
ORDER BY ABS(p.estoque_atual - b.estoque_atual) DESC
LIMIT 10;

-- Produtos que ainda estão negativos
SELECT '⚠️ PRODUTOS QUE AINDA ESTÃO NEGATIVOS' as "ANÁLISE";

SELECT 
    p.codigo,
    p.nome,
    p.estoque_atual,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as "Total Entradas",
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as "Total Saídas",
    ROUND((p.estoque_atual * p.preco_compra)::numeric, 2) as "Valor Compra (R$)"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.estoque_atual < 0 AND p.active = true
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual, p.preco_compra
ORDER BY p.estoque_atual;

-- Estatísticas das movimentações reprocessadas
SELECT '📦 ESTATÍSTICAS DAS MOVIMENTAÇÕES' as "ANÁLISE";

SELECT 
    tipo as "Tipo",
    COUNT(*) as "Quantidade Movimentações",
    ROUND(SUM(quantidade)::numeric, 2) as "Quantidade Total",
    COUNT(DISTINCT produto_id) as "Produtos Afetados"
FROM cardex_reprocessamento
GROUP BY tipo
ORDER BY tipo;

-- Valores finais
SELECT '💰 VALORES FINAIS APÓS REPROCESSAMENTO' as "ANÁLISE";

WITH valores AS (
    SELECT 
        COUNT(*) as total_produtos,
        COUNT(CASE WHEN estoque_atual = 0 THEN 1 END) as sem_estoque,
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as negativos,
        COUNT(CASE WHEN estoque_atual > 0 THEN 1 END) as positivos,
        ROUND(SUM(estoque_atual)::numeric, 2) as estoque_total,
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda,
        ROUND(SUM(estoque_atual * (preco_venda - preco_compra))::numeric, 2) as margem_lucro
    FROM produtos
    WHERE active = true
)
SELECT 
    total_produtos as "Total de Produtos",
    positivos as "Produtos com Estoque Positivo",
    sem_estoque as "Produtos Sem Estoque",
    negativos as "Produtos com Estoque Negativo",
    estoque_total as "Estoque Total (Unidades)",
    valor_compra as "Valor Total Compra (R$)",
    valor_venda as "Valor Total Venda (R$)",
    margem_lucro as "Margem de Lucro Potencial (R$)",
    CASE 
        WHEN valor_compra >= 0 AND valor_venda >= 0 THEN
            ROUND((margem_lucro / NULLIF(valor_venda, 0) * 100)::numeric, 2)
        ELSE 0
    END as "Margem (%)"
FROM valores;

-- =====================================================
-- ETAPA 7: CRIAR LOG DO REPROCESSAMENTO
-- =====================================================

SELECT '📝 ETAPA 7: Criando log do reprocessamento...' as "STATUS";

CREATE TABLE IF NOT EXISTS estoque_reprocessamento_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    produto_id UUID REFERENCES produtos(id),
    codigo_produto VARCHAR(50),
    nome_produto VARCHAR(255),
    estoque_anterior DECIMAL(10,2),
    estoque_recalculado DECIMAL(10,2),
    diferenca DECIMAL(10,2),
    total_entradas DECIMAL(10,2),
    total_saidas DECIMAL(10,2),
    movimentacoes_duplicadas_removidas INTEGER,
    reprocessado_em TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

INSERT INTO estoque_reprocessamento_log (
    produto_id, codigo_produto, nome_produto,
    estoque_anterior, estoque_recalculado, diferenca,
    total_entradas, total_saidas,
    movimentacoes_duplicadas_removidas
)
SELECT 
    p.id,
    p.codigo,
    p.nome,
    b.estoque_atual as estoque_anterior,
    p.estoque_atual as estoque_recalculado,
    (p.estoque_atual - b.estoque_atual) as diferenca,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as total_entradas,
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as total_saidas,
    0 as movimentacoes_duplicadas_removidas
FROM produtos p
JOIN backup_cardex_produtos b ON p.id = b.id
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE ABS(p.estoque_atual - b.estoque_atual) > 0.01
GROUP BY p.id, p.codigo, p.nome, b.estoque_atual, p.estoque_atual;

SELECT '✅ ETAPA 7: Log criado' as "STATUS";

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
        SUM(estoque_atual * preco_venda) as valor_venda_total
    FROM produtos
    WHERE active = true
)
SELECT 
    CASE 
        WHEN tem_negativos = 0 AND valor_compra_total >= 0 AND valor_venda_total >= 0 
        THEN '✅ REPROCESSAMENTO BEM SUCEDIDO!'
        WHEN tem_negativos > 0 
        THEN '⚠️ Ainda há ' || tem_negativos || ' produto(s) com estoque negativo'
        WHEN valor_compra_total < 0 OR valor_venda_total < 0
        THEN '⚠️ Valores monetários ainda estão negativos'
        ELSE '✅ Verificação OK'
    END as "Status Final",
    tem_negativos as "Produtos Negativos",
    ROUND(valor_compra_total::numeric, 2) as "Valor Total Compra",
    ROUND(valor_venda_total::numeric, 2) as "Valor Total Venda"
FROM verificacao;

-- =====================================================
-- DECISÃO FINAL
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            ⚠️ DECISÃO FINAL                               ║
╚═══════════════════════════════════════════════════════════╝

Revise os relatórios acima.

✅ Se o reprocessamento foi BEM SUCEDIDO:
   COMMIT;

❌ Se ainda há problemas:
   ROLLBACK;

Após COMMIT, execute: VALIDACAO_estoque.sql

╔═══════════════════════════════════════════════════════════╝
' as "DECISÃO";
