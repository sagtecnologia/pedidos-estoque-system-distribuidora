-- =====================================================
-- REPROCESSAMENTO TIPO CARDEX - AUTOMÁTICO
-- =====================================================
-- Este script reprocessa TUDO e faz COMMIT automático
-- se não houver problemas
-- =====================================================

DO $$
DECLARE
    v_negativos INTEGER;
    v_valor_compra NUMERIC;
    v_valor_venda NUMERIC;
BEGIN
    -- =====================================================
    -- ETAPA 1: BACKUP COMPLETO
    -- =====================================================
    
    RAISE NOTICE '💾 ETAPA 1: Criando backup completo...';
    
    DROP TABLE IF EXISTS backup_cardex_produtos;
    DROP TABLE IF EXISTS backup_cardex_movimentacoes;
    
    CREATE TEMP TABLE backup_cardex_produtos AS
    SELECT * FROM produtos;
    
    CREATE TEMP TABLE backup_cardex_movimentacoes AS
    SELECT * FROM estoque_movimentacoes;
    
    RAISE NOTICE '✅ ETAPA 1: Backup completo criado';
    
    -- =====================================================
    -- ETAPA 2: ZERAR ESTOQUE DE TODOS OS PRODUTOS
    -- =====================================================
    
    RAISE NOTICE '🔄 ETAPA 2: Zerando estoque de TODOS os produtos...';
    
    UPDATE produtos
    SET estoque_atual = 0,
        updated_at = NOW()
    WHERE active = true;
    
    RAISE NOTICE '✅ ETAPA 2: Estoque zerado para reprocessamento';
    
    -- =====================================================
    -- ETAPA 3: REPROCESSAR TODAS AS MOVIMENTAÇÕES
    -- =====================================================
    
    RAISE NOTICE '🔄 ETAPA 3: Reprocessando todas as movimentações...';
    
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
    
    -- =====================================================
    -- ETAPA 4: APLICAR MOVIMENTAÇÕES UMA POR UMA (CARDEX)
    -- =====================================================
    
    RAISE NOTICE '📊 ETAPA 4: Aplicando movimentações uma por uma...';
    
    WITH cardex_calculado AS (
        SELECT 
            cr.id as movimentacao_id,
            cr.produto_id,
            cr.tipo,
            cr.quantidade,
            COALESCE(
                (SELECT 
                    COALESCE(SUM(CASE WHEN cr2.tipo = 'ENTRADA' THEN cr2.quantidade ELSE -cr2.quantidade END), 0)
                 FROM cardex_reprocessamento cr2
                 WHERE cr2.produto_id = cr.produto_id
                   AND cr2.ordem < cr.ordem
                ), 0
            ) as estoque_anterior,
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
    
    RAISE NOTICE '✅ ETAPA 4: Valores atualizados';
    
    -- =====================================================
    -- ETAPA 5: ATUALIZAR ESTOQUE ATUAL DOS PRODUTOS
    -- =====================================================
    
    RAISE NOTICE '🔄 ETAPA 5: Calculando estoque final...';
    
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
    
    RAISE NOTICE '✅ ETAPA 5: Estoque atual atualizado';
    
    -- =====================================================
    -- ETAPA 6: CRIAR LOG DO REPROCESSAMENTO
    -- =====================================================
    
    RAISE NOTICE '📝 ETAPA 6: Criando log...';
    
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
    
    RAISE NOTICE '✅ ETAPA 6: Log criado';
    
    -- =====================================================
    -- VERIFICAÇÃO E DECISÃO AUTOMÁTICA
    -- =====================================================
    
    RAISE NOTICE '🔍 Verificando resultado...';
    
    SELECT 
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END),
        SUM(estoque_atual * preco_compra),
        SUM(estoque_atual * preco_venda)
    INTO v_negativos, v_valor_compra, v_valor_venda
    FROM produtos
    WHERE active = true;
    
    -- Verificar se está tudo OK
    IF v_negativos = 0 AND v_valor_compra >= 0 AND v_valor_venda >= 0 THEN
        RAISE NOTICE '✅ REPROCESSAMENTO BEM SUCEDIDO!';
        RAISE NOTICE 'Produtos Negativos: %', v_negativos;
        RAISE NOTICE 'Valor Total Compra: R$ %', ROUND(v_valor_compra, 2);
        RAISE NOTICE 'Valor Total Venda: R$ %', ROUND(v_valor_venda, 2);
        RAISE NOTICE '';
        RAISE NOTICE '✅ COMMIT EXECUTADO AUTOMATICAMENTE!';
        -- Tudo OK, transação será confirmada automaticamente
    ELSE
        -- Há problemas, fazer rollback
        RAISE EXCEPTION '⚠️ PROBLEMAS ENCONTRADOS - ROLLBACK EXECUTADO!
