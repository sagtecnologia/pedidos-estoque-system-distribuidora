-- =====================================================
-- MELHORAR MENSAGEM DE ERRO DE ESTOQUE INSUFICIENTE
-- =====================================================
-- Execute este SQL no Supabase SQL Editor

CREATE OR REPLACE FUNCTION finalizar_pedido(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_ja_finalizado BOOLEAN;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA - antes de qualquer leitura)
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    -- PROTEÇÃO 1: Impedir múltiplas finalizações
    IF v_status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Este pedido já foi finalizado anteriormente';
    END IF;
    
    -- PROTEÇÃO 2: Verificar se já existem movimentações
    SELECT EXISTS(
        SELECT 1 
        FROM estoque_movimentacoes 
        WHERE pedido_id = p_pedido_id 
        AND observacao LIKE '%Finalização pedido%'
    ) INTO v_ja_finalizado;
    
    IF v_ja_finalizado THEN
        RAISE EXCEPTION 'Este pedido já tem movimentações de estoque registradas';
    END IF;

    -- Processar itens do pedido COM INFORMAÇÕES DO PRODUTO
    FOR v_item IN 
        SELECT 
            pi.produto_id, 
            pi.sabor_id, 
            pi.quantidade,
            p.codigo as produto_codigo,
            ps.sabor as sabor_nome
        FROM pedido_itens pi
        LEFT JOIN produtos p ON p.id = pi.produto_id
        LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
        WHERE pi.pedido_id = p_pedido_id
    LOOP
        IF v_item.sabor_id IS NOT NULL THEN
            DECLARE
                v_estoque_anterior DECIMAL;
                v_estoque_novo DECIMAL;
                v_quantidade_ajuste DECIMAL;
            BEGIN
                -- Buscar estoque atual COM LOCK
                SELECT quantidade INTO v_estoque_anterior
                FROM produto_sabores
                WHERE id = v_item.sabor_id
                FOR UPDATE;  -- 🔒 LOCK no registro de estoque!
                
                -- Calcular ajuste baseado no tipo
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_quantidade_ajuste := v_item.quantidade;  -- Adiciona
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_quantidade_ajuste := -v_item.quantidade;  -- Remove
                    
                    -- ✅ VALIDAÇÃO COM MENSAGEM MELHORADA
                    IF v_estoque_anterior < v_item.quantidade THEN
                        RAISE EXCEPTION 'Estoque insuficiente para % (%). Necessário: %, Disponível: %',
                            v_item.produto_codigo, 
                            v_item.sabor_nome,
                            v_item.quantidade,
                            v_estoque_anterior;
                    END IF;
                ELSE
                    RAISE EXCEPTION 'Tipo de pedido inválido: %', v_tipo_pedido;
                END IF;
                
                -- Atualizar estoque
                UPDATE produto_sabores
                SET quantidade = quantidade + v_quantidade_ajuste
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_estoque_novo;
                
                -- Registrar movimentação
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    sabor_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    observacao
                ) VALUES (
                    v_item.produto_id,
                    v_item.sabor_id,
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                    v_item.quantidade,
                    v_estoque_anterior,
                    v_estoque_novo,
                    p_usuario_id,
                    p_pedido_id,
                    CASE 
                        WHEN v_tipo_pedido = 'COMPRA' THEN 'Entrada - Finalização pedido compra'
                        ELSE 'Saída - Finalização pedido venda'
                    END
                );
            END;
        END IF;
    END LOOP;

    -- Atualizar status e data de finalização
    UPDATE pedidos 
    SET 
        status = 'FINALIZADO',
        data_finalizacao = NOW(),
        aprovador_id = p_usuario_id
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Comentário explicativo
COMMENT ON FUNCTION finalizar_pedido IS 'Finaliza pedido com proteção contra duplicação, locks de transação e mensagens de erro detalhadas';

-- Teste
SELECT '✅ Função finalizar_pedido atualizada com mensagens de erro melhoradas!' as resultado;
