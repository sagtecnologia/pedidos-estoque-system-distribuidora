-- =====================================================
-- SCHEMA COMPLETO - SISTEMA DISTRIBUIDORA DE BEBIDAS
-- =====================================================
-- Versão: 2.0 - Distribuidora
-- Data: 2024
-- Descrição: Schema completo para sistema de distribuidora
--            com PDV, NFe, contas a pagar/receber e controle de validade
-- =====================================================

-- Limpar objetos existentes (CUIDADO: apaga tudo!)
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- Habilitar extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- TABELAS PRINCIPAIS
-- =====================================================

-- Tabela de Usuários
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'VENDEDOR' CHECK (role IN ('ADMIN', 'GERENTE', 'VENDEDOR', 'OPERADOR_CAIXA', 'ESTOQUISTA')),
    active BOOLEAN DEFAULT true,
    approved BOOLEAN DEFAULT false,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMP WITH TIME ZONE,
    telefone VARCHAR(20),
    cpf VARCHAR(14),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de Fornecedores
CREATE TABLE fornecedores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    razao_social VARCHAR(255) NOT NULL,
    nome_fantasia VARCHAR(255),
    cpf_cnpj VARCHAR(18) UNIQUE NOT NULL,
    inscricao_estadual VARCHAR(20),
    inscricao_municipal VARCHAR(20),
    email VARCHAR(255),
    telefone VARCHAR(20),
    celular VARCHAR(20),
    endereco VARCHAR(255),
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    estado CHAR(2),
    cep VARCHAR(10),
    observacoes TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de Clientes
CREATE TABLE clientes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo_pessoa CHAR(1) DEFAULT 'F' CHECK (tipo_pessoa IN ('F', 'J')),
    nome VARCHAR(255) NOT NULL,
    razao_social VARCHAR(255),
    cpf_cnpj VARCHAR(18),
    inscricao_estadual VARCHAR(20),
    email VARCHAR(255),
    telefone VARCHAR(20),
    celular VARCHAR(20),
    endereco VARCHAR(255),
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    estado CHAR(2),
    cep VARCHAR(10),
    limite_credito DECIMAL(12,2) DEFAULT 0,
    saldo_devedor DECIMAL(12,2) DEFAULT 0,
    observacoes TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de Categorias de Produtos
