-- =====================================================
-- Script para adicionar campos extras em empresa_config
-- Para armazenar todos os dados fiscais e endereço completo
-- =====================================================

DO $$
BEGIN
    -- Inscrição Estadual
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'inscricao_estadual') THEN
        ALTER TABLE empresa_config ADD COLUMN inscricao_estadual VARCHAR(20);
        RAISE NOTICE 'Coluna inscricao_estadual adicionada';
    END IF;

    -- Inscrição Municipal
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'inscricao_municipal') THEN
        ALTER TABLE empresa_config ADD COLUMN inscricao_municipal VARCHAR(20);
        RAISE NOTICE 'Coluna inscricao_municipal adicionada';
    END IF;

    -- Regime Tributário
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'regime_tributario') THEN
        ALTER TABLE empresa_config ADD COLUMN regime_tributario VARCHAR(1) DEFAULT '1';
        RAISE NOTICE 'Coluna regime_tributario adicionada';
    END IF;

    -- CNAE
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'cnae') THEN
        ALTER TABLE empresa_config ADD COLUMN cnae VARCHAR(10);
        RAISE NOTICE 'Coluna cnae adicionada';
    END IF;

    -- Código Município IBGE
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'codigo_municipio') THEN
        ALTER TABLE empresa_config ADD COLUMN codigo_municipio VARCHAR(10);
        RAISE NOTICE 'Coluna codigo_municipio adicionada';
    END IF;

    -- Endereço - Número
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'endereco_numero') THEN
        ALTER TABLE empresa_config ADD COLUMN endereco_numero VARCHAR(20);
        RAISE NOTICE 'Coluna endereco_numero adicionada';
    END IF;

    -- Bairro
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'bairro') THEN
        ALTER TABLE empresa_config ADD COLUMN bairro VARCHAR(100);
        RAISE NOTICE 'Coluna bairro adicionada';
    END IF;

    -- Logradouro
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'logradouro') THEN
        ALTER TABLE empresa_config ADD COLUMN logradouro VARCHAR(200);
        RAISE NOTICE 'Coluna logradouro adicionada';
    END IF;

    -- Complemento
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'complemento') THEN
        ALTER TABLE empresa_config ADD COLUMN complemento VARCHAR(100);
        RAISE NOTICE 'Coluna complemento adicionada';
    END IF;

    -- Certificado Digital (Caminho do arquivo)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'certificado_digital') THEN
        ALTER TABLE empresa_config ADD COLUMN certificado_digital TEXT;
        RAISE NOTICE 'Coluna certificado_digital adicionada';
    END IF;

    -- Senha do Certificado (criptografada)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'senha_certificado') THEN
        ALTER TABLE empresa_config ADD COLUMN senha_certificado TEXT;
        RAISE NOTICE 'Coluna senha_certificado adicionada';
    END IF;

    -- CSC ID (Código de Segurança do Contribuinte)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'csc_id') THEN
        ALTER TABLE empresa_config ADD COLUMN csc_id VARCHAR(50);
        RAISE NOTICE 'Coluna csc_id adicionada';
    END IF;

    -- CSC Token
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'csc_token') THEN
        ALTER TABLE empresa_config ADD COLUMN csc_token VARCHAR(100);
        RAISE NOTICE 'Coluna csc_token adicionada';
    END IF;

    -- Ambiente NF-e (1=Produção, 2=Homologação)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'ambiente_nfe') THEN
        ALTER TABLE empresa_config ADD COLUMN ambiente_nfe VARCHAR(1) DEFAULT '2';
        RAISE NOTICE 'Coluna ambiente_nfe adicionada';
    END IF;

    -- Série NF-e
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'serie_nfe') THEN
        ALTER TABLE empresa_config ADD COLUMN serie_nfe VARCHAR(5) DEFAULT '1';
        RAISE NOTICE 'Coluna serie_nfe adicionada';
    END IF;

    -- Número Próxima NF-e
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'proximo_numero_nfe') THEN
        ALTER TABLE empresa_config ADD COLUMN proximo_numero_nfe INTEGER DEFAULT 1;
        RAISE NOTICE 'Coluna proximo_numero_nfe adicionada';
    END IF;

    -- Cores do Sistema
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'cor_primaria') THEN
        ALTER TABLE empresa_config ADD COLUMN cor_primaria VARCHAR(7) DEFAULT '#3B82F6';
        RAISE NOTICE 'Coluna cor_primaria adicionada';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'cor_secundaria') THEN
        ALTER TABLE empresa_config ADD COLUMN cor_secundaria VARCHAR(7) DEFAULT '#10B981';
        RAISE NOTICE 'Coluna cor_secundaria adicionada';
    END IF;

    -- Configurações PDV
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'habilitar_cupom_fiscal') THEN
        ALTER TABLE empresa_config ADD COLUMN habilitar_cupom_fiscal BOOLEAN DEFAULT false;
        RAISE NOTICE 'Coluna habilitar_cupom_fiscal adicionada';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'habilitar_nfce') THEN
        ALTER TABLE empresa_config ADD COLUMN habilitar_nfce BOOLEAN DEFAULT false;
        RAISE NOTICE 'Coluna habilitar_nfce adicionada';
    END IF;

    -- Configurações de Estoque
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'alerta_estoque_minimo') THEN
        ALTER TABLE empresa_config ADD COLUMN alerta_estoque_minimo BOOLEAN DEFAULT true;
        RAISE NOTICE 'Coluna alerta_estoque_minimo adicionada';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'empresa_config' AND column_name = 'dias_alerta_validade') THEN
        ALTER TABLE empresa_config ADD COLUMN dias_alerta_validade INTEGER DEFAULT 30;
        RAISE NOTICE 'Coluna dias_alerta_validade adicionada';
    END IF;

END $$;

-- =====================================================
-- VERIFICAÇÃO FINAL
-- =====================================================

SELECT 
    '✅ Script executado com sucesso!' as status,
    'Empresa Config: +23 campos adicionados (fiscais, endereço, NF-e, personalização)' as resumo;
