-- =====================================================
-- ADICIONAR FUNÇÕES PARA VOLTAR STATUS DE ENVIO
-- =====================================================
-- Permite reverter status_envio para corrigir erros

-- 1. Função para voltar SEPARADO para AGUARDANDO_SEPARACAO
CREATE OR REPLACE FUNCTION voltar_para_separacao(
    p_pedido_id UUID,
    p_usuario_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_status_envio VARCHAR;
BEGIN
    -- Verificar status_envio atual
    SELECT status_envio INTO v_status_envio
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF v_status_envio != 'SEPARADO' THEN
        RAISE EXCEPTION 'Apenas pedidos SEPARADOS podem voltar para separação';
    END IF;
    
    -- Voltar para NULL (aguardando separação)
    UPDATE pedidos
    SET 
        status_envio = NULL,
        data_separacao = NULL,
        separado_por = NULL
    WHERE id = p_pedido_id;
    
    -- Desmarcar todos os itens
    UPDATE pedido_itens
    SET 
        conferido = false,
        conferido_por = NULL,
        data_conferencia = NULL
    WHERE pedido_id = p_pedido_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- 2. Função para voltar DESPACHADO para SEPARADO
CREATE OR REPLACE FUNCTION voltar_para_despacho(
    p_pedido_id UUID,
    p_usuario_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_status_envio VARCHAR;
BEGIN
    -- Verificar status_envio atual
    SELECT status_envio INTO v_status_envio
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF v_status_envio != 'DESPACHADO' THEN
        RAISE EXCEPTION 'Apenas pedidos DESPACHADOS podem voltar para despacho';
    END IF;
    
    -- Voltar para SEPARADO
    UPDATE pedidos
    SET 
        status_envio = 'SEPARADO',
        data_despacho = NULL,
        despachado_por = NULL
    WHERE id = p_pedido_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- 3. Comentários
COMMENT ON FUNCTION voltar_para_separacao IS 'Reverte pedido SEPARADO para AGUARDANDO_SEPARACAO e desmarca itens';
COMMENT ON FUNCTION voltar_para_despacho IS 'Reverte pedido DESPACHADO para SEPARADO';

SELECT '✅ FUNÇÕES DE VOLTAR STATUS CRIADAS!' as resultado,
       'voltar_para_separacao(pedido_id, usuario_id) - SEPARADO → AGUARDANDO' as funcao1,
       'voltar_para_despacho(pedido_id, usuario_id) - DESPACHADO → SEPARADO' as funcao2;
