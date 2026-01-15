-- =====================================================
-- CORREÇÃO PONTUAL: Ajustar Estoque de Produtos Específicos
-- =====================================================
-- Use este script para corrigir o estoque de produtos
-- específicos sem reprocessar tudo
-- =====================================================

-- =====================================================
-- ETAPA 1: IDENTIFICAR O PRODUTO PROBLEMÁTICO
-- =====================================================

-- Método 1: Buscar por código
SELECT 
    '🔍 Buscar Produto por Código' as "BUSCA";

-- Altere 'SEU_CODIGO' para o código do produto
SELECT 
    p.id,
    p.codigo,
    p.nome,
    p.estoque_atual as "Estoque Registrado",
    p.unidade,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as "Total Entradas",
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as "Total Saídas",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Estoque Calculado",
    p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Diferença"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.codigo ILIKE '%SEU_CODIGO%'  -- ⬅️ ALTERE AQUI
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual, p.unidade;

-- Método 2: Buscar por nome
SELECT 
    '🔍 Buscar Produto por Nome' as "BUSCA";

-- Altere 'SEU_NOME' para parte do nome do produto
SELECT 
    p.id,
    p.codigo,
    p.nome,
    p.estoque_atual as "Estoque Registrado",
    p.unidade,
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as "Total Entradas",
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as "Total Saídas",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Estoque Calculado",
    p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Diferença"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.nome ILIKE '%SEU_NOME%'  -- ⬅️ ALTERE AQUI
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual, p.unidade;

-- =====================================================
-- ETAPA 2: VER HISTÓRICO DE MOVIMENTAÇÕES
-- =====================================================

SELECT 
    '📋 Histórico de Movimentações do Produto' as "HISTÓRICO";

-- Altere 'SEU_CODIGO' para o código do produto
SELECT 
    em.created_at as "Data/Hora",
    em.tipo as "Tipo",
    em.quantidade as "Quantidade",
    em.estoque_anterior as "Estoque Antes",
    em.estoque_novo as "Estoque Depois",
    em.observacao as "Observação",
    ped.numero as "Pedido",
    u.full_name as "Usuário"
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
LEFT JOIN pedidos ped ON em.pedido_id = ped.id
LEFT JOIN users u ON em.usuario_id = u.id
WHERE p.codigo ILIKE '%SEU_CODIGO%'  -- ⬅️ ALTERE AQUI
ORDER BY em.created_at DESC
LIMIT 50;

-- =====================================================
-- ETAPA 3: IDENTIFICAR MOVIMENTAÇÕES DUPLICADAS DESTE PRODUTO
-- =====================================================

SELECT 
    '🔍 Movimentações Duplicadas do Produto' as "DUPLICATAS";

-- Altere 'SEU_CODIGO' para o código do produto
SELECT 
    ped.numero as "Pedido",
    em.tipo as "Tipo",
    em.quantidade as "Quantidade",
    em.observacao as "Observação",
    COUNT(*) as "Ocorrências",
    STRING_AGG(em.id::text, ', ') as "IDs das Movimentações",
    MIN(em.created_at) as "Primeira",
    MAX(em.created_at) as "Última"
FROM estoque_movimentacoes em
JOIN produtos p ON em.produto_id = p.id
LEFT JOIN pedidos ped ON em.pedido_id = ped.id
WHERE p.codigo ILIKE '%SEU_CODIGO%'  -- ⬅️ ALTERE AQUI
  AND em.pedido_id IS NOT NULL
GROUP BY ped.numero, em.tipo, em.quantidade, em.observacao, em.pedido_id, DATE(em.created_at)
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- =====================================================
-- ETAPA 4: CORREÇÃO - OPÇÃO A (Remover Duplicatas Específicas)
-- =====================================================

/*
-- Descomente para remover duplicatas específicas do produto

BEGIN;

SELECT 
    '🗑️ Removendo duplicatas do produto...' as "STATUS";

-- Altere 'SEU_CODIGO' para o código do produto
WITH movimentacoes_numeradas AS (
    SELECT 
        em.id,
        em.created_at,
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
    JOIN produtos p ON em.produto_id = p.id
    WHERE p.codigo ILIKE '%SEU_CODIGO%'  -- ⬅️ ALTERE AQUI
      AND em.pedido_id IS NOT NULL
)
DELETE FROM estoque_movimentacoes
WHERE id IN (
    SELECT id FROM movimentacoes_numeradas WHERE rn > 1
);

SELECT 
    '✅ Duplicatas removidas!' as "RESULTADO";

-- Mostrar quantas foram removidas
-- (já foram removidas, então este SELECT retornará 0)
SELECT COUNT(*) as "Duplicatas Restantes"
FROM (
    SELECT 
        em.pedido_id,
        em.produto_id,
        em.tipo,
        em.quantidade,
        DATE(em.created_at) as data,
        COUNT(*) as ocorrencias
    FROM estoque_movimentacoes em
    JOIN produtos p ON em.produto_id = p.id
    WHERE p.codigo ILIKE '%SEU_CODIGO%'  -- ⬅️ ALTERE AQUI
      AND em.pedido_id IS NOT NULL
    GROUP BY em.pedido_id, em.produto_id, em.tipo, em.quantidade, DATE(em.created_at)
    HAVING COUNT(*) > 1
) dup;

-- Revise e decida:
-- COMMIT; (para confirmar) ou ROLLBACK; (para cancelar)
*/

