-- =====================================================
-- SISTEMA DE PEDIDOS DE COMPRA E CONTROLE DE ESTOQUE
-- Schema SQL para Supabase (PostgreSQL)
-- =====================================================

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =====================================================
-- 1. TABELA DE USUÁRIOS (extends auth.users)
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('ADMIN', 'COMPRADOR', 'APROVADOR', 'VENDEDOR')),
    whatsapp VARCHAR(20),
    active BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_users_role ON users(role);
CREATE INDEX idx_users_active ON users(active);

-- =====================================================
-- 2. TABELA DE PRODUTOS
-- =====================================================
CREATE TABLE IF NOT EXISTS produtos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    categoria VARCHAR(100),
    unidade VARCHAR(20) NOT NULL,
    estoque_atual DECIMAL(10,2) DEFAULT 0,
    estoque_minimo DECIMAL(10,2) DEFAULT 0,
    preco_compra DECIMAL(10,2) DEFAULT 0,
    preco_venda DECIMAL(10,2) DEFAULT 0,
    preco DECIMAL(10,2) DEFAULT 0, -- Manter para compatibilidade (será igual a preco_venda)
    active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_produtos_codigo ON produtos(codigo);
CREATE INDEX idx_produtos_categoria ON produtos(categoria);
CREATE INDEX idx_produtos_active ON produtos(active);
CREATE INDEX idx_produtos_estoque_baixo ON produtos(estoque_atual) WHERE estoque_atual <= estoque_minimo;

-- =====================================================
-- 3. TABELA DE FORNECEDORES
-- =====================================================
CREATE TABLE IF NOT EXISTS fornecedores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(255) NOT NULL,
    cnpj VARCHAR(18) UNIQUE,
    contato VARCHAR(255),
    whatsapp VARCHAR(20),
    email VARCHAR(255),
    endereco TEXT,
    active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_fornecedores_cnpj ON fornecedores(cnpj);
CREATE INDEX idx_fornecedores_active ON fornecedores(active);

-- =====================================================
-- 3B. TABELA DE CLIENTES
-- =====================================================
CREATE TABLE IF NOT EXISTS clientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(255) NOT NULL,
    tipo VARCHAR(10) NOT NULL DEFAULT 'FISICA' CHECK (tipo IN ('FISICA', 'JURIDICA')),
    cpf_cnpj VARCHAR(18) UNIQUE,
    email VARCHAR(255),
    contato VARCHAR(20),
    whatsapp VARCHAR(20),
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
CREATE INDEX idx_clientes_tipo ON clientes(tipo);
CREATE INDEX idx_clientes_active ON clientes(active);

-- =====================================================
-- 4. TABELA DE PEDIDOS
-- =====================================================
CREATE TABLE IF NOT EXISTS pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(50) UNIQUE NOT NULL,
    tipo_pedido VARCHAR(10) NOT NULL DEFAULT 'COMPRA' CHECK (tipo_pedido IN ('COMPRA', 'VENDA')),
    solicitante_id UUID REFERENCES users(id) NOT NULL,
    fornecedor_id UUID REFERENCES fornecedores(id),
    cliente_id UUID REFERENCES clientes(id),
    status VARCHAR(20) NOT NULL DEFAULT 'RASCUNHO' CHECK (status IN ('RASCUNHO', 'ENVIADO', 'APROVADO', 'REJEITADO', 'FINALIZADO')),
    total DECIMAL(10,2) DEFAULT 0,
    observacoes TEXT,
    aprovador_id UUID REFERENCES users(id),
    data_aprovacao TIMESTAMP WITH TIME ZONE,
    motivo_rejeicao TEXT,
    data_finalizacao TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_pedidos_numero ON pedidos(numero);
CREATE INDEX idx_pedidos_tipo ON pedidos(tipo_pedido);
CREATE INDEX idx_pedidos_status ON pedidos(status);
CREATE INDEX idx_pedidos_solicitante ON pedidos(solicitante_id);
CREATE INDEX idx_pedidos_fornecedor ON pedidos(fornecedor_id);
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
CREATE INDEX idx_pedidos_aprovador ON pedidos(aprovador_id);
CREATE INDEX idx_pedidos_created_at ON pedidos(created_at DESC);

