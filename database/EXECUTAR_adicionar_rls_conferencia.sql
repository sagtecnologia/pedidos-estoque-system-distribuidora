-- =====================================================
-- ADICIONAR POLÍTICA RLS PARA CONFERÊNCIA DE ITENS
-- =====================================================
-- Permite atualizar campos de conferência em pedidos FINALIZADOS

-- Adicionar política para permitir atualizar campos de conferência
CREATE POLICY "Usuários podem conferir itens de pedidos finalizados"
    ON pedido_itens FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND status = 'FINALIZADO'
            AND tipo_pedido = 'VENDA'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND status = 'FINALIZADO'
            AND tipo_pedido = 'VENDA'
        )
    );

SELECT '✅ POLÍTICA RLS PARA CONFERÊNCIA ADICIONADA!' as resultado;
