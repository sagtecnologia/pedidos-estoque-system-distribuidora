-- =====================================================
-- CORREÇÃO: Políticas RLS para Pré-Pedidos Públicos
-- =====================================================

-- 1. DESABILITAR RLS temporariamente
ALTER TABLE pre_pedidos DISABLE ROW LEVEL SECURITY;
ALTER TABLE pre_pedido_itens DISABLE ROW LEVEL SECURITY;

-- 2. Remover TODAS as políticas existentes (forçado)
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'pre_pedidos'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON pre_pedidos', pol.policyname);
    END LOOP;
    
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'pre_pedido_itens'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON pre_pedido_itens', pol.policyname);
    END LOOP;
END $$;

-- 3. Criar políticas SUPER PERMISSIVAS para anon e public
CREATE POLICY "anon_insert_pre_pedidos"
ON pre_pedidos
FOR INSERT
TO anon, public
WITH CHECK (true);

CREATE POLICY "anon_select_pre_pedidos"
ON pre_pedidos
FOR SELECT
TO anon, public
USING (true);

CREATE POLICY "anon_insert_itens"
ON pre_pedido_itens
FOR INSERT
TO anon, public
WITH CHECK (true);

CREATE POLICY "anon_select_itens"
ON pre_pedido_itens
FOR SELECT
TO anon, public
USING (true);

-- 4. Políticas para usuários autenticados
CREATE POLICY "auth_all_pre_pedidos"
ON pre_pedidos
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "auth_all_itens"
ON pre_pedido_itens
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 5. RE-HABILITAR RLS
ALTER TABLE pre_pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_pedido_itens ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies
WHERE tablename IN ('pre_pedidos', 'pre_pedido_itens')
ORDER BY tablename, policyname;

SELECT '✅ Políticas RLS corrigidas com sucesso!' as status;
