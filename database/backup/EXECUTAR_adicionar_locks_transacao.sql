-- =====================================================
-- ADICIONAR LOCKS DE TRANSAÇÃO PARA PREVENIR RACE CONDITIONS
-- =====================================================

-- 0. Remover funções antigas (necessário se o tipo de retorno mudou)
DROP FUNCTION IF EXISTS finalizar_pedido(UUID, UUID);
DROP FUNCTION IF EXISTS cancelar_pedido_definitivo(UUID, UUID);

-- 1. Atualizar função finalizar_pedido com LOCK
CREATE OR REPLACE FUNCTION finalizar_pedido(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_ja_finalizado BOOLEAN;
BEGIN
    -- ⚠️ LOCK PESSIMISTA: Impede que outra transação modifique este pedido
    -- simultaneamente (previne race conditions)
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido 
    FROM pedidos 
    WHERE id = p_pedido_id
    FOR UPDATE;  -- 🔒 LOCK!
    
    -- PROTEÇÃO 1: Verificar se já foi finalizado
    IF v_status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Este pedido já foi finalizado anteriormente';
    END IF;
    
    -- PROTEÇÃO 2: Verificar se já foi cancelado
    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Este pedido foi cancelado e não pode ser finalizado';
    END IF;
    
    -- PROTEÇÃO 3: Verificar status válido
    IF v_status NOT IN ('RASCUNHO', 'APROVADO') THEN
        RAISE EXCEPTION 'Pedido não pode ser finalizado neste status: %', v_status;
    END IF;
    
    -- PROTEÇÃO 4: Verificar se já existem movimentações
    SELECT EXISTS(
        SELECT 1 
        FROM estoque_movimentacoes 
        WHERE pedido_id = p_pedido_id 
        AND observacao LIKE '%Finalização pedido%'
    ) INTO v_ja_finalizado;
    
    IF v_ja_finalizado THEN
        RAISE EXCEPTION 'Este pedido já tem movimentações de estoque registradas';
    END IF;

    -- Processar itens do pedido
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
                    
                    -- VALIDAÇÃO: Estoque suficiente para venda
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

-- 2. Atualizar função cancelar_pedido_definitivo com LOCK e validação
CREATE OR REPLACE FUNCTION cancelar_pedido_definitivo(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_estoque_atual DECIMAL;
    v_ja_cancelado BOOLEAN;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA - antes de qualquer leitura)
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    -- PROTEÇÃO 1: Verificar se já foi cancelado
    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Este pedido já foi cancelado anteriormente';
    END IF;
    
    -- PROTEÇÃO 2: Verificar se já existem movimentações de cancelamento
    SELECT EXISTS(
        SELECT 1 
        FROM estoque_movimentacoes 
        WHERE pedido_id = p_pedido_id 
        AND observacao LIKE '%Cancelamento definitivo%'
    ) INTO v_ja_cancelado;
    
    IF v_ja_cancelado THEN
        RAISE EXCEPTION 'Este pedido já tem movimentações de cancelamento registradas';
    END IF;
    
    -- PROTEÇÃO 3: Só pode cancelar se FINALIZADO
    IF v_status != 'FINALIZADO' THEN
        RAISE EXCEPTION 'Apenas pedidos finalizados podem ser cancelados definitivamente. Status atual: %', v_status;
    END IF;
    
    -- VALIDAÇÃO DE ESTOQUE ANTES DE QUALQUER ALTERAÇÃO (COM LOCK!)
    IF v_tipo_pedido = 'COMPRA' THEN
        -- Para cancelar COMPRA, precisa REMOVER do estoque
        -- Verificar se há estoque suficiente COM LOCK para evitar race conditions
        FOR v_item IN
            SELECT 
                pi.produto_id,
                pi.sabor_id,
                pi.quantidade,
                ps.quantidade as estoque_atual,
                ps.sabor,
                p.codigo as produto_codigo
            FROM pedido_itens pi
            JOIN produto_sabores ps ON ps.id = pi.sabor_id
            JOIN produtos p ON p.id = pi.produto_id
            WHERE pi.pedido_id = p_pedido_id
            FOR UPDATE OF ps  -- 🔒 LOCK nos registros de estoque DURANTE A VALIDAÇÃO!
        LOOP
            IF v_item.sabor_id IS NOT NULL THEN
                RAISE NOTICE 'Validando: Produto % (%) - Estoque atual: %, Quantidade pedido: %',
                    v_item.produto_codigo, v_item.sabor, v_item.estoque_atual, v_item.quantidade;
                
                IF v_item.estoque_atual < v_item.quantidade THEN
                    RAISE EXCEPTION 'BLOQUEIO: Não é possível cancelar esta compra! O produto % (%) já foi vendido. Estoque atual: %, tentando remover: %. Faltam: % unidades.',
                        v_item.produto_codigo, 
                        v_item.sabor, 
                        v_item.estoque_atual, 
                        v_item.quantidade,
                        (v_item.quantidade - v_item.estoque_atual);
                END IF;
            END IF;
        END LOOP;
    END IF;
    
    -- Se passou na validação, processar cancelamento
    FOR v_item IN
        SELECT produto_id, sabor_id, quantidade
        FROM pedido_itens
        WHERE pedido_id = p_pedido_id
    LOOP
        IF v_item.sabor_id IS NOT NULL THEN
            DECLARE
                v_estoque_anterior DECIMAL;
                v_estoque_novo DECIMAL;
                v_quantidade_ajuste DECIMAL;
            BEGIN
                -- Buscar estoque COM LOCK (já tem lock da validação acima)
                SELECT quantidade INTO v_estoque_anterior
                FROM produto_sabores
                WHERE id = v_item.sabor_id
                FOR UPDATE;
                
                -- Reverter movimentação
                IF v_tipo_pedido = 'COMPRA' THEN
                    -- COMPRA foi ENTRADA, agora precisa SAIR
                    v_quantidade_ajuste := -v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    -- VENDA foi SAÍDA, agora precisa ENTRAR (devolver)
                    v_quantidade_ajuste := v_item.quantidade;
                END IF;
                
                -- Atualizar estoque
                UPDATE produto_sabores
                SET quantidade = quantidade + v_quantidade_ajuste
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_estoque_novo;
                
                RAISE NOTICE 'Revertendo: Ajuste %, Estoque % → %', 
                    v_quantidade_ajuste, v_estoque_anterior, v_estoque_novo;
                
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
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'SAIDA' ELSE 'ENTRADA' END,
                    v_item.quantidade,
                    v_estoque_anterior,
                    v_estoque_novo,
                    p_usuario_id,
                    p_pedido_id,
                    'Ajuste - Cancelamento definitivo'
                );
            END;
        END IF;
    END LOOP;
    
    -- Atualizar status do pedido
    UPDATE pedidos
    SET 
        status = 'CANCELADO',
        aprovador_id = p_usuario_id
    WHERE id = p_pedido_id;
    
    RAISE NOTICE '✅ Cancelamento concluído com sucesso';
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 3. Comentários explicativos
COMMENT ON FUNCTION finalizar_pedido IS 'Finaliza pedido com proteção contra duplicação e locks de transação (FOR UPDATE)';
COMMENT ON FUNCTION cancelar_pedido_definitivo IS 'Cancela pedido com validação de estoque e locks de transação';

-- 4. Testar as funções (DESCOMENTE para executar testes)
-- SELECT 'Proteções com LOCK aplicadas com sucesso!' as resultado;
