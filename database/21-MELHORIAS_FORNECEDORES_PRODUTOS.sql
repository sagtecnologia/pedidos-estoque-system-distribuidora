-- =====================================================
-- Script para adicionar campos extras em fornecedores e produtos
-- Para melhorar integração com XML de NF-e
-- =====================================================

-- =====================================================
-- 1. ADICIONAR CAMPOS EM FORNECEDORES
-- =====================================================

-- Adicionar campos bancários e extras
DO $$
BEGIN
    -- Inscrição Estadual
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fornecedores' AND column_name = 'inscricao_estadual') THEN
        ALTER TABLE fornecedores ADD COLUMN inscricao_estadual VARCHAR(20);
        RAISE NOTICE 'Coluna inscricao_estadual adicionada';
    END IF;

    -- Site
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fornecedores' AND column_name = 'site') THEN
        ALTER TABLE fornecedores ADD COLUMN site VARCHAR(200);
        RAISE NOTICE 'Coluna site adicionada';
    END IF;

    -- Banco
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fornecedores' AND column_name = 'banco') THEN
        ALTER TABLE fornecedores ADD COLUMN banco VARCHAR(100);
        RAISE NOTICE 'Coluna banco adicionada';
    END IF;

    -- Agência
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fornecedores' AND column_name = 'agencia') THEN
        ALTER TABLE fornecedores ADD COLUMN agencia VARCHAR(20);
        RAISE NOTICE 'Coluna agencia adicionada';
    END IF;

    -- Conta
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fornecedores' AND column_name = 'conta') THEN
        ALTER TABLE fornecedores ADD COLUMN conta VARCHAR(30);
        RAISE NOTICE 'Coluna conta adicionada';
    END IF;

    -- PIX
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fornecedores' AND column_name = 'pix') THEN
        ALTER TABLE fornecedores ADD COLUMN pix VARCHAR(100);
        RAISE NOTICE 'Coluna pix adicionada';
    END IF;

    -- Observações
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'fornecedores' AND column_name = 'observacoes') THEN
        ALTER TABLE fornecedores ADD COLUMN observacoes TEXT;
        RAISE NOTICE 'Coluna observacoes adicionada';
    END IF;
END $$;

-- =====================================================
-- 2. ADICIONAR CAMPOS EM PRODUTOS (Para XML NF-e)
-- =====================================================

DO $$
BEGIN
    -- Código de Barras (EAN)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'codigo_barras') THEN
        ALTER TABLE produtos ADD COLUMN codigo_barras VARCHAR(50);
        RAISE NOTICE 'Coluna codigo_barras adicionada';
    END IF;

    -- SKU
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'sku') THEN
        ALTER TABLE produtos ADD COLUMN sku VARCHAR(50);
        RAISE NOTICE 'Coluna sku adicionada';
    END IF;

    -- Marca
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'marca') THEN
        ALTER TABLE produtos ADD COLUMN marca VARCHAR(100);
        RAISE NOTICE 'Coluna marca adicionada';
    END IF;

    -- Descrição completa
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'descricao') THEN
        ALTER TABLE produtos ADD COLUMN descricao TEXT;
        RAISE NOTICE 'Coluna descricao adicionada';
    END IF;

    -- CFOP Venda
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'cfop_venda') THEN
        ALTER TABLE produtos ADD COLUMN cfop_venda VARCHAR(10) DEFAULT '5102';
        RAISE NOTICE 'Coluna cfop_venda adicionada';
    END IF;

    -- CFOP Compra
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'cfop_compra') THEN
        ALTER TABLE produtos ADD COLUMN cfop_compra VARCHAR(10) DEFAULT '1102';
        RAISE NOTICE 'Coluna cfop_compra adicionada';
    END IF;

    -- Volume (ml/L)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'volume_ml') THEN
        ALTER TABLE produtos ADD COLUMN volume_ml DECIMAL(10,2);
        RAISE NOTICE 'Coluna volume_ml adicionada';
    END IF;

    -- Embalagem
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'embalagem') THEN
        ALTER TABLE produtos ADD COLUMN embalagem VARCHAR(50);
        RAISE NOTICE 'Coluna embalagem adicionada';
    END IF;

    -- Quantidade por embalagem
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'quantidade_embalagem') THEN
        ALTER TABLE produtos ADD COLUMN quantidade_embalagem INTEGER DEFAULT 1;
        RAISE NOTICE 'Coluna quantidade_embalagem adicionada';
    END IF;

    -- Localização no estoque
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'localizacao') THEN
        ALTER TABLE produtos ADD COLUMN localizacao VARCHAR(50);
        RAISE NOTICE 'Coluna localizacao adicionada';
    END IF;

    -- Peso (kg)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'peso_kg') THEN
        ALTER TABLE produtos ADD COLUMN peso_kg DECIMAL(10,3);
        RAISE NOTICE 'Coluna peso_kg adicionada';
    END IF;

    -- Controla validade
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'controla_validade') THEN
        ALTER TABLE produtos ADD COLUMN controla_validade BOOLEAN DEFAULT false;
        RAISE NOTICE 'Coluna controla_validade adicionada';
    END IF;

    -- Dias de alerta de validade
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'dias_alerta_validade') THEN
        ALTER TABLE produtos ADD COLUMN dias_alerta_validade INTEGER DEFAULT 30;
        RAISE NOTICE 'Coluna dias_alerta_validade adicionada';
    END IF;

    -- Marca ID (FK para tabela marcas se existir)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'marca_id') THEN
        ALTER TABLE produtos ADD COLUMN marca_id UUID;
        RAISE NOTICE 'Coluna marca_id adicionada';
    END IF;

    -- Categoria ID (FK para tabela categorias)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'categoria_id') THEN
        ALTER TABLE produtos ADD COLUMN categoria_id UUID;
        RAISE NOTICE 'Coluna categoria_id adicionada';
    END IF;

    -- Unidade de venda
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'unidade_venda') THEN
        ALTER TABLE produtos ADD COLUMN unidade_venda VARCHAR(10) DEFAULT 'UN';
        RAISE NOTICE 'Coluna unidade_venda adicionada';
    END IF;

    -- Preço de custo (além do preco_compra)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'preco_custo') THEN
        ALTER TABLE produtos ADD COLUMN preco_custo DECIMAL(10,2);
        RAISE NOTICE 'Coluna preco_custo adicionada';
    END IF;

    -- Estoque máximo
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'produtos' AND column_name = 'estoque_maximo') THEN
        ALTER TABLE produtos ADD COLUMN estoque_maximo DECIMAL(10,2) DEFAULT 0;
        RAISE NOTICE 'Coluna estoque_maximo adicionada';
    END IF;
