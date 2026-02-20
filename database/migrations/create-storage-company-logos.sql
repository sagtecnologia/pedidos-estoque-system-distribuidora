-- Criação do bucket de storage para logos de empresa
-- Execute este script no SQL Editor do Supabase

-- Criar bucket company-logos (público para que a logo apareça no sistema)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'company-logos',
    'company-logos',
    true,
    2097152, -- 2MB em bytes
    ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml']
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Políticas de acesso ao bucket

-- Permitir leitura pública (para exibir a logo)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'company-logos public read'
    ) THEN
        CREATE POLICY "company-logos public read"
        ON storage.objects FOR SELECT
        USING (bucket_id = 'company-logos');
    END IF;
END $$;

-- Permitir upload para usuários autenticados
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'company-logos authenticated upload'
    ) THEN
        CREATE POLICY "company-logos authenticated upload"
        ON storage.objects FOR INSERT
        TO authenticated
        WITH CHECK (bucket_id = 'company-logos');
    END IF;
END $$;

-- Permitir update para usuários autenticados
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'company-logos authenticated update'
    ) THEN
        CREATE POLICY "company-logos authenticated update"
        ON storage.objects FOR UPDATE
        TO authenticated
        USING (bucket_id = 'company-logos');
    END IF;
END $$;

-- Permitir delete para usuários autenticados
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'company-logos authenticated delete'
    ) THEN
        CREATE POLICY "company-logos authenticated delete"
        ON storage.objects FOR DELETE
        TO authenticated
        USING (bucket_id = 'company-logos');
    END IF;
END $$;

-- Permitir também para anon (caso o sistema use anon key)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'storage'
        AND tablename = 'objects'
        AND policyname = 'company-logos anon upload'
    ) THEN
        CREATE POLICY "company-logos anon upload"
        ON storage.objects FOR INSERT
        TO anon
        WITH CHECK (bucket_id = 'company-logos');
    END IF;
END $$;
