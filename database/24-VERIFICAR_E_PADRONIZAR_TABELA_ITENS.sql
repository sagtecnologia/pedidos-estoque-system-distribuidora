-- =====================================================
-- Script para verificar e padronizar nome da tabela de itens
-- =====================================================

-- Verificar qual tabela existe no banco
DO $$
DECLARE
    v_tabela_existe_singular BOOLEAN;
    v_tabela_existe_plural BOOLEAN;
BEGIN
    -- Verificar se existe 'venda_itens' (singular)
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'venda_itens'
    ) INTO v_tabela_existe_singular;
    
    -- Verificar se existe 'vendas_itens' (plural)
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'vendas_itens'
    ) INTO v_tabela_existe_plural;
    
    -- Exibir resultado
    IF v_tabela_existe_singular THEN
        RAISE NOTICE '✅ Tabela venda_itens (singular) existe';
    ELSE
        RAISE NOTICE '❌ Tabela venda_itens (singular) NÃO existe';
    END IF;
    
    IF v_tabela_existe_plural THEN
        RAISE NOTICE '✅ Tabela vendas_itens (plural) existe';
    ELSE
        RAISE NOTICE '❌ Tabela vendas_itens (plural) NÃO existe';
    END IF;
    
    -- Se existe plural mas não existe singular, renomear
    IF v_tabela_existe_plural AND NOT v_tabela_existe_singular THEN
        RAISE NOTICE '🔄 Renomeando vendas_itens para venda_itens...';
        ALTER TABLE vendas_itens RENAME TO venda_itens;
        RAISE NOTICE '✅ Tabela renomeada com sucesso!';
    END IF;
    
    -- Se existe singular, está OK
    IF v_tabela_existe_singular THEN
        RAISE NOTICE '✅ Tabela venda_itens já está com o nome correto';
    END IF;
END $$;
