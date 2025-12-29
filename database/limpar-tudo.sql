-- =====================================================
-- SOLUÇÃO DEFINITIVA - LIMPAR TUDO E COMEÇAR DO ZERO
-- =====================================================

-- PASSO 1: Limpar usuários órfãos do auth (sem registro na tabela users)
-- Importante: Anote os IDs antes se precisar
SELECT id, email, created_at FROM auth.users;

-- Se quiser deletar TODOS os usuários e começar do zero:
-- CUIDADO: Isso vai apagar todos os usuários!
-- DELETE FROM auth.users;

-- Ou delete apenas os usuários sem registro na tabela users:
DELETE FROM auth.users 
WHERE id NOT IN (SELECT id FROM public.users);

-- PASSO 2: Limpar tabela users
TRUNCATE TABLE public.users CASCADE;

-- PASSO 3: DESABILITAR RLS em TODAS as tabelas
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE produtos DISABLE ROW LEVEL SECURITY;
ALTER TABLE fornecedores DISABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos DISABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_itens DISABLE ROW LEVEL SECURITY;
ALTER TABLE estoque_movimentacoes DISABLE ROW LEVEL SECURITY;

-- PASSO 4: Remover TODAS as políticas
DROP POLICY IF EXISTS "Usuários podem ver outros usuários ativos" ON users;
DROP POLICY IF EXISTS "Usuários podem ver seus próprios dados" ON users;
DROP POLICY IF EXISTS "Apenas ADMIN pode gerenciar usuários" ON users;
DROP POLICY IF EXISTS "usuarios_select_policy" ON users;
DROP POLICY IF EXISTS "usuarios_insert_policy" ON users;
DROP POLICY IF EXISTS "usuarios_update_self_policy" ON users;
DROP POLICY IF EXISTS "usuarios_update_admin_policy" ON users;
DROP POLICY IF EXISTS "usuarios_delete_admin_policy" ON users;
DROP POLICY IF EXISTS "usuarios_podem_se_cadastrar" ON users;
DROP POLICY IF EXISTS "permitir_cadastro_temporario" ON users;
DROP POLICY IF EXISTS "allow_insert_own_user" ON users;
DROP POLICY IF EXISTS "allow_read_users" ON users;
DROP POLICY IF EXISTS "users_select" ON users;
DROP POLICY IF EXISTS "users_insert" ON users;
DROP POLICY IF EXISTS "users_update" ON users;
DROP POLICY IF EXISTS "users_delete" ON users;

-- Confirmação
SELECT 'TUDO LIMPO! RLS DESABILITADO!' as status;
SELECT 'Agora você pode criar o primeiro usuário pelo sistema!' as acao;
