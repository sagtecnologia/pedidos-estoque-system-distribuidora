-- =====================================================
-- SCRIPT PARA LIMPAR BASE DE DADOS
-- =====================================================
-- ATENÇÃO: Este script irá DELETAR TODOS OS DADOS!
-- Execute com cuidado e apenas em ambientes de desenvolvimento/teste
-- =====================================================

-- 1. DELETAR ITENS DE PEDIDOS (vendas e compras)
DELETE FROM pedido_itens;

-- 2. DELETAR MOVIMENTAÇÕES DE ESTOQUE (antes de pedidos, pois tem FK)
DELETE FROM estoque_movimentacoes;

-- 3. DELETAR PEDIDOS (vendas e compras)
DELETE FROM pedidos WHERE tipo_pedido = 'VENDA';
DELETE FROM pedidos WHERE tipo_pedido = 'COMPRA';
DELETE FROM pedidos;

-- 4. DELETAR SABORES DOS PRODUTOS (antes de produtos, pois tem FK)
DELETE FROM produto_sabores;

-- 5. DELETAR PRODUTOS
DELETE FROM produtos;

-- 6. RESETAR SEQUÊNCIAS (IDs) - OPCIONAL
-- Isso fará com que os próximos registros comecem do ID 1 novamente
-- Descomente as linhas abaixo se quiser resetar os IDs:
-- ALTER SEQUENCE pedidos_id_seq RESTART WITH 1;
-- ALTER SEQUENCE pedido_itens_id_seq RESTART WITH 1;
-- ALTER SEQUENCE produtos_id_seq RESTART WITH 1;
-- ALTER SEQUENCE produto_sabores_id_seq RESTART WITH 1;
-- ALTER SEQUENCE estoque_movimentacoes_id_seq RESTART WITH 1;

-- 7. DELETAR CLIENTES (OPCIONAL - descomente se quiser limpar também)
-- DELETE FROM clientes;

-- 8. DELETAR FORNECEDORES (OPCIONAL - descomente se quiser limpar também)
-- DELETE FROM fornecedores;

-- =====================================================
-- VERIFICAR RESULTADOS
-- =====================================================

SELECT 'VENDAS' as tabela, COUNT(*) as total FROM pedidos WHERE tipo_pedido = 'VENDA'
UNION ALL
SELECT 'COMPRAS', COUNT(*) FROM pedidos WHERE tipo_pedido = 'COMPRA'
UNION ALL
SELECT 'PEDIDO_ITENS', COUNT(*) FROM pedido_itens
UNION ALL
SELECT 'PRODUTOS', COUNT(*) FROM produtos
UNION ALL
SELECT 'PRODUTO_SABORES', COUNT(*) FROM produto_sabores
UNION ALL
SELECT 'MOVIMENTACOES', COUNT(*) FROM estoque_movimentacoes
UNION ALL
SELECT 'CLIENTES', COUNT(*) FROM clientes
UNION ALL
SELECT 'FORNECEDORES', COUNT(*) FROM fornecedores;

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================
