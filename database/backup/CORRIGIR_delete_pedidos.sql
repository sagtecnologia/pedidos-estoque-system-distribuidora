-- =====================================================
-- CORREÇÃO: POLÍTICAS RLS PARA DELETE DE PEDIDOS
-- =====================================================
-- Data: 2026-01-09
-- Problema: Pedidos em RASCUNHO não estão sendo excluídos
-- Solução: Recriar políticas RLS com regras mais específicas
-- =====================================================

-- PASSO 1: Ver políticas atuais
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename IN ('pedidos', 'pedido_itens')
ORDER BY tablename, policyname;

-- =====================================================
-- PASSO 2: REMOVER POLÍTICAS ANTIGAS DE DELETE
-- =====================================================

-- Remover política antiga de pedidos
DROP POLICY IF EXISTS "pedidos_delete" ON pedidos;

-- Remover política antiga de pedido_itens
DROP POLICY IF EXISTS "pedido_itens_delete" ON pedido_itens;

-- =====================================================
-- PASSO 3: CRIAR NOVAS POLÍTICAS DE DELETE
-- =====================================================

-- Política DELETE para PEDIDOS
-- Permite excluir:
-- 1. ADMIN pode excluir qualquer pedido em RASCUNHO
-- 2. SOLICITANTE pode excluir seus próprios pedidos em RASCUNHO
-- 3. VENDEDOR pode excluir pedidos de venda em RASCUNHO que criou
CREATE POLICY "pedidos_delete_rascunho"
    ON pedidos FOR DELETE
    TO authenticated
    USING (
        status = 'RASCUNHO' 
        AND (
            -- ADMIN pode excluir qualquer rascunho
            (SELECT role FROM users WHERE id = auth.uid()) = 'ADMIN'
            OR
            -- Solicitante pode excluir seus próprios rascunhos
            solicitante_id = auth.uid()
            OR
            -- Vendedor pode excluir vendas em rascunho que criou
            (
                (SELECT role FROM users WHERE id = auth.uid()) = 'VENDEDOR'
                AND tipo_pedido = 'VENDA'
                AND solicitante_id = auth.uid()
            )
        )
    );

-- Política DELETE para PEDIDO_ITENS
-- Permite excluir itens de pedidos em RASCUNHO
CREATE POLICY "pedido_itens_delete_rascunho"
    ON pedido_itens FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 
            FROM pedidos 
            WHERE pedidos.id = pedido_itens.pedido_id
            AND pedidos.status = 'RASCUNHO'
            AND (
                -- ADMIN pode excluir itens de qualquer rascunho
                (SELECT role FROM users WHERE id = auth.uid()) = 'ADMIN'
                OR
                -- Solicitante pode excluir itens de seus rascunhos
                pedidos.solicitante_id = auth.uid()
                OR
                -- Vendedor pode excluir itens de vendas em rascunho que criou
                (
                    (SELECT role FROM users WHERE id = auth.uid()) = 'VENDEDOR'
                    AND pedidos.tipo_pedido = 'VENDA'
                    AND pedidos.solicitante_id = auth.uid()
                )
            )
        )
    );

-- =====================================================
-- PASSO 4: COMENTÁRIOS EXPLICATIVOS
-- =====================================================

COMMENT ON POLICY "pedidos_delete_rascunho" ON pedidos IS 
'Permite exclusão de pedidos em RASCUNHO por:
1. ADMIN - qualquer pedido em rascunho
2. Solicitante - seus próprios pedidos em rascunho
3. VENDEDOR - vendas em rascunho que criou
IMPORTANTE: Apenas pedidos em RASCUNHO podem ser excluídos!';

COMMENT ON POLICY "pedido_itens_delete_rascunho" ON pedido_itens IS 
'Permite exclusão de itens de pedidos em RASCUNHO seguindo as mesmas regras da tabela pedidos.
Os itens são excluídos automaticamente quando o pedido é excluído (ON DELETE CASCADE).';

-- =====================================================
-- PASSO 5: TESTAR POLÍTICA
-- =====================================================

-- Ver políticas recriadas
SELECT 
    tablename,
    policyname,
    cmd as operacao,
    CASE 
        WHEN qual IS NOT NULL THEN 'Com condições'
        ELSE 'Sem condições'
    END as status
FROM pg_policies
WHERE tablename IN ('pedidos', 'pedido_itens')
AND cmd = 'DELETE'
ORDER BY tablename;

-- =====================================================
-- PASSO 6: VERIFICAR PEDIDOS EM RASCUNHO
-- =====================================================

-- Ver pedidos em rascunho que podem ser excluídos
SELECT 
    id,
    numero,
    tipo_pedido,
    status,
    solicitante_id,
    created_at,
    (SELECT full_name FROM users WHERE id = solicitante_id) as solicitante
FROM pedidos
WHERE status = 'RASCUNHO'
ORDER BY created_at DESC
LIMIT 10;

-- =====================================================
-- RESULTADO
-- =====================================================

SELECT '✅ POLÍTICAS RLS DE DELETE RECRIADAS!' as resultado,
       '🔒 Apenas pedidos em RASCUNHO podem ser excluídos' as restricao,
       '👤 ADMIN, SOLICITANTE e VENDEDOR podem excluir seus rascunhos' as permissoes,
       '🗑️ Itens são excluídos automaticamente (CASCADE)' as comportamento,
       '⚠️  Execute os testes acima para verificar' as proximo_passo;
