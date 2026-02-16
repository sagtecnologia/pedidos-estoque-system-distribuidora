-- =====================================================
-- SINCRONIZAÇÃO: Vendas com Documentos Fiscais Cancelados
-- Descrição: Sincroniza status_fiscal de vendas com documentos_fiscais
-- Data: 16/02/2026
-- =====================================================

-- ⚠️ IMPORTANTE: Execute este arquivo SQL COMPLETO de uma vez!
-- Não execute apenas a seção 3 - precisa da seção 2 primeiro para criar a função

-- =====================================================
-- 1. PROBLEMA IDENTIFICADO
-- =====================================================
-- Uma nota pode estar cancelada em documentos_fiscais mas não refletir em vendas
-- Isso causa que a mesma venda apareça como "Autorizado" em vendas.html
-- mas como "Cancelado" em documentos-fiscais.html

-- =====================================================
-- 2. SOLUÇÃO: Função de sincronização
-- =====================================================

-- Criar função para sincronizar vendas com documentos_fiscais
CREATE OR REPLACE FUNCTION sincronizar_vendas_com_documentos_cancelados()
RETURNS TABLE (
    venda_id UUID,
    numero_nfce VARCHAR,
    chave_acesso_nfce VARCHAR,
    status_anterior VARCHAR,
    status_novo VARCHAR,
    sincronizado BOOLEAN
) AS $$
DECLARE
    v_docs RECORD;
    v_count INT := 0;
BEGIN
    -- Encontrar documentos cancelados em documentos_fiscais
    FOR v_docs IN
        SELECT 
            d.id,
            d.numero_documento,
            d.chave_acesso,
            d.status_sefaz,
            v.id as venda_id,
            v.numero_nfce,
            v.status_fiscal
        FROM documentos_fiscais d
        LEFT JOIN vendas v ON (
            -- Buscar por número
            (d.numero_documento::text = v.numero_nfce::text AND v.numero_nfce IS NOT NULL) OR
            -- Buscar por chave
            (d.chave_acesso = v.chave_acesso_nfce AND v.chave_acesso_nfce IS NOT NULL)
        )
        WHERE 
            -- Documentos que estão cancelados na SEFAZ (status_sefaz = '135')
            d.status_sefaz = '135'
            -- Mas a venda não está refletindo isso
            AND v.id IS NOT NULL
            AND v.status_fiscal != 'CANCELADA'
    LOOP
        -- Atualizar a venda com o status correto
        UPDATE vendas
        SET 
            status_fiscal = 'CANCELADA'::documento_fiscal_status,
            updated_at = NOW()
        WHERE id = v_docs.venda_id;
        
        -- Retornar informações do registro atualizado
        RETURN QUERY SELECT 
            v_docs.venda_id,
            v_docs.numero_nfce,
            v_docs.chave_acesso,
            v_docs.status_fiscal::VARCHAR,
            'CANCELADA'::VARCHAR,
            TRUE;
        
        v_count := v_count + 1;
    END LOOP;
    
    RAISE NOTICE 'Sincronização concluída: % registros atualizados', v_count;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. EXECUTAR SINCRONIZAÇÃO AGORA
-- =====================================================
-- Este SELECT será executado automaticamente quando você rodar o script

-- Detectar e sincronizar todas as vendas desincronizadas
SELECT 
    venda_id,
    numero_nfce,
    chave_acesso_nfce,
    status_anterior,
    status_novo,
    sincronizado
FROM sincronizar_vendas_com_documentos_cancelados();

-- =====================================================
-- 4. VERIFICAÇÃO PÓS-SINCRONIZAÇÃO
-- =====================================================

-- Ver quais vendas foram corrigidas
SELECT 
    v.id,
    v.numero_nfce,
    v.chave_acesso_nfce,
    v.status_fiscal,
    v.updated_at,
    d.status_sefaz,
    d.numero_documento
FROM vendas v
LEFT JOIN documentos_fiscais d ON (
    v.numero_nfce::text = d.numero_documento::text OR
    v.chave_acesso_nfce = d.chave_acesso
)
WHERE v.status_fiscal = 'CANCELADA'
  AND v.updated_at > NOW() - INTERVAL '5 minutes'
ORDER BY v.updated_at DESC;

-- =====================================================
-- 5. CRIAR TRIGGER PARA SINCRONIZAÇÃO AUTOMÁTICA
-- =====================================================

-- Criar função de sincronização automática quando documentos_fiscais é atualizado
CREATE OR REPLACE FUNCTION sincronizar_venda_ao_cancelar_documento()
RETURNS TRIGGER AS $$
BEGIN
    -- Se um documento foi cancelado (status_sefaz = '135')
    IF NEW.status_sefaz = '135' AND (OLD.status_sefaz IS NULL OR OLD.status_sefaz != '135') THEN
        -- Tentar sincronizar com vendas
        UPDATE vendas
        SET 
            status_fiscal = 'CANCELADA'::documento_fiscal_status,
            updated_at = NOW()
        WHERE 
            (numero_nfce::text = NEW.numero_documento::text OR chave_acesso_nfce = NEW.chave_acesso)
            AND (status_fiscal != 'CANCELADA');
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger em documentos_fiscais
DROP TRIGGER IF EXISTS trg_sincronizar_venda_ao_cancelar_documento ON documentos_fiscais;
CREATE TRIGGER trg_sincronizar_venda_ao_cancelar_documento
AFTER UPDATE ON documentos_fiscais
FOR EACH ROW
EXECUTE FUNCTION sincronizar_venda_ao_cancelar_documento();

-- =====================================================
-- 6. UTILIDADE: Function para sincronizar por chave específica
-- =====================================================

CREATE OR REPLACE FUNCTION sincronizar_venda_por_chave(p_chave_acesso VARCHAR)
RETURNS TABLE (
    chave VARCHAR,
    venda_id UUID,
    numero_nfce VARCHAR,
    status_anterior VARCHAR,
    status_novo VARCHAR,
    sincronizado BOOLEAN
) AS $$
BEGIN
    UPDATE vendas
    SET 
        status_fiscal = 'CANCELADA'::documento_fiscal_status,
        updated_at = NOW()
    WHERE 
        chave_acesso_nfce = p_chave_acesso
        AND (status_fiscal != 'CANCELADA')
    RETURNING id, numero_nfce, status_fiscal;
    
    RETURN QUERY
    SELECT 
        p_chave_acesso,
        v.id,
        v.numero_nfce,
        'EMITIDA_NFCE',  -- status anterior presumido
        'CANCELADA',
        TRUE
    FROM vendas v
    WHERE v.chave_acesso_nfce = p_chave_acesso
      AND v.status_fiscal = 'CANCELADA';
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. EXEMPLO DE USO da função de sincronização por chave
-- =====================================================

-- Se você conhecer a chave de uma venda que está com problema:
-- SELECT * FROM sincronizar_venda_por_chave('COLOQUE_A_CHAVE_AQUI');

-- =====================================================
-- 8. INSTRUÇÕES FINAIS
-- =====================================================
-- 
-- ✅ PASSO 1: Copie TODO o conteúdo deste arquivo (linhas 1-190)
-- ✅ PASSO 2: Cole no Supabase SQL Editor
-- ✅ PASSO 3: Clique em "RUN" para executar TODO o script
--
-- O script vai:
--   1. Criar a função sincronizar_vendas_com_documentos_cancelados()
--   2. Executá-la automaticamente (seção 3)
--   3. Mostrar resultado na seção de saída
--   4. Criar trigger automático para futuras sincronizações (seção 5)
--
-- Se vir "execution completed" ao final, foncionou! ✅
