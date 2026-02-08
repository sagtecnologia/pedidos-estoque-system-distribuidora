-- =====================================================
-- EXTRAIR SCHEMA - PARTE 4: ÍNDICES
-- =====================================================
-- Execute no Supabase SQL Editor e copie o resultado

SELECT 
    indexdef || ';' || E'\n'
FROM pg_indexes
WHERE schemaname = 'public'
AND indexname NOT LIKE '%_pkey'  -- Excluir primary keys
ORDER BY tablename, indexname;