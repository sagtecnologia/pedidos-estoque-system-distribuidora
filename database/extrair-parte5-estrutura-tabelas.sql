-- =====================================================
-- EXTRAIR SCHEMA - PARTE 5: ESTRUTURA DE TABELAS
-- =====================================================
-- Execute no Supabase SQL Editor e copie o resultado

SELECT 
    table_name,
    column_name,
    data_type,
    character_maximum_length,
    is_nullable,
    column_default,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;