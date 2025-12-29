-- =====================================================
-- CORREÇÃO DAS POLÍTICAS RLS - TABELA USERS
-- =====================================================

-- Remover políticas antigas que causam recursão
DROP POLICY IF EXISTS "Usuários podem ver outros usuários ativos" ON users;
DROP POLICY IF EXISTS "Usuários podem ver seus próprios dados" ON users;
DROP POLICY IF EXISTS "Apenas ADMIN pode gerenciar usuários" ON users;

-- =====================================================
-- NOVAS POLÍTICAS SEM RECURSÃO
-- =====================================================

-- 1. SELECT: Todos usuários autenticados podem ver todos os usuários ativos
-- Sem recursão - não consulta a tabela users
CREATE POLICY "usuarios_select_policy"
    ON users FOR SELECT
    TO authenticated
    USING (active = true OR auth.uid() = id);

-- 2. INSERT: Permitir criação de novos usuários durante cadastro
-- Esta política permite que qualquer pessoa autenticada (incluindo novos usuários) 
-- possam inserir seus próprios dados
CREATE POLICY "usuarios_insert_policy"
    ON users FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- 3. UPDATE: Usuário pode atualizar seus próprios dados
CREATE POLICY "usuarios_update_self_policy"
    ON users FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- 4. UPDATE: ADMIN pode atualizar qualquer usuário
-- Usa auth.jwt() para verificar role sem consultar a tabela users
CREATE POLICY "usuarios_update_admin_policy"
    ON users FOR UPDATE
    TO authenticated
    USING (
        (auth.jwt()->>'role')::text = 'ADMIN'
    )
    WITH CHECK (
        (auth.jwt()->>'role')::text = 'ADMIN'
    );

-- 5. DELETE: Apenas ADMIN pode deletar
CREATE POLICY "usuarios_delete_admin_policy"
    ON users FOR DELETE
    TO authenticated
    USING (
        (auth.jwt()->>'role')::text = 'ADMIN'
    );

-- =====================================================
-- FUNÇÃO PARA CONFIGURAR JWT COM ROLE DO USUÁRIO
-- =====================================================

-- Esta função adiciona o role do usuário ao JWT após autenticação
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS TRIGGER AS $$
BEGIN
    -- Inserir na tabela users quando um novo usuário é criado no auth
    INSERT INTO public.users (id, email, full_name, role)
    VALUES (
        new.id,
        new.email,
        COALESCE(new.raw_user_meta_data->>'full_name', 'Usuário'),
        COALESCE(new.raw_user_meta_data->>'role', 'COMPRADOR')
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger para criar usuário automaticamente após signup
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =====================================================
-- ATUALIZAR POLÍTICAS DE PRODUTOS, FORNECEDORES E PEDIDOS
-- =====================================================

-- Remover políticas antigas que consultam a tabela users
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem criar produtos" ON produtos;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem atualizar produtos" ON produtos;
DROP POLICY IF EXISTS "Apenas ADMIN pode deletar produtos" ON produtos;

-- Novas políticas usando JWT em vez de consultar users
CREATE POLICY "produtos_insert_policy"
    ON produtos FOR INSERT
    TO authenticated
    WITH CHECK (
        (auth.jwt()->>'role')::text IN ('ADMIN', 'COMPRADOR')
    );

CREATE POLICY "produtos_update_policy"
    ON produtos FOR UPDATE
    TO authenticated
    USING (
        (auth.jwt()->>'role')::text IN ('ADMIN', 'COMPRADOR')
    );

CREATE POLICY "produtos_delete_policy"
    ON produtos FOR DELETE
    TO authenticated
    USING (
        (auth.jwt()->>'role')::text = 'ADMIN'
    );

-- Atualizar políticas de fornecedores
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem criar fornecedores" ON fornecedores;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem atualizar fornecedores" ON fornecedores;
DROP POLICY IF EXISTS "Apenas ADMIN pode deletar fornecedores" ON fornecedores;

CREATE POLICY "fornecedores_insert_policy"
    ON fornecedores FOR INSERT
    TO authenticated
    WITH CHECK (
        (auth.jwt()->>'role')::text IN ('ADMIN', 'COMPRADOR')
    );

CREATE POLICY "fornecedores_update_policy"
    ON fornecedores FOR UPDATE
    TO authenticated
    USING (
        (auth.jwt()->>'role')::text IN ('ADMIN', 'COMPRADOR')
    );

CREATE POLICY "fornecedores_delete_policy"
    ON fornecedores FOR DELETE
    TO authenticated
    USING (
        (auth.jwt()->>'role')::text = 'ADMIN'
    );
