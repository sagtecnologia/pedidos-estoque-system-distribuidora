-- =====================================================
-- DADOS INICIAIS: DISTRIBUIDORA DE BEBIDAS
-- =====================================================
-- Execute após a migração principal
-- =====================================================

-- =====================================================
-- 1. CAIXAS INICIAIS
-- =====================================================

INSERT INTO caixas (numero, nome, terminal, ativo) VALUES
    (1, 'Caixa 01 - Principal', 'PDV-001', true),
    (2, 'Caixa 02 - Secundário', 'PDV-002', true),
    (3, 'Caixa 03 - Balcão', 'PDV-003', true)
ON CONFLICT (numero) DO NOTHING;

-- =====================================================
-- 2. NCMs COMUNS PARA BEBIDAS (Referência)
-- =====================================================

-- Tabela de referência para facilitar cadastro
CREATE TABLE IF NOT EXISTS ncm_referencia (
    ncm VARCHAR(10) PRIMARY KEY,
    descricao VARCHAR(255) NOT NULL,
    categoria VARCHAR(100)
);

INSERT INTO ncm_referencia (ncm, descricao, categoria) VALUES
    -- Águas
    ('22011000', 'Águas minerais e águas gaseificadas', 'Águas'),
    ('22019000', 'Outras águas não adoçadas', 'Águas'),
    
    -- Refrigerantes e Sucos
    ('22021000', 'Águas, incluindo águas minerais e gaseificadas, com adição de açúcar', 'Refrigerantes'),
    ('22029000', 'Outras bebidas não alcoólicas (refrigerantes, energéticos)', 'Refrigerantes'),
    ('20091100', 'Suco de laranja, congelado', 'Sucos'),
    ('20091200', 'Suco de laranja, não congelado, Brix <= 20', 'Sucos'),
    ('20091900', 'Outros sucos de laranja', 'Sucos'),
    ('20098100', 'Suco de cramberry', 'Sucos'),
    ('20098900', 'Outros sucos de frutas/produtos hortícolas', 'Sucos'),
    ('20099000', 'Misturas de sucos', 'Sucos'),
    
    -- Cervejas
    ('22030000', 'Cervejas de malte', 'Cervejas'),
    
    -- Vinhos
    ('22041000', 'Vinhos espumantes', 'Vinhos'),
    ('22042100', 'Outros vinhos em recipientes de até 2L', 'Vinhos'),
    ('22042900', 'Outros vinhos em recipientes de mais de 2L', 'Vinhos'),
    ('22043000', 'Outros mostos de uvas', 'Vinhos'),
    
    -- Destilados
    ('22082000', 'Aguardentes de vinho ou de bagaço de uvas (conhaque, brandy)', 'Destilados'),
    ('22083000', 'Uísques', 'Destilados'),
    ('22084000', 'Rum e outras aguardentes de cana', 'Destilados'),
    ('22085000', 'Gim e genebra', 'Destilados'),
    ('22086000', 'Vodca', 'Destilados'),
    ('22087000', 'Licores', 'Destilados'),
    ('22089000', 'Outras bebidas destiladas (cachaça, tequila)', 'Destilados'),
    
    -- Outros
    ('22060000', 'Outras bebidas fermentadas (sidra, hidromel)', 'Outros'),
    ('21069021', 'Preparações compostas não alcoólicas (concentrados)', 'Outros')
ON CONFLICT (ncm) DO NOTHING;

-- =====================================================
-- 3. CFOP COMUNS (Referência)
-- =====================================================

CREATE TABLE IF NOT EXISTS cfop_referencia (
    cfop VARCHAR(4) PRIMARY KEY,
    descricao VARCHAR(255) NOT NULL,
    tipo VARCHAR(50)
);

INSERT INTO cfop_referencia (cfop, descricao, tipo) VALUES
    -- Vendas dentro do estado
    ('5101', 'Venda de produção do estabelecimento', 'Venda'),
    ('5102', 'Venda de mercadoria adquirida', 'Venda'),
    ('5103', 'Venda de produção com entrega futura', 'Venda'),
    ('5104', 'Venda de mercadoria adquirida com entrega futura', 'Venda'),
    ('5405', 'Venda de mercadoria com ST (substituição tributária)', 'Venda'),
    ('5403', 'Venda de mercadoria com ST, a consumidor final', 'Venda'),
    
    -- Vendas fora do estado
    ('6101', 'Venda de produção do estabelecimento', 'Venda Interestadual'),
    ('6102', 'Venda de mercadoria adquirida', 'Venda Interestadual'),
    ('6403', 'Venda de mercadoria com ST, a consumidor final', 'Venda Interestadual'),
    ('6404', 'Venda de mercadoria com ST, a contribuinte', 'Venda Interestadual'),
    
    -- Devoluções
    ('1202', 'Devolução de venda de mercadoria', 'Devolução'),
    ('2202', 'Devolução de venda interestadual', 'Devolução'),
    
    -- Compras
    ('1102', 'Compra para comercialização', 'Compra'),
    ('2102', 'Compra interestadual para comercialização', 'Compra')
