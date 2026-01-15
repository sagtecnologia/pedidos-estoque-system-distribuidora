-- =====================================================
-- DIAGNÓSTICO: Verificar Status de Pedidos e Triggers
-- =====================================================

-- 1. Verificar se a função de validação existe
SELECT 
    proname as "Nome da Função",
    pg_get_functiondef(oid) as "Definição"
FROM pg_proc 
WHERE proname = 'validar_mudanca_status_pedido';

-- 2. Verificar se o trigger existe
SELECT 
    trigger_name as "Nome do Trigger",
    event_manipulation as "Evento",
    action_statement as "Ação",
    action_timing as "Timing"
FROM information_schema.triggers 
WHERE trigger_name = 'trigger_validar_mudanca_status';

-- 3. Verificar constraint de status
SELECT 
    conname as "Constraint",
    pg_get_constraintdef(oid) as "Definição"
FROM pg_constraint 
WHERE conname LIKE '%status%' 
  AND conrelid = 'pedidos'::regclass;

-- 4. Listar todos os pedidos com status FINALIZADO
SELECT 
    id,
    numero,
    tipo_pedido,
    status,
    created_at,
    updated_at
FROM pedidos 
WHERE status = 'FINALIZADO'
ORDER BY created_at DESC
LIMIT 10;

-- 5. Verificar se há pedidos que foram "cancelados" mas estão FINALIZADO
SELECT 
    p.id,
    p.numero,
    p.tipo_pedido,
    p.status as "Status Atual",
    COUNT(em.id) as "Cancelamentos Registrados"
FROM pedidos p
LEFT JOIN estoque_movimentacoes em ON em.pedido_id = p.id
WHERE em.observacao LIKE '%Cancelamento%'
  AND p.status = 'FINALIZADO'
GROUP BY p.id, p.numero, p.tipo_pedido, p.status
HAVING COUNT(em.id) > 0;

-- 6. Testar se é possível atualizar um pedido FINALIZADO para CANCELADO
DO $$
DECLARE
    v_test_pedido_id UUID;
    v_test_numero TEXT;
    v_old_status TEXT;
    v_new_status TEXT;
BEGIN
    -- Buscar um pedido FINALIZADO para teste
    SELECT id, numero, status INTO v_test_pedido_id, v_test_numero, v_old_status
    FROM pedidos 
    WHERE status = 'FINALIZADO' 
    LIMIT 1;
    
    IF v_test_pedido_id IS NULL THEN
        RAISE NOTICE '⚠️ Nenhum pedido FINALIZADO encontrado para teste';
        RETURN;
    END IF;
    
    RAISE NOTICE '🧪 Testando atualização do pedido %', v_test_numero;
    RAISE NOTICE '   Status atual: %', v_old_status;
    
    -- Tentar atualizar (em transação que será revertida)
    BEGIN
        UPDATE pedidos 
        SET status = 'CANCELADO' 
        WHERE id = v_test_pedido_id
        RETURNING status INTO v_new_status;
        
        RAISE NOTICE '✅ SUCESSO: Status atualizado para %', v_new_status;
        
        -- Reverter imediatamente
        UPDATE pedidos 
        SET status = v_old_status 
        WHERE id = v_test_pedido_id;
        
        RAISE NOTICE '🔄 Status revertido para %', v_old_status;
        
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ ERRO ao tentar atualizar: %', SQLERRM;
    END;
END $$;

-- 7. Verificar permissões RLS na tabela pedidos
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    CASE 
        WHEN qual IS NOT NULL THEN 'USING: ' || substring(qual, 1, 50) || '...'
        ELSE 'Sem USING'
    END as "Condição USING",
    CASE 
        WHEN with_check IS NOT NULL THEN 'CHECK: ' || substring(with_check, 1, 50) || '...'
        ELSE 'Sem WITH CHECK'
    END as "Condição WITH CHECK"
FROM pg_policies 
WHERE tablename = 'pedidos'
ORDER BY cmd, policyname;

-- 8. Verificar se há políticas de UPDATE para ADMIN
SELECT 
    COUNT(*) as "Total Políticas UPDATE",
    COUNT(*) FILTER (WHERE qual LIKE '%ADMIN%' OR with_check LIKE '%ADMIN%') as "Políticas com ADMIN"
FROM pg_policies 
WHERE tablename = 'pedidos' 
AND cmd = 'UPDATE';

-- 9. Simular verificação de permissão para um pedido específico
DO $$
DECLARE
    v_pedido_finalizado UUID;
    v_total_admins INTEGER;
BEGIN
    SELECT id INTO v_pedido_finalizado 
    FROM pedidos 
    WHERE status = 'FINALIZADO' 
    LIMIT 1;
    
    SELECT COUNT(*) INTO v_total_admins 
    FROM users 
    WHERE role = 'ADMIN';
    
    RAISE NOTICE '';
    RAISE NOTICE '📊 RESUMO DO DIAGNÓSTICO:';
    RAISE NOTICE '   Total de usuários ADMIN: %', v_total_admins;
    RAISE NOTICE '   Pedido FINALIZADO para teste: %', COALESCE(v_pedido_finalizado::TEXT, 'Nenhum');
    RAISE NOTICE '';
    
    IF v_total_admins = 0 THEN
        RAISE NOTICE '⚠️  PROBLEMA: Não há usuários ADMIN no sistema!';
    END IF;
    
    IF v_pedido_finalizado IS NULL THEN
        RAISE NOTICE '⚠️  INFO: Não há pedidos FINALIZADOS para testar';
    END IF;
    
END $$;

SELECT '✅ Diagnóstico concluído!' as resultado;
