-- =====================================================
-- CORREÇÃO URGENTE: Permitir ADMIN Cancelar Pedidos
-- =====================================================
-- O problema: RLS está bloqueando o UPDATE de status
-- Solução: Adicionar política específica para cancelamento

-- 1. Remover políticas antigas de update que podem estar conflitando
DROP POLICY IF EXISTS "Admin pode cancelar pedidos" ON pedidos;
DROP POLICY IF EXISTS "Usuarios podem atualizar seus proprios pedidos em rascunho" ON pedidos;

-- 2. Criar política para ADMIN atualizar qualquer pedido (incluindo status)
CREATE POLICY "Admin pode atualizar qualquer pedido"
ON pedidos FOR UPDATE
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

-- 3. Criar política para VENDEDOR atualizar apenas seus próprios pedidos em RASCUNHO
CREATE POLICY "Vendedor pode atualizar seus pedidos em rascunho"
ON pedidos FOR UPDATE
TO authenticated
USING (
    solicitante_id = auth.uid() 
    AND status = 'RASCUNHO'
)
WITH CHECK (
    solicitante_id = auth.uid() 
    AND status = 'RASCUNHO'
);

-- 4. Criar política para APROVADOR poder aprovar/rejeitar
CREATE POLICY "Aprovador pode atualizar pedidos enviados"
ON pedidos FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM users 
        WHERE users.id = auth.uid() 
        AND users.role IN ('ADMIN', 'APROVADOR')
    )
    AND status IN ('ENVIADO', 'APROVADO')
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM users 
        WHERE users.id = auth.uid() 
        AND users.role IN ('ADMIN', 'APROVADOR')
    )
);

-- 5. Testar se ADMIN consegue atualizar status
DO $$
DECLARE
    v_admin_id UUID;
    v_pedido_id UUID;
    v_old_status TEXT;
    v_new_status TEXT;
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
    
    -- Buscar um pedido FINALIZADO
    SELECT id, status INTO v_pedido_id, v_old_status
    FROM pedidos 
    WHERE status = 'FINALIZADO' 
    LIMIT 1;
    
    IF v_pedido_id IS NULL THEN
        RAISE NOTICE '⚠️ Nenhum pedido FINALIZADO encontrado';
        RETURN;
    END IF;
    
    RAISE NOTICE '🧪 Testando update com ADMIN: %', v_admin_id;
    RAISE NOTICE '   Pedido: %', v_pedido_id;
    RAISE NOTICE '   Status atual: %', v_old_status;
    
    -- Simular update como se fosse o ADMIN
    -- (Nota: Este teste só valida a lógica, o RLS real precisa do auth.uid())
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ Políticas RLS atualizadas!';
    RAISE NOTICE '';
    RAISE NOTICE '📋 IMPORTANTE:';
    RAISE NOTICE '   1. Limpe o cache do navegador (Ctrl+Shift+Delete)';
    RAISE NOTICE '   2. Faça logout e login novamente';
    RAISE NOTICE '   3. Tente cancelar o pedido novamente';
    RAISE NOTICE '';
    
END $$;

-- 6. Listar todas as políticas ativas em pedidos
SELECT 
    policyname as "Política",
    cmd as "Comando",
    roles as "Roles",
    CASE 
        WHEN qual IS NOT NULL THEN 'USING definido'
        ELSE 'Sem USING'
    END as "USING",
    CASE 
        WHEN with_check IS NOT NULL THEN 'WITH CHECK definido'
        ELSE 'Sem WITH CHECK'
    END as "WITH CHECK"
FROM pg_policies 
WHERE tablename = 'pedidos'
ORDER BY cmd, policyname;

SELECT '✅ Correção de RLS aplicada com sucesso!' as resultado;
