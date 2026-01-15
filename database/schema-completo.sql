-- =====================================================
-- SCHEMA COMPLETO - SISTEMA DE PEDIDOS E ESTOQUE
-- =====================================================
-- Data de Consolidação: 14/01/2026
-- Descrição: Schema completo integrado com todas as features
-- Incluindo: Compras, Vendas, Sabores, Pré-Pedidos, Pagamentos,
--           Proteções contra duplicação, Empresa Config
-- =====================================================

-- =====================================================
-- EXTENSÕES NECESSÁRIAS
-- =====================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- 1. TABELA DE USUÁRIOS
-- =====================================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'COMPRADOR' 
        CHECK (role IN ('ADMIN', 'COMPRADOR', 'APROVADOR', 'VENDEDOR')),
    active BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_active ON users(active);

-- =====================================================
-- 2. TABELA DE PRODUTOS
-- =====================================================
CREATE TABLE IF NOT EXISTS produtos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(50) UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    marca VARCHAR(100),
    categoria VARCHAR(100),
    unidade VARCHAR(10) NOT NULL DEFAULT 'UN',
    estoque_atual DECIMAL(10,2) DEFAULT 0,
    estoque_minimo DECIMAL(10,2) DEFAULT 0,
    preco_compra DECIMAL(10,2),
    preco_venda DECIMAL(10,2),
    preco DECIMAL(10,2),
    observacoes TEXT,
    active BOOLEAN DEFAULT true,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_produtos_codigo ON produtos(codigo);
CREATE INDEX IF NOT EXISTS idx_produtos_nome ON produtos(nome);
CREATE INDEX IF NOT EXISTS idx_produtos_marca ON produtos(marca);
CREATE INDEX IF NOT EXISTS idx_produtos_categoria ON produtos(categoria);
CREATE INDEX IF NOT EXISTS idx_produtos_active ON produtos(active);

-- =====================================================
-- 3. TABELA DE SABORES DE PRODUTOS
-- =====================================================
CREATE TABLE IF NOT EXISTS produto_sabores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    produto_id UUID REFERENCES produtos(id) ON DELETE CASCADE NOT NULL,
    sabor VARCHAR(100) NOT NULL,
    quantidade DECIMAL(10,2) DEFAULT 0,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraint para evitar sabores duplicados no mesmo produto
    UNIQUE(produto_id, sabor)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_produto_sabores_produto ON produto_sabores(produto_id);
CREATE INDEX IF NOT EXISTS idx_produto_sabores_sabor ON produto_sabores(sabor);
CREATE INDEX IF NOT EXISTS idx_produto_sabores_ativo ON produto_sabores(ativo);

-- =====================================================
-- 4. TABELA DE FORNECEDORES
-- =====================================================
CREATE TABLE IF NOT EXISTS fornecedores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(255) NOT NULL,
    cpf_cnpj VARCHAR(18) UNIQUE,
    contato VARCHAR(255),
    email VARCHAR(255),
    telefone VARCHAR(20),
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
CREATE INDEX IF NOT EXISTS idx_fornecedores_nome ON fornecedores(nome);
CREATE INDEX IF NOT EXISTS idx_fornecedores_cpf_cnpj ON fornecedores(cpf_cnpj);
CREATE INDEX IF NOT EXISTS idx_fornecedores_active ON fornecedores(active);

-- =====================================================
-- 5. TABELA DE CLIENTES
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
CREATE INDEX IF NOT EXISTS idx_clientes_cpf_cnpj ON clientes(cpf_cnpj);
CREATE INDEX IF NOT EXISTS idx_clientes_active ON clientes(active);
CREATE INDEX IF NOT EXISTS idx_clientes_nome ON clientes(nome);

