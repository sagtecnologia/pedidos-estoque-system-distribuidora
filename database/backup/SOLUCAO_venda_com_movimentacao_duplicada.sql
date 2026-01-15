-- =====================================================
-- SOLUÇÃO: Venda com movimentação duplicada
-- Problema: "Já existe movimentação para o produto no pedido"
-- =====================================================
-- Este erro ocorre quando uma venda tem status RASCUNHO
-- mas já possui movimentações de estoque registradas.
--
-- CAUSAS COMUNS:
-- 1. Venda foi finalizada e depois reaberta como RASCUNHO
-- 2. Erro durante finalização que deixou movimentações "órfãs"
-- 3. Tentativa de finalização que falhou no meio do processo
-- =====================================================

-- PASSO 1: DIAGNOSTICAR A VENDA
-- Substitua 'VENDA-20260114-00005' pelo número da sua venda

SELECT 
    '🔍 DADOS DA VENDA' as "DIAGNÓSTICO";

SELECT 
    id,
    numero,
    status,
    tipo_pedido,
    total,
    TO_CHAR(created_at, 'DD/MM/YYYY HH24:MI') as "Data Criação",
    TO_CHAR(data_finalizacao, 'DD/MM/YYYY HH24:MI') as "Data Finalização"
FROM pedidos
WHERE numero = 'VENDA-20260114-00005';

-- PASSO 2: VERIFICAR MOVIMENTAÇÕES EXISTENTES

SELECT 
    '📦 MOVIMENTAÇÕES EXISTENTES' as "ANÁLISE";

SELECT 
    em.id,
    p.codigo as "Produto",
    ps.sabor as "Sabor",
    em.tipo as "Tipo",
    em.quantidade as "Qtd",
    em.observacao as "Observação",
    TO_CHAR(em.created_at, 'DD/MM/YYYY HH24:MI:SS') as "Data/Hora"
FROM estoque_movimentacoes em
LEFT JOIN produtos p ON p.id = em.produto_id
LEFT JOIN produto_sabores ps ON ps.id = em.sabor_id
WHERE em.pedido_id = (
    SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005'
)
ORDER BY em.created_at;

-- PASSO 3: VERIFICAR SE HÁ DUPLICAÇÕES

SELECT 
    '🔄 ANÁLISE DE DUPLICAÇÕES' as "VERIFICAÇÃO";

WITH movs_venda AS (
    SELECT 
        em.produto_id,
        em.sabor_id,
        em.tipo,
        COUNT(*) as total_movimentacoes,
        STRING_AGG(em.id::TEXT, ', ') as ids_movimentacoes
    FROM estoque_movimentacoes em
    WHERE em.pedido_id = (
        SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005'
    )
    GROUP BY em.produto_id, em.sabor_id, em.tipo
)
SELECT 
    p.codigo as "Produto",
    ps.sabor as "Sabor",
    mv.tipo as "Tipo",
    mv.total_movimentacoes as "Qtd Movimentações",
    CASE 
        WHEN mv.total_movimentacoes > 1 THEN '⚠️  DUPLICADO'
        ELSE '✅ OK'
    END as "Status"
FROM movs_venda mv
LEFT JOIN produtos p ON p.id = mv.produto_id
LEFT JOIN produto_sabores ps ON ps.id = mv.sabor_id;

-- =====================================================
-- SOLUÇÃO 1: LIMPAR TODAS AS MOVIMENTAÇÕES
-- =====================================================
-- Use esta opção se quiser começar do zero

SELECT 
    '💡 SOLUÇÃO 1: Limpar todas as movimentações' as "OPÇÃO";

-- ⚠️  DESCOMENTE PARA EXECUTAR:
/*
BEGIN;

-- Salvar movimentações para backup (opcional)
CREATE TEMP TABLE backup_movimentacoes AS
SELECT * FROM estoque_movimentacoes 
WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005');

-- Deletar as movimentações
DELETE FROM estoque_movimentacoes 
WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005');

SELECT 
    'Movimentações deletadas. Agora você pode finalizar a venda novamente.' as "RESULTADO";

-- IMPORTANTE: Se der tudo certo, execute COMMIT
-- Se algo der errado, execute ROLLBACK
*/

