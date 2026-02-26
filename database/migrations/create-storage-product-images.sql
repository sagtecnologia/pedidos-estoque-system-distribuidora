-- =====================================================
-- Migration: Criar bucket de imagens de produtos
-- =====================================================
-- Execute no Supabase SQL Editor ou crie manualmente:
-- Supabase Dashboard → Storage → New bucket
-- Nome: product-images
-- Public: true (ativar "Public bucket")
-- =====================================================

-- Criar bucket público para imagens de produtos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'product-images',
    'product-images',
    true,
    2097152, -- 2MB
    ARRAY['image/png', 'image/jpeg', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

-- Política: Qualquer pessoa autenticada pode fazer upload
CREATE POLICY "Authenticated users can upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'product-images');

-- Política: Qualquer pessoa pode ver (bucket público)
CREATE POLICY "Anyone can view product images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'product-images');

-- Política: Qualquer pessoa autenticada pode deletar
CREATE POLICY "Authenticated users can delete product images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images');

-- Política: Qualquer pessoa autenticada pode atualizar
CREATE POLICY "Authenticated users can update product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'product-images');
