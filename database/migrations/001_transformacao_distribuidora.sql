-- =====================================================
-- MIGRAÇÃO: TRANSFORMAÇÃO PARA DISTRIBUIDORA DE BEBIDAS
-- =====================================================
-- Versão: 1.0.0
-- Data: 02/02/2026
-- Descrição: Migração completa para sistema de PDV de alto fluxo
--            com integração fiscal (NFC-e/NF-e via Focus NFe)
-- =====================================================

-- =====================================================
-- FASE 1: BACKUP E PREPARAÇÃO
-- =====================================================

-- Criar tabela de backup de sabores antes de remover
CREATE TABLE IF NOT EXISTS _backup_produto_sabores AS
SELECT * FROM produto_sabores;

CREATE TABLE IF NOT EXISTS _backup_pre_pedido_itens AS
SELECT * FROM pre_pedido_itens;

-- =====================================================
-- FASE 2: ALTERAÇÕES NA TABELA DE PRODUTOS
-- =====================================================

-- Adicionar campos fiscais e de código de barras
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS codigo_barras VARCHAR(20);
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS codigo_barras_embalagem VARCHAR(20);

-- Campos fiscais obrigatórios para NFC-e/NF-e
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS ncm VARCHAR(10); -- Nomenclatura Comum do Mercosul
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS cest VARCHAR(9); -- Código Especificador da Substituição Tributária
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS cfop VARCHAR(4) DEFAULT '5102'; -- Código Fiscal de Operações
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS origem INTEGER DEFAULT 0; -- 0=Nacional, 1=Estrangeira, etc
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS cst_icms VARCHAR(3); -- Código de Situação Tributária ICMS
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS csosn VARCHAR(3); -- Simples Nacional
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS aliquota_icms DECIMAL(5,2) DEFAULT 0;
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS aliquota_pis DECIMAL(5,4) DEFAULT 0;
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS aliquota_cofins DECIMAL(5,4) DEFAULT 0;
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS cst_pis VARCHAR(2) DEFAULT '01';
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS cst_cofins VARCHAR(2) DEFAULT '01';

-- Campos de controle de embalagem
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS quantidade_embalagem INTEGER DEFAULT 1;
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS unidade_tributavel VARCHAR(10);
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS preco_unitario_tributavel DECIMAL(10,4);

-- Campo para produtos compostos (kits/combos)
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS tipo_produto VARCHAR(20) DEFAULT 'SIMPLES' 
    CHECK (tipo_produto IN ('SIMPLES', 'KIT', 'SERVICO'));

-- Peso para frete
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS peso_liquido DECIMAL(10,3);
ALTER TABLE produtos ADD COLUMN IF NOT EXISTS peso_bruto DECIMAL(10,3);

-- Índices para busca rápida por código de barras (PDV)
CREATE INDEX IF NOT EXISTS idx_produtos_codigo_barras ON produtos(codigo_barras);
CREATE INDEX IF NOT EXISTS idx_produtos_codigo_barras_emb ON produtos(codigo_barras_embalagem);
CREATE INDEX IF NOT EXISTS idx_produtos_ncm ON produtos(ncm);

-- =====================================================
-- FASE 3: CONFIGURAÇÕES DA EMPRESA - DADOS FISCAIS E API
-- =====================================================

-- Expandir tabela empresa_config com dados fiscais e API
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS inscricao_estadual VARCHAR(20);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS inscricao_municipal VARCHAR(20);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS regime_tributario INTEGER DEFAULT 1; -- 1=Simples Nacional, 3=Lucro Presumido
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS numero VARCHAR(20);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS complemento VARCHAR(100);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS bairro VARCHAR(100);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS codigo_municipio VARCHAR(7);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS codigo_pais VARCHAR(4) DEFAULT '1058';
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS nome_pais VARCHAR(50) DEFAULT 'Brasil';
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS telefone_secundario VARCHAR(20);

-- Configurações Focus NFe
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_token VARCHAR(100);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_ambiente INTEGER DEFAULT 2; -- 1=Produção, 2=Homologação
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_ref_nfce_ultima INTEGER DEFAULT 0;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_ref_nfe_ultima INTEGER DEFAULT 0;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_serie_nfce INTEGER DEFAULT 1;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_serie_nfe INTEGER DEFAULT 1;

-- Certificado Digital (A1)
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS certificado_validade DATE;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS certificado_arquivo_url TEXT;

-- CSC para NFC-e (Código de Segurança do Contribuinte)
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS csc_nfce_id VARCHAR(10);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS csc_nfce_token VARCHAR(50);

