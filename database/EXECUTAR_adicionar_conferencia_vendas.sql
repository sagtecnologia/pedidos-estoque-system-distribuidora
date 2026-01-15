-- =====================================================
-- ADICIONAR SISTEMA DE CONFERÊNCIA/SEPARAÇÃO DE VENDAS
-- =====================================================
-- Execute este SQL para adicionar o fluxo de separação e despacho
-- IMPORTANTE: Usa campo 'status_envio' separado, não afeta 'status' existente

-- 1. Adicionar campo status_envio (controle logístico separado)
ALTER TABLE pedidos 
    ADD COLUMN IF NOT EXISTS status_envio VARCHAR(30),
    ADD CONSTRAINT pedidos_status_envio_check 
    CHECK (status_envio IN ('AGUARDANDO_SEPARACAO', 'SEPARADO', 'DESPACHADO'));

-- 2. Adicionar campos de controle de separação
ALTER TABLE pedidos 
    ADD COLUMN IF NOT EXISTS data_separacao TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS separado_por UUID REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS data_despacho TIMESTAMP WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS despachado_por UUID REFERENCES users(id);

-- 3. Adicionar campos de conferência nos itens
ALTER TABLE pedido_itens 
    ADD COLUMN IF NOT EXISTS conferido BOOLEAN DEFAULT false,
    ADD COLUMN IF NOT EXISTS conferido_por UUID REFERENCES users(id),
    ADD COLUMN IF NOT EXISTS data_conferencia TIMESTAMP WITH TIME ZONE;

-- 4. Criar índices para performance
CREATE INDEX IF NOT EXISTS idx_pedido_itens_conferido ON pedido_itens(conferido);
CREATE INDEX IF NOT EXISTS idx_pedidos_status_envio ON pedidos(status_envio);
CREATE INDEX IF NOT EXISTS idx_pedidos_data_separacao ON pedidos(data_separacao);
CREATE INDEX IF NOT EXISTS idx_pedidos_data_despacho ON pedidos(data_despacho);

-- 5. Criar view para vendas aguardando separação
CREATE OR REPLACE VIEW vw_vendas_aguardando_separacao AS
SELECT 
    p.id,
    p.numero,
    p.created_at,
    p.data_finalizacao,
    c.nome as cliente_nome,
    c.whatsapp as cliente_whatsapp,
    u.full_name as vendedor,
    p.total,
    COUNT(pi.id) as total_itens,
    COALESCE(SUM(CASE WHEN pi.conferido = true THEN 1 ELSE 0 END), 0) as itens_conferidos,
    CASE 
        WHEN COUNT(pi.id) = COALESCE(SUM(CASE WHEN pi.conferido = true THEN 1 ELSE 0 END), 0) 
        THEN true 
        ELSE false 
    END as todos_conferidos
FROM pedidos p
INNER JOIN clientes c ON p.cliente_id = c.id
INNER JOIN users u ON p.solicitante_id = u.id
LEFT JOIN pedido_itens pi ON p.id = pi.pedido_id
WHERE p.tipo_pedido = 'VENDA'
  AND p.status = 'FINALIZADO'
  AND (p.status_envio IS NULL OR p.status_envio = 'AGUARDANDO_SEPARACAO')
GROUP BY p.id, c.nome, c.whatsapp, u.full_name
ORDER BY p.data_finalizacao DESC;

-- 6. Criar view para vendas separadas aguardando despacho
CREATE OR REPLACE VIEW vw_vendas_aguardando_despacho AS
SELECT 
    p.id,
    p.numero,
    p.data_finalizacao,
    p.data_separacao,
    c.nome as cliente_nome,
    c.whatsapp as cliente_whatsapp,
    c.endereco,
    c.cidade,
    c.estado,
    u.full_name as vendedor,
    us.full_name as separado_por_nome,
    p.total,
    COUNT(pi.id) as total_itens
