-- =====================================================
-- CORREÇÃO: PROTEÇÃO CONTRA CANCELAMENTO INCONSISTENTE
-- =====================================================
-- Cria trigger que reverte movimentações automaticamente
-- quando pedido muda de FINALIZADO para RASCUNHO/CANCELADO
-- =====================================================

-- 1. Criar função que reverte movimentações automaticamente
CREATE OR REPLACE FUNCTION reverter_movimentacoes_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_mov RECORD;
    v_estoque_atual DECIMAL;
    v_produto_codigo VARCHAR;
    v_sabor_nome VARCHAR;
BEGIN
    -- Só age se o status mudou de FINALIZADO para RASCUNHO ou CANCELADO
    IF OLD.status = 'FINALIZADO' AND NEW.status IN ('RASCUNHO', 'CANCELADO') THEN
        
        RAISE NOTICE '🔄 Pedido % mudou de FINALIZADO para %. Revertendo movimentações...', OLD.numero, NEW.status;
        
        -- VALIDAÇÃO: Verificar se há estoque suficiente para reverter COMPRAS
        IF OLD.tipo_pedido = 'COMPRA' THEN
            FOR v_mov IN 
                SELECT m.*, p.codigo as produto_codigo, ps.sabor as sabor_nome,
                       COALESCE(ps.quantidade, p.estoque_atual) as estoque_disponivel
                FROM estoque_movimentacoes m
                JOIN produtos p ON m.produto_id = p.id
                LEFT JOIN produto_sabores ps ON m.sabor_id = ps.id
                WHERE m.pedido_id = OLD.id AND m.tipo = 'ENTRADA'
            LOOP
                -- Verifica se há estoque suficiente para remover
                IF v_mov.estoque_disponivel < v_mov.quantidade THEN
                    RAISE EXCEPTION 'BLOQUEIO: Não é possível cancelar esta compra! O produto % (%) já foi vendido. Estoque atual: %, tentando remover: %. Faltam: % unidades.',
                        v_mov.produto_codigo,
                        COALESCE(v_mov.sabor_nome, 'geral'),
                        v_mov.estoque_disponivel,
                        v_mov.quantidade,
                        (v_mov.quantidade - v_mov.estoque_disponivel);
                END IF;
            END LOOP;
        END IF;
        
        -- Buscar todas as movimentações deste pedido
        FOR v_mov IN 
            SELECT id, tipo, quantidade, produto_id, sabor_id
            FROM estoque_movimentacoes
            WHERE pedido_id = OLD.id
            ORDER BY created_at DESC
        LOOP
            RAISE NOTICE '   Revertendo movimentação: Tipo=% Qtd=%', v_mov.tipo, v_mov.quantidade;
            
            -- Reverter no estoque do sabor (se existir)
            IF v_mov.sabor_id IS NOT NULL THEN
                IF v_mov.tipo = 'ENTRADA' THEN
                    -- Era ENTRADA, precisa REMOVER
                    UPDATE produto_sabores
                    SET quantidade = quantidade - v_mov.quantidade
                    WHERE id = v_mov.sabor_id;
                    
                    RAISE NOTICE '   ✅ Removido % do sabor', v_mov.quantidade;
                ELSIF v_mov.tipo = 'SAIDA' THEN
                    -- Era SAIDA, precisa DEVOLVER
                    UPDATE produto_sabores
                    SET quantidade = quantidade + v_mov.quantidade
                    WHERE id = v_mov.sabor_id;
                    
                    RAISE NOTICE '   ✅ Devolvido % ao sabor', v_mov.quantidade;
                END IF;
            END IF;
            
            -- Reverter no estoque geral do produto
            IF v_mov.tipo = 'ENTRADA' THEN
                UPDATE produtos
                SET estoque_atual = estoque_atual - v_mov.quantidade
                WHERE id = v_mov.produto_id;
            ELSIF v_mov.tipo = 'SAIDA' THEN
                UPDATE produtos
                SET estoque_atual = estoque_atual + v_mov.quantidade
                WHERE id = v_mov.produto_id;
            END IF;
            
            -- DELETAR a movimentação (já foi revertida)
            DELETE FROM estoque_movimentacoes WHERE id = v_mov.id;
            RAISE NOTICE '   ✅ Movimentação deletada';
        END LOOP;
        
        RAISE NOTICE '✅ Todas as movimentações do pedido % foram revertidas e deletadas', OLD.numero;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Criar trigger que executa ANTES de atualizar o pedido
DROP TRIGGER IF EXISTS trigger_reverter_movimentacoes ON pedidos;

CREATE TRIGGER trigger_reverter_movimentacoes
    BEFORE UPDATE ON pedidos
    FOR EACH ROW
    WHEN (OLD.status = 'FINALIZADO' AND NEW.status IN ('RASCUNHO', 'CANCELADO'))
    EXECUTE FUNCTION reverter_movimentacoes_pedido();

-- 3. Proteção adicional: impedir finalizar pedido que JÁ FOI CANCELADO
CREATE OR REPLACE FUNCTION impedir_finalizar_cancelado()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'CANCELADO' AND NEW.status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Não é possível finalizar um pedido cancelado! Reabra como RASCUNHO primeiro.';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_impedir_finalizar_cancelado ON pedidos;

CREATE TRIGGER trigger_impedir_finalizar_cancelado
    BEFORE UPDATE ON pedidos
    FOR EACH ROW
    WHEN (OLD.status = 'CANCELADO' AND NEW.status = 'FINALIZADO')
    EXECUTE FUNCTION impedir_finalizar_cancelado();

-- Resultado
SELECT '✅ PROTEÇÃO INSTALADA' as "STATUS";

SELECT '
╔═══════════════════════════════════════════════════════════╗
║  ✅ CORREÇÃO APLICADA COM SUCESSO                         ║
╚═══════════════════════════════════════════════════════════╝

📋 O QUE FOI CORRIGIDO:

1️⃣ Trigger automático de reversão:
   • Quando pedido muda de FINALIZADO → RASCUNHO/CANCELADO
   • Reverte AUTOMATICAMENTE todas as movimentações
   • Deleta as movimentações antigas (evita duplicação)
   • Atualiza estoque do produto e sabores corretamente

2️⃣ Proteção contra estados inválidos:
   • Impede finalizar pedido que foi cancelado
   • Força reabrir como RASCUNHO antes

3️⃣ Benefícios:
   • ✅ Não importa quantas vezes cancele/reabra
   • ✅ Estoque sempre consistente
   • ✅ Movimentações sempre corretas
   • ✅ Sem movimentações órfãs
   • ✅ BLOQUEIA cancelamento de COMPRA se produtos já foram vendidos

🧪 TESTE:
1. Finalize um pedido de compra (estoque aumenta)
2. Cancele e reabra como RASCUNHO
3. Verifique: estoque volta ao valor original
4. Verifique: movimentações foram deletadas
5. Finalize novamente (tudo OK!)

🚨 TESTE DE BLOQUEIO:
1. Finalize uma compra de 100 unidades (estoque: 100)
2. Finalize uma venda de 80 unidades (estoque: 20)
3. Tente cancelar a compra
4. ✅ SISTEMA BLOQUEIA com mensagem:
   "BLOQUEIO: Não é possível cancelar esta compra! 
    O produto já foi vendido. Estoque atual: 20, 
    tentando remover: 100. Faltam: 80 unidades."

' as "DETALHES";