-- =====================================================
-- ETAPA 5: CORREÇÃO - OPÇÃO B (Recalcular Estoque do Produto)
-- =====================================================

/*
-- Descomente para recalcular o estoque do produto

BEGIN;

SELECT 
    '🔄 Recalculando estoque do produto...' as "STATUS";

-- Altere 'SEU_CODIGO' para o código do produto
WITH estoque_calculado AS (
    SELECT 
        p.id,
        p.codigo,
        p.nome,
        p.estoque_atual as estoque_anterior,
        COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as estoque_novo
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.codigo ILIKE '%SEU_CODIGO%'  -- ⬅️ ALTERE AQUI
    GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
)
UPDATE produtos p
SET 
    estoque_atual = ec.estoque_novo,
    updated_at = NOW()
FROM estoque_calculado ec
WHERE p.id = ec.produto_id;

-- Mostrar resultado
SELECT 
    codigo as "Código",
    nome as "Produto",
    estoque_atual as "Novo Estoque",
    unidade as "Unidade"
FROM produtos
WHERE codigo ILIKE '%SEU_CODIGO%';  -- ⬅️ ALTERE AQUI

-- Revise e decida:
-- COMMIT; (para confirmar) ou ROLLBACK; (para cancelar)
*/

-- =====================================================
-- ETAPA 6: CORREÇÃO - OPÇÃO C (Ajuste Manual)
-- =====================================================

/*
-- Descomente para ajustar manualmente o estoque

BEGIN;

SELECT 
    '✏️ Ajustando estoque manualmente...' as "STATUS";

-- Altere os valores:
-- 'SEU_CODIGO' = código do produto
-- 100.00 = novo valor do estoque
UPDATE produtos
SET 
    estoque_atual = 100.00,  -- ⬅️ ALTERE O VALOR AQUI
    updated_at = NOW()
WHERE codigo ILIKE '%SEU_CODIGO%';  -- ⬅️ ALTERE O CÓDIGO AQUI

-- Mostrar resultado
SELECT 
    codigo as "Código",
    nome as "Produto",
    estoque_atual as "Novo Estoque",
    unidade as "Unidade"
FROM produtos
WHERE codigo ILIKE '%SEU_CODIGO%';  -- ⬅️ ALTERE O CÓDIGO AQUI

-- Revise e decida:
-- COMMIT; (para confirmar) ou ROLLBACK; (para cancelar)
*/

-- =====================================================
-- ETAPA 7: VALIDAÇÃO FINAL
-- =====================================================

SELECT 
    '✅ Validação Final do Produto' as "VALIDAÇÃO";

-- Altere 'SEU_CODIGO' para o código do produto
SELECT 
    p.codigo as "Código",
    p.nome as "Produto",
    p.estoque_atual as "Estoque Registrado",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE 0 END), 0) as "Total Entradas",
    COALESCE(SUM(CASE WHEN em.tipo = 'SAIDA' THEN em.quantidade ELSE 0 END), 0) as "Total Saídas",
    COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0) as "Estoque Calculado",
    CASE 
        WHEN ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) < 0.01 
        THEN '✅ CONSISTENTE'
        ELSE '❌ INCONSISTENTE'
    END as "Status"
FROM produtos p
LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
WHERE p.codigo ILIKE '%SEU_CODIGO%'  -- ⬅️ ALTERE AQUI
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual;

-- =====================================================
-- INSTRUÇÕES
-- =====================================================

SELECT '
=====================================================
    🎯 CORREÇÃO PONTUAL DE PRODUTO
=====================================================

PASSO A PASSO:

1️⃣ IDENTIFICAR O PRODUTO (Etapa 1)
   - Busque por código ou nome
   - Anote o ID e veja a diferença

2️⃣ VER HISTÓRICO (Etapa 2)
   - Verifique todas as movimentações
   - Identifique entradas e saídas

3️⃣ IDENTIFICAR DUPLICATAS (Etapa 3)
   - Veja se há movimentações duplicadas
   - Anote quantas duplicatas existem

4️⃣ ESCOLHER CORREÇÃO:

   OPÇÃO A: Remover Duplicatas
   - Use se houver duplicatas
   - Mais conservador
   - Mantém movimentações originais

   OPÇÃO B: Recalcular Estoque
   - Use após remover duplicatas
   - Calcula baseado nas movimentações
   - Mais automático

   OPÇÃO C: Ajuste Manual
   - Use se souber o valor correto
   - Mais direto
   - Para casos específicos

5️⃣ VALIDAR (Etapa 7)
   - Confirme que está consistente
   - Status deve ser "✅ CONSISTENTE"

⚠️ IMPORTANTE:
- Altere todos os "SEU_CODIGO" no script
- Revise antes de fazer COMMIT
- Use ROLLBACK se algo não estiver certo

=====================================================
' as "INSTRUÇÕES";
