-- =====================================================
-- RECONSTRUIR PRODUTO_SABORES (V2)
-- =====================================================
-- Solução: Criar política RLS temporária que permite INSERT
-- =====================================================

-- 1. Criar política temporária que permite tudo
CREATE POLICY temp_allow_all ON produto_sabores
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 2. Inserir sabores para produtos com estoque
INSERT INTO produto_sabores (produto_id, sabor, quantidade, ativo)
SELECT 
    p.id,
    'MIX' as sabor,
    p.estoque_atual as quantidade,
    true as ativo
FROM produtos p
WHERE p.active = true
  AND p.estoque_atual != 0
  AND NOT EXISTS (
    SELECT 1 
    FROM produto_sabores ps 
    WHERE ps.produto_id = p.id 
      AND ps.ativo = true
  );

-- 3. Remover política temporária
DROP POLICY IF EXISTS temp_allow_all ON produto_sabores;

-- 4. Mostrar resultado
SELECT '✅ SABORES CRIADOS' as "STATUS";

SELECT 
    p.codigo as "Código",
    p.nome as "Produto",
    ps.sabor as "Sabor",
    ps.quantidade as "Quantidade",
    p.preco_compra as "Preço Compra (R$)",
    ROUND((ps.quantidade * p.preco_compra)::numeric, 2) as "Valor Compra (R$)",
    ROUND((ps.quantidade * p.preco_venda)::numeric, 2) as "Valor Venda (R$)"
FROM produto_sabores ps
JOIN produtos p ON ps.produto_id = p.id
WHERE ps.ativo = true
ORDER BY p.codigo, ps.sabor;

SELECT '💰 TOTAIS' as "STATUS";

SELECT 
    ROUND(SUM(ps.quantidade * p.preco_compra)::numeric, 2) as "Valor Total Compra (R$)",
    ROUND(SUM(ps.quantidade * p.preco_venda)::numeric, 2) as "Valor Total Venda (R$)",
    COUNT(*) as "Total Sabores"
FROM produto_sabores ps
JOIN produtos p ON ps.produto_id = p.id
WHERE ps.ativo = true;
