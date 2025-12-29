-- =====================================================
-- CORREÇÃO RÁPIDA PARA PERMITIR CADASTRO
-- =====================================================

-- Remover política antiga que bloqueia INSERT
DROP POLICY IF EXISTS "Apenas ADMIN pode gerenciar usuários" ON users;

-- Permitir INSERT para usuários autenticados (seu próprio ID)
CREATE POLICY "usuarios_podem_se_cadastrar"
    ON users FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- OU, se preferir permitir qualquer INSERT temporariamente:
-- DROP POLICY IF EXISTS "usuarios_podem_se_cadastrar" ON users;
-- CREATE POLICY "permitir_cadastro_temporario"
--     ON users FOR INSERT
--     TO authenticated
--     WITH CHECK (true);