-- =====================================================
-- 5. TABELA DE ITENS DO PEDIDO
-- =====================================================
CREATE TABLE IF NOT EXISTS pedido_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE NOT NULL,
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    quantidade DECIMAL(10,2) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_pedido_itens_pedido ON pedido_itens(pedido_id);
CREATE INDEX idx_pedido_itens_produto ON pedido_itens(produto_id);

-- =====================================================
-- 6. TABELA DE MOVIMENTAÇÕES DE ESTOQUE
-- =====================================================
CREATE TABLE IF NOT EXISTS estoque_movimentacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA')),
    quantidade DECIMAL(10,2) NOT NULL,
    estoque_anterior DECIMAL(10,2) NOT NULL,
    estoque_novo DECIMAL(10,2) NOT NULL,
    pedido_id UUID REFERENCES pedidos(id),
    usuario_id UUID REFERENCES users(id) NOT NULL,
    observacao TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX idx_estoque_mov_produto ON estoque_movimentacoes(produto_id);
CREATE INDEX idx_estoque_mov_pedido ON estoque_movimentacoes(pedido_id);
CREATE INDEX idx_estoque_mov_created_at ON estoque_movimentacoes(created_at DESC);

-- =====================================================
-- TRIGGERS E FUNÇÕES
-- =====================================================

-- Função para atualizar updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers para updated_at
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_produtos_updated_at BEFORE UPDATE ON produtos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_fornecedores_updated_at BEFORE UPDATE ON fornecedores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clientes_updated_at BEFORE UPDATE ON clientes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pedidos_updated_at BEFORE UPDATE ON pedidos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Função para atualizar total do pedido
CREATE OR REPLACE FUNCTION update_pedido_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE pedidos 
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM pedido_itens
        WHERE pedido_id = NEW.pedido_id
    )
    WHERE id = NEW.pedido_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para calcular total do pedido
CREATE TRIGGER update_pedido_total_trigger
AFTER INSERT OR UPDATE OR DELETE ON pedido_itens
FOR EACH ROW EXECUTE FUNCTION update_pedido_total();

