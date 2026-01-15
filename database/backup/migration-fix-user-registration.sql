-- =====================================================
-- MIGRAÇÃO: CORRIGIR POLICIES DE CADASTRO DE USUÁRIOS
-- Execute este script no Supabase SQL Editor
-- =====================================================

-- Alterar o DEFAULT da coluna active para false
ALTER TABLE users 
ALTER COLUMN active SET DEFAULT false;

-- Remover a policy antiga que bloqueava auto-cadastro
DROP POLICY IF EXISTS "Apenas ADMIN pode gerenciar usuários" ON users;

-- Criar policy para permitir auto-cadastro (INSERT com active=false)
CREATE POLICY "Usuários podem se cadastrar"
    ON users FOR INSERT
    WITH CHECK (
        auth.uid() = id AND active = false
    );

-- Criar policy para ADMIN atualizar usuários
CREATE POLICY "Apenas ADMIN pode gerenciar usuários"
    ON users FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- Criar policy para ADMIN deletar usuários
CREATE POLICY "Apenas ADMIN pode deletar usuários"
    ON users FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

SELECT 'MIGRAÇÃO CONCLUÍDA!' as status;
SELECT 'Usuários agora podem se auto-cadastrar com active=false (padrão)' as resultado;
