-- =====================================================
-- MIGRAÇÃO: ADICIONAR PERFIL VENDEDOR
-- Execute este script no Supabase SQL Editor
-- =====================================================

-- 1. Verificar se há algum usuário VENDEDOR já cadastrado (para debug)
SELECT COUNT(*) as vendedores_existentes FROM users WHERE role = 'VENDEDOR';

-- 2. Remover a constraint antiga de role
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;

-- 3. Adicionar nova constraint incluindo VENDEDOR
ALTER TABLE users 
ADD CONSTRAINT users_role_check 
CHECK (role IN ('ADMIN', 'COMPRADOR', 'APROVADOR', 'VENDEDOR'));

-- 4. Verificar se a constraint foi criada corretamente
SELECT conname, pg_get_constraintdef(oid) 
FROM pg_constraint 
WHERE conrelid = 'users'::regclass AND conname = 'users_role_check';

SELECT 'MIGRAÇÃO CONCLUÍDA!' as status;
SELECT 'Perfil VENDEDOR adicionado com sucesso. Agora você pode cadastrar usuários como VENDEDOR.' as resultado;
