-- =====================================================
-- CORRIGIR VIEW DE ESTOQUE E PREÇOS
-- =====================================================
-- Este script garante que a view vw_estoque_sabores funcione
-- corretamente com as colunas de preço

-- =====================================================
-- 1. VERIFICAR E ADICIONAR COLUNAS DE PREÇO
-- =====================================================

-- Adicionar preco_compra se não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'produtos' AND column_name = 'preco_compra'
    ) THEN
        ALTER TABLE produtos ADD COLUMN preco_compra NUMERIC(10,2) DEFAULT 0;
        RAISE NOTICE '✅ Coluna preco_compra adicionada';
    ELSE
        RAISE NOTICE 'ℹ️  Coluna preco_compra já existe';
    END IF;
END $$;

-- Adicionar preco_venda se não existir
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'produtos' AND column_name = 'preco_venda'
    ) THEN
        ALTER TABLE produtos ADD COLUMN preco_venda NUMERIC(10,2) DEFAULT 0;
        RAISE NOTICE '✅ Coluna preco_venda adicionada';
    ELSE
        RAISE NOTICE 'ℹ️  Coluna preco_venda já existe';
    END IF;
END $$;

-- Se a coluna 'preco' existe, copiar valores para preco_venda se estiverem zerados
UPDATE produtos 
SET preco_venda = preco 
WHERE preco_venda = 0 AND preco > 0;

-- =====================================================
-- 2. RECRIAR A VIEW vw_estoque_sabores
-- =====================================================

DROP VIEW IF EXISTS vw_estoque_sabores;

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
    COALESCE(p.preco_compra, 0) as preco_compra,
    COALESCE(p.preco_venda, p.preco, 0) as preco_venda,
    CASE 
        WHEN ps.quantidade = 0 THEN 'ZERADO'
        WHEN ps.quantidade <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produtos p
LEFT JOIN produto_sabores ps ON p.id = ps.produto_id
WHERE p.active = true AND ps.ativo = true
ORDER BY p.marca, p.nome, ps.sabor;

-- =====================================================
-- 3. TESTAR A VIEW
-- =====================================================

-- Ver estrutura da view
SELECT 
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'vw_estoque_sabores'
ORDER BY ordinal_position;

-- Contar registros
SELECT 
    COUNT(*) as total_sabores,
    COUNT(DISTINCT produto_id) as total_produtos,
    COUNT(DISTINCT marca) as total_marcas
FROM vw_estoque_sabores;

-- Ver amostra de dados
SELECT 
    marca,
    produto,
    sabor,
    quantidade,
    preco_compra,
    preco_venda,
    (preco_venda - preco_compra) as margem,
    status_estoque
FROM vw_estoque_sabores
LIMIT 10;

-- =====================================================
-- 4. ATUALIZAR PREÇOS DOS PRODUTOS (SE NECESSÁRIO)
-- =====================================================

-- Verificar produtos sem preço de compra/venda
SELECT 
    codigo,
    nome,
    marca,
    preco_compra,
    preco_venda,
    preco
FROM produtos
WHERE preco_compra = 0 OR preco_venda = 0
ORDER BY marca, nome;

-- Se quiser atualizar preços em massa (DESCOMENTE):
-- UPDATE produtos SET 
--     preco_compra = 10.00,
--     preco_venda = 15.00
-- WHERE preco_compra = 0 AND marca = 'IGNITE';

-- =====================================================
-- 5. VERIFICAR TOTAIS CALCULADOS
-- =====================================================

-- Calcular totais como a página faz
SELECT 
    COUNT(*) as total_itens,
    SUM(quantidade) as quantidade_total,
    SUM(quantidade * preco_compra) as valor_total_compra,
    SUM(quantidade * preco_venda) as valor_total_venda,
    SUM(quantidade * (preco_venda - preco_compra)) as margem_lucro_total,
    CASE 
        WHEN SUM(quantidade * preco_compra) > 0 
        THEN ROUND((SUM(quantidade * (preco_venda - preco_compra)) / SUM(quantidade * preco_compra) * 100), 2)
        ELSE 0 
    END as margem_percentual
FROM vw_estoque_sabores;

-- =====================================================
-- 6. RESOLVER PROBLEMAS COMUNS
-- =====================================================

-- Problema: Produtos sem marca (aparece NULL)
-- Solução: Definir marca padrão
-- UPDATE produtos SET marca = 'GERAL' WHERE marca IS NULL OR marca = '';

-- Problema: Sabores inativos ainda aparecem
-- Solução: Já filtrado na view com ps.ativo = true

-- Problema: Produtos inativos ainda aparecem
-- Solução: Já filtrado na view com p.active = true

-- =====================================================
-- RESULTADO FINAL
-- =====================================================

SELECT 
    '✅ View vw_estoque_sabores criada/atualizada!' as status,
    (SELECT COUNT(*) FROM vw_estoque_sabores) as total_registros,
    (SELECT SUM(quantidade * preco_compra) FROM vw_estoque_sabores) as valor_investido,
    (SELECT SUM(quantidade * preco_venda) FROM vw_estoque_sabores) as valor_potencial;