-- =====================================================
-- 6. TABELA DE PEDIDOS
-- =====================================================
CREATE TABLE IF NOT EXISTS pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(50) UNIQUE NOT NULL,
    tipo_pedido VARCHAR(10) NOT NULL DEFAULT 'COMPRA' 
        CHECK (tipo_pedido IN ('COMPRA', 'VENDA')),
    solicitante_id UUID REFERENCES users(id) NOT NULL,
    fornecedor_id UUID REFERENCES fornecedores(id),
    cliente_id UUID REFERENCES clientes(id),
    status VARCHAR(20) NOT NULL DEFAULT 'RASCUNHO' 
        CHECK (status IN ('RASCUNHO', 'ENVIADO', 'APROVADO', 'REJEITADO', 'FINALIZADO', 'CANCELADO')),
    status_envio VARCHAR(30)
        CHECK (status_envio IN ('AGUARDANDO_SEPARACAO', 'SEPARADO', 'DESPACHADO')),
    total DECIMAL(10,2) DEFAULT 0,
    observacoes TEXT,
    aprovador_id UUID REFERENCES users(id),
    data_aprovacao TIMESTAMP WITH TIME ZONE,
    motivo_rejeicao TEXT,
    data_finalizacao TIMESTAMP WITH TIME ZONE,
    data_separacao TIMESTAMP WITH TIME ZONE,
    separado_por UUID REFERENCES users(id),
    data_despacho TIMESTAMP WITH TIME ZONE,
    despachado_por UUID REFERENCES users(id),
    
    -- Controle de pagamento (para vendas)
    pagamento_status TEXT DEFAULT 'PENDENTE' 
        CHECK (pagamento_status IN ('PENDENTE', 'PARCIAL', 'PAGO')),
    valor_pago DECIMAL(10,2) DEFAULT 0,
    valor_pendente DECIMAL(10,2) DEFAULT 0,
    data_pagamento_completo TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Constraint para garantir consistência de tipo de pedido
ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedido_tipo_check;
ALTER TABLE pedidos ADD CONSTRAINT pedido_tipo_check 
    CHECK (
        (status = 'RASCUNHO') OR
        (tipo_pedido = 'COMPRA' AND fornecedor_id IS NOT NULL AND cliente_id IS NULL) OR
        (tipo_pedido = 'VENDA' AND cliente_id IS NOT NULL AND fornecedor_id IS NULL)
    );

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_pedidos_numero ON pedidos(numero);
CREATE INDEX IF NOT EXISTS idx_pedidos_tipo ON pedidos(tipo_pedido);
CREATE INDEX IF NOT EXISTS idx_pedidos_status ON pedidos(status);
CREATE INDEX IF NOT EXISTS idx_pedidos_solicitante ON pedidos(solicitante_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_fornecedor ON pedidos(fornecedor_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_aprovador ON pedidos(aprovador_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_created_at ON pedidos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pedidos_pagamento_status ON pedidos(pagamento_status);
CREATE INDEX IF NOT EXISTS idx_pedidos_valor_pendente ON pedidos(valor_pendente);

-- =====================================================
-- 7. TABELA DE ITENS DO PEDIDO
-- =====================================================
CREATE TABLE IF NOT EXISTS pedido_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE NOT NULL,
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    sabor_id UUID REFERENCES produto_sabores(id),
    quantidade DECIMAL(10,2) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    conferido BOOLEAN DEFAULT false,
    conferido_por UUID REFERENCES users(id),
    data_conferencia TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_pedido_itens_pedido ON pedido_itens(pedido_id);
CREATE INDEX IF NOT EXISTS idx_pedido_itens_produto ON pedido_itens(produto_id);
CREATE INDEX IF NOT EXISTS idx_pedido_itens_sabor ON pedido_itens(sabor_id);

-- =====================================================
-- 8. TABELA DE MOVIMENTAÇÕES DE ESTOQUE
-- =====================================================
CREATE TABLE IF NOT EXISTS estoque_movimentacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    sabor_id UUID REFERENCES produto_sabores(id),
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
CREATE INDEX IF NOT EXISTS idx_estoque_mov_produto ON estoque_movimentacoes(produto_id);
CREATE INDEX IF NOT EXISTS idx_estoque_mov_sabor ON estoque_movimentacoes(sabor_id);
CREATE INDEX IF NOT EXISTS idx_estoque_mov_pedido ON estoque_movimentacoes(pedido_id);
CREATE INDEX IF NOT EXISTS idx_estoque_mov_created_at ON estoque_movimentacoes(created_at DESC);

-- =====================================================
-- 9. CONSTRAINT ÚNICA PARA PREVENIR DUPLICAÇÃO DE MOVIMENTAÇÕES
-- =====================================================

-- Constraint para movimentações de finalização (uma por produto/sabor)
DROP INDEX IF EXISTS idx_movimentacao_finalização_unica;
CREATE UNIQUE INDEX idx_movimentacao_finalização_unica 
ON estoque_movimentacoes (
    pedido_id, 
    produto_id, 
    COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
) 
WHERE pedido_id IS NOT NULL 
  AND (observacao LIKE '%Finalização%' OR observacao LIKE '%finalização%');

-- Constraint para movimentações de cancelamento
DROP INDEX IF EXISTS idx_movimentacao_cancelamento_unica;
CREATE UNIQUE INDEX idx_movimentacao_cancelamento_unica 
ON estoque_movimentacoes (
    pedido_id, 
    produto_id, 
    COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
) 
WHERE pedido_id IS NOT NULL 
  AND observacao LIKE '%Cancelamento%';

-- =====================================================
-- 10. TABELA DE PAGAMENTOS (HISTÓRICO DE PARCIAIS)
-- =====================================================
CREATE TABLE IF NOT EXISTS pagamentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    valor DECIMAL(10,2) NOT NULL,
    forma_pagamento TEXT,
    observacao TEXT,
    usuario_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índice
CREATE INDEX IF NOT EXISTS idx_pagamentos_pedido_id ON pagamentos(pedido_id);

-- =====================================================
-- 11. TABELA DE PRÉ-PEDIDOS (PEDIDOS PÚBLICOS)
-- =====================================================
CREATE TABLE IF NOT EXISTS pre_pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(50) UNIQUE NOT NULL,
    nome_solicitante VARCHAR(255) NOT NULL,
    email_contato VARCHAR(255),
    telefone_contato VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDENTE' 
      CHECK (status IN ('PENDENTE', 'EM_ANALISE', 'APROVADO', 'REJEITADO', 'EXPIRADO')),
    total DECIMAL(10,2) DEFAULT 0,
    observacoes TEXT,
    token_publico VARCHAR(100) UNIQUE NOT NULL,
    ip_origem VARCHAR(50),
    user_agent TEXT,
    data_expiracao TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Campos de processamento interno
    analisado_por UUID REFERENCES users(id),
    data_analise TIMESTAMP WITH TIME ZONE,
    cliente_vinculado_id UUID REFERENCES clientes(id),
    pedido_gerado_id UUID REFERENCES pedidos(id),
    motivo_rejeicao TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_status ON pre_pedidos(status);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_token ON pre_pedidos(token_publico);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_expiracao ON pre_pedidos(data_expiracao);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_created ON pre_pedidos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_numero ON pre_pedidos(numero);

-- =====================================================
-- 12. TABELA DE ITENS DE PRÉ-PEDIDO
-- =====================================================
CREATE TABLE IF NOT EXISTS pre_pedido_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pre_pedido_id UUID REFERENCES pre_pedidos(id) ON DELETE CASCADE NOT NULL,
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    sabor_id UUID REFERENCES produto_sabores(id),
    quantidade DECIMAL(10,2) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    estoque_disponivel_momento DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_pre_pedido_itens_pre_pedido ON pre_pedido_itens(pre_pedido_id);
CREATE INDEX IF NOT EXISTS idx_pre_pedido_itens_produto ON pre_pedido_itens(produto_id);
CREATE INDEX IF NOT EXISTS idx_pre_pedido_itens_sabor ON pre_pedido_itens(sabor_id);

-- =====================================================
-- 13. TABELA DE CONFIGURAÇÕES DA EMPRESA
-- =====================================================
CREATE TABLE IF NOT EXISTS empresa_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_empresa VARCHAR(200) NOT NULL,
    razao_social VARCHAR(200),
    cnpj VARCHAR(18),
    endereco TEXT,
    cidade VARCHAR(100),
    estado VARCHAR(2),
    cep VARCHAR(9),
    telefone VARCHAR(20),
    email VARCHAR(100),
    website VARCHAR(200),
    logo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inserir registro padrão
INSERT INTO empresa_config (nome_empresa, email)
SELECT 'Minha Empresa', 'contato@minhaempresa.com'
WHERE NOT EXISTS (SELECT 1 FROM empresa_config LIMIT 1);

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
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_produtos_updated_at ON produtos;
CREATE TRIGGER update_produtos_updated_at BEFORE UPDATE ON produtos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_fornecedores_updated_at ON fornecedores;
CREATE TRIGGER update_fornecedores_updated_at BEFORE UPDATE ON fornecedores
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_clientes_updated_at ON clientes;
CREATE TRIGGER update_clientes_updated_at BEFORE UPDATE ON clientes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pedidos_updated_at ON pedidos;
CREATE TRIGGER update_pedidos_updated_at BEFORE UPDATE ON pedidos
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_produto_sabores_updated_at ON produto_sabores;
CREATE TRIGGER update_produto_sabores_updated_at
    BEFORE UPDATE ON produto_sabores
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pre_pedidos_updated_at ON pre_pedidos;
CREATE TRIGGER update_pre_pedidos_updated_at
    BEFORE UPDATE ON pre_pedidos
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS empresa_config_updated_at ON empresa_config;
CREATE TRIGGER empresa_config_updated_at
    BEFORE UPDATE ON empresa_config
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- Função para atualizar total do pedido
-- =====================================================
CREATE OR REPLACE FUNCTION update_pedido_total()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE pedidos 
    SET total = (
        SELECT COALESCE(SUM(subtotal), 0)
        FROM pedido_itens
        WHERE pedido_id = COALESCE(NEW.pedido_id, OLD.pedido_id)
    )
    WHERE id = COALESCE(NEW.pedido_id, OLD.pedido_id);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger para calcular total do pedido
DROP TRIGGER IF EXISTS update_pedido_total_trigger ON pedido_itens;
CREATE TRIGGER update_pedido_total_trigger
AFTER INSERT OR UPDATE OR DELETE ON pedido_itens
FOR EACH ROW EXECUTE FUNCTION update_pedido_total();

-- =====================================================
-- Função para atualizar estoque do produto (soma de sabores)
-- =====================================================
CREATE OR REPLACE FUNCTION atualizar_estoque_produto()
RETURNS TRIGGER AS $$
BEGIN
    -- Atualizar estoque_atual do produto somando todos os sabores ativos
    UPDATE produtos
    SET estoque_atual = (
        SELECT COALESCE(SUM(quantidade), 0)
        FROM produto_sabores
        WHERE produto_id = COALESCE(NEW.produto_id, OLD.produto_id)
        AND ativo = true
    )
    WHERE id = COALESCE(NEW.produto_id, OLD.produto_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Trigger para atualizar estoque do produto quando sabores mudarem
DROP TRIGGER IF EXISTS trigger_atualizar_estoque_produto ON produto_sabores;
CREATE TRIGGER trigger_atualizar_estoque_produto
    AFTER INSERT OR UPDATE OR DELETE ON produto_sabores
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_estoque_produto();

-- =====================================================
-- Função auxiliar: Verificar se movimentação já existe
-- =====================================================
CREATE OR REPLACE FUNCTION verificar_movimentacao_existente(
    p_pedido_id UUID,
    p_produto_id UUID,
    p_sabor_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    SELECT EXISTS(
        SELECT 1
        FROM estoque_movimentacoes
        WHERE pedido_id = p_pedido_id
        AND produto_id = p_produto_id
        AND COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::UUID) = 
            COALESCE(p_sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
    ) INTO v_existe;
    
    RETURN v_existe;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Função principal: Finalizar pedido (COMPRA ou VENDA)
-- =====================================================
CREATE OR REPLACE FUNCTION finalizar_pedido(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_ja_finalizado BOOLEAN;
    v_mov_existente BOOLEAN;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA - previne race conditions)
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    -- PROTEÇÃO 1: Impedir múltiplas finalizações
    IF v_status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Este pedido já foi finalizado anteriormente';
    END IF;
    
    -- PROTEÇÃO 2: Verificar se pedido foi cancelado
    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Este pedido foi cancelado e não pode ser finalizado';
    END IF;
    
    -- PROTEÇÃO 3: Verificar status válido (permite RASCUNHO ou APROVADO)
    IF v_status NOT IN ('RASCUNHO', 'APROVADO') THEN
        RAISE EXCEPTION 'Pedido não pode ser finalizado neste status: %', v_status;
    END IF;
    
    -- PROTEÇÃO 4: Verificar se já existem movimentações de finalização
    SELECT EXISTS(
        SELECT 1 
        FROM estoque_movimentacoes 
        WHERE pedido_id = p_pedido_id 
        AND (observacao LIKE '%Finalização%' OR observacao LIKE '%finalização%')
    ) INTO v_ja_finalizado;
    
    IF v_ja_finalizado THEN
        RAISE EXCEPTION 'Este pedido já tem movimentações de finalização registradas';
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
        -- 🛡️ PROTEÇÃO ADICIONAL: Verificar se movimentação já existe
        v_mov_existente := verificar_movimentacao_existente(
            p_pedido_id, 
            v_item.produto_id, 
            v_item.sabor_id
        );
        
        IF v_mov_existente THEN
            RAISE EXCEPTION 'Já existe movimentação para o produto % no pedido especificado', 
                v_item.produto_codigo;
        END IF;
        
        -- Processar movimentação de sabor (se aplicável)
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
                FOR UPDATE;
                
                -- Calcular ajuste baseado no tipo
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_quantidade_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_quantidade_ajuste := -v_item.quantidade;
                    
                    -- Validação de estoque para venda
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
                
                -- Atualizar estoque do sabor
                UPDATE produto_sabores
                SET quantidade = quantidade + v_quantidade_ajuste
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_estoque_novo;
                
                -- 📝 Registrar movimentação (constraint única garante não duplicar)
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
        ELSE
            -- Processar produto sem sabor (lógica similar)
            DECLARE
                v_estoque_anterior DECIMAL;
                v_estoque_novo DECIMAL;
                v_quantidade_ajuste DECIMAL;
            BEGIN
                SELECT estoque_atual INTO v_estoque_anterior
                FROM produtos
                WHERE id = v_item.produto_id
                FOR UPDATE;
                
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_quantidade_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_quantidade_ajuste := -v_item.quantidade;
                    
                    IF v_estoque_anterior < v_item.quantidade THEN
                        RAISE EXCEPTION 'Estoque insuficiente para %. Necessário: %, Disponível: %',
                            v_item.produto_codigo,
                            v_item.quantidade,
                            v_estoque_anterior;
                    END IF;
                END IF;
                
                UPDATE produtos
                SET estoque_atual = estoque_atual + v_quantidade_ajuste
                WHERE id = v_item.produto_id
                RETURNING estoque_atual INTO v_estoque_novo;
                
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    observacao
                ) VALUES (
                    v_item.produto_id,
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

    -- Atualizar status do pedido
    UPDATE pedidos 
    SET 
        status = 'FINALIZADO',
        data_finalizacao = NOW(),
        aprovador_id = p_usuario_id
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Função para reverter movimentações ao cancelar/reabrir
-- =====================================================
CREATE OR REPLACE FUNCTION reverter_movimentacoes_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_mov RECORD;
BEGIN
    -- Só age se o status mudou de FINALIZADO para RASCUNHO ou CANCELADO
    IF OLD.status = 'FINALIZADO' AND NEW.status IN ('RASCUNHO', 'CANCELADO') THEN
        
        RAISE NOTICE '🔄 Pedido % mudou de FINALIZADO para %. Revertendo movimentações...', OLD.numero, NEW.status;
        
        -- VALIDAÇÃO: Verificar se há estoque suficiente para reverter COMPRAS
        IF OLD.tipo_pedido = 'COMPRA' THEN
            FOR v_mov IN 
                SELECT m.*, p.codigo as produto_codigo, ps.sabor as sabor_nome,
                       COALESCE(ps.quantidade, p.estoque_atual) as estoque_disponivel
                FROM estoque_movimentacoes m
                JOIN produtos p ON m.produto_id = p.id
                LEFT JOIN produto_sabores ps ON m.sabor_id = ps.id
                WHERE m.pedido_id = OLD.id AND m.tipo = 'ENTRADA'
            LOOP
                IF v_mov.estoque_disponivel < v_mov.quantidade THEN
                    RAISE EXCEPTION 'BLOQUEIO: Não é possível cancelar esta compra! O produto % (%) já foi vendido. Estoque atual: %, tentando remover: %. Faltam: % unidades.',
                        v_mov.produto_codigo,
                        COALESCE(v_mov.sabor_nome, 'geral'),
                        v_mov.estoque_disponivel,
                        v_mov.quantidade,
                        (v_mov.quantidade - v_mov.estoque_disponivel);
                END IF;
            END LOOP;
        END IF;
        
        -- Buscar e reverter todas as movimentações
        FOR v_mov IN 
            SELECT id, tipo, quantidade, produto_id, sabor_id
            FROM estoque_movimentacoes
            WHERE pedido_id = OLD.id
            ORDER BY created_at DESC
        LOOP
            -- Reverter no estoque do sabor (se existir)
            IF v_mov.sabor_id IS NOT NULL THEN
                IF v_mov.tipo = 'ENTRADA' THEN
                    UPDATE produto_sabores
                    SET quantidade = quantidade - v_mov.quantidade
                    WHERE id = v_mov.sabor_id;
                ELSIF v_mov.tipo = 'SAIDA' THEN
                    UPDATE produto_sabores
                    SET quantidade = quantidade + v_mov.quantidade
                    WHERE id = v_mov.sabor_id;
                END IF;
            END IF;
            
            -- Reverter no estoque geral do produto
            IF v_mov.tipo = 'ENTRADA' THEN
                UPDATE produtos
                SET estoque_atual = estoque_atual - v_mov.quantidade
                WHERE id = v_mov.produto_id;
            ELSIF v_mov.tipo = 'SAIDA' THEN
                UPDATE produtos
                SET estoque_atual = estoque_atual + v_mov.quantidade
                WHERE id = v_mov.produto_id;
            END IF;
            
            -- DELETAR a movimentação (já foi revertida)
            DELETE FROM estoque_movimentacoes WHERE id = v_mov.id;
        END LOOP;
        
        RAISE NOTICE '✅ Movimentações do pedido % revertidas', OLD.numero;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para reverter movimentações automaticamente
DROP TRIGGER IF EXISTS trigger_reverter_movimentacoes ON pedidos;
CREATE TRIGGER trigger_reverter_movimentacoes
    BEFORE UPDATE ON pedidos
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION reverter_movimentacoes_pedido();

-- =====================================================
-- Função para validar mudança de status (proteção cancelamento duplo)
-- =====================================================
CREATE OR REPLACE FUNCTION validar_mudanca_status_pedido()
RETURNS TRIGGER AS $$
BEGIN
    -- Se o status antigo já era CANCELADO, não permitir qualquer mudança
    IF OLD.status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Não é possível alterar um pedido já cancelado. Status atual: CANCELADO';
    END IF;
    
    -- Se está mudando PARA cancelado, validar origem
    IF NEW.status = 'CANCELADO' AND OLD.status NOT IN ('FINALIZADO', 'APROVADO', 'ENVIADO', 'REJEITADO') THEN
        RAISE EXCEPTION 'Só é possível cancelar pedidos FINALIZADO, APROVADO, ENVIADO ou REJEITADO. Status atual: %', OLD.status;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger de validação
DROP TRIGGER IF EXISTS trigger_validar_mudanca_status ON pedidos;
CREATE TRIGGER trigger_validar_mudanca_status
    BEFORE UPDATE OF status ON pedidos
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION validar_mudanca_status_pedido();

-- =====================================================
-- Função para impedir finalizar pedido cancelado
-- =====================================================
CREATE OR REPLACE FUNCTION impedir_finalizar_cancelado()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'FINALIZADO' AND OLD.status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Não é possível finalizar um pedido cancelado';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
DROP TRIGGER IF EXISTS trigger_impedir_finalizar_cancelado ON pedidos;
CREATE TRIGGER trigger_impedir_finalizar_cancelado
    BEFORE UPDATE ON pedidos
    FOR EACH ROW
    EXECUTE FUNCTION impedir_finalizar_cancelado();

-- =====================================================
-- Função para gerar número de pré-pedido
-- =====================================================
CREATE OR REPLACE FUNCTION gerar_numero_pre_pedido()
RETURNS TRIGGER AS $$
DECLARE
    ano_atual TEXT;
    proximo_numero INTEGER;
    novo_numero TEXT;
BEGIN
    ano_atual := TO_CHAR(NOW(), 'YYYY');
    
    SELECT COALESCE(MAX(
        CAST(
            SUBSTRING(numero FROM 'PRE-' || ano_atual || '-(\d+)')
            AS INTEGER
        )
    ), 0) + 1
    INTO proximo_numero
    FROM pre_pedidos
    WHERE numero LIKE 'PRE-' || ano_atual || '-%';
    
    novo_numero := 'PRE-' || ano_atual || '-' || LPAD(proximo_numero::TEXT, 4, '0');
    
    NEW.numero := novo_numero;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
DROP TRIGGER IF EXISTS trigger_gerar_numero_pre_pedido ON pre_pedidos;
CREATE TRIGGER trigger_gerar_numero_pre_pedido
    BEFORE INSERT ON pre_pedidos
    FOR EACH ROW
    WHEN (NEW.numero IS NULL OR NEW.numero = '')
    EXECUTE FUNCTION gerar_numero_pre_pedido();

-- =====================================================
-- Função para expirar pré-pedidos
-- =====================================================
CREATE OR REPLACE FUNCTION expirar_pre_pedidos()
RETURNS INTEGER AS $$
DECLARE
    quantidade_expirados INTEGER;
BEGIN
    UPDATE pre_pedidos
    SET status = 'EXPIRADO',
        updated_at = NOW()
    WHERE status IN ('PENDENTE', 'EM_ANALISE')
      AND data_expiracao < NOW();
    
    GET DIAGNOSTICS quantidade_expirados = ROW_COUNT;
    RETURN quantidade_expirados;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- VIEWS ÚTEIS
-- =====================================================

-- View: Produtos com estoque baixo
CREATE OR REPLACE VIEW produtos_estoque_baixo AS
SELECT 
    p.*,
    (p.estoque_minimo - p.estoque_atual) as deficit
FROM produtos p
WHERE p.active = true 
AND p.estoque_atual <= p.estoque_minimo
ORDER BY deficit DESC;

-- View: Estoque detalhado por marca, produto e sabor
CREATE OR REPLACE VIEW vw_estoque_sabores AS
SELECT 
    p.id as produto_id,
    p.marca,
    p.nome as produto,
    p.codigo,
    ps.id as sabor_id,
    ps.sabor,
    ps.quantidade,
    p.estoque_minimo,
    p.preco_compra,
    p.preco_venda,
    CASE 
        WHEN ps.quantidade = 0 THEN 'ZERADO'
        WHEN ps.quantidade <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produtos p
LEFT JOIN produto_sabores ps ON p.id = ps.produto_id
WHERE p.active = true AND ps.ativo = true
ORDER BY p.marca, p.nome, ps.sabor;

-- View: Produtos públicos (para pré-pedidos)
CREATE OR REPLACE VIEW vw_produtos_publicos AS
SELECT 
    p.id,
    p.codigo,
    p.marca,
    p.nome,
    p.unidade,
    p.preco_venda,
    p.estoque_atual,
    p.estoque_minimo,
    CASE 
        WHEN p.estoque_atual = 0 THEN 'ZERADO'
        WHEN p.estoque_atual <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produtos p
WHERE p.active = true
  AND p.estoque_atual > 0
ORDER BY p.marca, p.nome;

-- View: Sabores públicos (para pré-pedidos)
CREATE OR REPLACE VIEW vw_sabores_publicos AS
SELECT 
    s.id,
    s.produto_id,
    s.sabor,
    s.quantidade,
    p.preco_venda,
    p.estoque_minimo,
    p.marca,
    p.nome as produto_nome,
    p.codigo as produto_codigo,
    CASE 
        WHEN s.quantidade = 0 THEN 'ZERADO'
        WHEN s.quantidade <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produto_sabores s
INNER JOIN produtos p ON p.id = s.produto_id
WHERE s.ativo = true
  AND p.active = true
  AND s.quantidade > 0
ORDER BY p.marca, p.nome, s.sabor;

-- View: Resumo de vendas
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
    p.pagamento_status,
    p.valor_pago,
    p.valor_pendente,
    COUNT(pi.id) as total_itens
FROM pedidos p
LEFT JOIN clientes c ON p.cliente_id = c.id
LEFT JOIN users u ON p.solicitante_id = u.id
LEFT JOIN pedido_itens pi ON p.id = pi.pedido_id
WHERE p.tipo_pedido = 'VENDA'
GROUP BY p.id, c.nome, c.cpf_cnpj, u.full_name;

-- View: Estatísticas de pedidos
CREATE OR REPLACE VIEW estatisticas_pedidos AS
SELECT 
    status,
    tipo_pedido,
    COUNT(*) as total,
    SUM(total) as valor_total
FROM pedidos
GROUP BY status, tipo_pedido;

-- =====================================================
-- FIM DO SCHEMA BASE
-- =====================================================
-- PRÓXIMOS PASSOS:
-- 1. Execute este schema em um banco limpo
-- 2. Execute o arquivo de políticas RLS separado
-- 3. Configure o primeiro usuário admin
-- =====================================================

SELECT '✅ SCHEMA COMPLETO CRIADO COM SUCESSO!' as status,
       'Tabelas: users, produtos, produto_sabores, fornecedores, clientes, pedidos, pedido_itens, estoque_movimentacoes, pagamentos, pre_pedidos, pre_pedido_itens, empresa_config' as tabelas,
       'Funções: finalizar_pedido, reverter_movimentacoes_pedido, verificar_movimentacao_existente, expirar_pre_pedidos, gerar_numero_pre_pedido' as funcoes,
       'Views: produtos_estoque_baixo, vw_estoque_sabores, vw_produtos_publicos, vw_sabores_publicos, vw_vendas_resumo, estatisticas_pedidos' as views,
       '⚠️  IMPORTANTE: Execute agora o schema-rls-policies.sql para configurar segurança!' as proximo_passo;
