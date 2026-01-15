-- =====================================================
-- REPROCESSAMENTO COMPLETO DO ESTOQUE
-- =====================================================
-- Este script recalcula TODO o estoque baseado nas
-- movimentações de entrada e saída registradas
-- =====================================================
-- ⚠️ IMPORTANTE: 
-- 1. Execute DIAGNOSTICO_estoque_completo.sql primeiro
-- 2. Faça um backup antes de executar este script
-- 3. Revise os resultados após a execução
-- =====================================================

BEGIN;

-- =====================================================
-- ETAPA 1: BACKUP DA SITUAÇÃO ATUAL
-- =====================================================

-- Criar tabela temporária com o estado atual (para rollback se necessário)
DROP TABLE IF EXISTS backup_estoque_antes_reprocessamento;

CREATE TEMP TABLE backup_estoque_antes_reprocessamento AS
SELECT 
    id,
    codigo,
    nome,
    estoque_atual,
    NOW() as backup_data
FROM produtos;

SELECT '✅ ETAPA 1: Backup criado' as "STATUS";
SELECT COUNT(*) as "Produtos Salvos" FROM backup_estoque_antes_reprocessamento;

-- =====================================================
-- ETAPA 2: IDENTIFICAR E REMOVER MOVIMENTAÇÕES DUPLICADAS
-- =====================================================

SELECT '🔍 ETAPA 2: Identificando movimentações duplicadas...' as "STATUS";

-- Criar tabela temporária com movimentações duplicadas
DROP TABLE IF EXISTS movimentacoes_duplicadas;

CREATE TEMP TABLE movimentacoes_duplicadas AS
WITH movimentacoes_numeradas AS (
    SELECT 
        em.*,
        ROW_NUMBER() OVER (
            PARTITION BY 
                em.pedido_id, 
                em.produto_id, 
                em.tipo,
                em.quantidade,
                DATE(em.created_at)
            ORDER BY em.created_at ASC
        ) as rn
    FROM estoque_movimentacoes em
    WHERE em.pedido_id IS NOT NULL
)
SELECT *
FROM movimentacoes_numeradas
WHERE rn > 1;

-- Mostrar o que será removido
SELECT 
    COUNT(*) as "Movimentações Duplicadas Encontradas",
    COUNT(DISTINCT pedido_id) as "Pedidos Afetados",
    COUNT(DISTINCT produto_id) as "Produtos Afetados"
FROM movimentacoes_duplicadas;

-- Listar as duplicatas por pedido
SELECT 
    ped.numero as "Pedido",
    p.codigo as "Produto",
    p.nome as "Nome",
    md.tipo as "Tipo",
    md.quantidade as "Quantidade",
    md.observacao as "Observação",
    md.created_at as "Data"
FROM movimentacoes_duplicadas md
JOIN pedidos ped ON md.pedido_id = ped.id
JOIN produtos p ON md.produto_id = p.id
ORDER BY ped.numero, p.codigo, md.created_at;

-- Remover as duplicatas (mantendo apenas a primeira ocorrência)
DELETE FROM estoque_movimentacoes
WHERE id IN (SELECT id FROM movimentacoes_duplicadas);

SELECT '✅ ETAPA 2: Movimentações duplicadas removidas' as "STATUS";

-- =====================================================
-- ETAPA 3: RECALCULAR ESTOQUE DE TODOS OS PRODUTOS
-- =====================================================

SELECT '🔄 ETAPA 3: Recalculando estoque de todos os produtos...' as "STATUS";

-- Criar tabela temporária com o estoque calculado
DROP TABLE IF EXISTS estoque_recalculado;

CREATE TEMP TABLE estoque_recalculado AS
SELECT 
    p.id as produto_id,
    p.codigo,
    p.nome,
    p.estoque_atual as estoque_anterior,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as total_entradas,
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as total_saidas,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_calculado,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) - p.estoque_atual as diferenca
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.active = true
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual;

-- Mostrar o que será atualizado
SELECT 
    COUNT(*) as "Total de Produtos",
    COUNT(CASE WHEN ABS(diferenca) > 0.01 THEN 1 END) as "Produtos que Serão Atualizados",
    ROUND(SUM(ABS(diferenca))::numeric, 2) as "Total de Ajustes"
FROM estoque_recalculado;

-- Mostrar os produtos que serão ajustados
SELECT 
    '📋 Produtos que serão atualizados:' as "AJUSTES";