-- Função para criar movimentação de estoque e atualizar estoque do produto
CREATE OR REPLACE FUNCTION processar_movimentacao_estoque(
    p_produto_id UUID,
    p_tipo VARCHAR,
    p_quantidade DECIMAL,
    p_usuario_id UUID,
    p_pedido_id UUID DEFAULT NULL,
    p_observacao TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_estoque_anterior DECIMAL;
    v_estoque_novo DECIMAL;
    v_movimentacao_id UUID;
BEGIN
    -- Buscar estoque atual
    SELECT estoque_atual INTO v_estoque_anterior
    FROM produtos
    WHERE id = p_produto_id;

    -- Calcular novo estoque
    IF p_tipo = 'ENTRADA' THEN
        v_estoque_novo := v_estoque_anterior + p_quantidade;
    ELSE
        v_estoque_novo := v_estoque_anterior - p_quantidade;
    END IF;

    -- Verificar se há estoque suficiente para saída
    IF p_tipo = 'SAIDA' AND v_estoque_novo < 0 THEN
        RAISE EXCEPTION 'Estoque insuficiente para realizar a saída';
    END IF;

    -- Atualizar estoque do produto
    UPDATE produtos
    SET estoque_atual = v_estoque_novo
    WHERE id = p_produto_id;

    -- Criar registro de movimentação
    INSERT INTO estoque_movimentacoes (
        produto_id, tipo, quantidade, estoque_anterior, estoque_novo,
        pedido_id, usuario_id, observacao
    ) VALUES (
        p_produto_id, p_tipo, p_quantidade, v_estoque_anterior, v_estoque_novo,
        p_pedido_id, p_usuario_id, p_observacao
    ) RETURNING id INTO v_movimentacao_id;

    RETURN v_movimentacao_id;
END;
$$ LANGUAGE plpgsql;

-- Função para finalizar pedido e dar baixa no estoque
CREATE OR REPLACE FUNCTION finalizar_pedido(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
BEGIN
    -- Verificar status do pedido
    SELECT status INTO v_status FROM pedidos WHERE id = p_pedido_id;
    
    IF v_status != 'APROVADO' THEN
        RAISE EXCEPTION 'Apenas pedidos aprovados podem ser finalizados';
    END IF;

    -- Processar baixa de cada item
    FOR v_item IN 
        SELECT produto_id, quantidade 
        FROM pedido_itens 
        WHERE pedido_id = p_pedido_id
    LOOP
        PERFORM processar_movimentacao_estoque(
            v_item.produto_id,
            'SAIDA',
            v_item.quantidade,
            p_usuario_id,
            p_pedido_id,
            'Baixa automática - Finalização de pedido'
        );
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
-- ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Habilitar RLS em todas as tabelas
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE fornecedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE estoque_movimentacoes ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- POLICIES - USERS
-- =====================================================

-- Todos podem ver usuários ativos
CREATE POLICY "Usuários podem ver outros usuários ativos"
    ON users FOR SELECT
    USING (active = true);

-- Usuários podem ver seus próprios dados
CREATE POLICY "Usuários podem ver seus próprios dados"
    ON users FOR SELECT
    USING (auth.uid() = id);

-- Usuários podem se auto-inserir durante cadastro (active=false)
CREATE POLICY "Usuários podem se cadastrar"
    ON users FOR INSERT
    WITH CHECK (
        auth.uid() = id AND active = false
    );

-- Apenas ADMIN pode atualizar/deletar usuários
CREATE POLICY "Apenas ADMIN pode gerenciar usuários"
    ON users FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

CREATE POLICY "Apenas ADMIN pode deletar usuários"
    ON users FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - PRODUTOS
-- =====================================================

-- Todos os usuários autenticados podem ver produtos ativos
CREATE POLICY "Usuários podem ver produtos ativos"
    ON produtos FOR SELECT
    USING (active = true);

-- ADMIN e COMPRADOR podem criar produtos
CREATE POLICY "ADMIN e COMPRADOR podem criar produtos"
    ON produtos FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- ADMIN e COMPRADOR podem atualizar produtos
CREATE POLICY "ADMIN e COMPRADOR podem atualizar produtos"
    ON produtos FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- Apenas ADMIN pode deletar produtos
CREATE POLICY "Apenas ADMIN pode deletar produtos"
    ON produtos FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - FORNECEDORES
-- =====================================================

-- Todos os usuários autenticados podem ver fornecedores ativos
CREATE POLICY "Usuários podem ver fornecedores ativos"
    ON fornecedores FOR SELECT
    USING (active = true);

-- ADMIN e COMPRADOR podem criar fornecedores
CREATE POLICY "ADMIN e COMPRADOR podem criar fornecedores"
    ON fornecedores FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- ADMIN e COMPRADOR podem atualizar fornecedores
CREATE POLICY "ADMIN e COMPRADOR podem atualizar fornecedores"
    ON fornecedores FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- Apenas ADMIN pode deletar fornecedores
CREATE POLICY "Apenas ADMIN pode deletar fornecedores"
    ON fornecedores FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - CLIENTES
-- =====================================================

-- Todos os usuários autenticados podem ver clientes ativos
CREATE POLICY "Usuários podem ver clientes ativos"
    ON clientes FOR SELECT
    USING (active = true);

-- ADMIN e COMPRADOR podem criar clientes
CREATE POLICY "ADMIN e COMPRADOR podem criar clientes"
    ON clientes FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- ADMIN e COMPRADOR podem atualizar clientes
CREATE POLICY "ADMIN e COMPRADOR podem atualizar clientes"
    ON clientes FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- Apenas ADMIN pode deletar clientes
CREATE POLICY "Apenas ADMIN pode deletar clientes"
    ON clientes FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - PEDIDOS
-- =====================================================

-- Usuários podem ver pedidos que criaram
CREATE POLICY "Usuários podem ver seus pedidos"
    ON pedidos FOR SELECT
    USING (solicitante_id = auth.uid());

-- APROVADOR pode ver pedidos enviados/aprovados/rejeitados
CREATE POLICY "APROVADOR pode ver pedidos para aprovar"
    ON pedidos FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'APROVADOR'
        )
    );

-- ADMIN pode ver todos os pedidos
CREATE POLICY "ADMIN pode ver todos os pedidos"
    ON pedidos FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- COMPRADOR pode criar pedidos
CREATE POLICY "COMPRADOR pode criar pedidos"
    ON pedidos FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('COMPRADOR', 'ADMIN')
        ) AND solicitante_id = auth.uid()
    );

