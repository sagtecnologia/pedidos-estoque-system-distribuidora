-- CORREÇÃO: Permitir finalizar pedidos de COMPRA direto do RASCUNHO
-- Pedidos de COMPRA não precisam de aprovação

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
    
    -- COMPRA e VENDA: podem finalizar de RASCUNHO ou APROVADO (sem obrigar aprovação)
    IF v_status NOT IN ('RASCUNHO', 'APROVADO') THEN
        RAISE EXCEPTION 'Pedido não pode ser finalizado neste status';
    END IF;

    -- Processar itens do pedido
    FOR v_item IN 
        SELECT produto_id, sabor_id, quantidade 
        FROM pedido_itens 
        WHERE pedido_id = p_pedido_id
    LOOP
        IF v_tipo_pedido = 'COMPRA' THEN
            -- COMPRA: ENTRADA de estoque (adiciona)
            IF v_item.sabor_id IS NOT NULL THEN
                -- Atualizar quantidade do sabor
                UPDATE produto_sabores
                SET quantidade = quantidade + v_item.quantidade
                WHERE id = v_item.sabor_id;
            END IF;
            
            -- Registrar movimentação
            INSERT INTO estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade, 
                estoque_anterior, estoque_novo,
                usuario_id, pedido_id, observacao
            ) 
            SELECT 
                v_item.produto_id,
                v_item.sabor_id,
                'ENTRADA',
                v_item.quantidade,
                COALESCE(ps.quantidade - v_item.quantidade, 0),
                COALESCE(ps.quantidade, 0),
                p_usuario_id,
                p_pedido_id,
                'Entrada - Finalização pedido compra'
            FROM produto_sabores ps
            WHERE ps.id = v_item.sabor_id;
            
        ELSIF v_tipo_pedido = 'VENDA' THEN
            -- VENDA: SAÍDA de estoque (remove)
            IF v_item.sabor_id IS NOT NULL THEN
                -- Verificar se há estoque suficiente
                DECLARE
                    v_estoque_atual DECIMAL;
                BEGIN
                    SELECT quantidade INTO v_estoque_atual
                    FROM produto_sabores
                    WHERE id = v_item.sabor_id;
                    
                    IF v_estoque_atual < v_item.quantidade THEN
                        RAISE EXCEPTION 'Estoque insuficiente para finalizar venda';
                    END IF;
                END;
                
                -- Atualizar quantidade do sabor
                UPDATE produto_sabores
                SET quantidade = quantidade - v_item.quantidade
                WHERE id = v_item.sabor_id;
            END IF;
            
            -- Registrar movimentação
            INSERT INTO estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                usuario_id, pedido_id, observacao
            )
            SELECT 
                v_item.produto_id,
                v_item.sabor_id,
                'SAIDA',
                v_item.quantidade,
                COALESCE(ps.quantidade + v_item.quantidade, 0),
                COALESCE(ps.quantidade, 0),
                p_usuario_id,
                p_pedido_id,
                'Saída - Finalização pedido venda'
            FROM produto_sabores ps
            WHERE ps.id = v_item.sabor_id;
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
