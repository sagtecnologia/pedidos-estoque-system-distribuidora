-- =====================================================
-- AJUSTE EMERGENCIAL DE ESTOQUE
-- RECONSTRUIR movimentações baseadas nos PEDIDOS FINALIZADOS
-- =====================================================

-- PASSO 1: Backup das movimentações atuais (caso precise reverter)
CREATE TABLE IF NOT EXISTS estoque_movimentacoes_backup AS 
SELECT * FROM estoque_movimentacoes;

-- PASSO 2: Visualizar pedidos que serão processados
SELECT 
    p.numero,
    p.tipo_pedido,
    p.status,
    p.data_finalizacao,
    COUNT(pi.id) as total_itens,
    SUM(pi.quantidade) as total_quantidade
FROM pedidos p
LEFT JOIN pedido_itens pi ON pi.pedido_id = p.id
WHERE p.status = 'FINALIZADO'
GROUP BY p.id, p.numero, p.tipo_pedido, p.status, p.data_finalizacao
ORDER BY p.data_finalizacao;

-- PASSO 3: LIMPAR TODAS as movimentações (vamos reconstruir do zero)
-- ⚠️ DESCOMENTE as linhas abaixo quando estiver pronto para limpar!
DELETE FROM estoque_movimentacoes;

-- PASSO 4: ZERAR estoque de todos os produtos
-- ⚠️ DESCOMENTE a linha abaixo quando estiver pronto!
UPDATE produto_sabores SET quantidade = 0;

-- PASSO 5: REPROCESSAR todos os pedidos finalizados na ordem cronológica
DO $$
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
    
    -- Processar cada pedido finalizado na ordem cronológica
    FOR v_pedido IN 
        SELECT p.*
        FROM pedidos p
        WHERE p.status = 'FINALIZADO'
        ORDER BY p.data_finalizacao NULLS LAST, p.created_at
    LOOP
        RAISE NOTICE '';
        RAISE NOTICE '📦 Processando pedido: % (%) - %', 
            v_pedido.numero, 
            v_pedido.tipo_pedido,
            COALESCE(v_pedido.data_finalizacao::text, v_pedido.created_at::text);
        
        -- Processar cada item do pedido
        FOR v_item IN
            SELECT 
                pi.*,
                p.codigo as produto_codigo,
                ps.sabor,
                ps.quantidade as estoque_atual
            FROM pedido_itens pi
            JOIN produtos p ON p.id = pi.produto_id
            LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
            WHERE pi.pedido_id = v_pedido.id
        LOOP
            IF v_item.sabor_id IS NOT NULL THEN
                v_estoque_anterior := v_item.estoque_atual;
                
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
                    
                    RAISE NOTICE '  ⬆️  % (%) +%: % → %',
                        v_item.produto_codigo,
                        v_item.sabor,
                        v_item.quantidade,
                        v_estoque_anterior,
                        v_estoque_novo;
                    
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
                    
                    RAISE NOTICE '  ⬇️  % (%) -%: % → %',
                        v_item.produto_codigo,
                        v_item.sabor,
                        v_item.quantidade,
                        v_estoque_anterior,
                        v_estoque_novo;
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
END $$;

-- PASSO 6: Verificar estoque final de todos os produtos
SELECT 
    p.codigo,
    p.nome,
    ps.sabor,
    ps.quantidade as estoque_final,
    (SELECT COALESCE(SUM(quantidade), 0) 
     FROM estoque_movimentacoes 
     WHERE sabor_id = ps.id AND tipo = 'ENTRADA') as total_entradas,
    (SELECT COALESCE(SUM(quantidade), 0) 
     FROM estoque_movimentacoes 
     WHERE sabor_id = ps.id AND tipo = 'SAIDA') as total_saidas,
    ((SELECT COALESCE(SUM(quantidade), 0) 
      FROM estoque_movimentacoes 
      WHERE sabor_id = ps.id AND tipo = 'ENTRADA') -
     (SELECT COALESCE(SUM(quantidade), 0) 
      FROM estoque_movimentacoes 
      WHERE sabor_id = ps.id AND tipo = 'SAIDA')) as estoque_calculado,
    CASE 
        WHEN ps.quantidade = 
             ((SELECT COALESCE(SUM(quantidade), 0) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'ENTRADA') -
              (SELECT COALESCE(SUM(quantidade), 0) FROM estoque_movimentacoes WHERE sabor_id = ps.id AND tipo = 'SAIDA'))
        THEN '✅' 
        ELSE '⚠️' 
    END as status
FROM produtos p
JOIN produto_sabores ps ON ps.produto_id = p.id
WHERE p.active = true
ORDER BY p.codigo, ps.sabor;

-- PASSO 7: Contar pedidos e movimentações
SELECT 
    'Pedidos Finalizados' as tipo,
    COUNT(*) as total
FROM pedidos 
WHERE status = 'FINALIZADO'
UNION ALL
SELECT 
    'Movimentações Criadas' as tipo,
    COUNT(*) as total
FROM estoque_movimentacoes;