-- Configurações de impressão
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS impressora_padrao VARCHAR(100);
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS largura_cupom INTEGER DEFAULT 80; -- mm
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS mensagem_cupom TEXT;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS mensagem_promocional TEXT;

-- Configurações de operação
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS permite_venda_estoque_negativo BOOLEAN DEFAULT false;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS exige_cliente_venda BOOLEAN DEFAULT false;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS exige_vendedor_venda BOOLEAN DEFAULT true;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS desconto_maximo_percentual DECIMAL(5,2) DEFAULT 10.00;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS acrescimo_maximo_percentual DECIMAL(5,2) DEFAULT 0;

-- =====================================================
-- FASE 4: TABELA DE CAIXAS (CONTROLE DE PDV)
-- =====================================================

CREATE TABLE IF NOT EXISTS caixas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero INTEGER NOT NULL,
    nome VARCHAR(100) NOT NULL,
    terminal VARCHAR(100), -- Identificação do computador/terminal
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(numero)
);

-- Tabela de abertura/fechamento de caixa
CREATE TABLE IF NOT EXISTS caixa_sessoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    caixa_id UUID REFERENCES caixas(id) NOT NULL,
    usuario_id UUID REFERENCES users(id) NOT NULL,
    status VARCHAR(20) DEFAULT 'ABERTO' CHECK (status IN ('ABERTO', 'FECHADO', 'CONFERINDO')),
    
    -- Valores de abertura
    valor_abertura DECIMAL(12,2) NOT NULL DEFAULT 0,
    data_abertura TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Valores de fechamento
    valor_fechamento_sistema DECIMAL(12,2), -- Calculado pelo sistema
    valor_fechamento_informado DECIMAL(12,2), -- Informado pelo operador
    diferenca DECIMAL(12,2),
    data_fechamento TIMESTAMP WITH TIME ZONE,
    usuario_fechamento_id UUID REFERENCES users(id),
    
    -- Totais por forma de pagamento (atualizado em tempo real)
    total_dinheiro DECIMAL(12,2) DEFAULT 0,
    total_pix DECIMAL(12,2) DEFAULT 0,
    total_debito DECIMAL(12,2) DEFAULT 0,
    total_credito DECIMAL(12,2) DEFAULT 0,
    total_crediario DECIMAL(12,2) DEFAULT 0,
    total_outros DECIMAL(12,2) DEFAULT 0,
    
    -- Movimentações
    total_sangrias DECIMAL(12,2) DEFAULT 0,
    total_suprimentos DECIMAL(12,2) DEFAULT 0,
    total_cancelamentos DECIMAL(12,2) DEFAULT 0,
    
    observacoes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Movimentações do caixa (sangria, suprimento)
CREATE TABLE IF NOT EXISTS caixa_movimentacoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sessao_id UUID REFERENCES caixa_sessoes(id) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('SANGRIA', 'SUPRIMENTO', 'AJUSTE')),
    valor DECIMAL(12,2) NOT NULL,
    motivo TEXT NOT NULL,
    usuario_id UUID REFERENCES users(id) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_caixa_sessoes_status ON caixa_sessoes(status);
CREATE INDEX IF NOT EXISTS idx_caixa_sessoes_usuario ON caixa_sessoes(usuario_id);
CREATE INDEX IF NOT EXISTS idx_caixa_sessoes_data ON caixa_sessoes(data_abertura DESC);

-- =====================================================
-- FASE 5: TABELA DE VENDAS PDV (ALTO DESEMPENHO)
-- =====================================================

-- Tabela principal de vendas (otimizada para PDV)
CREATE TABLE IF NOT EXISTS vendas (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero_venda SERIAL, -- Número sequencial rápido
    
    -- Referências
    sessao_caixa_id UUID REFERENCES caixa_sessoes(id),
    cliente_id UUID REFERENCES clientes(id),
    vendedor_id UUID REFERENCES users(id) NOT NULL,
    
    -- Valores
    subtotal DECIMAL(12,2) NOT NULL DEFAULT 0,
    desconto_percentual DECIMAL(5,2) DEFAULT 0,
    desconto_valor DECIMAL(12,2) DEFAULT 0,
    acrescimo_percentual DECIMAL(5,2) DEFAULT 0,
    acrescimo_valor DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) NOT NULL DEFAULT 0,
    
    -- Status
    status VARCHAR(20) DEFAULT 'EM_ANDAMENTO' 
        CHECK (status IN ('EM_ANDAMENTO', 'FINALIZADA', 'CANCELADA', 'PENDENTE')),
    
    -- Fiscal
    tipo_documento VARCHAR(10) CHECK (tipo_documento IN ('NFCE', 'NFE', 'ORCAMENTO', 'CUPOM_NAO_FISCAL')),
    documento_fiscal_id UUID, -- Referência para documentos_fiscais
    
    -- Controle
    observacoes TEXT,
    motivo_cancelamento TEXT,
    cancelado_por UUID REFERENCES users(id),
    data_cancelamento TIMESTAMP WITH TIME ZONE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabela de itens da venda (otimizada)
