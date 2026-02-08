-- =====================================================
-- EXTRAIR SCHEMA - PARTE 2: TRIGGERS
-- =====================================================
-- Execute no Supabase SQL Editor e copie o resultado

SELECT 
    '-- Trigger: ' || tg.tgname || ' na tabela ' || c.relname || E'\n' ||
    pg_get_triggerdef(tg.oid) || ';' || E'\n\n'
FROM pg_trigger tg
JOIN pg_class c ON tg.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
AND NOT tg.tgisinternal
ORDER BY c.relname, tg.tgname;