ON CONFLICT (cfop) DO NOTHING;

-- =====================================================
-- 4. CST/CSOSN COMUNS (Referência)
-- =====================================================

CREATE TABLE IF NOT EXISTS cst_referencia (
    codigo VARCHAR(4) PRIMARY KEY,
    descricao VARCHAR(255) NOT NULL,
    regime VARCHAR(50)
);

-- CST ICMS (Lucro Real/Presumido)
INSERT INTO cst_referencia (codigo, descricao, regime) VALUES
    ('00', 'Tributada integralmente', 'Normal'),
    ('10', 'Tributada e com cobrança de ICMS por ST', 'Normal'),
    ('20', 'Com redução de base de cálculo', 'Normal'),
    ('30', 'Isenta ou não tributada e com cobrança de ICMS por ST', 'Normal'),
    ('40', 'Isenta', 'Normal'),
    ('41', 'Não tributada', 'Normal'),
    ('50', 'Suspensão', 'Normal'),
    ('51', 'Diferimento', 'Normal'),
    ('60', 'ICMS cobrado anteriormente por ST', 'Normal'),
    ('70', 'Com redução de BC e cobrança de ICMS por ST', 'Normal'),
    ('90', 'Outras', 'Normal')
ON CONFLICT (codigo) DO NOTHING;

-- CSOSN (Simples Nacional)
INSERT INTO cst_referencia (codigo, descricao, regime) VALUES
    ('101', 'Tributada com permissão de crédito', 'Simples Nacional'),
    ('102', 'Tributada sem permissão de crédito', 'Simples Nacional'),
    ('103', 'Isenção do ICMS para faixa de receita bruta', 'Simples Nacional'),
    ('201', 'Tributada com permissão de crédito e com cobrança de ICMS por ST', 'Simples Nacional'),
    ('202', 'Tributada sem permissão de crédito e com cobrança de ICMS por ST', 'Simples Nacional'),
    ('203', 'Isenção do ICMS para faixa de receita bruta e com cobrança de ICMS por ST', 'Simples Nacional'),
    ('300', 'Imune', 'Simples Nacional'),
    ('400', 'Não tributada', 'Simples Nacional'),
    ('500', 'ICMS cobrado anteriormente por ST ou por antecipação', 'Simples Nacional'),
    ('900', 'Outros', 'Simples Nacional')
ON CONFLICT (codigo) DO UPDATE SET descricao = EXCLUDED.descricao;

-- =====================================================
-- 5. PRODUTOS DE EXEMPLO (BEBIDAS)
-- =====================================================