CREATE TABLE categorias (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inserir categorias padrão de distribuidora de bebidas
INSERT INTO categorias (nome, descricao) VALUES 
    ('Cervejas', 'Cervejas nacionais e importadas'),
    ('Refrigerantes', 'Refrigerantes e sodas'),
    ('Água', 'Água mineral e saborizada'),
    ('Sucos', 'Sucos naturais e industrializados'),
    ('Energéticos', 'Bebidas energéticas'),
    ('Destilados', 'Whisky, vodka, cachaça, etc'),
    ('Vinhos', 'Vinhos tintos, brancos e espumantes'),
    ('Outros', 'Outros produtos');

-- Tabela de Produtos (sem sabores, com campos fiscais e validade)
CREATE TABLE produtos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(50) UNIQUE NOT NULL,
    codigo_barras VARCHAR(50),
    nome VARCHAR(255) NOT NULL,
    descricao TEXT,
    marca VARCHAR(100),
    categoria_id UUID REFERENCES categorias(id),
    unidade VARCHAR(20) DEFAULT 'UN',
    volume_ml INTEGER, -- Volume em ml para bebidas
    embalagem VARCHAR(50), -- Ex: "Caixa com 12", "Pack 6 unidades"
    quantidade_embalagem INTEGER DEFAULT 1,
    
    -- Preços
    preco_custo DECIMAL(12,2) DEFAULT 0,
    preco_venda DECIMAL(12,2) DEFAULT 0,
    margem_lucro DECIMAL(5,2) GENERATED ALWAYS AS (
        CASE WHEN preco_custo > 0 
        THEN ((preco_venda - preco_custo) / preco_custo * 100)
        ELSE 0 END
    ) STORED,
    
    -- Estoque
    estoque_atual DECIMAL(12,3) DEFAULT 0,
    estoque_minimo DECIMAL(12,3) DEFAULT 0,
    estoque_maximo DECIMAL(12,3) DEFAULT 0,
    localizacao VARCHAR(50), -- Localização no depósito
    
    -- Controle de Validade
    controla_validade BOOLEAN DEFAULT true,
    dias_alerta_validade INTEGER DEFAULT 30, -- Alerta X dias antes de vencer
    
    -- Dados Fiscais
    ncm VARCHAR(10),
    cest VARCHAR(10),
    cfop_venda VARCHAR(10) DEFAULT '5102',
    cfop_compra VARCHAR(10) DEFAULT '1102',
    cst_icms VARCHAR(5),
    cst_pis VARCHAR(5),
    cst_cofins VARCHAR(5),
    cst_ipi VARCHAR(5),
    origem VARCHAR(1) DEFAULT '0', -- 0=Nacional, 1=Estrangeira importação direta, etc
    aliquota_icms DECIMAL(5,2) DEFAULT 0,
    aliquota_pis DECIMAL(5,4) DEFAULT 0,
    aliquota_cofins DECIMAL(5,4) DEFAULT 0,
    aliquota_ipi DECIMAL(5,2) DEFAULT 0,
    
    -- Fornecedor padrão
    fornecedor_id UUID REFERENCES fornecedores(id),
    
    -- Imagem
    imagem_url TEXT,
    
    -- Controle
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para produtos
CREATE INDEX idx_produtos_codigo ON produtos(codigo);
CREATE INDEX idx_produtos_codigo_barras ON produtos(codigo_barras);
CREATE INDEX idx_produtos_marca ON produtos(marca);
CREATE INDEX idx_produtos_categoria ON produtos(categoria_id);
CREATE INDEX idx_produtos_fornecedor ON produtos(fornecedor_id);

-- Tabela de Lotes (controle de validade)
CREATE TABLE produto_lotes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    produto_id UUID NOT NULL REFERENCES produtos(id) ON DELETE CASCADE,
    numero_lote VARCHAR(50) NOT NULL,
    data_fabricacao DATE,
    data_validade DATE NOT NULL,
    quantidade_inicial DECIMAL(12,3) NOT NULL,
    quantidade_atual DECIMAL(12,3) NOT NULL,
    preco_custo DECIMAL(12,2),
    fornecedor_id UUID REFERENCES fornecedores(id),
    nota_fiscal VARCHAR(50),
    observacoes TEXT,
    status VARCHAR(20) DEFAULT 'ATIVO' CHECK (status IN ('ATIVO', 'VENCIDO', 'ESGOTADO', 'BLOQUEADO')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(produto_id, numero_lote)
);

CREATE INDEX idx_lotes_produto ON produto_lotes(produto_id);
CREATE INDEX idx_lotes_validade ON produto_lotes(data_validade);
CREATE INDEX idx_lotes_status ON produto_lotes(status);

-- =====================================================
-- TABELAS DE PDV E VENDAS
-- =====================================================

-- Tabela de Caixas (pontos de venda)
CREATE TABLE caixas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero INTEGER UNIQUE NOT NULL,
    nome VARCHAR(100) NOT NULL,
    impressora_nfce VARCHAR(100),
    impressora_cupom VARCHAR(100),
    terminal VARCHAR(100),
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inserir caixa padrão
INSERT INTO caixas (numero, nome) VALUES (1, 'Caixa Principal');

-- Tabela de Sessões de Caixa
CREATE TABLE caixa_sessoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    caixa_id UUID NOT NULL REFERENCES caixas(id),
    operador_id UUID NOT NULL REFERENCES users(id),
    data_abertura TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_fechamento TIMESTAMP WITH TIME ZONE,
    valor_abertura DECIMAL(12,2) DEFAULT 0,
    valor_fechamento DECIMAL(12,2),
    valor_vendas DECIMAL(12,2) DEFAULT 0,
    valor_sangrias DECIMAL(12,2) DEFAULT 0,
    valor_suprimentos DECIMAL(12,2) DEFAULT 0,
    diferenca DECIMAL(12,2),
    status VARCHAR(20) DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'FECHADO', 'CONFERIDO')),
    observacoes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_sessoes_caixa ON caixa_sessoes(caixa_id);
CREATE INDEX idx_sessoes_operador ON caixa_sessoes(operador_id);
CREATE INDEX idx_sessoes_status ON caixa_sessoes(status);

-- Tabela de Movimentações de Caixa (sangrias e suprimentos)
CREATE TABLE caixa_movimentacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sessao_id UUID NOT NULL REFERENCES caixa_sessoes(id),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('SANGRIA', 'SUPRIMENTO')),
    valor DECIMAL(12,2) NOT NULL,
    motivo TEXT,
    responsavel_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de Vendas (PDV)
CREATE TABLE vendas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(20) UNIQUE NOT NULL,
    sessao_id UUID REFERENCES caixa_sessoes(id),
    cliente_id UUID REFERENCES clientes(id),
    vendedor_id UUID NOT NULL REFERENCES users(id),
    
    -- Valores
    subtotal DECIMAL(12,2) DEFAULT 0,
    desconto_percentual DECIMAL(5,2) DEFAULT 0,
    desconto_valor DECIMAL(12,2) DEFAULT 0,
    acrescimo DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    
    -- Pagamento
    forma_pagamento VARCHAR(30), -- DINHEIRO, CARTAO_CREDITO, CARTAO_DEBITO, PIX, BOLETO, PRAZO
    troco DECIMAL(12,2) DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'FINALIZADA' CHECK (status IN ('ABERTA', 'FINALIZADA', 'CANCELADA')),
    motivo_cancelamento TEXT,
    
    -- Dados fiscais
    nfce_numero VARCHAR(20),
    nfce_serie VARCHAR(5),
    nfce_chave VARCHAR(50),
    nfce_status VARCHAR(20),
    nfce_xml TEXT,
    
    -- Datas
    data_venda TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    data_cancelamento TIMESTAMP WITH TIME ZONE,
    
    observacoes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_vendas_numero ON vendas(numero);
CREATE INDEX idx_vendas_sessao ON vendas(sessao_id);
CREATE INDEX idx_vendas_cliente ON vendas(cliente_id);
CREATE INDEX idx_vendas_data ON vendas(data_venda);
CREATE INDEX idx_vendas_status ON vendas(status);