-- Solicitante pode atualizar seus pedidos em RASCUNHO
CREATE POLICY "Solicitante pode atualizar seus pedidos em RASCUNHO"
    ON pedidos FOR UPDATE
    USING (
        solicitante_id = auth.uid() AND status = 'RASCUNHO'
    );

-- APROVADOR pode atualizar status para APROVADO/REJEITADO
CREATE POLICY "APROVADOR pode aprovar/rejeitar pedidos"
    ON pedidos FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('APROVADOR', 'ADMIN')
        ) AND status = 'ENVIADO'
    );

-- ADMIN pode finalizar pedidos aprovados
CREATE POLICY "ADMIN pode finalizar pedidos"
    ON pedidos FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        ) AND status = 'APROVADO'
    );

-- =====================================================
-- POLICIES - PEDIDO_ITENS
-- =====================================================

-- Usuários podem ver itens de pedidos que podem ver
CREATE POLICY "Usuários podem ver itens de seus pedidos"
    ON pedido_itens FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND (
                solicitante_id = auth.uid() 
                OR EXISTS (
                    SELECT 1 FROM users 
                    WHERE id = auth.uid() AND role IN ('APROVADOR', 'ADMIN')
                )
            )
        )
    );

-- Solicitante pode inserir itens em seus pedidos RASCUNHO
CREATE POLICY "Solicitante pode inserir itens em pedidos RASCUNHO"
    ON pedido_itens FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND solicitante_id = auth.uid() 
            AND status = 'RASCUNHO'
        )
    );

-- Solicitante pode atualizar itens em seus pedidos RASCUNHO
CREATE POLICY "Solicitante pode atualizar itens em pedidos RASCUNHO"
    ON pedido_itens FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND solicitante_id = auth.uid() 
            AND status = 'RASCUNHO'
        )
    );

-- Solicitante pode deletar itens de seus pedidos RASCUNHO
CREATE POLICY "Solicitante pode deletar itens de pedidos RASCUNHO"
    ON pedido_itens FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND solicitante_id = auth.uid() 
            AND status = 'RASCUNHO'
        )
    );

-- =====================================================
-- POLICIES - ESTOQUE_MOVIMENTACOES
-- =====================================================

-- Todos podem ver movimentações
CREATE POLICY "Todos podem ver movimentações de estoque"
    ON estoque_movimentacoes FOR SELECT
    USING (true);

-- Apenas ADMIN pode criar movimentações manuais
CREATE POLICY "ADMIN pode criar movimentações"
    ON estoque_movimentacoes FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- VIEWS ÚTEIS
-- =====================================================

-- View de produtos com estoque baixo
CREATE OR REPLACE VIEW produtos_estoque_baixo AS
SELECT 
    p.*,
    (p.estoque_minimo - p.estoque_atual) as deficit
FROM produtos p
WHERE p.active = true 
AND p.estoque_atual <= p.estoque_minimo
ORDER BY deficit DESC;

-- View de estatísticas de pedidos
CREATE OR REPLACE VIEW estatisticas_pedidos AS
SELECT 
    status,
    COUNT(*) as total,
    SUM(total) as valor_total
FROM pedidos
GROUP BY status;

-- =====================================================
-- DADOS INICIAIS (OPCIONAL)
-- =====================================================

-- =====================================================
-- USUÁRIO ADMINISTRADOR PADRÃO
-- =====================================================
-- IMPORTANTE: Este usuário admin será criado automaticamente
-- Email: brunoallencar@hotmail.com
-- Senha: Bb93163087@@
-- 
-- ATENÇÃO: Após o primeiro login, altere a senha!
-- =====================================================

-- Nota: O ID do usuário no auth.users será gerado pelo Supabase Auth
-- quando o admin fizer o primeiro login com as credenciais acima.
-- Após o login, o registro abaixo será vinculado automaticamente.

-- Se você já fez o cadastro manual do admin no Supabase Auth, 
-- substitua o UUID abaixo pelo ID real do usuário:
-- INSERT INTO users (id, email, full_name, role, active) 
-- VALUES ('SEU-UUID-AQUI', 'brunoallencar@hotmail.com', 'Administrador', 'ADMIN', true)
-- ON CONFLICT (email) DO UPDATE SET active = true, role = 'ADMIN';

-- =====================================================
-- FIM DO SCHEMA
-- =====================================================