CREATE TABLE IF NOT EXISTS venda_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venda_id UUID REFERENCES vendas(id) ON DELETE CASCADE NOT NULL,
    sequencial INTEGER NOT NULL, -- Ordem do item na venda
    
    -- Produto
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    codigo_barras VARCHAR(20),
    descricao VARCHAR(255) NOT NULL, -- Snapshot do nome
    unidade VARCHAR(10) NOT NULL,
    
    -- Quantidades e valores
    quantidade DECIMAL(10,3) NOT NULL,
    preco_unitario DECIMAL(12,4) NOT NULL,
    desconto_percentual DECIMAL(5,2) DEFAULT 0,
    desconto_valor DECIMAL(12,2) DEFAULT 0,
    subtotal DECIMAL(12,2) NOT NULL,
    
    -- Dados fiscais (snapshot)
    ncm VARCHAR(10),
    cfop VARCHAR(4),
    cst_icms VARCHAR(3),
    aliquota_icms DECIMAL(5,2),
    
    -- Controle
    cancelado BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices otimizados para PDV
CREATE INDEX IF NOT EXISTS idx_vendas_numero ON vendas(numero_venda);
CREATE INDEX IF NOT EXISTS idx_vendas_status ON vendas(status);
CREATE INDEX IF NOT EXISTS idx_vendas_sessao ON vendas(sessao_caixa_id);
CREATE INDEX IF NOT EXISTS idx_vendas_created ON vendas(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_venda_itens_venda ON venda_itens(venda_id);
CREATE INDEX IF NOT EXISTS idx_venda_itens_produto ON venda_itens(produto_id);

-- =====================================================
-- FASE 6: TABELA DE PAGAMENTOS (MULTIFORMA)
-- =====================================================

-- Formas de pagamento configuráveis
CREATE TABLE IF NOT EXISTS formas_pagamento (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo VARCHAR(20) UNIQUE NOT NULL,
    descricao VARCHAR(100) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('DINHEIRO', 'PIX', 'DEBITO', 'CREDITO', 'CREDIARIO', 'BOLETO', 'CHEQUE', 'OUTROS')),
    
    -- Integração TEF (se aplicável)
    tef_habilitado BOOLEAN DEFAULT false,
    tef_codigo VARCHAR(20),
    
    -- Taxas
    taxa_percentual DECIMAL(5,2) DEFAULT 0,
    dias_recebimento INTEGER DEFAULT 0, -- D+X
    
    -- Parcelas (para crédito)
    permite_parcelamento BOOLEAN DEFAULT false,
    parcelas_maximas INTEGER DEFAULT 1,
    parcela_minima DECIMAL(10,2),
    
    -- Controle
    ativo BOOLEAN DEFAULT true,
    ordem INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Pagamentos da venda (multiforma)
CREATE TABLE IF NOT EXISTS venda_pagamentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    venda_id UUID REFERENCES vendas(id) ON DELETE CASCADE NOT NULL,
    forma_pagamento_id UUID REFERENCES formas_pagamento(id) NOT NULL,
    
    valor DECIMAL(12,2) NOT NULL,
    parcelas INTEGER DEFAULT 1,
    
    -- TEF/Cartão
    nsu VARCHAR(50),
    autorizacao VARCHAR(50),
    bandeira VARCHAR(50),
    
    -- PIX
    txid VARCHAR(100),
    
    -- Troco (para dinheiro)
    valor_recebido DECIMAL(12,2),
    troco DECIMAL(12,2),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Inserir formas de pagamento padrão
INSERT INTO formas_pagamento (codigo, descricao, tipo, ordem) VALUES
    ('DIN', 'Dinheiro', 'DINHEIRO', 1),
    ('PIX', 'PIX', 'PIX', 2),
    ('DEB', 'Cartão de Débito', 'DEBITO', 3),
    ('CRE', 'Cartão de Crédito', 'CREDITO', 4),
    ('CRD', 'Crediário', 'CREDIARIO', 5)
ON CONFLICT (codigo) DO NOTHING;

-- =====================================================
-- FASE 7: DOCUMENTOS FISCAIS (NFC-e / NF-e)
-- =====================================================

CREATE TABLE IF NOT EXISTS documentos_fiscais (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Tipo e identificação
    tipo VARCHAR(10) NOT NULL CHECK (tipo IN ('NFCE', 'NFE')),
    numero INTEGER NOT NULL,
    serie INTEGER NOT NULL,
    chave VARCHAR(44), -- Chave de acesso
    
    -- Referências
    venda_id UUID REFERENCES vendas(id),
    cliente_id UUID REFERENCES clientes(id),
    
    -- Status SEFAZ
    status VARCHAR(30) DEFAULT 'PENDENTE' 
        CHECK (status IN ('PENDENTE', 'PROCESSANDO', 'AUTORIZADA', 'REJEITADA', 'CANCELADA', 'INUTILIZADA', 'DENEGADA')),
    status_sefaz VARCHAR(10), -- Código retorno SEFAZ
    motivo_sefaz TEXT, -- Mensagem retorno SEFAZ
    
    -- Protocolo
    protocolo VARCHAR(20),
    data_autorizacao TIMESTAMP WITH TIME ZONE,
    
    -- Valores
    valor_total DECIMAL(12,2) NOT NULL,
    valor_produtos DECIMAL(12,2),
    valor_desconto DECIMAL(12,2),
    valor_icms DECIMAL(12,2),
    valor_pis DECIMAL(12,2),
    valor_cofins DECIMAL(12,2),
    
    -- Focus NFe
    focusnfe_ref VARCHAR(100), -- Referência única Focus
    focusnfe_status VARCHAR(50),
    focusnfe_url_danfe TEXT,
    focusnfe_url_xml TEXT,
    
    -- Cancelamento
    cancelado BOOLEAN DEFAULT false,
    protocolo_cancelamento VARCHAR(20),
    data_cancelamento TIMESTAMP WITH TIME ZONE,
    justificativa_cancelamento TEXT,
    
    -- XML e DANFE
    xml_envio TEXT,
    xml_retorno TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_doc_fiscal_tipo ON documentos_fiscais(tipo);
CREATE INDEX IF NOT EXISTS idx_doc_fiscal_status ON documentos_fiscais(status);
CREATE INDEX IF NOT EXISTS idx_doc_fiscal_chave ON documentos_fiscais(chave);
CREATE INDEX IF NOT EXISTS idx_doc_fiscal_venda ON documentos_fiscais(venda_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_doc_fiscal_numero ON documentos_fiscais(tipo, serie, numero);

-- =====================================================
-- FASE 8: CONTAS A RECEBER
-- =====================================================

CREATE TABLE IF NOT EXISTS contas_receber (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    
    -- Referências
    venda_id UUID REFERENCES vendas(id),
    cliente_id UUID REFERENCES clientes(id) NOT NULL,
    
    -- Identificação
    documento VARCHAR(50),
    parcela INTEGER DEFAULT 1,
    total_parcelas INTEGER DEFAULT 1,
    
    -- Valores
    valor_original DECIMAL(12,2) NOT NULL,
    valor_juros DECIMAL(12,2) DEFAULT 0,
    valor_multa DECIMAL(12,2) DEFAULT 0,
    valor_desconto DECIMAL(12,2) DEFAULT 0,
    valor_pago DECIMAL(12,2) DEFAULT 0,
    valor_aberto DECIMAL(12,2) NOT NULL,
    
    -- Datas
    data_vencimento DATE NOT NULL,
    data_pagamento DATE,
    
    -- Status
    status VARCHAR(20) DEFAULT 'ABERTO' 
        CHECK (status IN ('ABERTO', 'PAGO', 'PARCIAL', 'VENCIDO', 'CANCELADO', 'RENEGOCIADO')),
    
    -- Forma de pagamento prevista
    forma_pagamento_id UUID REFERENCES formas_pagamento(id),
    
    observacoes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Histórico de pagamentos de contas
CREATE TABLE IF NOT EXISTS contas_receber_pagamentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conta_id UUID REFERENCES contas_receber(id) NOT NULL,
    valor DECIMAL(12,2) NOT NULL,
    forma_pagamento_id UUID REFERENCES formas_pagamento(id),
    usuario_id UUID REFERENCES users(id),
    observacao TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_contas_receber_cliente ON contas_receber(cliente_id);
CREATE INDEX IF NOT EXISTS idx_contas_receber_vencimento ON contas_receber(data_vencimento);
CREATE INDEX IF NOT EXISTS idx_contas_receber_status ON contas_receber(status);

-- =====================================================
-- FASE 9: ANÁLISE DE FORNECEDORES E COMPRAS
-- =====================================================

-- Expandir fornecedores com dados de análise
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS inscricao_estadual VARCHAR(20);
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS razao_social VARCHAR(255);
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS prazo_medio_entrega INTEGER; -- em dias
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS prazo_pagamento INTEGER; -- em dias
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS desconto_padrao DECIMAL(5,2) DEFAULT 0;
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS limite_credito DECIMAL(12,2);
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS observacoes_internas TEXT;
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS avaliacao INTEGER CHECK (avaliacao BETWEEN 1 AND 5);
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS banco VARCHAR(50);
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS agencia VARCHAR(20);
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS conta VARCHAR(20);
ALTER TABLE fornecedores ADD COLUMN IF NOT EXISTS pix_chave VARCHAR(100);

-- Tabela de cotações/orçamentos de compra
CREATE TABLE IF NOT EXISTS cotacoes_compra (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(50) UNIQUE NOT NULL,
    fornecedor_id UUID REFERENCES fornecedores(id) NOT NULL,
    usuario_id UUID REFERENCES users(id) NOT NULL,
    
    status VARCHAR(20) DEFAULT 'ABERTA' 
        CHECK (status IN ('ABERTA', 'APROVADA', 'REJEITADA', 'CONVERTIDA', 'EXPIRADA')),
    
    validade DATE,
    prazo_entrega INTEGER,
    condicao_pagamento TEXT,
    
    subtotal DECIMAL(12,2) DEFAULT 0,
    desconto DECIMAL(12,2) DEFAULT 0,
    frete DECIMAL(12,2) DEFAULT 0,
    total DECIMAL(12,2) DEFAULT 0,
    
    observacoes TEXT,
    pedido_gerado_id UUID REFERENCES pedidos(id),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Itens da cotação
CREATE TABLE IF NOT EXISTS cotacao_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cotacao_id UUID REFERENCES cotacoes_compra(id) ON DELETE CASCADE NOT NULL,
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    quantidade DECIMAL(10,3) NOT NULL,
    preco_unitario DECIMAL(12,4) NOT NULL,
    subtotal DECIMAL(12,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- View de análise de fornecedores
CREATE OR REPLACE VIEW vw_analise_fornecedores AS
SELECT 
    f.id,
    f.nome,
    f.cpf_cnpj,
    f.avaliacao,
    f.prazo_medio_entrega,
    COUNT(DISTINCT p.id) as total_pedidos,
    SUM(p.total) as valor_total_compras,
    AVG(p.total) as ticket_medio,
    COUNT(DISTINCT CASE WHEN p.status = 'FINALIZADO' THEN p.id END) as pedidos_finalizados,
    MAX(p.created_at) as ultima_compra
FROM fornecedores f
LEFT JOIN pedidos p ON p.fornecedor_id = f.id AND p.tipo_pedido = 'COMPRA'
WHERE f.active = true
GROUP BY f.id, f.nome, f.cpf_cnpj, f.avaliacao, f.prazo_medio_entrega;

-- =====================================================
-- FASE 10: FUNÇÕES PARA PDV DE ALTO DESEMPENHO
-- =====================================================

-- Função: Buscar produto por código de barras (otimizada)
CREATE OR REPLACE FUNCTION buscar_produto_codigo_barras(p_codigo VARCHAR)
RETURNS TABLE (
    id UUID,
    codigo VARCHAR,
    codigo_barras VARCHAR,
    nome VARCHAR,
    unidade VARCHAR,
    preco_venda DECIMAL,
    estoque_atual DECIMAL,
    ncm VARCHAR,
    cfop VARCHAR,
    cst_icms VARCHAR,
    aliquota_icms DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.codigo,
        p.codigo_barras,
        p.nome,
        p.unidade,
        p.preco_venda,
        p.estoque_atual,
        p.ncm,
        p.cfop,
        p.cst_icms,
        p.aliquota_icms
    FROM produtos p
    WHERE p.active = true
      AND (p.codigo_barras = p_codigo 
           OR p.codigo_barras_embalagem = p_codigo
           OR p.codigo = p_codigo)
    LIMIT 1;
END;
$$ LANGUAGE plpgsql STABLE;

-- Função: Iniciar venda no PDV
CREATE OR REPLACE FUNCTION iniciar_venda_pdv(
    p_vendedor_id UUID,
    p_sessao_caixa_id UUID DEFAULT NULL,
    p_cliente_id UUID DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_venda_id UUID;
BEGIN
    INSERT INTO vendas (
        sessao_caixa_id,
        cliente_id,
        vendedor_id,
        status
    ) VALUES (
        p_sessao_caixa_id,
        p_cliente_id,
        p_vendedor_id,
        'EM_ANDAMENTO'
    ) RETURNING id INTO v_venda_id;
    
    RETURN v_venda_id;
END;
$$ LANGUAGE plpgsql;

-- Função: Adicionar item à venda (otimizada)
CREATE OR REPLACE FUNCTION adicionar_item_venda(
    p_venda_id UUID,
    p_produto_id UUID,
    p_quantidade DECIMAL DEFAULT 1,
    p_desconto_percentual DECIMAL DEFAULT 0
)
RETURNS UUID AS $$
DECLARE
    v_produto RECORD;
    v_item_id UUID;
    v_sequencial INTEGER;
    v_subtotal DECIMAL;
    v_desconto_valor DECIMAL;
BEGIN
    -- Buscar dados do produto
    SELECT * INTO v_produto
    FROM produtos
    WHERE id = p_produto_id AND active = true;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Produto não encontrado ou inativo';
    END IF;
    
    -- Verificar estoque
    IF v_produto.estoque_atual < p_quantidade THEN
        -- Verificar configuração de venda sem estoque
        IF NOT EXISTS (SELECT 1 FROM empresa_config WHERE permite_venda_estoque_negativo = true LIMIT 1) THEN
            RAISE EXCEPTION 'Estoque insuficiente. Disponível: %', v_produto.estoque_atual;
        END IF;
    END IF;
    
    -- Calcular sequencial
    SELECT COALESCE(MAX(sequencial), 0) + 1 INTO v_sequencial
    FROM venda_itens
    WHERE venda_id = p_venda_id;
    
    -- Calcular valores
    v_desconto_valor := (v_produto.preco_venda * p_quantidade) * (p_desconto_percentual / 100);
    v_subtotal := (v_produto.preco_venda * p_quantidade) - v_desconto_valor;
    
    -- Inserir item
    INSERT INTO venda_itens (
        venda_id,
        sequencial,
        produto_id,
        codigo_barras,
        descricao,
        unidade,
        quantidade,
        preco_unitario,
        desconto_percentual,
        desconto_valor,
        subtotal,
        ncm,
        cfop,
        cst_icms,
        aliquota_icms
    ) VALUES (
        p_venda_id,
        v_sequencial,
        p_produto_id,
        v_produto.codigo_barras,
        v_produto.nome,
        v_produto.unidade,
        p_quantidade,
        v_produto.preco_venda,
        p_desconto_percentual,
        v_desconto_valor,
        v_subtotal,
        v_produto.ncm,
        v_produto.cfop,
        v_produto.cst_icms,
        v_produto.aliquota_icms
    ) RETURNING id INTO v_item_id;
    
    -- Atualizar totais da venda
    PERFORM atualizar_totais_venda(p_venda_id);
    
    RETURN v_item_id;
END;
$$ LANGUAGE plpgsql;

-- Função: Atualizar totais da venda
CREATE OR REPLACE FUNCTION atualizar_totais_venda(p_venda_id UUID)
RETURNS VOID AS $$
DECLARE
    v_subtotal DECIMAL;
    v_desconto_itens DECIMAL;
    v_venda RECORD;
    v_total DECIMAL;
BEGIN
    -- Calcular subtotal e descontos dos itens
    SELECT 
        COALESCE(SUM(subtotal + desconto_valor), 0),
        COALESCE(SUM(desconto_valor), 0)
    INTO v_subtotal, v_desconto_itens
    FROM venda_itens
    WHERE venda_id = p_venda_id AND NOT cancelado;
    
    -- Buscar descontos/acréscimos da venda
    SELECT * INTO v_venda FROM vendas WHERE id = p_venda_id;
    
    -- Calcular total final
    v_total := v_subtotal 
        - v_desconto_itens 
        - COALESCE(v_venda.desconto_valor, 0)
        + COALESCE(v_venda.acrescimo_valor, 0);
    
    -- Atualizar venda
    UPDATE vendas
    SET 
        subtotal = v_subtotal,
        total = v_total,
        updated_at = NOW()
    WHERE id = p_venda_id;
END;
$$ LANGUAGE plpgsql;

-- Função: Finalizar venda com pagamento
CREATE OR REPLACE FUNCTION finalizar_venda_pdv(
    p_venda_id UUID,
    p_pagamentos JSONB, -- Array de {forma_pagamento_id, valor, nsu?, parcelas?}
    p_tipo_documento VARCHAR DEFAULT 'NFCE'
)
RETURNS JSONB AS $$
DECLARE
    v_venda RECORD;
    v_pagamento JSONB;
    v_total_pago DECIMAL := 0;
    v_item RECORD;
BEGIN
    -- Verificar venda
    SELECT * INTO v_venda FROM vendas WHERE id = p_venda_id FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Venda não encontrada';
    END IF;
    
    IF v_venda.status != 'EM_ANDAMENTO' THEN
        RAISE EXCEPTION 'Venda não está em andamento. Status: %', v_venda.status;
    END IF;
    
    IF v_venda.total <= 0 THEN
        RAISE EXCEPTION 'Venda sem itens ou com valor zerado';
    END IF;
    
    -- Processar pagamentos
    FOR v_pagamento IN SELECT * FROM jsonb_array_elements(p_pagamentos)
    LOOP
        INSERT INTO venda_pagamentos (
            venda_id,
            forma_pagamento_id,
            valor,
            parcelas,
            nsu,
            valor_recebido,
            troco
        ) VALUES (
            p_venda_id,
            (v_pagamento->>'forma_pagamento_id')::UUID,
            (v_pagamento->>'valor')::DECIMAL,
            COALESCE((v_pagamento->>'parcelas')::INTEGER, 1),
            v_pagamento->>'nsu',
            (v_pagamento->>'valor_recebido')::DECIMAL,
            (v_pagamento->>'troco')::DECIMAL
        );
        
        v_total_pago := v_total_pago + (v_pagamento->>'valor')::DECIMAL;
    END LOOP;
    
    -- Verificar se pagamento cobre o total
    IF v_total_pago < v_venda.total THEN
        RAISE EXCEPTION 'Pagamento insuficiente. Total: %, Pago: %', v_venda.total, v_total_pago;
    END IF;
    
    -- Baixar estoque
    FOR v_item IN 
        SELECT produto_id, quantidade 
        FROM venda_itens 
        WHERE venda_id = p_venda_id AND NOT cancelado
    LOOP
        UPDATE produtos
        SET estoque_atual = estoque_atual - v_item.quantidade
        WHERE id = v_item.produto_id;
        
        -- Registrar movimentação
        INSERT INTO estoque_movimentacoes (
            produto_id,
            tipo,
            quantidade,
            estoque_anterior,
            estoque_novo,
            usuario_id,
            observacao
        )
        SELECT 
            v_item.produto_id,
            'SAIDA',
            v_item.quantidade,
            estoque_atual + v_item.quantidade,
            estoque_atual,
            v_venda.vendedor_id,
            'Venda PDV #' || v_venda.numero_venda
        FROM produtos WHERE id = v_item.produto_id;
    END LOOP;
    
    -- Atualizar status da venda
    UPDATE vendas
    SET 
        status = 'FINALIZADA',
        tipo_documento = p_tipo_documento,
        updated_at = NOW()
    WHERE id = p_venda_id;
    
    -- Atualizar totais da sessão do caixa
    IF v_venda.sessao_caixa_id IS NOT NULL THEN
        PERFORM atualizar_totais_sessao_caixa(v_venda.sessao_caixa_id);
    END IF;
    
    RETURN jsonb_build_object(
        'success', true,
        'venda_id', p_venda_id,
        'numero_venda', v_venda.numero_venda,
        'total', v_venda.total,
        'total_pago', v_total_pago,
        'troco', v_total_pago - v_venda.total
    );
END;
$$ LANGUAGE plpgsql;

-- Função: Atualizar totais da sessão do caixa
CREATE OR REPLACE FUNCTION atualizar_totais_sessao_caixa(p_sessao_id UUID)
RETURNS VOID AS $$
BEGIN
    UPDATE caixa_sessoes cs
    SET 
        total_dinheiro = (
            SELECT COALESCE(SUM(vp.valor), 0)
            FROM venda_pagamentos vp
            JOIN vendas v ON v.id = vp.venda_id
            JOIN formas_pagamento fp ON fp.id = vp.forma_pagamento_id
            WHERE v.sessao_caixa_id = p_sessao_id 
              AND v.status = 'FINALIZADA'
              AND fp.tipo = 'DINHEIRO'
        ),
        total_pix = (
            SELECT COALESCE(SUM(vp.valor), 0)
            FROM venda_pagamentos vp
            JOIN vendas v ON v.id = vp.venda_id
            JOIN formas_pagamento fp ON fp.id = vp.forma_pagamento_id
            WHERE v.sessao_caixa_id = p_sessao_id 
              AND v.status = 'FINALIZADA'
              AND fp.tipo = 'PIX'
        ),
        total_debito = (
            SELECT COALESCE(SUM(vp.valor), 0)
            FROM venda_pagamentos vp
            JOIN vendas v ON v.id = vp.venda_id
            JOIN formas_pagamento fp ON fp.id = vp.forma_pagamento_id
            WHERE v.sessao_caixa_id = p_sessao_id 
              AND v.status = 'FINALIZADA'
              AND fp.tipo = 'DEBITO'
        ),
        total_credito = (
            SELECT COALESCE(SUM(vp.valor), 0)
            FROM venda_pagamentos vp
            JOIN vendas v ON v.id = vp.venda_id
            JOIN formas_pagamento fp ON fp.id = vp.forma_pagamento_id
            WHERE v.sessao_caixa_id = p_sessao_id 
              AND v.status = 'FINALIZADA'
              AND fp.tipo = 'CREDITO'
        ),
        total_crediario = (
            SELECT COALESCE(SUM(vp.valor), 0)
            FROM venda_pagamentos vp
            JOIN vendas v ON v.id = vp.venda_id
            JOIN formas_pagamento fp ON fp.id = vp.forma_pagamento_id
            WHERE v.sessao_caixa_id = p_sessao_id 
              AND v.status = 'FINALIZADA'
              AND fp.tipo = 'CREDIARIO'
        ),
        total_cancelamentos = (
            SELECT COALESCE(SUM(v.total), 0)
            FROM vendas v
            WHERE v.sessao_caixa_id = p_sessao_id 
              AND v.status = 'CANCELADA'
        ),
        updated_at = NOW()
    WHERE id = p_sessao_id;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- FASE 11: TRIGGERS DE ATUALIZAÇÃO
-- =====================================================

-- Trigger para updated_at nas novas tabelas
CREATE TRIGGER update_vendas_updated_at
    BEFORE UPDATE ON vendas
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_caixa_sessoes_updated_at
    BEFORE UPDATE ON caixa_sessoes
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_documentos_fiscais_updated_at
    BEFORE UPDATE ON documentos_fiscais
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_contas_receber_updated_at
    BEFORE UPDATE ON contas_receber
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- FASE 12: VIEWS DE ANÁLISE E DASHBOARD
-- =====================================================

-- View: Dashboard PDV em tempo real
CREATE OR REPLACE VIEW vw_dashboard_pdv AS
SELECT 
    DATE(v.created_at) as data,
    COUNT(*) as total_vendas,
    SUM(v.total) as valor_total,
    AVG(v.total) as ticket_medio,
    COUNT(DISTINCT v.cliente_id) as clientes_unicos,
    SUM(CASE WHEN v.status = 'CANCELADA' THEN 1 ELSE 0 END) as vendas_canceladas,
    SUM(CASE WHEN v.status = 'CANCELADA' THEN v.total ELSE 0 END) as valor_cancelado
FROM vendas v
WHERE v.created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(v.created_at)
ORDER BY data DESC;

-- View: Produtos mais vendidos
CREATE OR REPLACE VIEW vw_produtos_mais_vendidos AS
SELECT 
    p.id,
    p.codigo,
    p.nome,
    p.categoria,
    SUM(vi.quantidade) as quantidade_vendida,
    SUM(vi.subtotal) as valor_total,
    COUNT(DISTINCT vi.venda_id) as total_vendas
FROM venda_itens vi
JOIN produtos p ON p.id = vi.produto_id
JOIN vendas v ON v.id = vi.venda_id
WHERE v.status = 'FINALIZADA'
  AND v.created_at >= CURRENT_DATE - INTERVAL '30 days'
  AND NOT vi.cancelado
GROUP BY p.id, p.codigo, p.nome, p.categoria
ORDER BY quantidade_vendida DESC;

-- View: Conciliação por forma de pagamento
CREATE OR REPLACE VIEW vw_conciliacao_pagamentos AS
SELECT 
    DATE(v.created_at) as data,
    fp.descricao as forma_pagamento,
    fp.tipo,
    COUNT(*) as quantidade,
    SUM(vp.valor) as valor_total,
    SUM(vp.valor * fp.taxa_percentual / 100) as taxa_estimada,
    SUM(vp.valor) - SUM(vp.valor * fp.taxa_percentual / 100) as valor_liquido
FROM venda_pagamentos vp
JOIN vendas v ON v.id = vp.venda_id
JOIN formas_pagamento fp ON fp.id = vp.forma_pagamento_id
WHERE v.status = 'FINALIZADA'
GROUP BY DATE(v.created_at), fp.descricao, fp.tipo
ORDER BY data DESC, valor_total DESC;

-- =====================================================
-- FINALIZAÇÃO
-- =====================================================

SELECT '✅ MIGRAÇÃO DISTRIBUIDORA CONCLUÍDA!' as status,
       'Novas tabelas: vendas, venda_itens, venda_pagamentos, caixas, caixa_sessoes, documentos_fiscais, contas_receber, formas_pagamento, cotacoes_compra' as tabelas,
       'Campos fiscais adicionados em produtos e empresa_config' as alteracoes,
       'Funções PDV: buscar_produto_codigo_barras, iniciar_venda_pdv, adicionar_item_venda, finalizar_venda_pdv' as funcoes;