-- Tabela de Itens da Venda
CREATE TABLE venda_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venda_id UUID NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
    produto_id UUID NOT NULL REFERENCES produtos(id),
    lote_id UUID REFERENCES produto_lotes(id),
    quantidade DECIMAL(12,3) NOT NULL,
    preco_unitario DECIMAL(12,2) NOT NULL,
    desconto_percentual DECIMAL(5,2) DEFAULT 0,
    desconto_valor DECIMAL(12,2) DEFAULT 0,
    subtotal DECIMAL(12,2) NOT NULL,
    
    -- Dados fiscais do item
    cfop VARCHAR(10),
    ncm VARCHAR(10),
    cst_icms VARCHAR(5),
    valor_icms DECIMAL(12,2) DEFAULT 0,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_venda_itens_venda ON venda_itens(venda_id);
CREATE INDEX idx_venda_itens_produto ON venda_itens(produto_id);

-- Tabela de Pagamentos da Venda
CREATE TABLE venda_pagamentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venda_id UUID NOT NULL REFERENCES vendas(id) ON DELETE CASCADE,
    forma_pagamento VARCHAR(30) NOT NULL,
    valor DECIMAL(12,2) NOT NULL,
    bandeira VARCHAR(50), -- Para cartões
    nsu VARCHAR(50), -- Número sequencial único do cartão
    autorizacao VARCHAR(50),
    parcelas INTEGER DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- TABELAS DE PEDIDOS (COMPRAS)
-- =====================================================

-- Tabela de Pedidos de Compra
CREATE TABLE pedidos_compra (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(20) UNIQUE NOT NULL,
    fornecedor_id UUID NOT NULL REFERENCES fornecedores(id),
    usuario_id UUID NOT NULL REFERENCES users(id),
    
    -- Valores
    subtotal DECIMAL(12,2) DEFAULT 0,
    desconto DECIMAL(12,2) DEFAULT 0,
    frete DECIMAL(12,2) DEFAULT 0,
    outras_despesas DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    
    -- Datas
    data_pedido DATE DEFAULT CURRENT_DATE,
    data_previsao DATE,
    data_recebimento DATE,
    
    -- Nota fiscal do fornecedor
    nf_numero VARCHAR(50),
    nf_serie VARCHAR(10),
    nf_chave VARCHAR(50),
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'APROVADO', 'RECEBIDO', 'CANCELADO')),
    
    observacoes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_pedidos_compra_fornecedor ON pedidos_compra(fornecedor_id);
CREATE INDEX idx_pedidos_compra_status ON pedidos_compra(status);
CREATE INDEX idx_pedidos_compra_data ON pedidos_compra(data_pedido);

-- Tabela de Itens do Pedido de Compra
CREATE TABLE pedido_compra_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID NOT NULL REFERENCES pedidos_compra(id) ON DELETE CASCADE,
    produto_id UUID NOT NULL REFERENCES produtos(id),
    quantidade DECIMAL(12,3) NOT NULL,
    quantidade_recebida DECIMAL(12,3) DEFAULT 0,
    preco_unitario DECIMAL(12,2) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    
    -- Dados do lote recebido
    numero_lote VARCHAR(50),
    data_validade DATE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- TABELAS FINANCEIRAS
-- =====================================================

-- Tabela de Contas a Pagar
CREATE TABLE contas_pagar (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_documento VARCHAR(50),
    descricao VARCHAR(255) NOT NULL,
    fornecedor_id UUID REFERENCES fornecedores(id),
    pedido_compra_id UUID REFERENCES pedidos_compra(id),
    
    -- Valores
    valor_original DECIMAL(12,2) NOT NULL,
    valor_desconto DECIMAL(12,2) DEFAULT 0,
    valor_juros DECIMAL(12,2) DEFAULT 0,
    valor_multa DECIMAL(12,2) DEFAULT 0,
    valor_pago DECIMAL(12,2) DEFAULT 0,
    valor_total DECIMAL(12,2) GENERATED ALWAYS AS (
        valor_original - valor_desconto + valor_juros + valor_multa
    ) STORED,
    
    -- Datas
    data_emissao DATE DEFAULT CURRENT_DATE,
    data_vencimento DATE NOT NULL,
    data_pagamento DATE,
    
    -- Forma de pagamento
    forma_pagamento VARCHAR(30),
    conta_bancaria VARCHAR(100),
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'PAGO', 'PAGO_PARCIAL', 'VENCIDO', 'CANCELADO')),
    
    -- Categorização
    categoria VARCHAR(50) DEFAULT 'FORNECEDOR', -- FORNECEDOR, DESPESA_FIXA, DESPESA_VARIAVEL, IMPOSTO, OUTROS
    centro_custo VARCHAR(50),
    
    -- Parcelas
    parcela_atual INTEGER DEFAULT 1,
    total_parcelas INTEGER DEFAULT 1,
    
    observacoes TEXT,
    usuario_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_contas_pagar_fornecedor ON contas_pagar(fornecedor_id);
