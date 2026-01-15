-- =====================================================
-- CORREÇÃO RÁPIDA: Estoque Zerado por Engano
-- =====================================================
-- Use este script APENAS se você executou o reprocessamento
-- e algo deu errado, resultando em estoques zerados ou
-- incorretos E você não consegue fazer ROLLBACK
-- =====================================================
-- ⚠️ ATENÇÃO: Este script restaura o estoque manualmente
-- baseado nas movimentações. Use apenas em emergências!
-- =====================================================

-- Verificar se há backup recente
SELECT 
    '🔍 Verificando backups disponíveis...' as "STATUS";

SELECT 
    COUNT(*) as "Registros de Backup",
    MIN(backup_data) as "Backup Mais Antigo",
    MAX(backup_data) as "Backup Mais Recente"
FROM backup_estoque_antes_reprocessamento;

-- Se houver backup, mostrar os dados
SELECT 
    '📋 Dados do Backup' as "BACKUP";

SELECT 
    codigo,
    nome,
    estoque_atual as "Estoque no Backup",
    backup_data as "Data do Backup"
FROM backup_estoque_antes_reprocessamento
ORDER BY codigo
LIMIT 20;

-- =====================================================
-- OPÇÃO 1: RESTAURAR DO BACKUP (se existir)
-- =====================================================

/*
-- Descomente para restaurar do backup

BEGIN;

UPDATE produtos p
SET 
    estoque_atual = b.estoque_atual,
    updated_at = NOW()
FROM backup_estoque_antes_reprocessamento b
WHERE p.id = b.id;

SELECT 
    '✅ Estoque restaurado do backup!' as "RESULTADO",
    COUNT(*) as "Produtos Restaurados"
FROM backup_estoque_antes_reprocessamento;

-- Revise e decida:
-- COMMIT; (para confirmar) ou ROLLBACK; (para cancelar)
*/

-- =====================================================
-- OPÇÃO 2: RECALCULAR ESTOQUE MANUALMENTE
-- =====================================================

/*
-- Descomente para recalcular manualmente
-- Esta opção recalcula TUDO do zero baseado nas movimentações

BEGIN;

WITH estoque_calculado AS (
    SELECT 
        p.id as produto_id,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as novo_estoque
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id
)
UPDATE produtos p
SET 
    estoque_atual = ec.novo_estoque,
    updated_at = NOW()
FROM estoque_calculado ec
WHERE p.id = ec.produto_id;

SELECT 
    '✅ Estoque recalculado manualmente!' as "RESULTADO";

-- Mostrar resultado
SELECT 
    codigo,
    nome,
    estoque_atual as "Novo Estoque",
    unidade
FROM produtos
WHERE active = true
ORDER BY codigo
LIMIT 20;

-- Revise e decida:
-- COMMIT; (para confirmar) ou ROLLBACK; (para cancelar)
*/

-- =====================================================
-- OPÇÃO 3: RESTAURAR PRODUTO ESPECÍFICO
-- =====================================================

/*
-- Descomente e ajuste para restaurar um produto específico

-- Exemplo: Restaurar produto com código 'PROD001'
BEGIN;

WITH estoque_calculado AS (
    SELECT 
        p.id,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as novo_estoque
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.codigo = 'PROD001'  -- ⬅️ ALTERE O CÓDIGO AQUI
    GROUP BY p.id
)
UPDATE produtos p
SET 
    estoque_atual = ec.novo_estoque,
    updated_at = NOW()
FROM estoque_calculado ec
WHERE p.id = ec.produto_id;

SELECT 
    '✅ Produto restaurado!' as "RESULTADO",
    codigo,
    nome,
    estoque_atual
FROM produtos
WHERE codigo = 'PROD001';  -- ⬅️ ALTERE O CÓDIGO AQUI

-- Revise e decida:
-- COMMIT; (para confirmar) ou ROLLBACK; (para cancelar)
*/

-- =====================================================
-- VERIFICAR ESTADO ATUAL
-- =====================================================

SELECT 
    '📊 Estado Atual do Estoque' as "ESTADO";

SELECT 
    COUNT(*) as "Total de Produtos",
    COUNT(CASE WHEN estoque_atual = 0 THEN 1 END) as "Produtos Zerados",
    COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as "Produtos Negativos",
    COUNT(CASE WHEN estoque_atual > 0 THEN 1 END) as "Produtos com Estoque",
    ROUND(SUM(estoque_atual)::numeric, 2) as "Estoque Total"
FROM produtos
WHERE active = true;

-- Lista dos primeiros produtos
SELECT 
    codigo as "Código",
    nome as "Produto",
    estoque_atual as "Estoque",
    unidade as "Unidade"
FROM produtos
WHERE active = true
ORDER BY codigo
LIMIT 20;

-- =====================================================
-- INFORMAÇÕES ÚTEIS
-- =====================================================

SELECT '
=====================================================
        🆘 CORREÇÃO RÁPIDA DE ESTOQUE
=====================================================

OPÇÕES DISPONÍVEIS:

1️⃣ RESTAURAR DO BACKUP
   - Mais rápido
   - Volta exatamente ao estado anterior
   - Requer que o backup exista

2️⃣ RECALCULAR MANUALMENTE
   - Calcula do zero
   - Baseado nas movimentações
   - Funciona mesmo sem backup

3️⃣ RESTAURAR PRODUTO ESPECÍFICO
   - Para corrigir apenas um produto
   - Útil para ajustes pontuais

COMO USAR:
1. Escolha a opção que deseja
2. Descomente o bloco de código
3. Ajuste parâmetros se necessário
4. Execute o script
5. Revise os resultados
6. Execute COMMIT ou ROLLBACK

⚠️ IMPORTANTE:
- Sempre revise antes de fazer COMMIT
- Use ROLLBACK se algo não estiver certo
- Em caso de dúvida, não faça COMMIT

=====================================================
' as "INSTRUÇÕES";

-- Verificar se há log recente de reprocessamento
SELECT 
    '📝 Últimos Reprocessamentos' as "LOG";

SELECT 
    codigo_produto,
    nome_produto,
    estoque_anterior,
    estoque_recalculado,
    diferenca,
    reprocessado_em
FROM estoque_reprocessamento_log
ORDER BY reprocessado_em DESC
LIMIT 10;
