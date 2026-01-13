-- =====================================================
-- CORREÇÃO: Permitir exclusão de pedidos gerados por pré-pedidos
-- =====================================================

-- Alterar constraint de pre_pedidos.pedido_gerado_id para ON DELETE SET NULL
-- Isso permite excluir o pedido sem bloquear
ALTER TABLE pre_pedidos 
DROP CONSTRAINT IF EXISTS pre_pedidos_pedido_gerado_id_fkey;

ALTER TABLE pre_pedidos 
ADD CONSTRAINT pre_pedidos_pedido_gerado_id_fkey 
FOREIGN KEY (pedido_gerado_id) 
REFERENCES pedidos(id) 
ON DELETE SET NULL;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

SELECT 
    conname AS constraint_name,
    conrelid::regclass AS table_name,
    confrelid::regclass AS referenced_table,
    confdeltype AS on_delete_action
FROM pg_constraint
WHERE conname = 'pre_pedidos_pedido_gerado_id_fkey';

SELECT '✅ Constraint corrigida - agora pode excluir pedidos!' as status;
