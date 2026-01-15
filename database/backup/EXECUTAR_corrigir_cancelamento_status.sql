-- =====================================================
-- CORREÇÃO: Falha ao atualizar status após cancelamento
-- =====================================================

-- 1. Verificar políticas RLS da tabela pedidos
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
WHERE tablename = 'pedidos'
ORDER BY policyname;

-- 2. Garantir que usuários podem atualizar status de pedidos finalizados
DROP POLICY IF EXISTS "Usuários podem atualizar seus pedidos" ON pedidos;
DROP POLICY IF EXISTS "update_pedidos_policy" ON pedidos;

CREATE POLICY "update_pedidos_policy" ON pedidos
    FOR UPDATE
    USING (
        auth.uid() IN (
            SELECT id FROM users WHERE active = true
        )
    )
    WITH CHECK (
        auth.uid() IN (
            SELECT id FROM users WHERE active = true
        )
    );

-- 3. Criar função para cancelar pedido com log completo
CREATE OR REPLACE FUNCTION cancelar_pedido_definitivo(
    p_pedido_id UUID,
    p_usuario_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_pedido RECORD;
    v_item RECORD;
    v_resultado JSON;
    v_movs_revertidas INTEGER := 0;
BEGIN
    -- Buscar pedido
    SELECT * INTO v_pedido
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Pedido não encontrado'
        );
    END IF;
    
    -- Validar status
    IF v_pedido.status = 'CANCELADO' THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Pedido já está cancelado'
        );
    END IF;
    
    IF v_pedido.status = 'RASCUNHO' THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Pedido em rascunho não precisa ser cancelado'
        );
    END IF;
    
    -- Se o pedido está FINALIZADO, reverter o estoque
    IF v_pedido.status = 'FINALIZADO' THEN
        FOR v_item IN 
            SELECT pi.*, ps.quantidade as estoque_atual
            FROM pedido_itens pi
            LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
            WHERE pi.pedido_id = p_pedido_id
        LOOP
            IF v_item.sabor_id IS NOT NULL THEN
                -- COMPRA finalizada: remover o que foi adicionado
                IF v_pedido.tipo_pedido = 'COMPRA' THEN
                    -- ⚠️ VALIDAÇÃO CRÍTICA: Verificar se há estoque suficiente ANTES de remover
                    IF v_item.estoque_atual < v_item.quantidade THEN
                        RAISE EXCEPTION 'BLOQUEIO: Não é possível cancelar esta compra! O produto % já foi vendido. Estoque atual: %, tentando remover: %. Faltam: % unidades.',
                            (SELECT CONCAT(p.codigo, ' (', (SELECT sabor FROM produto_sabores WHERE id = v_item.sabor_id), ')') 
                             FROM produtos p WHERE p.id = v_item.produto_id),
                            v_item.estoque_atual,
                            v_item.quantidade,
                            (v_item.quantidade - v_item.estoque_atual);
                    END IF;
                    
                    -- Remover a quantidade que foi adicionada
                    UPDATE produto_sabores
                    SET quantidade = quantidade - v_item.quantidade
                    WHERE id = v_item.sabor_id;
                    
                    -- Registrar movimentação de reversão
                    INSERT INTO estoque_movimentacoes (
                        produto_id, sabor_id, tipo, quantidade,
                        estoque_anterior, estoque_novo,
                        usuario_id, pedido_id, observacao
                    ) VALUES (
                        v_item.produto_id,
                        v_item.sabor_id,
                        'SAIDA',
                        v_item.quantidade,
                        v_item.estoque_atual,
                        v_item.estoque_atual - v_item.quantidade,
                        p_usuario_id,
                        p_pedido_id,
                        'Ajuste - Cancelamento definitivo de compra'
                    );
                    
                    v_movs_revertidas := v_movs_revertidas + 1;
                    
                -- VENDA finalizada: devolver o que foi removido
                ELSIF v_pedido.tipo_pedido = 'VENDA' THEN
                    -- Devolver a quantidade que foi removida
                    UPDATE produto_sabores
                    SET quantidade = quantidade + v_item.quantidade
                    WHERE id = v_item.sabor_id;
                    
                    -- Registrar movimentação de reversão
                    INSERT INTO estoque_movimentacoes (
                        produto_id, sabor_id, tipo, quantidade,
                        estoque_anterior, estoque_novo,
                        usuario_id, pedido_id, observacao
                    ) VALUES (
                        v_item.produto_id,
                        v_item.sabor_id,
                        'ENTRADA',
                        v_item.quantidade,
                        v_item.estoque_atual,
                        v_item.estoque_atual + v_item.quantidade,
                        p_usuario_id,
                        p_pedido_id,
                        'Ajuste - Cancelamento definitivo de venda'
                    );
                    
                    v_movs_revertidas := v_movs_revertidas + 1;
                END IF;
            END IF;
        END LOOP;
    END IF;
    
    -- Atualizar status do pedido para CANCELADO
    UPDATE pedidos
    SET status = 'CANCELADO',
        aprovador_id = p_usuario_id,
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    -- Verificar se foi atualizado
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Não foi possível atualizar o status do pedido'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'pedido_id', p_pedido_id,
        'status_anterior', v_pedido.status,
        'status_novo', 'CANCELADO',
        'movimentacoes_revertidas', v_movs_revertidas
    );
    
EXCEPTION WHEN OTHERS THEN
    RETURN json_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Comentário explicativo
COMMENT ON FUNCTION cancelar_pedido_definitivo IS 
'Cancela um pedido definitivamente, revertendo o estoque se necessário e atualizando o status para CANCELADO';

-- 5. Buscar pedidos que estão finalizados mas deveriam estar cancelados
SELECT 
    p.id,
    p.numero,
    p.tipo_pedido,
    p.status,
    p.total,
    COUNT(em.id) as total_movimentacoes,
    COUNT(CASE WHEN em.observacao LIKE '%Cancelamento%' THEN 1 END) as movs_cancelamento
FROM pedidos p
LEFT JOIN estoque_movimentacoes em ON em.pedido_id = p.id
WHERE p.status = 'FINALIZADO'
GROUP BY p.id, p.numero, p.tipo_pedido, p.status, p.total
HAVING COUNT(CASE WHEN em.observacao LIKE '%Cancelamento%' THEN 1 END) > 0;
