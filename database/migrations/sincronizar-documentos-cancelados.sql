-- =====================================================
-- SINCRONIZAÇÃO MANUAL: Documentos cancelados mas com status desatualizado
-- Descrição: Encontra e sincroniza documentos que estão CANCELADOS na SEFAZ mas marcados como EMITIDA_NFCE no banco
-- Data: 06/02/2026
-- =====================================================

-- ANTES DE EXECUTAR:
-- 1. Verifique: Qual é o numero_nfce ou chave_acesso_nfce que está com problema?
-- 2. Execute a query de diagnóstico primeiro (veja abaixo)
-- 3. Depois execute a sincronização

-- =====================================================
-- 1. DIAGNÓSTICO: Encontrar documentos inconsistentes
-- =====================================================

-- Se sabe o número da NFC-e:
SELECT 
    id,
    numero_nfce,
    chave_acesso_nfce,
    status_fiscal,
    data_emissao,
    updated_at
FROM vendas
WHERE numero_nfce = 'SEU_NUMERO_AQUI'  -- ← Coloque o número aqui
ORDER BY data_emissao DESC;

-- OU Se sabe a chave de acesso:
SELECT 
    id,
    numero_nfce,
    chave_acesso_nfce,
    status_fiscal,
    data_emissao,
    updated_at
FROM vendas
WHERE chave_acesso_nfce = 'SUA_CHAVE_AQUI'  -- ← Coloque a chave aqui
ORDER BY data_emissao DESC;

-- OU para listar TODOS os documentos EMITIDA_NFCE:
SELECT 
    id,
    numero_nfce,
    chave_acesso_nfce,
    status_fiscal,
    data_emissao,
    updated_at
FROM vendas
WHERE status_fiscal = 'EMITIDA_NFCE'
ORDER BY data_emissao DESC
LIMIT 20;

-- =====================================================
-- 2. SINCRONIZAÇÃO: Atualizar um documento específico
-- =====================================================

-- Se você tem o ID da venda (ex: id = 500):
UPDATE vendas
SET 
    status_fiscal = 'CANCELADA_NFCE',
    data_cancelamento = NOW(),
    updated_at = NOW()
WHERE id = 500  -- ← Coloque o ID da venda aqui
RETURNING id, numero_nfce, status_fiscal, data_cancelamento;

-- OU se você tem o número da NFC-e (ex: numero_nfce = '12345'):
UPDATE vendas
SET 
    status_fiscal = 'CANCELADA_NFCE',
    data_cancelamento = NOW(),
    updated_at = NOW()
WHERE numero_nfce = '12345'  -- ← Coloque o número da NFC-e aqui
  AND status_fiscal = 'EMITIDA_NFCE'  -- Só atualiza se estava EMITIDA
RETURNING id, numero_nfce, status_fiscal, data_cancelamento;

-- OU se você tem a chave de acesso:
UPDATE vendas
SET 
    status_fiscal = 'CANCELADA_NFCE',
    data_cancelamento = NOW(),
    updated_at = NOW()
WHERE chave_acesso_nfce = 'SUA_CHAVE_AQUI'  -- ← Coloque a chave aqui
  AND status_fiscal = 'EMITIDA_NFCE'
RETURNING id, numero_nfce, status_fiscal, data_cancelamento;

-- =====================================================
-- 3. SINCRONIZAÇÃO EM BATCH: Múltiplos documentos
-- =====================================================

-- ⚠️ CUIDADO: Isso atualiza TODOS os documentos EMITIDA_NFCE!
-- Use com cuidado e apenas se tiver certeza!

UPDATE vendas
SET 
    status_fiscal = 'CANCELADA_NFCE',
    data_cancelamento = NOW(),
    updated_at = NOW()
WHERE status_fiscal = 'EMITIDA_NFCE'
  AND numero_nfce IS NOT NULL
RETURNING id, numero_nfce, status_fiscal;

-- =====================================================
-- 4. VERIFICAÇÃO PÓS-SINCRONIZAÇÃO
-- =====================================================

-- Verificar que o documento foi atualizado corretamente:
SELECT 
    id,
    numero_nfce,
    chave_acesso_nfce,
    status_fiscal,
    data_emissao,
    data_cancelamento,
    updated_at
FROM vendas
WHERE numero_nfce = 'SEU_NUMERO_AQUI'  -- ← Coloque o número aqui
ORDER BY data_emissao DESC;

-- Deve mostrar:
-- ✅ status_fiscal = 'CANCELADA_NFCE'
-- ✅ data_cancelamento preenchido
-- ✅ updated_at atualizado para agora

-- =====================================================
-- 5. ATUALIZAR DOCUMENTOS_FISCAIS TAMBÉM
-- =====================================================

-- Se você tem docId, atualizar correspondente em documentos_fiscais:
UPDATE documentos_fiscais
SET 
    status_sefaz = '135',
    mensagem_sefaz = 'Cancelamento autorizado pela SEFAZ (sincronizado manualmente)',
    updated_at = NOW()
WHERE id = 'SEU_DOC_ID_AQUI'  -- ← Coloque o ID aqui
RETURNING id, tipo_documento, status_sefaz;

-- =====================================================
-- HISTÓRICO DE ALTERAÇÕES
-- =====================================================

-- Ver quais vendas foram sincronizadas recentemente:
SELECT 
    id,
    numero_nfce,
    status_fiscal,
    data_cancelamento,
    updated_at
FROM vendas
WHERE status_fiscal = 'CANCELADA_NFCE'
  AND updated_at > NOW() - INTERVAL '1 hour'  -- Últimas 1 hora
ORDER BY updated_at DESC;

-- =====================================================
-- FIM DO SCRIPT
-- =====================================================