CREATE INDEX idx_contas_pagar_vencimento ON contas_pagar(data_vencimento);
CREATE INDEX idx_contas_pagar_status ON contas_pagar(status);
CREATE INDEX idx_contas_pagar_categoria ON contas_pagar(categoria);

-- Tabela de Contas a Receber
CREATE TABLE contas_receber (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_documento VARCHAR(50),
    descricao VARCHAR(255) NOT NULL,
    cliente_id UUID REFERENCES clientes(id),
    venda_id UUID REFERENCES vendas(id),
    
    -- Valores
    valor_original DECIMAL(12,2) NOT NULL,
    valor_desconto DECIMAL(12,2) DEFAULT 0,
    valor_juros DECIMAL(12,2) DEFAULT 0,
    valor_multa DECIMAL(12,2) DEFAULT 0,
    valor_recebido DECIMAL(12,2) DEFAULT 0,
    valor_total DECIMAL(12,2) GENERATED ALWAYS AS (
        valor_original - valor_desconto + valor_juros + valor_multa
    ) STORED,
    
    -- Datas
    data_emissao DATE DEFAULT CURRENT_DATE,
    data_vencimento DATE NOT NULL,
    data_recebimento DATE,
    
    -- Forma de recebimento
    forma_recebimento VARCHAR(30),
    conta_bancaria VARCHAR(100),
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'RECEBIDO', 'RECEBIDO_PARCIAL', 'VENCIDO', 'CANCELADO')),
    
    -- Categorização
    categoria VARCHAR(50) DEFAULT 'VENDA', -- VENDA, SERVICO, OUTROS
    
    -- Parcelas
    parcela_atual INTEGER DEFAULT 1,
    total_parcelas INTEGER DEFAULT 1,
    
    observacoes TEXT,
    usuario_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_contas_receber_cliente ON contas_receber(cliente_id);
CREATE INDEX idx_contas_receber_vencimento ON contas_receber(data_vencimento);
CREATE INDEX idx_contas_receber_status ON contas_receber(status);

-- Tabela de Histórico de Pagamentos/Recebimentos
CREATE TABLE movimentacoes_financeiras (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('PAGAMENTO', 'RECEBIMENTO')),
    conta_pagar_id UUID REFERENCES contas_pagar(id),
    conta_receber_id UUID REFERENCES contas_receber(id),
    valor DECIMAL(12,2) NOT NULL,
    data_movimento DATE DEFAULT CURRENT_DATE,
    forma VARCHAR(30),
    conta_bancaria VARCHAR(100),
    comprovante VARCHAR(255),
    observacoes TEXT,
    usuario_id UUID REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- TABELAS DE ESTOQUE
-- =====================================================

