-- =====================================================
-- EXTRAIR SCHEMA - PARTE 3: VIEWS
-- =====================================================
-- Execute no Supabase SQL Editor e copie o resultado

SELECT 
    '-- View: ' || table_name || E'\n' ||
    'CREATE OR REPLACE VIEW ' || table_name || ' AS' || E'\n' ||
    view_definition || ';' || E'\n\n'
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;