Produtos Negativos: %
Valor Total Compra: R$ %
Valor Total Venda: R$ %

Execute o script de diagnóstico para investigar.', 
            v_negativos, 
            ROUND(v_valor_compra, 2), 
            ROUND(v_valor_venda, 2);
    END IF;
    
END $$;

-- =====================================================
-- RELATÓRIOS FINAIS (Após COMMIT)
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            📊 RELATÓRIO FINAL                             ║
╚═══════════════════════════════════════════════════════════╝
' as "RELATÓRIO";

-- Comparação ANTES x DEPOIS
SELECT '📋 COMPARAÇÃO: ANTES x DEPOIS' as "SEÇÃO";

WITH log_stats AS (
    SELECT 
        COUNT(*) as produtos_alterados,
        COUNT(CASE WHEN estoque_anterior < 0 THEN 1 END) as era_negativo,
        COUNT(CASE WHEN estoque_recalculado < 0 THEN 1 END) as ficou_negativo,
        SUM(ABS(diferenca)) as diferenca_total
    FROM estoque_reprocessamento_log
    WHERE reprocessado_em = (SELECT MAX(reprocessado_em) FROM estoque_reprocessamento_log)
)
SELECT 
    produtos_alterados as "Produtos Alterados",
    era_negativo as "Eram Negativos",
    ficou_negativo as "Ficaram Negativos",
    ROUND(diferenca_total, 2) as "Diferença Total (UN)"
FROM log_stats;

-- Status atual
SELECT '💰 STATUS ATUAL DO ESTOQUE' as "SEÇÃO";

WITH valores AS (
    SELECT 
        COUNT(*) as total_produtos,
        COUNT(CASE WHEN estoque_atual = 0 THEN 1 END) as sem_estoque,
        COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as negativos,
        COUNT(CASE WHEN estoque_atual > 0 THEN 1 END) as positivos,
        ROUND(SUM(estoque_atual)::numeric, 2) as estoque_total,
        ROUND(SUM(estoque_atual * preco_compra)::numeric, 2) as valor_compra,
        ROUND(SUM(estoque_atual * preco_venda)::numeric, 2) as valor_venda
    FROM produtos
    WHERE active = true
)
SELECT 
    total_produtos as "Total de Produtos",
    positivos as "✅ Com Estoque",
    sem_estoque as "⚪ Sem Estoque",
    negativos as "❌ Negativos",
    estoque_total as "Estoque Total (UN)",
    valor_compra as "Valor Compra (R$)",
    valor_venda as "Valor Venda (R$)"
FROM valores;

-- Top 10 produtos alterados
SELECT '📊 TOP 10 PRODUTOS MAIS ALTERADOS' as "SEÇÃO";

SELECT 
    codigo_produto as "Código",
    nome_produto as "Nome",
    estoque_anterior as "Antes",
    estoque_recalculado as "Depois",
    diferenca as "Diferença",
    CASE 
        WHEN estoque_recalculado >= 0 AND estoque_anterior < 0 THEN '✅ Corrigido'
        WHEN estoque_recalculado < 0 THEN '❌ Negativo'
        WHEN diferenca > 0 THEN '📈 Aumentou'
        WHEN diferenca < 0 THEN '📉 Diminuiu'
        ELSE '➡️ Igual'
    END as "Status"
FROM estoque_reprocessamento_log
WHERE reprocessado_em = (SELECT MAX(reprocessado_em) FROM estoque_reprocessamento_log)
ORDER BY ABS(diferenca) DESC
LIMIT 10;

SELECT '
╔═══════════════════════════════════════════════════════════╗
║  ✅ REPROCESSAMENTO CONCLUÍDO COM SUCESSO!                ║
║                                                           ║
║  Próximo passo:                                           ║
║  Execute o script: VALIDACAO_estoque.sql                  ║
╚═══════════════════════════════════════════════════════════╝
' as "CONCLUSÃO";