-- Tabela de Movimentações de Estoque
CREATE TABLE estoque_movimentacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    produto_id UUID NOT NULL REFERENCES produtos(id),
    lote_id UUID REFERENCES produto_lotes(id),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('ENTRADA', 'SAIDA', 'AJUSTE', 'TRANSFERENCIA', 'PERDA', 'DEVOLUCAO')),
    quantidade DECIMAL(12,3) NOT NULL,
    estoque_anterior DECIMAL(12,3),
    estoque_novo DECIMAL(12,3),
    
    -- Referências
    venda_id UUID REFERENCES vendas(id),
    pedido_compra_id UUID REFERENCES pedidos_compra(id),
    
    -- Detalhes
    motivo VARCHAR(255),
    observacao TEXT,
    usuario_id UUID REFERENCES users(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_estoque_mov_produto ON estoque_movimentacoes(produto_id);
CREATE INDEX idx_estoque_mov_tipo ON estoque_movimentacoes(tipo);
CREATE INDEX idx_estoque_mov_data ON estoque_movimentacoes(created_at);

-- =====================================================
-- TABELA DE DOCUMENTOS FISCAIS
-- =====================================================

CREATE TABLE documentos_fiscais (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('NFCE', 'NFE', 'NFSE')),
    numero VARCHAR(20) NOT NULL,
    serie VARCHAR(5) NOT NULL,
    chave VARCHAR(50) UNIQUE,
    
    -- Referências
    venda_id UUID REFERENCES vendas(id),
    
    -- Valores
    valor_total DECIMAL(12,2),
    valor_produtos DECIMAL(12,2),
    valor_desconto DECIMAL(12,2),
    valor_icms DECIMAL(12,2),
    valor_pis DECIMAL(12,2),
    valor_cofins DECIMAL(12,2),
    
    -- Status
    status VARCHAR(20) DEFAULT 'PENDENTE' CHECK (status IN ('PENDENTE', 'AUTORIZADA', 'CANCELADA', 'INUTILIZADA', 'REJEITADA')),
    
    -- XMLs
    xml_envio TEXT,
    xml_retorno TEXT,
    pdf_url TEXT,
    
    -- Protocolo
    protocolo VARCHAR(50),
    data_autorizacao TIMESTAMP WITH TIME ZONE,
    motivo_rejeicao TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_docs_fiscais_tipo ON documentos_fiscais(tipo);
CREATE INDEX idx_docs_fiscais_numero ON documentos_fiscais(numero);
CREATE INDEX idx_docs_fiscais_status ON documentos_fiscais(status);

-- =====================================================
-- CONFIGURAÇÕES DA EMPRESA
-- =====================================================

CREATE TABLE empresa_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Dados básicos
    razao_social VARCHAR(255) NOT NULL,
    nome_fantasia VARCHAR(255),
    cnpj VARCHAR(18) NOT NULL,
    inscricao_estadual VARCHAR(20),
    inscricao_municipal VARCHAR(20),
    
    -- Endereço
    cep VARCHAR(10),
    logradouro VARCHAR(255),
    numero VARCHAR(20),
    complemento VARCHAR(100),
    bairro VARCHAR(100),
    cidade VARCHAR(100),
    estado CHAR(2),
    codigo_ibge VARCHAR(10),
    
    -- Contato
    telefone VARCHAR(20),
    email VARCHAR(255),
    site VARCHAR(255),
    
    -- Configurações fiscais
    regime_tributario VARCHAR(20) DEFAULT 'SIMPLES', -- SIMPLES, LUCRO_PRESUMIDO, LUCRO_REAL
    cnae_principal VARCHAR(20),
    ambiente_nfe VARCHAR(20) DEFAULT 'homologacao', -- homologacao, producao
    serie_nfce VARCHAR(5) DEFAULT '1',
    serie_nfe VARCHAR(5) DEFAULT '1',
    ultimo_numero_nfce INTEGER DEFAULT 0,
    ultimo_numero_nfe INTEGER DEFAULT 0,
    
    -- Integração Focus NFe
    focus_nfe_token VARCHAR(255),
    focus_nfe_ambiente VARCHAR(20) DEFAULT 'homologacao',
    
    -- Certificado digital
    certificado_base64 TEXT,
    certificado_senha VARCHAR(255),
    certificado_validade DATE,
    
    -- Configurações de estoque
    estoque_negativo BOOLEAN DEFAULT false,
    alerta_estoque_dias INTEGER DEFAULT 7,
    alerta_validade_dias INTEGER DEFAULT 30,
    
    -- Configurações de PDV
    pdv_impressao_automatica BOOLEAN DEFAULT true,
    pdv_desconto_maximo DECIMAL(5,2) DEFAULT 10,
    pdv_venda_consumidor_final BOOLEAN DEFAULT true,
    
    -- Logo
    logo_url TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- FUNÇÕES AUXILIARES
-- =====================================================

-- Função para gerar número sequencial de venda
CREATE OR REPLACE FUNCTION gerar_numero_venda()
RETURNS TRIGGER AS $$
DECLARE
    ano_atual TEXT;
    proximo_numero INTEGER;
BEGIN
    ano_atual := TO_CHAR(NOW(), 'YYYY');
    
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(numero FROM '\d+$') AS INTEGER)
    ), 0) + 1
    INTO proximo_numero
    FROM vendas
    WHERE numero LIKE 'VDA-' || ano_atual || '-%';
    
    NEW.numero := 'VDA-' || ano_atual || '-' || LPAD(proximo_numero::TEXT, 6, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gerar_numero_venda
    BEFORE INSERT ON vendas
    FOR EACH ROW
    WHEN (NEW.numero IS NULL OR NEW.numero = '')
    EXECUTE FUNCTION gerar_numero_venda();

-- Função para gerar número de pedido de compra
CREATE OR REPLACE FUNCTION gerar_numero_pedido_compra()
RETURNS TRIGGER AS $$
DECLARE
    ano_atual TEXT;
    proximo_numero INTEGER;
BEGIN
    ano_atual := TO_CHAR(NOW(), 'YYYY');
    
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(numero FROM '\d+$') AS INTEGER)
    ), 0) + 1
    INTO proximo_numero
    FROM pedidos_compra
    WHERE numero LIKE 'PC-' || ano_atual || '-%';
    
    NEW.numero := 'PC-' || ano_atual || '-' || LPAD(proximo_numero::TEXT, 5, '0');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gerar_numero_pedido_compra
    BEFORE INSERT ON pedidos_compra
    FOR EACH ROW
    WHEN (NEW.numero IS NULL OR NEW.numero = '')
    EXECUTE FUNCTION gerar_numero_pedido_compra();

-- Função para atualizar estoque na venda
CREATE OR REPLACE FUNCTION atualizar_estoque_venda()
RETURNS TRIGGER AS $$
DECLARE
    v_estoque_anterior DECIMAL(12,3);
    v_estoque_novo DECIMAL(12,3);
