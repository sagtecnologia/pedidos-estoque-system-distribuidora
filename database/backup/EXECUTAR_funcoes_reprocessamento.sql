-- =====================================================
-- FUNÇÕES PARA REPROCESSAMENTO DE ESTOQUE
-- =====================================================
-- Data: 2026-01-09
-- Executar no Supabase SQL Editor
-- ⚠️ ATENÇÃO: Estas funções são CRÍTICAS para o sistema!
-- =====================================================

-- Função 1: Criar backup das movimentações
CREATE OR REPLACE FUNCTION criar_backup_movimentacoes()
RETURNS void AS $$
BEGIN
    -- Remover backup anterior se existir
    DROP TABLE IF EXISTS estoque_movimentacoes_backup;
    
    -- Criar novo backup
    CREATE TABLE estoque_movimentacoes_backup AS 
    SELECT * FROM estoque_movimentacoes;
    
    RAISE NOTICE '✅ Backup criado com % registros', (SELECT COUNT(*) FROM estoque_movimentacoes_backup);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
-- Função 2: Reprocessar estoque completo
-- ⚠️ ESTA FUNÇÃO É PERIGOSA! ELA:
-- 1. Apaga TODAS as movimentações de estoque
-- 2. ZERA todo o estoque de produtos
-- 3. Reconstrói tudo do zero baseado nos pedidos finalizados
CREATE OR REPLACE FUNCTION reprocessar_estoque_completo()
RETURNS TABLE(
    pedidos_processados INTEGER,
    movimentacoes_criadas INTEGER,
    mensagem TEXT
) AS $$
DECLARE
    v_pedido RECORD;
    v_item RECORD;
    v_estoque_anterior DECIMAL;
    v_estoque_novo DECIMAL;
    v_total_processados INTEGER := 0;
    v_total_movs INTEGER := 0;
BEGIN
    RAISE NOTICE '🔧 REPROCESSANDO PEDIDOS FINALIZADOS...';
    RAISE NOTICE '════════════════════════════════════════';
    
    -- PASSO 1: Limpar todas as movimentações
    DELETE FROM estoque_movimentacoes WHERE true;
    RAISE NOTICE '✓ Movimentações limpas';
    
    -- PASSO 2: Zerar estoque de todos os produtos
    UPDATE produto_sabores SET quantidade = 0 WHERE true;
    RAISE NOTICE '✓ Estoque zerado';
    
    -- PASSO 3: Processar cada pedido finalizado na ordem cronológica
    FOR v_pedido IN 
        SELECT p.*
        FROM pedidos p
        WHERE p.status = 'FINALIZADO'
        ORDER BY p.data_finalizacao NULLS LAST, p.created_at
    LOOP
        RAISE NOTICE '📦 Processando pedido: % (%)', v_pedido.numero, v_pedido.tipo_pedido;
        
        -- Processar cada item do pedido
        FOR v_item IN
            SELECT 
                pi.*,
                ps.quantidade as estoque_atual
            FROM pedido_itens pi
            LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
            WHERE pi.pedido_id = v_pedido.id
        LOOP
            IF v_item.sabor_id IS NOT NULL THEN
                v_estoque_anterior := COALESCE(v_item.estoque_atual, 0);
                
                IF v_pedido.tipo_pedido = 'COMPRA' THEN
                    -- COMPRA: ADICIONAR ao estoque
                    UPDATE produto_sabores
                    SET quantidade = quantidade + v_item.quantidade
                    WHERE id = v_item.sabor_id
                    RETURNING quantidade INTO v_estoque_novo;
                    
                    -- Registrar movimentação de ENTRADA
                    INSERT INTO estoque_movimentacoes (
                        produto_id, sabor_id, tipo, quantidade,
                        estoque_anterior, estoque_novo,
                        usuario_id, pedido_id, observacao,
                        created_at
                    ) VALUES (
                        v_item.produto_id,
                        v_item.sabor_id,
                        'ENTRADA',
                        v_item.quantidade,
                        v_estoque_anterior,
                        v_estoque_novo,
                        v_pedido.solicitante_id,
                        v_pedido.id,
                        'Entrada - Finalização pedido compra',
                        COALESCE(v_pedido.data_finalizacao, v_pedido.created_at)
                    );
                    
                    RAISE NOTICE '  ⬆️  +%: % → %', v_item.quantidade, v_estoque_anterior, v_estoque_novo;
                    
                ELSIF v_pedido.tipo_pedido = 'VENDA' THEN
                    -- VENDA: REMOVER do estoque
                    UPDATE produto_sabores
                    SET quantidade = quantidade - v_item.quantidade
                    WHERE id = v_item.sabor_id
                    RETURNING quantidade INTO v_estoque_novo;
                    
                    -- Registrar movimentação de SAÍDA
                    INSERT INTO estoque_movimentacoes (
                        produto_id, sabor_id, tipo, quantidade,
                        estoque_anterior, estoque_novo,
                        usuario_id, pedido_id, observacao,
                        created_at
                    ) VALUES (
                        v_item.produto_id,
                        v_item.sabor_id,
                        'SAIDA',
                        v_item.quantidade,
                        v_estoque_anterior,
                        v_estoque_novo,
                        v_pedido.solicitante_id,
                        v_pedido.id,
                        'Saída - Finalização pedido venda',
                        COALESCE(v_pedido.data_finalizacao, v_pedido.created_at)
                    );
                    
                    RAISE NOTICE '  ⬇️  -%: % → %', v_item.quantidade, v_estoque_anterior, v_estoque_novo;
                END IF;
                
                v_total_movs := v_total_movs + 1;
            END IF;
        END LOOP;
        
        v_total_processados := v_total_processados + 1;
    END LOOP;
    
    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════';
    RAISE NOTICE '✅ REPROCESSAMENTO CONCLUÍDO!';
    RAISE NOTICE '   Pedidos processados: %', v_total_processados;
    RAISE NOTICE '   Movimentações criadas: %', v_total_movs;
    RAISE NOTICE '════════════════════════════════════════';
    
    RETURN QUERY SELECT 
        v_total_processados,
        v_total_movs,
        'Reprocessamento concluído com sucesso!'::TEXT;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Função 3: Verificar consistência do estoque
