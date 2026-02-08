-- =====================================================
-- EXTRAIR SCHEMA COMPLETO DO SUPABASE
-- =====================================================
-- Execute este script no Supabase SQL Editor
-- Copie os resultados para atualizar seu schema.sql local
-- =====================================================

-- =====================================================
-- 1. LISTAR TODAS AS TABELAS
-- =====================================================
SELECT 
    'TABLE' as object_type,
    table_name,
    NULL as definition
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_type = 'BASE TABLE'
ORDER BY table_name;

-- =====================================================
-- 2. GERAR DDL DE TODAS AS TABELAS
-- =====================================================
-- Para cada tabela listada acima, execute:
-- SELECT pg_get_tabledef('public.nome_da_tabela'::regclass);
-- Ou use o comando abaixo para gerar os CREATEs:

SELECT
    'CREATE TABLE ' || table_schema || '.' || table_name || ' (' ||
    string_agg(
        column_name || ' ' || 
        data_type || 
        CASE 
            WHEN character_maximum_length IS NOT NULL 
            THEN '(' || character_maximum_length || ')'
            ELSE ''
        END ||
        CASE WHEN is_nullable = 'NO' THEN ' NOT NULL' ELSE '' END ||
        CASE 
            WHEN column_default IS NOT NULL 
            THEN ' DEFAULT ' || column_default
            ELSE ''
        END,
        ', '
        ORDER BY ordinal_position
    ) || ');' as create_table_statement
FROM information_schema.columns
WHERE table_schema = 'public'
GROUP BY table_schema, table_name
ORDER BY table_name;

-- =====================================================
-- 3. LISTAR TODAS AS FUNÇÕES
-- =====================================================
SELECT 
    p.proname as function_name,
    pg_get_functiondef(p.oid) as function_definition
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public'
ORDER BY p.proname;

-- =====================================================
-- 4. LISTAR TODOS OS TRIGGERS
-- =====================================================
SELECT 
    tg.tgname as trigger_name,
    c.relname as table_name,
    pg_get_triggerdef(tg.oid) as trigger_definition
FROM pg_trigger tg
JOIN pg_class c ON tg.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname = 'public'
AND NOT tg.tgisinternal
ORDER BY c.relname, tg.tgname;

-- =====================================================
-- 5. LISTAR TODAS AS VIEWS
-- =====================================================
SELECT 
    table_name as view_name,
    'CREATE OR REPLACE VIEW ' || table_name || ' AS ' || view_definition as view_definition
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY table_name;

-- =====================================================
-- 6. LISTAR TODOS OS ÍNDICES
-- =====================================================
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- =====================================================
-- 7. LISTAR TODAS AS CONSTRAINTS
-- =====================================================
SELECT
    tc.table_name,
    tc.constraint_name,
    tc.constraint_type,
    CASE 
        WHEN tc.constraint_type = 'FOREIGN KEY' THEN
            'ALTER TABLE ' || tc.table_name || 
            ' ADD CONSTRAINT ' || tc.constraint_name ||
            ' FOREIGN KEY (' || kcu.column_name || ')' ||
            ' REFERENCES ' || ccu.table_name || '(' || ccu.column_name || ');'
        WHEN tc.constraint_type = 'PRIMARY KEY' THEN
            'ALTER TABLE ' || tc.table_name ||
            ' ADD CONSTRAINT ' || tc.constraint_name ||
            ' PRIMARY KEY (' || kcu.column_name || ');'
        WHEN tc.constraint_type = 'CHECK' THEN
            'ALTER TABLE ' || tc.table_name ||
            ' ADD CONSTRAINT ' || tc.constraint_name ||
            ' CHECK ' || cc.check_clause || ';'
        ELSE NULL
    END as constraint_definition
FROM information_schema.table_constraints tc
LEFT JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
LEFT JOIN information_schema.constraint_column_usage ccu
    ON tc.constraint_name = ccu.constraint_name
    AND tc.table_schema = ccu.table_schema
LEFT JOIN information_schema.check_constraints cc
    ON tc.constraint_name = cc.constraint_name
WHERE tc.table_schema = 'public'
ORDER BY tc.table_name, tc.constraint_type, tc.constraint_name;

-- =====================================================
-- 8. LISTAR POLÍTICAS RLS
-- =====================================================
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd,
    'CREATE POLICY ' || policyname || ' ON ' || tablename || 
    ' FOR ' || cmd || 
    ' TO ' || permissive || ';' as policy_definition
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;