-- =====================================================
-- SOLUÇÃO 2: REVERTER MOVIMENTAÇÕES E ATUALIZAR ESTOQUE
-- =====================================================
-- Use esta opção se as movimentações já afetaram o estoque
-- e você precisa reverter o impacto

SELECT 
    '💡 SOLUÇÃO 2: Reverter movimentações e corrigir estoque' as "OPÇÃO";

-- ⚠️  DESCOMENTE PARA EXECUTAR:
/*
BEGIN;

-- Para cada movimentação de SAÍDA, devolver o estoque
WITH movs_para_reverter AS (
    SELECT 
        em.sabor_id,
        em.quantidade,
        em.tipo
    FROM estoque_movimentacoes em
    WHERE em.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
    AND em.tipo = 'SAIDA'
    AND em.sabor_id IS NOT NULL
)
UPDATE produto_sabores ps
SET quantidade = ps.quantidade + mpr.quantidade
FROM movs_para_reverter mpr
WHERE ps.id = mpr.sabor_id;

-- Agora deletar as movimentações
DELETE FROM estoque_movimentacoes 
WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005');

SELECT 
    'Estoque revertido e movimentações deletadas. Agora você pode finalizar a venda novamente.' as "RESULTADO";

-- IMPORTANTE: Se der tudo certo, execute COMMIT
-- Se algo der errado, execute ROLLBACK
*/

-- =====================================================
-- SOLUÇÃO 3: MARCAR VENDA COMO FINALIZADA (SE MOVIMENTAÇÕES ESTÃO CORRETAS)
-- =====================================================
-- Use esta opção se as movimentações estão corretas
-- e você só precisa atualizar o status

SELECT 
    '💡 SOLUÇÃO 3: Marcar como finalizada (movimentações OK)' as "OPÇÃO";

-- ⚠️  DESCOMENTE PARA EXECUTAR:
/*
BEGIN;

UPDATE pedidos
SET 
    status = 'FINALIZADO',
    data_finalizacao = NOW()
WHERE numero = 'VENDA-20260114-00005';

SELECT 
    'Venda marcada como FINALIZADA' as "RESULTADO";

-- IMPORTANTE: Se der tudo certo, execute COMMIT
-- Se algo der errado, execute ROLLBACK
*/

-- =====================================================
-- VERIFICAÇÃO FINAL
-- =====================================================

SELECT 
    '📊 VERIFICAÇÃO APÓS CORREÇÃO' as "FINAL";

-- Status da venda
SELECT 
    numero,
    status,
    TO_CHAR(data_finalizacao, 'DD/MM/YYYY HH24:MI') as "Data Finalização"
FROM pedidos
WHERE numero = 'VENDA-20260114-00005';

-- Movimentações (deve estar vazio após Solução 1 ou 2)
SELECT 
    COUNT(*) as "Total Movimentações"
FROM estoque_movimentacoes
WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005');

-- =====================================================
-- 📝 INSTRUÇÕES DE USO:
-- =====================================================
/*
1. Execute primeiro o PASSO 1, 2 e 3 para diagnosticar
2. Escolha qual solução usar:
   
   SOLUÇÃO 1: Se você quer limpar tudo e refinalizar
   - Descomente o bloco BEGIN/DELETE da Solução 1
   - Execute o SQL
   - Se estiver correto, execute: COMMIT;
   - Se algo der errado: ROLLBACK;
   - Vá na interface e finalize a venda novamente
   
   SOLUÇÃO 2: Se as movimentações já afetaram o estoque
   - Descomente o bloco BEGIN/UPDATE/DELETE da Solução 2
   - Execute o SQL
   - Se estiver correto, execute: COMMIT;
   - Se algo der errado: ROLLBACK;
   - Vá na interface e finalize a venda novamente
   
   SOLUÇÃO 3: Se as movimentações estão corretas
   - Descomente o bloco BEGIN/UPDATE da Solução 3
   - Execute o SQL
   - Se estiver correto, execute: COMMIT;
   - Se algo der errado: ROLLBACK;
   - A venda ficará como FINALIZADA

3. Execute a VERIFICAÇÃO FINAL para confirmar
*/
