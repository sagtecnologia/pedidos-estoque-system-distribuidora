-- =====================================================
-- EXTRAIR SCHEMA COMPLETO - SEM DOCKER
-- =====================================================
-- Execute este script NO SUPABASE SQL EDITOR
-- Copie cada resultado e salve em arquivos separados
-- =====================================================

-- =====================================================
-- PARTE 1: FUNÇÕES (copie este resultado para functions.sql)
-- =====================================================
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT 
            p.proname,
            pg_get_functiondef(p.oid) as def
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public'
        ORDER BY p.proname
    )
    LOOP
        RAISE NOTICE '%', r.def;
        RAISE NOTICE '';
        RAISE NOTICE '-- ==========================================';
        RAISE NOTICE '';
    END LOOP;
END $$;
