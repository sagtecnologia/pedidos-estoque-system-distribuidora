-- =====================================================
-- MIGRAÇÃO: CORRIGIR MOVIMENTAÇÃO ESTOQUE COM SABORES
-- =====================================================
-- Data: 2025-12-19
-- Descrição: Atualiza funções de movimentação para considerar sabores individuais
-- =====================================================

-- =====================================================
-- 1. ATUALIZAR FUNÇÃO processar_movimentacao_estoque
-- =====================================================
-- Adicionar parâmetro p_sabor_id e atualizar produto_sabores

CREATE OR REPLACE FUNCTION processar_movimentacao_estoque(
    p_produto_id UUID,
    p_tipo VARCHAR,
    p_quantidade DECIMAL,
    p_usuario_id UUID,
    p_pedido_id UUID DEFAULT NULL,
    p_observacao TEXT DEFAULT NULL,
    p_sabor_id UUID DEFAULT NULL  -- NOVO: ID do sabor
)
RETURNS UUID AS $$
DECLARE
    v_estoque_anterior DECIMAL;
    v_estoque_novo DECIMAL;
    v_movimentacao_id UUID;
    v_sabor_qtd_anterior DECIMAL;
    v_sabor_qtd_nova DECIMAL;
BEGIN
    -- Buscar estoque atual do produto
    SELECT estoque_atual INTO v_estoque_anterior
    FROM produtos
    WHERE id = p_produto_id;

    -- Calcular novo estoque do produto (será recalculado pelo trigger)
    IF p_tipo = 'ENTRADA' THEN
        v_estoque_novo := v_estoque_anterior + p_quantidade;
    ELSE
        v_estoque_novo := v_estoque_anterior - p_quantidade;
    END IF;

    -- Se foi informado sabor_id, atualizar quantidade do sabor
    IF p_sabor_id IS NOT NULL THEN
        -- Buscar quantidade atual do sabor
        SELECT quantidade INTO v_sabor_qtd_anterior
        FROM produto_sabores
        WHERE id = p_sabor_id;

        -- Calcular nova quantidade do sabor
        IF p_tipo = 'ENTRADA' THEN
            v_sabor_qtd_nova := v_sabor_qtd_anterior + p_quantidade;
        ELSE
            v_sabor_qtd_nova := v_sabor_qtd_anterior - p_quantidade;
        END IF;

        -- Verificar se há estoque suficiente do sabor para saída
        IF p_tipo = 'SAIDA' AND v_sabor_qtd_nova < 0 THEN
            RAISE EXCEPTION 'Estoque insuficiente do sabor para realizar a saída';
        END IF;

        -- Atualizar quantidade do sabor
        UPDATE produto_sabores
        SET quantidade = v_sabor_qtd_nova
        WHERE id = p_sabor_id;

        -- O trigger atualizar_estoque_produto() irá somar todos os sabores
        -- e atualizar automaticamente o estoque_atual do produto
        
    ELSE
        -- Sem sabor informado: verificar estoque total do produto
        IF p_tipo = 'SAIDA' AND v_estoque_novo < 0 THEN
            RAISE EXCEPTION 'Estoque insuficiente para realizar a saída';
        END IF;

        -- Atualizar estoque do produto manualmente (quando não há sabor)
        UPDATE produtos
        SET estoque_atual = v_estoque_novo
        WHERE id = p_produto_id;
    END IF;

    -- Criar registro de movimentação com sabor_id
    INSERT INTO estoque_movimentacoes (
        produto_id, tipo, quantidade, estoque_anterior, estoque_novo,
        pedido_id, usuario_id, observacao, sabor_id
    ) VALUES (
        p_produto_id, p_tipo, p_quantidade, v_estoque_anterior, v_estoque_novo,
        p_pedido_id, p_usuario_id, p_observacao, p_sabor_id
    ) RETURNING id INTO v_movimentacao_id;

    RETURN v_movimentacao_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. ATUALIZAR FUNÇÃO finalizar_pedido
-- =====================================================
-- Passar sabor_id para processar_movimentacao_estoque

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
    
    IF v_status != 'APROVADO' THEN
        RAISE EXCEPTION 'Apenas pedidos aprovados podem ser finalizados';
    END IF;

    -- Processar itens de acordo com o tipo (agora incluindo sabor_id)
    FOR v_item IN 
        SELECT produto_id, quantidade, sabor_id
        FROM pedido_itens 
        WHERE pedido_id = p_pedido_id
    LOOP
        IF v_tipo_pedido = 'COMPRA' THEN
            -- Pedido de compra: ENTRADA no estoque
            PERFORM processar_movimentacao_estoque(
                v_item.produto_id,
                'ENTRADA',
                v_item.quantidade,
                p_usuario_id,
                p_pedido_id,
                'Entrada automática - Finalização de pedido de compra',
                v_item.sabor_id  -- Passar sabor_id
            );
        ELSIF v_tipo_pedido = 'VENDA' THEN
            -- Pedido de venda: SAÍDA no estoque
            PERFORM processar_movimentacao_estoque(
                v_item.produto_id,
                'SAIDA',
                v_item.quantidade,
                p_usuario_id,
                p_pedido_id,
                'Saída automática - Finalização de pedido de venda',
                v_item.sabor_id  -- Passar sabor_id
            );
        END IF;
    END LOOP;

    -- Atualizar status do pedido
    UPDATE pedidos 
    SET status = 'FINALIZADO', 
        data_finalizacao = NOW()
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

SELECT 'Funções atualizadas com sucesso!' as status;
SELECT 'processar_movimentacao_estoque agora aceita p_sabor_id' as funcao1;
SELECT 'finalizar_pedido agora passa sabor_id para movimentações' as funcao2;
SELECT 'Quantidade de sabores será atualizada automaticamente' as funcao3;

-- =====================================================
-- INSTRUÇÕES DE USO
-- =====================================================
-- 1. Execute este script no SQL Editor do Supabase
-- 2. As funções serão atualizadas para considerar sabores
-- 3. Movimentações de estoque atualizarão produto_sabores.quantidade
-- 4. O trigger atualizar_estoque_produto() somará os sabores automaticamente
-- 5. Teste criando um pedido de compra/venda e finalizando
-- =====================================================
