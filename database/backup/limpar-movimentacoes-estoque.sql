-- =====================================================
-- LIMPAR MOVIMENTAÇÕES DE ESTOQUE
-- =====================================================
-- Este script EXCLUI apenas registros da tabela estoque_movimentacoes
-- NÃO exclui: pedidos, produtos, sabores ou outras tabelas

-- ⚠️ ATENÇÃO: Esta ação é IRREVERSÍVEL!
-- Execute com cuidado e faça backup se necessário

-- =====================================================
-- PASSO 1: VISUALIZAR O QUE SERÁ EXCLUÍDO
-- =====================================================

-- Ver total de movimentações por tipo
SELECT 
    tipo,
    COUNT(*) as total,
    MIN(created_at) as primeira_movimentacao,
    MAX(created_at) as ultima_movimentacao
FROM estoque_movimentacoes
GROUP BY tipo
ORDER BY tipo;

-- Ver movimentações por período (últimos 30 dias)
SELECT 
    DATE(created_at) as data,
    tipo,
    COUNT(*) as quantidade_movimentacoes
FROM estoque_movimentacoes
WHERE created_at >= NOW() - INTERVAL '30 days'
GROUP BY DATE(created_at), tipo
ORDER BY data DESC, tipo;

-- Ver total geral
SELECT 
    COUNT(*) as total_movimentacoes,
    COUNT(DISTINCT produto_id) as produtos_afetados,
    COUNT(DISTINCT sabor_id) as sabores_afetados,
    COUNT(DISTINCT pedido_id) as pedidos_relacionados,
    COUNT(DISTINCT usuario_id) as usuarios_envolvidos
FROM estoque_movimentacoes;

-- =====================================================
-- OPÇÃO 1: EXCLUIR TODAS AS MOVIMENTAÇÕES
-- =====================================================
-- ⚠️ DESCOMENTE AS LINHAS ABAIXO PARA EXECUTAR

-- BEGIN;
-- 
-- DELETE FROM estoque_movimentacoes;
-- 
-- SELECT 'Total de movimentações excluídas' as mensagem, 
--        (SELECT COUNT(*) FROM estoque_movimentacoes) as restantes;
-- 
-- COMMIT;
-- SELECT '✅ TODAS as movimentações foram excluídas!' as resultado;

-- =====================================================
-- OPÇÃO 2: EXCLUIR MOVIMENTAÇÕES POR TIPO
-- =====================================================
-- Exclui apenas movimentações de um tipo específico

-- Excluir apenas ENTRADA
-- DELETE FROM estoque_movimentacoes WHERE tipo = 'ENTRADA';

-- Excluir apenas SAIDA
-- DELETE FROM estoque_movimentacoes WHERE tipo = 'SAIDA';

-- Excluir apenas AJUSTE
-- DELETE FROM estoque_movimentacoes WHERE tipo = 'AJUSTE';

-- =====================================================
-- OPÇÃO 3: EXCLUIR MOVIMENTAÇÕES POR PERÍODO
-- =====================================================

-- Excluir movimentações mais antigas que 90 dias
-- DELETE FROM estoque_movimentacoes 
-- WHERE created_at < NOW() - INTERVAL '90 days';

-- Excluir movimentações de um mês específico
-- DELETE FROM estoque_movimentacoes 
-- WHERE DATE_TRUNC('month', created_at) = '2025-12-01'::DATE;

-- Excluir movimentações de um período específico
-- DELETE FROM estoque_movimentacoes 
-- WHERE created_at BETWEEN '2025-01-01' AND '2025-12-31';

-- =====================================================
-- OPÇÃO 4: EXCLUIR MOVIMENTAÇÕES DE CANCELAMENTO
-- =====================================================
-- Exclui apenas as movimentações relacionadas a cancelamentos

-- Excluir movimentações de cancelamento de compras
-- DELETE FROM estoque_movimentacoes 
-- WHERE observacao LIKE '%Cancelamento%' 
--   OR observacao LIKE '%Reabertura%';

-- Excluir movimentações de devolução de vendas
-- DELETE FROM estoque_movimentacoes 
-- WHERE observacao LIKE '%Devolução%';

-- =====================================================
-- OPÇÃO 5: EXCLUIR MOVIMENTAÇÕES DE PEDIDOS ESPECÍFICOS
-- =====================================================

