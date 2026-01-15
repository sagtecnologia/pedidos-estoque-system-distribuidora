-- =====================================================
-- CORREÇÃO: Remover exigência de aprovação para finalizar pedidos de compra
-- Agora pedidos de COMPRA podem ser finalizados diretamente do RASCUNHO
-- Pedidos de VENDA ainda precisam ser APROVADOS antes de finalizar
-- =====================================================

CREATE OR REPLACE FUNCTION finalizar_pedido(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
BEGIN
    -- Verificar status e tipo do pedido
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido 
    FROM pedidos 
    WHERE id = p_pedido_id;
    
    -- COMPRA: pode finalizar de RASCUNHO
    -- VENDA: precisa estar APROVADO
    IF v_tipo_pedido = 'VENDA' AND v_status != 'APROVADO' THEN
        RAISE EXCEPTION 'Vendas precisam ser aprovadas antes de finalizar';
    END IF;
    
    IF v_tipo_pedido = 'COMPRA' AND v_status NOT IN ('RASCUNHO', 'APROVADO') THEN
        RAISE EXCEPTION 'Apenas pedidos em rascunho ou aprovados podem ser finalizados';
    END IF;

    -- Processar itens de acordo com o tipo
    FOR v_item IN 
        SELECT produto_id, sabor_id, quantidade 
        FROM pedido_itens 
        WHERE pedido_id = p_pedido_id
    LOOP
        IF v_tipo_pedido = 'COMPRA' THEN
            -- Pedido de compra: ENTRADA no estoque (aumenta)
            IF v_item.sabor_id IS NOT NULL THEN
                PERFORM atualizar_estoque_sabor(v_item.sabor_id, v_item.quantidade);
            END IF;
            
            -- Registrar movimentação
            INSERT INTO estoque_movimentacoes (
                produto_id,
                sabor_id,
                tipo_movimentacao,
                quantidade,
                usuario_id,
                pedido_id,
                observacoes
            ) VALUES (
                v_item.produto_id,
                v_item.sabor_id,
                'ENTRADA',
                v_item.quantidade,
                p_usuario_id,
                p_pedido_id,
                'Entrada automática - Finalização de pedido de compra'
            );
            
        ELSIF v_tipo_pedido = 'VENDA' THEN
            -- Pedido de venda: SAÍDA no estoque (reduz)
            IF v_item.sabor_id IS NOT NULL THEN
                PERFORM atualizar_estoque_sabor(v_item.sabor_id, -v_item.quantidade);
            END IF;
            
            -- Registrar movimentação
            INSERT INTO estoque_movimentacoes (
                produto_id,
                sabor_id,
                tipo_movimentacao,
                quantidade,
                usuario_id,
                pedido_id,
                observacoes
            ) VALUES (
                v_item.produto_id,
                v_item.sabor_id,
                'SAIDA',
                v_item.quantidade,
                p_usuario_id,
                p_pedido_id,
                'Saída automática - Finalização de pedido de venda'
            );
        END IF;
    END LOOP;

    -- Atualizar status do pedido para FINALIZADO
    UPDATE pedidos 
    SET status = 'FINALIZADO', 
        data_finalizacao = NOW()
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

SELECT 'Função finalizar_pedido atualizada - COMPRA pode finalizar de RASCUNHO' as resultado;