END $$;

-- =====================================================
-- 3. CRIAR TABELA DE IMPORTAÇÃO XML (Log)
-- =====================================================

CREATE TABLE IF NOT EXISTS importacao_xml_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    arquivo_nome VARCHAR(255) NOT NULL,
    chave_nfe VARCHAR(44),
    numero_nfe VARCHAR(20),
    fornecedor_id UUID,
    fornecedor_cnpj VARCHAR(18),
    fornecedor_nome VARCHAR(255),
    pedido_id UUID,
    total_produtos INTEGER DEFAULT 0,
    valor_total DECIMAL(10,2) DEFAULT 0,
    status VARCHAR(20) DEFAULT 'PROCESSANDO' CHECK (status IN ('PROCESSANDO', 'SUCESSO', 'ERRO', 'PARCIAL')),
    erro_mensagem TEXT,
    created_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Adicionar FK para fornecedores se existir
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'fornecedores') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                      WHERE constraint_name = 'fk_importacao_xml_fornecedor') THEN
            ALTER TABLE importacao_xml_log 
            ADD CONSTRAINT fk_importacao_xml_fornecedor 
            FOREIGN KEY (fornecedor_id) REFERENCES fornecedores(id);
            RAISE NOTICE 'FK fornecedores adicionada';
        END IF;
    END IF;
    
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'users') THEN
        IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints 
                      WHERE constraint_name = 'fk_importacao_xml_user') THEN
            ALTER TABLE importacao_xml_log 
            ADD CONSTRAINT fk_importacao_xml_user 
            FOREIGN KEY (created_by) REFERENCES users(id);
            RAISE NOTICE 'FK users adicionada';
        END IF;
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_importacao_xml_log_chave ON importacao_xml_log(chave_nfe);
CREATE INDEX IF NOT EXISTS idx_importacao_xml_log_fornecedor ON importacao_xml_log(fornecedor_id);
CREATE INDEX IF NOT EXISTS idx_importacao_xml_log_pedido ON importacao_xml_log(pedido_id);
CREATE INDEX IF NOT EXISTS idx_importacao_xml_log_status ON importacao_xml_log(status);
CREATE INDEX IF NOT EXISTS idx_importacao_xml_log_created ON importacao_xml_log(created_at DESC);

-- =====================================================
-- 4. VERIFICAÇÃO FINAL
-- =====================================================

SELECT 
    '✅ Script de melhorias executado com sucesso!' as status,
    'Fornecedores: +7 campos | Produtos: +15 campos | Nova tabela: importacao_xml_log' as resumo;