-- Apenas se não existirem produtos
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM produtos WHERE codigo_barras IS NOT NULL LIMIT 1) THEN
        -- Águas
        INSERT INTO produtos (codigo, nome, marca, categoria, unidade, preco_venda, preco_compra, estoque_atual, estoque_minimo, codigo_barras, ncm, cfop, cst_icms, origem, active)
        VALUES 
            ('AGU-001', 'Água Mineral 500ml', 'Crystal', 'Águas', 'UN', 2.50, 1.20, 100, 20, '7891234500001', '22011000', '5102', '102', 0, true),
            ('AGU-002', 'Água Mineral 1,5L', 'Crystal', 'Águas', 'UN', 4.00, 2.00, 80, 15, '7891234500002', '22011000', '5102', '102', 0, true),
            ('AGU-003', 'Água com Gás 500ml', 'São Lourenço', 'Águas', 'UN', 3.50, 1.80, 50, 10, '7891234500003', '22011000', '5102', '102', 0, true);
        
        -- Refrigerantes
        INSERT INTO produtos (codigo, nome, marca, categoria, unidade, preco_venda, preco_compra, estoque_atual, estoque_minimo, codigo_barras, ncm, cfop, cst_icms, origem, active)
        VALUES 
            ('REF-001', 'Coca-Cola 350ml Lata', 'Coca-Cola', 'Refrigerantes', 'UN', 4.50, 2.50, 200, 50, '7894900010015', '22021000', '5102', '102', 0, true),
            ('REF-002', 'Coca-Cola 2L', 'Coca-Cola', 'Refrigerantes', 'UN', 10.00, 6.00, 100, 30, '7894900011012', '22021000', '5102', '102', 0, true),
            ('REF-003', 'Guaraná Antarctica 350ml Lata', 'Antarctica', 'Refrigerantes', 'UN', 4.00, 2.20, 150, 40, '7891991010016', '22021000', '5102', '102', 0, true),
            ('REF-004', 'Fanta Laranja 2L', 'Fanta', 'Refrigerantes', 'UN', 9.00, 5.50, 80, 20, '7894900020014', '22021000', '5102', '102', 0, true);
        
        -- Cervejas
        INSERT INTO produtos (codigo, nome, marca, categoria, unidade, preco_venda, preco_compra, estoque_atual, estoque_minimo, codigo_barras, ncm, cfop, cst_icms, origem, active)
        VALUES 
            ('CER-001', 'Skol Lata 350ml', 'Skol', 'Cervejas', 'UN', 4.00, 2.30, 300, 100, '7891149100019', '22030000', '5405', '500', 0, true),
            ('CER-002', 'Brahma Lata 350ml', 'Brahma', 'Cervejas', 'UN', 4.00, 2.30, 250, 80, '7891149101016', '22030000', '5405', '500', 0, true),
            ('CER-003', 'Heineken Long Neck 330ml', 'Heineken', 'Cervejas', 'UN', 8.00, 5.00, 150, 50, '8712000900120', '22030000', '5405', '500', 1, true),
            ('CER-004', 'Corona Extra 330ml', 'Corona', 'Cervejas', 'UN', 10.00, 6.50, 100, 30, '7501064191084', '22030000', '5405', '500', 1, true);
        
        -- Energéticos
        INSERT INTO produtos (codigo, nome, marca, categoria, unidade, preco_venda, preco_compra, estoque_atual, estoque_minimo, codigo_barras, ncm, cfop, cst_icms, origem, active)
        VALUES 
            ('ENE-001', 'Red Bull 250ml', 'Red Bull', 'Energéticos', 'UN', 12.00, 8.00, 60, 20, '9002490100070', '22029000', '5102', '102', 1, true),
            ('ENE-002', 'Monster Energy 473ml', 'Monster', 'Energéticos', 'UN', 10.00, 6.50, 50, 15, '0070847811169', '22029000', '5102', '102', 1, true);
        
        -- Sucos
        INSERT INTO produtos (codigo, nome, marca, categoria, unidade, preco_venda, preco_compra, estoque_atual, estoque_minimo, codigo_barras, ncm, cfop, cst_icms, origem, active)
        VALUES 
            ('SUC-001', 'Suco Del Valle Laranja 1L', 'Del Valle', 'Sucos', 'UN', 8.00, 5.00, 40, 10, '7894900530018', '20091900', '5102', '102', 0, true),
            ('SUC-002', 'Suco Del Valle Uva 1L', 'Del Valle', 'Sucos', 'UN', 8.00, 5.00, 35, 10, '7894900530025', '20098900', '5102', '102', 0, true);
        
        RAISE NOTICE '✅ Produtos de exemplo inseridos!';
    ELSE
        RAISE NOTICE '⚠️ Produtos já existem, ignorando inserção de exemplos.';
    END IF;
END $$;

-- =====================================================
-- 6. VISUALIZAÇÕES ÚTEIS
-- =====================================================

-- View: Produtos para PDV (otimizada)
CREATE OR REPLACE VIEW vw_produtos_pdv AS
SELECT 
    p.id,
    p.codigo,
    p.codigo_barras,
    p.nome,
    p.marca,
    p.categoria,
    p.unidade,
    p.preco_venda,
    p.estoque_atual,
    p.estoque_minimo,
    p.ncm,
    p.cfop,
    p.cst_icms,
    p.csosn,
    p.aliquota_icms,
    p.origem,
    CASE 
        WHEN p.estoque_atual <= 0 THEN 'SEM_ESTOQUE'
        WHEN p.estoque_atual <= p.estoque_minimo THEN 'ESTOQUE_BAIXO'
        ELSE 'DISPONIVEL'
    END as status_estoque
FROM produtos p
WHERE p.active = true
ORDER BY p.nome;

-- View: Resumo de vendas por período
CREATE OR REPLACE VIEW vw_resumo_vendas_diario AS
SELECT 
    DATE(v.created_at) as data,
    COUNT(*) as qtd_vendas,
    COUNT(DISTINCT v.cliente_id) as qtd_clientes,
    SUM(v.subtotal) as subtotal,
    SUM(v.desconto_valor) as descontos,
    SUM(v.total) as total,
    AVG(v.total) as ticket_medio,
    SUM(CASE WHEN v.status = 'CANCELADA' THEN 1 ELSE 0 END) as cancelamentos
FROM vendas v
WHERE v.created_at >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY DATE(v.created_at)
ORDER BY data DESC;

-- =====================================================
-- FINALIZAÇÃO
-- =====================================================

SELECT '✅ DADOS INICIAIS INSERIDOS!' as status,
       (SELECT COUNT(*) FROM caixas) as caixas,
       (SELECT COUNT(*) FROM ncm_referencia) as ncms,
       (SELECT COUNT(*) FROM cfop_referencia) as cfops,
       (SELECT COUNT(*) FROM formas_pagamento) as formas_pagamento;
