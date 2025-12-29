-- =====================================================
-- MÓDULO DE VENDAS - EXTENSÃO DO SISTEMA
-- Execute este script no Supabase após o schema.sql
-- =====================================================

-- =====================================================
-- 1. TABELA DE CLIENTES
-- =====================================================
CREATE TABLE IF NOT EXISTS clientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(255) NOT NULL,
    cpf_cnpj VARCHAR(18) UNIQUE,
    tipo VARCHAR(10) CHECK (tipo IN ('FISICA', 'JURIDICA')),
    contato VARCHAR(255),
    whatsapp VARCHAR(20),
    email VARCHAR(255),
    endereco TEXT,
    cidade VARCHAR(100),
    estado VARCHAR(2),
    cep VARCHAR(10),
    active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_clientes_cpf_cnpj ON clientes(cpf_cnpj);
CREATE INDEX idx_clientes_active ON clientes(active);
CREATE INDEX idx_clientes_nome ON clientes(nome);

-- Trigger para updated_at
CREATE TRIGGER update_clientes_updated_at BEFORE UPDATE ON clientes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 2. MODIFICAR TABELA PEDIDOS
-- =====================================================

-- Adicionar coluna tipo_pedido
ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS tipo_pedido VARCHAR(10) 
    DEFAULT 'COMPRA' CHECK (tipo_pedido IN ('COMPRA', 'VENDA'));

-- Adicionar coluna cliente_id
ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS cliente_id UUID REFERENCES clientes(id);

-- Tornar fornecedor_id opcional (NULL para vendas)
ALTER TABLE pedidos ALTER COLUMN fornecedor_id DROP NOT NULL;

-- Remover constraint antiga se existir
ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedido_tipo_check;

-- Adicionar constraint flexível: permite NULL em rascunho
-- Pedidos COMPRA finalizados devem ter fornecedor
-- Pedidos VENDA finalizados devem ter cliente
ALTER TABLE pedidos ADD CONSTRAINT pedido_tipo_check 
    CHECK (
        -- Permite rascunhos sem fornecedor/cliente
        (status = 'RASCUNHO') OR
        -- Pedidos de COMPRA (não rascunho) devem ter fornecedor
        (tipo_pedido = 'COMPRA' AND fornecedor_id IS NOT NULL AND cliente_id IS NULL) OR
        -- Pedidos de VENDA (não rascunho) devem ter cliente
        (tipo_pedido = 'VENDA' AND cliente_id IS NOT NULL AND fornecedor_id IS NULL)
    );

-- Índices
CREATE INDEX IF NOT EXISTS idx_pedidos_tipo_pedido ON pedidos(tipo_pedido);
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(cliente_id);

-- =====================================================
-- 3. FUNÇÃO PARA FINALIZAR PEDIDO DE VENDA
-- =====================================================

-- Atualizar função de finalizar pedido para suportar COMPRA e VENDA
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

    -- Processar itens de acordo com o tipo
    FOR v_item IN 
        SELECT produto_id, quantidade 
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
                'Entrada automática - Finalização de pedido de compra'
            );
        ELSIF v_tipo_pedido = 'VENDA' THEN
            -- Pedido de venda: SAÍDA no estoque
            PERFORM processar_movimentacao_estoque(
                v_item.produto_id,
                'SAIDA',
                v_item.quantidade,
                p_usuario_id,
                p_pedido_id,
                'Saída automática - Finalização de pedido de venda'
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
-- 4. VIEW PARA RELATÓRIO DE VENDAS
-- =====================================================

CREATE OR REPLACE VIEW vw_vendas_resumo AS
SELECT 
    p.id,
    p.numero,
    p.created_at as data_venda,
    c.nome as cliente_nome,
    c.cpf_cnpj as cliente_documento,
    u.full_name as vendedor,
    p.total,
    p.status,
    COUNT(pi.id) as total_itens
FROM pedidos p
LEFT JOIN clientes c ON p.cliente_id = c.id
LEFT JOIN users u ON p.solicitante_id = u.id
LEFT JOIN pedido_itens pi ON p.id = pi.pedido_id
WHERE p.tipo_pedido = 'VENDA'
GROUP BY p.id, c.nome, c.cpf_cnpj, u.full_name;

-- =====================================================
-- 5. POLÍTICAS RLS PARA CLIENTES
-- =====================================================

-- Habilitar RLS
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;

-- Políticas simples
CREATE POLICY "clientes_select"
    ON clientes FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "clientes_insert"
    ON clientes FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "clientes_update"
    ON clientes FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "clientes_delete"
    ON clientes FOR DELETE
    TO authenticated
    USING (true);

-- =====================================================
-- 6. DADOS DE EXEMPLO (OPCIONAL)
-- =====================================================

-- Inserir alguns clientes de exemplo
INSERT INTO clientes (nome, cpf_cnpj, tipo, email, whatsapp, endereco, cidade, estado, cep, active)
VALUES 
    ('João Silva', '123.456.789-00', 'FISICA', 'joao@email.com', '5511999998888', 'Rua A, 123', 'São Paulo', 'SP', '01000-000', true),
    ('Empresa ABC Ltda', '12.345.678/0001-99', 'JURIDICA', 'contato@empresaabc.com', '5511988887777', 'Av. Paulista, 1000', 'São Paulo', 'SP', '01310-100', true),
    ('Maria Santos', '987.654.321-00', 'FISICA', 'maria@email.com', '5511977776666', 'Rua B, 456', 'São Paulo', 'SP', '02000-000', true)
ON CONFLICT (cpf_cnpj) DO NOTHING;

-- =====================================================
-- CONFIRMAÇÃO
-- =====================================================

SELECT 'MÓDULO DE VENDAS INSTALADO COM SUCESSO!' as status;
SELECT 'Tabela clientes criada' as tabela_1;
SELECT 'Pedidos adaptados para COMPRA/VENDA' as tabela_2;
SELECT 'Função finalizar_pedido atualizada' as funcao;
SELECT 'Políticas RLS criadas' as seguranca;