BEGIN
    -- Buscar estoque atual
    SELECT estoque_atual INTO v_estoque_anterior
    FROM produtos WHERE id = NEW.produto_id;
    
    -- Calcular novo estoque
    v_estoque_novo := v_estoque_anterior - NEW.quantidade;
    
    -- Atualizar estoque do produto
    UPDATE produtos
    SET estoque_atual = v_estoque_novo,
        updated_at = NOW()
    WHERE id = NEW.produto_id;
    
    -- Registrar movimentação
    INSERT INTO estoque_movimentacoes (
        produto_id, lote_id, tipo, quantidade,
        estoque_anterior, estoque_novo,
        venda_id, motivo, usuario_id
    ) VALUES (
        NEW.produto_id, NEW.lote_id, 'SAIDA', NEW.quantidade,
        v_estoque_anterior, v_estoque_novo,
        NEW.venda_id, 'Venda', 
        (SELECT vendedor_id FROM vendas WHERE id = NEW.venda_id)
    );
    
    -- Atualizar lote se especificado
    IF NEW.lote_id IS NOT NULL THEN
        UPDATE produto_lotes
        SET quantidade_atual = quantidade_atual - NEW.quantidade,
            status = CASE WHEN quantidade_atual - NEW.quantidade <= 0 THEN 'ESGOTADO' ELSE status END,
            updated_at = NOW()
        WHERE id = NEW.lote_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_atualizar_estoque_venda
    AFTER INSERT ON venda_itens
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_estoque_venda();

-- Função para atualizar estoque no recebimento de compra
CREATE OR REPLACE FUNCTION atualizar_estoque_recebimento()
RETURNS TRIGGER AS $$
DECLARE
    v_item RECORD;
    v_estoque_anterior DECIMAL(12,3);
    v_estoque_novo DECIMAL(12,3);
    v_lote_id UUID;
BEGIN
    -- Só processa quando status muda para RECEBIDO
    IF NEW.status = 'RECEBIDO' AND OLD.status != 'RECEBIDO' THEN
        -- Processar cada item do pedido
        FOR v_item IN 
            SELECT * FROM pedido_compra_itens WHERE pedido_id = NEW.id
        LOOP
            -- Buscar estoque atual
            SELECT estoque_atual INTO v_estoque_anterior
            FROM produtos WHERE id = v_item.produto_id;
            
            v_estoque_novo := v_estoque_anterior + v_item.quantidade;
            
            -- Atualizar estoque do produto
            UPDATE produtos
            SET estoque_atual = v_estoque_novo,
                preco_custo = v_item.preco_unitario,
                updated_at = NOW()
            WHERE id = v_item.produto_id;
            
            -- Criar lote se tiver dados de validade
            IF v_item.data_validade IS NOT NULL THEN
                INSERT INTO produto_lotes (
                    produto_id, numero_lote, data_validade,
                    quantidade_inicial, quantidade_atual,
                    preco_custo, fornecedor_id, nota_fiscal
                ) VALUES (
                    v_item.produto_id, 
                    COALESCE(v_item.numero_lote, 'LOTE-' || TO_CHAR(NOW(), 'YYYYMMDD-HH24MI')),
                    v_item.data_validade,
                    v_item.quantidade, v_item.quantidade,
                    v_item.preco_unitario, NEW.fornecedor_id, NEW.nf_numero
                )
                RETURNING id INTO v_lote_id;
            END IF;
            
            -- Registrar movimentação
            INSERT INTO estoque_movimentacoes (
                produto_id, lote_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                pedido_compra_id, motivo, usuario_id
            ) VALUES (
                v_item.produto_id, v_lote_id, 'ENTRADA', v_item.quantidade,
                v_estoque_anterior, v_estoque_novo,
                NEW.id, 'Recebimento de compra', NEW.usuario_id
            );
        END LOOP;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_atualizar_estoque_recebimento
    AFTER UPDATE ON pedidos_compra
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_estoque_recebimento();

-- Função para atualizar status de lotes vencidos
CREATE OR REPLACE FUNCTION atualizar_lotes_vencidos()
RETURNS INTEGER AS $$
DECLARE
    quantidade_atualizada INTEGER;
BEGIN
    UPDATE produto_lotes
    SET status = 'VENCIDO',
        updated_at = NOW()
    WHERE status = 'ATIVO'
      AND data_validade < CURRENT_DATE;
    
    GET DIAGNOSTICS quantidade_atualizada = ROW_COUNT;
    RETURN quantidade_atualizada;
END;
$$ LANGUAGE plpgsql;

-- Função para atualizar status de contas vencidas
CREATE OR REPLACE FUNCTION atualizar_contas_vencidas()
RETURNS VOID AS $$
BEGIN
    -- Contas a pagar
    UPDATE contas_pagar
    SET status = 'VENCIDO',
        updated_at = NOW()
    WHERE status = 'PENDENTE'
      AND data_vencimento < CURRENT_DATE;
    
    -- Contas a receber
    UPDATE contas_receber
    SET status = 'VENCIDO',
        updated_at = NOW()
    WHERE status = 'PENDENTE'
      AND data_vencimento < CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;

-- Função para gerar contas a receber de venda a prazo
CREATE OR REPLACE FUNCTION gerar_contas_receber_venda()
RETURNS TRIGGER AS $$
BEGIN
    -- Só gera se for venda a prazo
    IF NEW.forma_pagamento = 'PRAZO' AND NEW.status = 'FINALIZADA' AND NEW.cliente_id IS NOT NULL THEN
        INSERT INTO contas_receber (
            numero_documento, descricao, cliente_id, venda_id,
            valor_original, data_vencimento, categoria, usuario_id
        ) VALUES (
            NEW.numero,
            'Venda ' || NEW.numero,
            NEW.cliente_id,
            NEW.id,
            NEW.total,
            CURRENT_DATE + INTERVAL '30 days',
            'VENDA',
            NEW.vendedor_id
        );
        
        -- Atualizar saldo devedor do cliente
        UPDATE clientes
        SET saldo_devedor = saldo_devedor + NEW.total
        WHERE id = NEW.cliente_id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gerar_contas_receber_venda
    AFTER INSERT ON vendas
    FOR EACH ROW
    EXECUTE FUNCTION gerar_contas_receber_venda();

