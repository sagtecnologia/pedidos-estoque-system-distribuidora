-- =====================================================
-- PROTEÇÃO DEFINITIVA CONTRA DUPLICAÇÃO DE MOVIMENTAÇÕES
-- =====================================================
-- Data: 2026-01-09
-- Descrição: Cria constraint única para impedir movimentações duplicadas
-- Execução: Copie e execute no Supabase SQL Editor
-- =====================================================

-- =====================================================
-- PASSO 1: VERIFICAR DUPLICATAS EXISTENTES
-- =====================================================

-- Ver quantas duplicatas existem atualmente
SELECT 
    pedido_id,
    produto_id,
    sabor_id,
    COUNT(*) as total_movimentacoes
FROM estoque_movimentacoes
WHERE pedido_id IS NOT NULL
GROUP BY pedido_id, produto_id, sabor_id
HAVING COUNT(*) > 1
ORDER BY total_movimentacoes DESC;

-- =====================================================
-- PASSO 2: CRIAR CONSTRAINT ÚNICA (VERSÃO CORRIGIDA)
-- =====================================================

-- IMPORTANTE: Esta constraint precisa permitir:
-- 1. UMA movimentação de finalização por produto/sabor
-- 2. UMA movimentação de cancelamento por produto/sabor
-- Solução: Incluir tipo+observação na constraint

-- Primeiro, remover constraint antiga se existir
DROP INDEX IF EXISTS idx_movimentacao_unica;

-- Nova constraint que diferencia finalização de cancelamento
CREATE UNIQUE INDEX idx_movimentacao_finalização_unica 
ON estoque_movimentacoes (
    pedido_id, 
    produto_id, 
    COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
) 
WHERE pedido_id IS NOT NULL 
  AND (observacao LIKE '%Finalização%' OR observacao LIKE '%finalização%');

-- Constraint separada para cancelamentos
CREATE UNIQUE INDEX idx_movimentacao_cancelamento_unica 
ON estoque_movimentacoes (
    pedido_id, 
    produto_id, 
    COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
) 
WHERE pedido_id IS NOT NULL 
  AND observacao LIKE '%Cancelamento%';

-- Comentários explicativos
COMMENT ON INDEX idx_movimentacao_finalização_unica IS 
'Garante que cada pedido tenha apenas UMA movimentação de FINALIZAÇÃO por produto/sabor. 
Previne duplicações causadas por sessões expiradas, cliques duplos ou retry de rede.';

COMMENT ON INDEX idx_movimentacao_cancelamento_unica IS 
'Garante que cada pedido tenha apenas UMA movimentação de CANCELAMENTO por produto/sabor.
Permite cancelar pedidos que já foram finalizados sem conflitar com as movimentações de finalização.';

-- =====================================================
-- PASSO 3: CRIAR FUNÇÃO DE VALIDAÇÃO
-- =====================================================

