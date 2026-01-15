-- =====================================================
-- RESET COMPLETO - RESOLVER PROBLEMAS DE RLS E CADASTRO
-- Execute este script no SQL Editor do Supabase
-- =====================================================

-- PASSO 1: Remover TODAS as políticas antigas que podem causar problema
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

-- PASSO 2: DESABILITAR RLS temporariamente para criar primeiro usuário
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
ALTER TABLE produtos DISABLE ROW LEVEL SECURITY;
ALTER TABLE fornecedores DISABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos DISABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_itens DISABLE ROW LEVEL SECURITY;
ALTER TABLE estoque_movimentacoes DISABLE ROW LEVEL SECURITY;

-- PASSO 3: Verificar se a tabela users existe e está correta
-- Se houver erro aqui, significa que o schema.sql não foi executado
SELECT COUNT(*) FROM users;

-- PASSO 4: Mostrar instruções para o próximo passo
SELECT 'RLS DESABILITADO - Agora você pode criar o primeiro usuário!' as status;
SELECT 'Após criar o primeiro usuário, execute o script: enable-rls-simple.sql' as proxima_acao;
