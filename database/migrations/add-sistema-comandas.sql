-- =====================================================
-- MIGRAÇÃO: Sistema de Comandas (Vendas Abertas)
-- Descrição: Controle de vendas em aberto para consumo no local
-- Data: 2025
-- =====================================================

-- Tabela: comandas
-- Armazena vendas em aberto (mesas, balcão, delivery)
CREATE TABLE IF NOT EXISTS comandas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_comanda VARCHAR(20) UNIQUE NOT NULL, -- Ex: Mesa 1, Comanda 001, Balcão 5
    numero_mesa VARCHAR(10),                    -- Número da mesa (opcional)
    tipo VARCHAR(20) DEFAULT 'mesa'             -- 'mesa', 'balcao', 'delivery'
        CHECK (tipo IN ('mesa', 'balcao', 'delivery')),
    cliente_id UUID REFERENCES clientes(id),    -- Cliente (opcional)
    cliente_nome VARCHAR(255),                  -- Nome do cliente (se não cadastrado)
    status VARCHAR(20) DEFAULT 'aberta'         -- 'aberta', 'fechada', 'cancelada'
        CHECK (status IN ('aberta', 'fechada', 'cancelada')),
    data_abertura TIMESTAMP DEFAULT NOW(),
    data_fechamento TIMESTAMP,
    usuario_abertura_id UUID REFERENCES users(id),
    usuario_fechamento_id UUID REFERENCES users(id),
    
    -- Valores
    subtotal DECIMAL(10, 2) DEFAULT 0,
    desconto DECIMAL(10, 2) DEFAULT 0,
    acrescimo DECIMAL(10, 2) DEFAULT 0,
    valor_total DECIMAL(10, 2) DEFAULT 0,
    
    -- Observações
    observacoes TEXT,
    
    -- Venda gerada ao fechar comanda
    venda_id UUID REFERENCES vendas(id),
    
    -- Auditoria
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tabela: comanda_itens
-- Itens adicionados à comanda
CREATE TABLE IF NOT EXISTS comanda_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    comanda_id UUID NOT NULL REFERENCES comandas(id) ON DELETE CASCADE,
    produto_id UUID NOT NULL REFERENCES produtos(id),
    
    -- Dados do produto no momento da adição
    nome_produto VARCHAR(255) NOT NULL,
    quantidade DECIMAL(10, 3) NOT NULL DEFAULT 1,
    preco_unitario DECIMAL(10, 2) NOT NULL,
    subtotal DECIMAL(10, 2) NOT NULL,
    desconto DECIMAL(10, 2) DEFAULT 0,
    
    -- Status do item
    status VARCHAR(20) DEFAULT 'pendente'       -- 'pendente', 'preparando', 'entregue', 'cancelado'
        CHECK (status IN ('pendente', 'preparando', 'entregue', 'cancelado')),
    
    -- Observações do item
    observacoes TEXT,                           -- Ex: "Sem cebola", "Bem passado"
    
    -- Usuário que adicionou
    usuario_id UUID REFERENCES users(id),
    
    -- Auditoria
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_comandas_status ON comandas(status);
CREATE INDEX IF NOT EXISTS idx_comandas_data_abertura ON comandas(data_abertura);
CREATE INDEX IF NOT EXISTS idx_comandas_numero ON comandas(numero_comanda);
CREATE INDEX IF NOT EXISTS idx_comandas_mesa ON comandas(numero_mesa);
CREATE INDEX IF NOT EXISTS idx_comanda_itens_comanda ON comanda_itens(comanda_id);
CREATE INDEX IF NOT EXISTS idx_comanda_itens_produto ON comanda_itens(produto_id);
CREATE INDEX IF NOT EXISTS idx_comanda_itens_status ON comanda_itens(status);

-- Comentários
COMMENT ON TABLE comandas IS 'Comandas/vendas em aberto para consumo no local';
COMMENT ON TABLE comanda_itens IS 'Itens adicionados às comandas abertas';
COMMENT ON COLUMN comandas.numero_comanda IS 'Identificador único da comanda (Mesa 1, Comanda 001, etc)';
COMMENT ON COLUMN comandas.tipo IS 'Tipo de atendimento: mesa, balcao ou delivery';
COMMENT ON COLUMN comandas.status IS 'Status da comanda: aberta, fechada ou cancelada';
COMMENT ON COLUMN comanda_itens.status IS 'Status do item: pendente, preparando, entregue, cancelado';

-- Função: Atualizar totais da comanda automaticamente
CREATE OR REPLACE FUNCTION atualizar_totais_comanda()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE comandas
    SET 
        subtotal = (
            SELECT COALESCE(SUM(subtotal - desconto), 0)
            FROM comanda_itens
            WHERE comanda_id = NEW.comanda_id
            AND status != 'cancelado'
        ),
        valor_total = (
            SELECT COALESCE(SUM(subtotal - desconto), 0)
            FROM comanda_itens
            WHERE comanda_id = NEW.comanda_id
            AND status != 'cancelado'
        ) - COALESCE((SELECT desconto FROM comandas WHERE id = NEW.comanda_id), 0) 
          + COALESCE((SELECT acrescimo FROM comandas WHERE id = NEW.comanda_id), 0),
        updated_at = NOW()
    WHERE id = NEW.comanda_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger: Atualizar totais quando item é inserido/atualizado/deletado
DROP TRIGGER IF EXISTS trigger_atualizar_totais_comanda_insert ON comanda_itens;
CREATE TRIGGER trigger_atualizar_totais_comanda_insert
    AFTER INSERT ON comanda_itens
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_totais_comanda();

DROP TRIGGER IF EXISTS trigger_atualizar_totais_comanda_update ON comanda_itens;
CREATE TRIGGER trigger_atualizar_totais_comanda_update
    AFTER UPDATE ON comanda_itens
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_totais_comanda();

DROP TRIGGER IF EXISTS trigger_atualizar_totais_comanda_delete ON comanda_itens;
CREATE TRIGGER trigger_atualizar_totais_comanda_delete
    AFTER DELETE ON comanda_itens
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_totais_comanda();

-- Conceder permissões (ajustar conforme seu ambiente)
GRANT ALL ON comandas TO authenticated;
GRANT ALL ON comanda_itens TO authenticated;

-- =====================================================
-- FIM DA MIGRAÇÃO
-- =====================================================

-- DICAS DE USO:
-- 1. Para abrir uma nova comanda:
--    INSERT INTO comandas (numero_comanda, tipo, usuario_abertura_id)
--    VALUES ('Mesa 5', 'mesa', 'xxxx-xxx-xxx-xxxx');
--
-- 2. Para adicionar item à comanda:
--    INSERT INTO comanda_itens (comanda_id, produto_id, nome_produto, quantidade, preco_unitario, subtotal, usuario_id)
--    VALUES (1, 10, 'Coca-Cola 2L', 2, 8.90, 17.80, 'xxxx-xxx-xxx-xxxx');
--
-- 3. Para fechar comanda:
--    UPDATE comandas SET status = 'fechada', data_fechamento = NOW()
--    WHERE id = 1;
--
-- 4. Para consultar comandas abertas:
--    SELECT * FROM comandas WHERE status = 'aberta' ORDER BY data_abertura DESC;