SELECT 
    codigo as "Código",
    nome as "Produto",
    estoque_anterior as "Estoque Anterior",
    total_entradas as "Total Entradas",
    total_saidas as "Total Saídas",
    estoque_calculado as "Estoque Calculado",
    diferenca as "Diferença",
    CASE 
        WHEN diferenca > 0 THEN '📈 AUMENTAR'
        WHEN diferenca < 0 THEN '📉 DIMINUIR'
        ELSE '✅ IGUAL'
    END as "Ação"
FROM estoque_recalculado
WHERE ABS(diferenca) > 0.01
ORDER BY ABS(diferenca) DESC;

-- Atualizar os produtos
UPDATE produtos p
SET 
    estoque_atual = er.estoque_calculado,
    updated_at = NOW()
FROM estoque_recalculado er
WHERE p.id = er.produto_id
  AND ABS(er.diferenca) > 0.01;

SELECT '✅ ETAPA 3: Estoque recalculado e atualizado' as "STATUS";

-- =====================================================
-- ETAPA 4: CRIAR LOG DE AJUSTES
-- =====================================================

SELECT '📝 ETAPA 4: Criando log de ajustes...' as "STATUS";

-- Criar tabela de log se não existir
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

-- Inserir log
INSERT INTO estoque_reprocessamento_log (
    produto_id, codigo_produto, nome_produto, 
    estoque_anterior, estoque_recalculado, diferenca,
    total_entradas, total_saidas,
    movimentacoes_duplicadas_removidas
)
SELECT 
    er.produto_id,
    er.codigo,
    er.nome,
    er.estoque_anterior,
    er.estoque_calculado,
    er.diferenca,
    er.total_entradas,
    er.total_saidas,
    (SELECT COUNT(*) FROM movimentacoes_duplicadas WHERE produto_id = er.produto_id)
FROM estoque_recalculado er
WHERE ABS(er.diferenca) > 0.01;

SELECT '✅ ETAPA 4: Log de ajustes criado' as "STATUS";

-- =====================================================
-- ETAPA 5: RELATÓRIO FINAL
-- =====================================================

SELECT '
=====================================================
        🎉 REPROCESSAMENTO CONCLUÍDO
=====================================================
' as "RESULTADO";

SELECT 
    COUNT(*) as "Produtos Processados",
    SUM(CASE WHEN ABS(diferenca) > 0.01 THEN 1 ELSE 0 END) as "Produtos Ajustados",
    SUM(CASE WHEN diferenca > 0 THEN 1 ELSE 0 END) as "Estoques Aumentados",
    SUM(CASE WHEN diferenca < 0 THEN 1 ELSE 0 END) as "Estoques Diminuídos",
    ROUND(SUM(ABS(diferenca))::numeric, 2) as "Total de Ajustes"
FROM estoque_recalculado;

SELECT 
    '📊 RESUMO DOS AJUSTES' as "TÍTULO";

SELECT 
    codigo as "Código",
    nome as "Produto",
    estoque_anterior as "Antes",
    estoque_calculado as "Depois",
    diferenca as "Diferença",
    total_entradas as "Entradas",
    total_saidas as "Saídas"
FROM estoque_recalculado
WHERE ABS(diferenca) > 0.01
ORDER BY ABS(diferenca) DESC
LIMIT 20;

SELECT 
    '📋 MOVIMENTAÇÕES DUPLICADAS REMOVIDAS' as "TÍTULO";

SELECT 
    (SELECT COUNT(*) FROM movimentacoes_duplicadas) as "Total Removidas",
    (SELECT COUNT(DISTINCT pedido_id) FROM movimentacoes_duplicadas) as "Pedidos Afetados",
    (SELECT COUNT(DISTINCT produto_id) FROM movimentacoes_duplicadas) as "Produtos Afetados";

-- =====================================================
-- COMMIT OU ROLLBACK
-- =====================================================

SELECT '
=====================================================
⚠️ ATENÇÃO: DECISÃO NECESSÁRIA
=====================================================

Revise os resultados acima.

Se estiver TUDO CORRETO, execute:
    ✅ COMMIT;

Se algo estiver ERRADO, execute:
    ❌ ROLLBACK;
    
Após COMMIT, execute VALIDACAO_estoque.sql
para confirmar que tudo está correto.

=====================================================
' as "PRÓXIMA AÇÃO";

-- NÃO FAÇA COMMIT AUTOMÁTICO!
-- O usuário deve revisar e decidir:
-- COMMIT; ou ROLLBACK;
