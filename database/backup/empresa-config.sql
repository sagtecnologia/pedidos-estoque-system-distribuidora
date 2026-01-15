-- =====================================================
-- TABELA DE CONFIGURAÇÕES DA EMPRESA
-- =====================================================

-- Criar tabela para armazenar dados da empresa
CREATE TABLE IF NOT EXISTS empresa_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nome_empresa VARCHAR(200) NOT NULL,
    razao_social VARCHAR(200),
    cnpj VARCHAR(18),
    endereco TEXT,
    cidade VARCHAR(100),
    estado VARCHAR(2),
    cep VARCHAR(9),
    telefone VARCHAR(20),
    email VARCHAR(100),
    website VARCHAR(200),
    logo_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Apenas um registro de configuração da empresa
-- Se já existir, não insere
INSERT INTO empresa_config (nome_empresa, email)
SELECT 'Minha Empresa', 'contato@minhaempresa.com'
WHERE NOT EXISTS (SELECT 1 FROM empresa_config LIMIT 1);

-- =====================================================
-- POLÍTICAS RLS
-- =====================================================

ALTER TABLE empresa_config ENABLE ROW LEVEL SECURITY;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "empresa_select_policy" ON empresa_config;
DROP POLICY IF EXISTS "empresa_update_policy" ON empresa_config;
DROP POLICY IF EXISTS "empresa_insert_policy" ON empresa_config;

-- Todos autenticados podem visualizar
CREATE POLICY "empresa_select_policy"
    ON empresa_config FOR SELECT
    TO authenticated
    USING (true);

-- Apenas ADMIN pode atualizar (usando tabela users)
CREATE POLICY "empresa_update_policy"
    ON empresa_config FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role = 'ADMIN'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role = 'ADMIN'
        )
    );

-- Apenas ADMIN pode inserir (usando tabela users)
CREATE POLICY "empresa_insert_policy"
    ON empresa_config FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role = 'ADMIN'
        )
    );

-- =====================================================
-- STORAGE BUCKET PARA LOGOS
-- =====================================================

-- Criar bucket para logos da empresa
INSERT INTO storage.buckets (id, name, public)
VALUES ('company-logos', 'company-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Remover políticas antigas se existirem
DROP POLICY IF EXISTS "Todos podem ver logos" ON storage.objects;
DROP POLICY IF EXISTS "Apenas ADMIN pode fazer upload de logos" ON storage.objects;
DROP POLICY IF EXISTS "Apenas ADMIN pode atualizar logos" ON storage.objects;
DROP POLICY IF EXISTS "Apenas ADMIN pode deletar logos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem fazer upload de logos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar logos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar logos" ON storage.objects;

-- Políticas de acesso ao bucket - simplificadas
-- Como a página já verifica se é ADMIN, permitimos qualquer autenticado
CREATE POLICY "Todos podem ver logos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'company-logos');

CREATE POLICY "Usuários autenticados podem fazer upload de logos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'company-logos');

CREATE POLICY "Usuários autenticados podem atualizar logos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'company-logos');

CREATE POLICY "Usuários autenticados podem deletar logos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'company-logos');

-- =====================================================
-- FUNÇÃO PARA ATUALIZAR updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_empresa_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS empresa_config_updated_at ON empresa_config;

CREATE TRIGGER empresa_config_updated_at
    BEFORE UPDATE ON empresa_config
    FOR EACH ROW
    EXECUTE FUNCTION update_empresa_updated_at();