CREATE OR REPLACE FUNCTION verificar_consistencia_estoque()
RETURNS TABLE(
    produto TEXT,
    sabor TEXT,
    estoque_final DECIMAL,
    total_entradas DECIMAL,
    total_saidas DECIMAL,
    estoque_calculado DECIMAL,
    status TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.nome::TEXT as produto,
        ps.sabor::TEXT as sabor,
        ps.quantidade::DECIMAL as estoque_final,
        COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA'), 0)::DECIMAL as total_entradas,
        COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA'), 0)::DECIMAL as total_saidas,
        (COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA'), 0) -
         COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA'), 0))::DECIMAL as estoque_calculado,
        CASE 
            WHEN ps.quantidade = 
                 (COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA'), 0) -
                  COALESCE((SELECT SUM(quantidade) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA'), 0))
            THEN '✅ OK'::TEXT
            ELSE '⚠️ Inconsistente'::TEXT
        END as status
    FROM produtos p
    JOIN produto_sabores ps ON ps.produto_id = p.id
    WHERE p.active = true
    ORDER BY p.nome, ps.sabor;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- INSTRUÇÕES DE USO
-- =====================================================

-- 1. Execute este script COMPLETO no Supabase SQL Editor
-- 2. Verifique se as 3 funções foram criadas com sucesso
-- 3. Acesse pages/reprocessar-estoque.html
-- 4. SEMPRE crie um backup ANTES de reprocessar!
-- 5. O reprocessamento é IRREVERSÍVEL (só pode voltar com o backup)

-- =====================================================
-- RESULTADO
-- =====================================================

SELECT '✅ FUNÇÕES CRIADAS COM SUCESSO!' as resultado,
       '⚠️ ATENÇÃO: Operação Perigosa!' as aviso,
       '1. criar_backup_movimentacoes()' as funcao1,
       '2. reprocessar_estoque_completo()' as funcao2,
       '3. verificar_consistencia_estoque()' as funcao3,
       '📄 Acesse: pages/reprocessar-estoque.html' as proximo_passo;