FROM pedidos p
INNER JOIN clientes c ON p.cliente_id = c.id
INNER JOIN users u ON p.solicitante_id = u.id
LEFT JOIN users us ON p.separado_por = us.id
LEFT JOIN pedido_itens pi ON p.id = pi.pedido_id
WHERE p.tipo_pedido = 'VENDA'
  AND p.status = 'FINALIZADO'
  AND p.status_envio = 'SEPARADO'
GROUP BY p.id, c.nome, c.whatsapp, c.endereco, c.cidade, c.estado, u.full_name, us.full_name
ORDER BY p.data_separacao DESC;

-- 7. Criar função para marcar item como conferido
CREATE OR REPLACE FUNCTION conferir_item_pedido(
    p_item_id UUID,
    p_usuario_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE pedido_itens
    SET 
        conferido = true,
        conferido_por = p_usuario_id,
        data_conferencia = NOW()
    WHERE id = p_item_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- 8. Criar função para marcar pedido como separado
CREATE OR REPLACE FUNCTION marcar_pedido_separado(
    p_pedido_id UUID,
    p_usuario_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
    v_status VARCHAR;
    v_todos_conferidos BOOLEAN;
BEGIN
    -- Verificar status atual
    SELECT status INTO v_status
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF v_status != 'FINALIZADO' THEN
        RAISE EXCEPTION 'Apenas pedidos FINALIZADOS podem ser marcados como SEPARADO';
    END IF;
    
    -- Verificar se todos os itens foram conferidos
    SELECT 
        COUNT(*) = COALESCE(SUM(CASE WHEN conferido = true THEN 1 ELSE 0 END), 0)
    INTO v_todos_conferidos
    FROM pedido_itens
    WHERE pedido_id = p_pedido_id;
    
    IF NOT v_todos_conferidos THEN
        RAISE EXCEPTION 'Todos os itens devem ser conferidos antes de marcar como SEPARADO';
    END IF;
    
    -- Atualizar pedido (status_envio)
    UPDATE pedidos
    SET 
        status_envio = 'SEPARADO',
        data_separacao = NOW(),
        separado_por = p_usuario_id
    WHERE id = p_pedido_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- 9. Criar função para marcar pedido como despachado
CREATE OR REPLACE FUNCTION marcar_pedido_despachado(
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
        RAISE EXCEPTION 'Apenas pedidos SEPARADOS podem ser marcados como DESPACHADO';
    END IF;
    
    -- Atualizar pedido (status_envio)
    UPDATE pedidos
    SET 
        status_envio = 'DESPACHADO',
        data_despacho = NOW(),
        despachado_por = p_usuario_id
    WHERE id = p_pedido_id;
    
    RETURN true;
END;
$$ LANGUAGE plpgsql;

-- 10. Comentários
COMMENT ON COLUMN pedidos.status_envio IS 'Status do fluxo logístico: AGUARDANDO_SEPARACAO, SEPARADO, DESPACHADO';
COMMENT ON COLUMN pedidos.data_separacao IS 'Data em que o pedido foi separado/conferido';
COMMENT ON COLUMN pedidos.separado_por IS 'Usuário que separou o pedido';
COMMENT ON COLUMN pedidos.data_despacho IS 'Data em que o pedido foi despachado/enviado';
COMMENT ON COLUMN pedidos.despachado_por IS 'Usuário que despachou o pedido';
COMMENT ON COLUMN pedido_itens.conferido IS 'Item foi conferido na separação';
COMMENT ON COLUMN pedido_itens.conferido_por IS 'Usuário que conferiu o item';
COMMENT ON COLUMN pedido_itens.data_conferencia IS 'Data/hora da conferência do item';

SELECT '✅ SISTEMA DE CONFERÊNCIA/SEPARAÇÃO INSTALADO COM SUCESSO!' as resultado,
       'Campo status_envio criado (não afeta status existente)' as observacao,
       'Valores status_envio: AGUARDANDO_SEPARACAO, SEPARADO, DESPACHADO' as valores,
       'Views: vw_vendas_aguardando_separacao, vw_vendas_aguardando_despacho' as views,
       'Funções: conferir_item_pedido, marcar_pedido_separado, marcar_pedido_despachado' as funcoes;