-- Função para gerar contas a pagar de compra
CREATE OR REPLACE FUNCTION gerar_contas_pagar_compra()
RETURNS TRIGGER AS $$
BEGIN
    -- Gera conta a pagar quando pedido é aprovado ou recebido
    IF NEW.status IN ('APROVADO', 'RECEBIDO') AND OLD.status NOT IN ('APROVADO', 'RECEBIDO') THEN
        INSERT INTO contas_pagar (
            numero_documento, descricao, fornecedor_id, pedido_compra_id,
            valor_original, data_vencimento, categoria, usuario_id
        ) VALUES (
            COALESCE(NEW.nf_numero, NEW.numero),
            'Compra ' || NEW.numero || ' - ' || (SELECT razao_social FROM fornecedores WHERE id = NEW.fornecedor_id),
            NEW.fornecedor_id,
            NEW.id,
            NEW.total,
            COALESCE(NEW.data_previsao, CURRENT_DATE + INTERVAL '30 days'),
            'FORNECEDOR',
            NEW.usuario_id
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_gerar_contas_pagar_compra
    AFTER UPDATE ON pedidos_compra
    FOR EACH ROW
    EXECUTE FUNCTION gerar_contas_pagar_compra();

-- =====================================================
-- VIEWS
-- =====================================================

-- View: Produtos com estoque baixo
CREATE OR REPLACE VIEW vw_produtos_estoque_baixo AS
SELECT 
    p.id,
    p.codigo,
    p.nome,
    p.marca,
    c.nome as categoria,
    p.estoque_atual,
    p.estoque_minimo,
    (p.estoque_minimo - p.estoque_atual) as deficit,
    p.preco_custo,
    (p.estoque_minimo - p.estoque_atual) * p.preco_custo as valor_reposicao
FROM produtos p
LEFT JOIN categorias c ON p.categoria_id = c.id
WHERE p.active = true 
  AND p.estoque_atual <= p.estoque_minimo
ORDER BY deficit DESC;

-- View: Produtos próximos da validade
CREATE OR REPLACE VIEW vw_produtos_vencimento AS
SELECT 
    p.id as produto_id,
    p.codigo,
    p.nome,
    p.marca,
    l.id as lote_id,
    l.numero_lote,
    l.data_validade,
    l.quantidade_atual,
    l.status as status_lote,
    (l.data_validade - CURRENT_DATE) as dias_para_vencer,
    CASE 
        WHEN l.data_validade < CURRENT_DATE THEN 'VENCIDO'
        WHEN l.data_validade <= CURRENT_DATE + INTERVAL '7 days' THEN 'CRITICO'
        WHEN l.data_validade <= CURRENT_DATE + INTERVAL '30 days' THEN 'ALERTA'
        ELSE 'OK'
    END as situacao
FROM produto_lotes l
INNER JOIN produtos p ON l.produto_id = p.id
WHERE l.status = 'ATIVO'
  AND l.quantidade_atual > 0
  AND l.data_validade <= CURRENT_DATE + INTERVAL '60 days'
ORDER BY l.data_validade ASC;

-- View: Resumo financeiro
CREATE OR REPLACE VIEW vw_resumo_financeiro AS
SELECT 
    'A_PAGAR' as tipo,
    status,
    COUNT(*) as quantidade,
    SUM(valor_total) as valor_total
FROM contas_pagar
WHERE status IN ('PENDENTE', 'VENCIDO')
GROUP BY status
UNION ALL
SELECT 
    'A_RECEBER' as tipo,
    status,
    COUNT(*) as quantidade,
    SUM(valor_total) as valor_total
FROM contas_receber
WHERE status IN ('PENDENTE', 'VENCIDO')
GROUP BY status;

-- View: Vendas do dia
CREATE OR REPLACE VIEW vw_vendas_hoje AS
SELECT 
    v.id,
    v.numero,
    v.data_venda,
    c.nome as cliente,
    u.full_name as vendedor,
    v.total,
    v.forma_pagamento,
    v.status,
    COUNT(vi.id) as total_itens
FROM vendas v
LEFT JOIN clientes c ON v.cliente_id = c.id
LEFT JOIN users u ON v.vendedor_id = u.id
LEFT JOIN venda_itens vi ON v.id = vi.venda_id
WHERE DATE(v.data_venda) = CURRENT_DATE
  AND v.status = 'FINALIZADA'
GROUP BY v.id, c.nome, u.full_name;

-- View: Contas a pagar vencendo
CREATE OR REPLACE VIEW vw_contas_pagar_vencendo AS
SELECT 
    cp.*,
    f.razao_social as fornecedor_nome,
    (cp.data_vencimento - CURRENT_DATE) as dias_para_vencer
FROM contas_pagar cp
LEFT JOIN fornecedores f ON cp.fornecedor_id = f.id
WHERE cp.status = 'PENDENTE'
  AND cp.data_vencimento <= CURRENT_DATE + INTERVAL '7 days'
ORDER BY cp.data_vencimento ASC;

-- View: Contas a receber vencendo
CREATE OR REPLACE VIEW vw_contas_receber_vencendo AS
SELECT 
    cr.*,
    c.nome as cliente_nome,
    (cr.data_vencimento - CURRENT_DATE) as dias_para_vencer
FROM contas_receber cr
LEFT JOIN clientes c ON cr.cliente_id = c.id
WHERE cr.status = 'PENDENTE'
  AND cr.data_vencimento <= CURRENT_DATE + INTERVAL '7 days'
ORDER BY cr.data_vencimento ASC;

-- View: Estoque valorizado
CREATE OR REPLACE VIEW vw_estoque_valorizado AS
SELECT 
    p.id,
    p.codigo,
    p.nome,
    p.marca,
    c.nome as categoria,
    p.estoque_atual,
    p.preco_custo,
    p.preco_venda,
    (p.estoque_atual * p.preco_custo) as valor_custo_total,
    (p.estoque_atual * p.preco_venda) as valor_venda_total,
    p.margem_lucro
FROM produtos p
LEFT JOIN categorias c ON p.categoria_id = c.id
WHERE p.active = true
  AND p.estoque_atual > 0
ORDER BY valor_custo_total DESC;

-- View: Dashboard de vendas
CREATE OR REPLACE VIEW vw_dashboard_vendas AS
SELECT 
    DATE(data_venda) as data,
    COUNT(*) as total_vendas,
    SUM(total) as faturamento,
    AVG(total) as ticket_medio,
    COUNT(DISTINCT cliente_id) as clientes_atendidos
FROM vendas
WHERE status = 'FINALIZADA'
  AND data_venda >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(data_venda)
ORDER BY data DESC;

-- =====================================================
-- POLÍTICAS RLS (Row Level Security)
-- =====================================================

-- Habilitar RLS em todas as tabelas principais
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE fornecedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE categorias ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendas ENABLE ROW LEVEL SECURITY;
ALTER TABLE venda_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos_compra ENABLE ROW LEVEL SECURITY;
ALTER TABLE contas_pagar ENABLE ROW LEVEL SECURITY;
ALTER TABLE contas_receber ENABLE ROW LEVEL SECURITY;
ALTER TABLE estoque_movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE caixas ENABLE ROW LEVEL SECURITY;
ALTER TABLE caixa_sessoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE produto_lotes ENABLE ROW LEVEL SECURITY;
ALTER TABLE empresa_config ENABLE ROW LEVEL SECURITY;

-- Função auxiliar para verificar se usuário está autenticado
CREATE OR REPLACE FUNCTION auth_user_id() 
RETURNS UUID AS $$
BEGIN
    RETURN auth.uid();
EXCEPTION
    WHEN OTHERS THEN
        RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função para verificar se usuário é admin ou gerente
CREATE OR REPLACE FUNCTION is_admin_or_manager() 
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM users 
        WHERE id = auth.uid() 
        AND role IN ('ADMIN', 'GERENTE')
        AND active = true
        AND approved = true
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Políticas básicas (permitir tudo para usuários autenticados - ajustar conforme necessidade)
CREATE POLICY "Usuários autenticados podem ver produtos" ON produtos
    FOR SELECT USING (auth.uid() IS NOT NULL);

CREATE POLICY "Usuários autenticados podem inserir produtos" ON produtos
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Usuários autenticados podem atualizar produtos" ON produtos
    FOR UPDATE USING (auth.uid() IS NOT NULL);

CREATE POLICY "Admin pode deletar produtos" ON produtos
    FOR DELETE USING (is_admin_or_manager());

-- Políticas para outras tabelas (padrão)
CREATE POLICY "Acesso geral" ON fornecedores FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON clientes FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON categorias FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON vendas FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON venda_itens FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON pedidos_compra FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON contas_pagar FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON contas_receber FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON estoque_movimentacoes FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON caixas FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON caixa_sessoes FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON produto_lotes FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso geral" ON empresa_config FOR ALL USING (auth.uid() IS NOT NULL);
CREATE POLICY "Acesso próprio e admin" ON users FOR SELECT USING (auth.uid() = id OR is_admin_or_manager());
CREATE POLICY "Admin pode gerenciar users" ON users FOR ALL USING (is_admin_or_manager());

-- =====================================================
-- DADOS INICIAIS
-- =====================================================

-- Inserir configuração inicial da empresa
INSERT INTO empresa_config (razao_social, nome_fantasia, cnpj) 
VALUES ('MINHA DISTRIBUIDORA LTDA', 'MINHA DISTRIBUIDORA', '00.000.000/0001-00');

-- =====================================================
-- FINALIZAÇÃO
-- =====================================================

SELECT '✅ SCHEMA DISTRIBUIDORA CRIADO COM SUCESSO!' as status,
       'Execute este schema em um banco Supabase limpo' as instrucao,
       'Configure o primeiro usuário admin após executar' as proximo_passo;
