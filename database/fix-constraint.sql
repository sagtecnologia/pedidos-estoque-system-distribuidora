-- =====================================================
-- CORREÇÃO: Remover constraint problemática
-- Execute este script no Supabase
-- =====================================================

-- Remover a constraint que está causando problema
ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedido_tipo_check;

-- Verificar dados existentes
SELECT id, numero, tipo_pedido, status, fornecedor_id, cliente_id 
FROM pedidos 
LIMIT 10;

-- Confirmação
SELECT 'Constraint removida! Agora você pode enviar pedidos normalmente.' as status;
