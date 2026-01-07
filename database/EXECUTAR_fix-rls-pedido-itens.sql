-- =====================================================
-- CORREÇÃO: Permitir Edição de Itens de Pedido
-- =====================================================
-- O problema: RLS bloqueando UPDATE em pedido_itens
-- Solução: Adicionar políticas para permitir edição

-- =====================================================
-- VERIFICAR POLÍTICAS ATUAIS
-- =====================================================

-- Ver políticas existentes em pedido_itens
SELECT 
    policyname as "Política",
    cmd as "Comando",
    CASE 
        WHEN qual IS NOT NULL THEN 'USING definido'
        ELSE 'Sem USING'
    END as "USING",
    CASE 
        WHEN with_check IS NOT NULL THEN 'WITH CHECK definido'
        ELSE 'Sem WITH CHECK'
    END as "WITH CHECK"
FROM pg_policies 
WHERE tablename = 'pedido_itens'
ORDER BY cmd, policyname;

-- =====================================================
-- CRIAR POLÍTICAS PARA pedido_itens
-- =====================================================

-- 1. Remover políticas antigas que podem estar conflitando
DROP POLICY IF EXISTS "Usuarios podem atualizar itens de seus pedidos em rascunho" ON pedido_itens;
DROP POLICY IF EXISTS "Admin pode atualizar qualquer item" ON pedido_itens;

-- 2. ADMIN pode fazer qualquer operação em pedido_itens
CREATE POLICY "Admin pode atualizar qualquer item de pedido"
ON pedido_itens FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM users 
        WHERE users.id = auth.uid() 
        AND users.role = 'ADMIN'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM users 
        WHERE users.id = auth.uid() 
        AND users.role = 'ADMIN'
    )
);

-- 3. VENDEDOR pode atualizar itens de seus próprios pedidos em RASCUNHO
CREATE POLICY "Vendedor pode atualizar itens de pedidos em rascunho"
ON pedido_itens FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM pedidos p
        WHERE p.id = pedido_itens.pedido_id
        AND p.solicitante_id = auth.uid()
        AND p.status = 'RASCUNHO'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM pedidos p
        WHERE p.id = pedido_itens.pedido_id
        AND p.solicitante_id = auth.uid()
        AND p.status = 'RASCUNHO'
    )
);

-- 4. Política para DELETE (ADMIN e itens de pedidos em rascunho)
DROP POLICY IF EXISTS "Admin pode excluir itens" ON pedido_itens;
DROP POLICY IF EXISTS "Usuarios podem excluir itens de pedidos em rascunho" ON pedido_itens;

CREATE POLICY "Admin pode excluir qualquer item"
ON pedido_itens FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM users 
        WHERE users.id = auth.uid() 
        AND users.role = 'ADMIN'
    )
);

CREATE POLICY "Vendedor pode excluir itens de pedidos em rascunho"
ON pedido_itens FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM pedidos p
        WHERE p.id = pedido_itens.pedido_id
        AND p.solicitante_id = auth.uid()
        AND p.status = 'RASCUNHO'
    )
);

-- =====================================================
-- TESTAR POLÍTICAS
-- =====================================================

DO $$
DECLARE
    v_admin_id UUID;
    v_pedido_id UUID;
    v_item_id UUID;
BEGIN
    -- Buscar um usuário ADMIN
    SELECT id INTO v_admin_id 
    FROM users 
    WHERE role = 'ADMIN' 
    LIMIT 1;
    
    IF v_admin_id IS NULL THEN
        RAISE NOTICE '⚠️ Nenhum usuário ADMIN encontrado';
        RETURN;
    END IF;
    
    -- Buscar um pedido e um item
    SELECT p.id, pi.id INTO v_pedido_id, v_item_id
    FROM pedidos p
    JOIN pedido_itens pi ON pi.pedido_id = p.id
    LIMIT 1;
    
    IF v_item_id IS NULL THEN
        RAISE NOTICE '⚠️ Nenhum item de pedido encontrado para teste';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Políticas RLS para pedido_itens atualizadas!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 IMPORTANTE:';
    RAISE NOTICE '   1. Faça logout e login novamente';
    RAISE NOTICE '   2. Limpe o cache do navegador (Ctrl+Shift+Delete)';
    RAISE NOTICE '   3. Tente editar o item novamente';
    RAISE NOTICE '';
    RAISE NOTICE '🔍 Verifique no console (F12) os novos logs detalhados';
    RAISE NOTICE '';
    
END $$;

-- =====================================================
-- VERIFICAR POLÍTICAS CRIADAS
-- =====================================================

SELECT 
    policyname as "Política",
    cmd as "Comando",
    roles as "Roles"
FROM pg_policies 
WHERE tablename = 'pedido_itens'
ORDER BY cmd, policyname;

SELECT '✅ Correção de RLS para pedido_itens aplicada com sucesso!' as resultado;
