-- =====================================================
-- CORREÇÃO: Impedir registro de movimentação após erro
-- =====================================================

-- Esta função corrige o cancelamento no JavaScript também
-- Mas primeiro, vamos garantir que a função SQL não registra
-- movimentação se der erro

-- Verificar se a função já tem a validação
SELECT 
    proname as funcao,
    prosrc as codigo
FROM pg_proc
WHERE proname = 'cancelar_pedido_definitivo'
LIMIT 1;

-- A função cancelar_pedido_definitivo agora tem validação
-- Mas o problema é que o JavaScript está usando outra função

-- Vamos criar uma função auxiliar para validar estoque
CREATE OR REPLACE FUNCTION validar_estoque_para_cancelamento(
    p_pedido_id UUID
)
RETURNS JSON AS $$
DECLARE
    v_pedido RECORD;
    v_item RECORD;
    v_bloqueios JSON[] := ARRAY[]::JSON[];
BEGIN
    -- Buscar pedido
    SELECT * INTO v_pedido
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object('valido', false, 'erro', 'Pedido não encontrado');
    END IF;
    
    -- Só validar se for COMPRA FINALIZADA
    IF v_pedido.tipo_pedido = 'COMPRA' AND v_pedido.status = 'FINALIZADO' THEN
        FOR v_item IN 
            SELECT 
                pi.*,
                ps.quantidade as estoque_atual,
                ps.sabor,
                p.codigo
            FROM pedido_itens pi
            LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
            LEFT JOIN produtos p ON p.id = pi.produto_id
            WHERE pi.pedido_id = p_pedido_id
        LOOP
            IF v_item.sabor_id IS NOT NULL THEN
                -- Verificar se há estoque suficiente
                IF v_item.estoque_atual < v_item.quantidade THEN
                    v_bloqueios := array_append(v_bloqueios, json_build_object(
                        'produto', v_item.codigo,
                        'sabor', v_item.sabor,
                        'estoque_atual', v_item.estoque_atual,
                        'quantidade_necessaria', v_item.quantidade,
                        'faltam', v_item.quantidade - v_item.estoque_atual
                    ));
                END IF;
            END IF;
        END LOOP;
    END IF;
    
    IF array_length(v_bloqueios, 1) > 0 THEN
        RETURN json_build_object(
            'valido', false, 
            'bloqueios', v_bloqueios,
            'mensagem', 'Produtos já foram vendidos e não há estoque suficiente para cancelar'
        );
    END IF;
    
    RETURN json_build_object('valido', true);
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION validar_estoque_para_cancelamento IS 
'Valida se há estoque suficiente para cancelar um pedido de compra, SEM fazer alterações';