-- Função auxiliar para verificar se movimentação já existe
CREATE OR REPLACE FUNCTION verificar_movimentacao_existente(
    p_pedido_id UUID,
    p_produto_id UUID,
    p_sabor_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_existe BOOLEAN;
BEGIN
    -- Verifica se já existe movimentação para este pedido+produto+sabor
    SELECT EXISTS(
        SELECT 1
        FROM estoque_movimentacoes
        WHERE pedido_id = p_pedido_id
        AND produto_id = p_produto_id
        AND COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::UUID) = 
            COALESCE(p_sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
    ) INTO v_existe;
    
    RETURN v_existe;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION verificar_movimentacao_existente IS 
'Verifica se já existe uma movimentação para o pedido+produto+sabor especificado. 
Útil para validações adicionais antes de criar movimentações.';

-- =====================================================
-- PASSO 4: ATUALIZAR FUNÇÃO finalizar_pedido
-- =====================================================

-- Adicionar validação extra antes de criar movimentações
CREATE OR REPLACE FUNCTION finalizar_pedido(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_ja_finalizado BOOLEAN;
    v_mov_existente BOOLEAN;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA)
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    -- PROTEÇÃO 1: Impedir múltiplas finalizações
    IF v_status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Este pedido já foi finalizado anteriormente';
    END IF;
    
    -- PROTEÇÃO 2: Verificar se pedido foi cancelado
    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Este pedido foi cancelado e não pode ser finalizado';
    END IF;
    
    -- PROTEÇÃO 3: Verificar se já existem movimentações de finalização
    SELECT EXISTS(
        SELECT 1 
        FROM estoque_movimentacoes 
        WHERE pedido_id = p_pedido_id 
        AND (observacao LIKE '%Finalização%' OR observacao LIKE '%finalização%')
    ) INTO v_ja_finalizado;
    
    IF v_ja_finalizado THEN
        RAISE EXCEPTION 'Este pedido já tem movimentações de finalização registradas';
    END IF;

    -- Processar itens do pedido
    FOR v_item IN 
        SELECT 
            pi.produto_id, 
            pi.sabor_id, 
            pi.quantidade,
            p.codigo as produto_codigo,
            ps.sabor as sabor_nome
        FROM pedido_itens pi
        LEFT JOIN produtos p ON p.id = pi.produto_id
        LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
        WHERE pi.pedido_id = p_pedido_id
    LOOP
        -- 🛡️ PROTEÇÃO ADICIONAL: Verificar se movimentação já existe
        v_mov_existente := verificar_movimentacao_existente(
            p_pedido_id, 
            v_item.produto_id, 
            v_item.sabor_id
        );
        
        IF v_mov_existente THEN
            RAISE EXCEPTION 'Já existe movimentação para o produto % no pedido especificado', 
                v_item.produto_codigo;
        END IF;
        
        -- Processar movimentação de sabor (se aplicável)
        IF v_item.sabor_id IS NOT NULL THEN
            DECLARE
                v_estoque_anterior DECIMAL;
                v_estoque_novo DECIMAL;
                v_quantidade_ajuste DECIMAL;
            BEGIN
                -- Buscar estoque atual COM LOCK
                SELECT quantidade INTO v_estoque_anterior
                FROM produto_sabores
                WHERE id = v_item.sabor_id
                FOR UPDATE;
                
                -- Calcular ajuste baseado no tipo
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_quantidade_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_quantidade_ajuste := -v_item.quantidade;
                    
                    -- Validação de estoque
                    IF v_estoque_anterior < v_item.quantidade THEN
                        RAISE EXCEPTION 'Estoque insuficiente para % (%). Necessário: %, Disponível: %',
                            v_item.produto_codigo, 
                            v_item.sabor_nome,
                            v_item.quantidade,
                            v_estoque_anterior;
                    END IF;
                ELSE
                    RAISE EXCEPTION 'Tipo de pedido inválido: %', v_tipo_pedido;
                END IF;
                
                -- Atualizar estoque
                UPDATE produto_sabores
                SET quantidade = quantidade + v_quantidade_ajuste
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_estoque_novo;
                
                -- 📝 Registrar movimentação (constraint única garante não duplicar)
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    sabor_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    observacao
                ) VALUES (
                    v_item.produto_id,
                    v_item.sabor_id,
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                    v_item.quantidade,
                    v_estoque_anterior,
                    v_estoque_novo,
                    p_usuario_id,
                    p_pedido_id,
                    CASE 
                        WHEN v_tipo_pedido = 'COMPRA' THEN 'Entrada - Finalização pedido compra'
                        ELSE 'Saída - Finalização pedido venda'
                    END
                );
            END;
        ELSE
            -- Processar produto sem sabor (lógica similar)
            DECLARE
                v_estoque_anterior DECIMAL;
                v_estoque_novo DECIMAL;
                v_quantidade_ajuste DECIMAL;
            BEGIN
                SELECT estoque_atual INTO v_estoque_anterior
                FROM produtos
                WHERE id = v_item.produto_id
                FOR UPDATE;
                
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_quantidade_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_quantidade_ajuste := -v_item.quantidade;
                    
                    IF v_estoque_anterior < v_item.quantidade THEN
                        RAISE EXCEPTION 'Estoque insuficiente para %. Necessário: %, Disponível: %',
                            v_item.produto_codigo,
                            v_item.quantidade,
                            v_estoque_anterior;
                    END IF;
                END IF;
                
                UPDATE produtos
                SET estoque_atual = estoque_atual + v_quantidade_ajuste
                WHERE id = v_item.produto_id
                RETURNING estoque_atual INTO v_estoque_novo;
                
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    observacao
                ) VALUES (
                    v_item.produto_id,
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                    v_item.quantidade,
                    v_estoque_anterior,
                    v_estoque_novo,
                    p_usuario_id,
                    p_pedido_id,
                    CASE 
                        WHEN v_tipo_pedido = 'COMPRA' THEN 'Entrada - Finalização pedido compra'
                        ELSE 'Saída - Finalização pedido venda'
                    END
                );
            END;
        END IF;
    END LOOP;

    -- Atualizar status do pedido
    UPDATE pedidos 
    SET 
        status = 'FINALIZADO',
        data_finalizacao = NOW(),
        aprovador_id = p_usuario_id
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION finalizar_pedido IS 
'Finaliza pedido com múltiplas camadas de proteção:
1. Lock pessimista (FOR UPDATE)
2. Verificação de status
3. Verificação de movimentações existentes
4. Validação antes de cada inserção
5. Constraint única no banco (proteção definitiva)';

-- =====================================================
-- PASSO 5: TESTES DE VALIDAÇÃO
-- =====================================================

-- Teste 1: Verificar se constraints foram criadas
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'estoque_movimentacoes'
AND indexname IN ('idx_movimentacao_finalização_unica', 'idx_movimentacao_cancelamento_unica');

-- Teste 2: Verificar função auxiliar
SELECT 
    proname as nome_funcao,
    pg_get_functiondef(oid) as definicao
FROM pg_proc
WHERE proname = 'verificar_movimentacao_existente';

-- =====================================================
-- RESULTADO
-- =====================================================

SELECT '✅ PROTEÇÃO CONTRA DUPLICAÇÃO IMPLEMENTADA COM SUCESSO!' as resultado,
       '🛡️ Constraint de finalização: idx_movimentacao_finalização_unica' as detalhe1,
       '🛡️ Constraint de cancelamento: idx_movimentacao_cancelamento_unica' as detalhe2,
       '📝 Função de validação criada: verificar_movimentacao_existente' as detalhe3,
       '🔒 Função finalizar_pedido atualizada com validações extras' as detalhe4,
       '⚠️  IMPORTANTE: Execute o script de correção de duplicatas antes se houver inconsistências!' as aviso;
