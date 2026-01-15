-- =====================================================
-- PROTEÇÃO CONTRA CANCELAMENTO DUPLO DE PEDIDOS
-- =====================================================
-- Execute este SQL no Supabase para adicionar proteção no banco de dados
-- contra cancelamentos múltiplos que causam estoque negativo

-- Criar função para validar mudança de status
CREATE OR REPLACE FUNCTION validar_mudanca_status_pedido()
RETURNS TRIGGER AS $$
BEGIN
    -- Se o status antigo já era CANCELADO, não permitir qualquer mudança
    IF OLD.status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Não é possível alterar um pedido já cancelado. Status atual: CANCELADO';
    END IF;
    
    -- Se está mudando PARA cancelado, validar que só pode vir de FINALIZADO, APROVADO ou ENVIADO
    IF NEW.status = 'CANCELADO' AND OLD.status NOT IN ('FINALIZADO', 'APROVADO', 'ENVIADO', 'REJEITADO') THEN
        RAISE EXCEPTION 'Só é possível cancelar pedidos com status FINALIZADO, APROVADO, ENVIADO ou REJEITADO. Status atual: %', OLD.status;
    END IF;
    
    -- Se está mudando PARA rascunho de um FINALIZADO, permitir
    IF NEW.status = 'RASCUNHO' AND OLD.status IN ('FINALIZADO', 'APROVADO', 'ENVIADO') THEN
        RETURN NEW;
    END IF;
    
    -- Se o status antigo era RASCUNHO e o novo também é RASCUNHO, não há problema
    IF OLD.status = 'RASCUNHO' AND NEW.status = 'RASCUNHO' THEN
        RETURN NEW;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Remover trigger se já existir
DROP TRIGGER IF EXISTS trigger_validar_mudanca_status ON pedidos;

-- Criar trigger BEFORE UPDATE
CREATE TRIGGER trigger_validar_mudanca_status
    BEFORE UPDATE OF status ON pedidos
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION validar_mudanca_status_pedido();

-- Testar a proteção
DO $$
DECLARE
    v_teste_id UUID;
BEGIN
    -- Criar um pedido de teste
    INSERT INTO pedidos (numero, tipo_pedido, status, solicitante_id, total)
    VALUES ('TESTE-PROTECTION-001', 'COMPRA', 'CANCELADO', 
            (SELECT id FROM users LIMIT 1), 100.00)
    RETURNING id INTO v_teste_id;
    
    -- Tentar alterar um pedido cancelado (deve falhar)
    BEGIN
        UPDATE pedidos 
        SET status = 'FINALIZADO' 
        WHERE id = v_teste_id;
        
        RAISE NOTICE '❌ ERRO: A proteção NÃO funcionou - pedido cancelado foi alterado!';
    EXCEPTION 
        WHEN OTHERS THEN
            RAISE NOTICE '✅ SUCESSO: Proteção funcionou - impediu alteração de pedido cancelado';
    END;
    
    -- Limpar teste
    DELETE FROM pedidos WHERE id = v_teste_id;
END $$;

SELECT '✅ Proteção contra cancelamento duplo instalada com sucesso!' as resultado;