-- Excluir movimentações de um pedido específico
-- DELETE FROM estoque_movimentacoes 
-- WHERE pedido_id = 'UUID-DO-PEDIDO-AQUI';

-- Excluir movimentações de pedidos cancelados
-- DELETE FROM estoque_movimentacoes 
-- WHERE pedido_id IN (
--     SELECT id FROM pedidos WHERE status = 'CANCELADO'
-- );

-- =====================================================
-- OPÇÃO 6: EXCLUIR DUPLICATAS (MOVIMENTAÇÕES REDUNDANTES)
-- =====================================================
-- Remove movimentações duplicadas mantendo apenas a mais recente

-- Visualizar duplicatas primeiro
SELECT 
    produto_id,
    sabor_id,
    tipo,
    quantidade,
    pedido_id,
    created_at,
    COUNT(*) as vezes_registrado
FROM estoque_movimentacoes
GROUP BY produto_id, sabor_id, tipo, quantidade, pedido_id, created_at
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC;

-- Excluir duplicatas (mantém a primeira ocorrência)
-- DELETE FROM estoque_movimentacoes a
-- USING estoque_movimentacoes b
-- WHERE a.id > b.id
--   AND a.produto_id = b.produto_id
--   AND a.sabor_id = b.sabor_id
--   AND a.tipo = b.tipo
--   AND a.quantidade = b.quantidade
--   AND a.created_at = b.created_at;

-- =====================================================
-- OPÇÃO 7: ZERAR E REINICIAR CONTADOR (CUIDADO!)
-- =====================================================
-- Exclui TUDO e reseta o contador de IDs

-- ⚠️ EXTREMO CUIDADO - ISTO APAGA TUDO!
-- DELETE FROM estoque_movimentacoes;
-- ALTER SEQUENCE estoque_movimentacoes_id_seq RESTART WITH 1;

-- =====================================================
-- VERIFICAÇÕES PÓS-EXCLUSÃO
-- =====================================================

-- Verificar quantas movimentações restam
SELECT 
    COUNT(*) as total_restante,
    COUNT(*) FILTER (WHERE tipo = 'ENTRADA') as entradas,
    COUNT(*) FILTER (WHERE tipo = 'SAIDA') as saidas,
    COUNT(*) FILTER (WHERE tipo = 'AJUSTE') as ajustes
FROM estoque_movimentacoes;

-- Verificar se pedidos ainda existem (devem estar intactos)
SELECT 
    COUNT(*) as total_pedidos,
    COUNT(*) FILTER (WHERE tipo_pedido = 'COMPRA') as compras,
    COUNT(*) FILTER (WHERE tipo_pedido = 'VENDA') as vendas
FROM pedidos;

-- Verificar se produtos ainda existem (devem estar intactos)
SELECT COUNT(*) as total_produtos FROM produtos;

-- Verificar se sabores ainda existem (devem estar intactos)
SELECT COUNT(*) as total_sabores FROM produto_sabores;

-- =====================================================
-- SCRIPT SEGURO: EXCLUIR TUDO COM BACKUP
-- =====================================================
-- Cria backup antes de excluir (recomendado!)

-- Criar tabela temporária com backup
-- CREATE TEMP TABLE backup_movimentacoes AS 
-- SELECT * FROM estoque_movimentacoes;

-- Verificar backup
-- SELECT COUNT(*) as total_no_backup FROM backup_movimentacoes;

-- Excluir da tabela principal
-- DELETE FROM estoque_movimentacoes;

-- Se algo der errado, restaurar:
-- INSERT INTO estoque_movimentacoes 
-- SELECT * FROM backup_movimentacoes;

-- Remover backup (após confirmar que está tudo OK)
-- DROP TABLE backup_movimentacoes;

-- =====================================================
-- RESUMO DE COMANDOS RÁPIDOS
-- =====================================================

-- Ver total:
-- SELECT COUNT(*) FROM estoque_movimentacoes;

-- Excluir TUDO:
-- DELETE FROM estoque_movimentacoes;

-- Excluir cancelamentos:
-- DELETE FROM estoque_movimentacoes WHERE observacao LIKE '%Cancelamento%';

-- Excluir antigas (mais de 6 meses):
-- DELETE FROM estoque_movimentacoes WHERE created_at < NOW() - INTERVAL '6 months';

SELECT '📋 Script de limpeza carregado. DESCOMENTE as linhas desejadas para executar.' as info;
