-- =====================================================
-- EXTRAIR SCHEMA - PARTE 1: FUNÇÕES
-- =====================================================
-- Execute no Supabase SQL Editor e copie o resultado

SELECT 
    '-- ========================================' || E'\n' ||
    '-- FUNÇÃO: ' || p.proname || E'\n' ||
    '-- ========================================' || E'\n' ||
    pg_get_functiondef(p.oid) || E'\n\n'
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
ORDER BY p.proname;