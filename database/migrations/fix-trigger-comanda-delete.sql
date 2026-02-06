-- =====================================================
-- MIGRAÇÃO: Corrigir Trigger de Atualização de Totais na Remoção de Item
-- Descrição: O trigger de DELETE estava usando NEW.comanda_id ao invés de OLD.comanda_id
-- Data: 06/02/2026
-- =====================================================

-- Recriar função para atualizar totais no DELETE (usa OLD ao invés de NEW)
CREATE OR REPLACE FUNCTION atualizar_totais_comanda_delete()
RETURNS TRIGGER AS $$
BEGIN
    -- No DELETE, usamos OLD ao invés de NEW
    UPDATE comandas
    SET 
        subtotal = (
            SELECT COALESCE(SUM(subtotal - desconto), 0)
            FROM comanda_itens
            WHERE comanda_id = OLD.comanda_id
            AND status != 'cancelado'
        ),
        valor_total = (
            SELECT COALESCE(SUM(subtotal - desconto), 0)
            FROM comanda_itens
            WHERE comanda_id = OLD.comanda_id
            AND status != 'cancelado'
        ) - COALESCE((SELECT desconto FROM comandas WHERE id = OLD.comanda_id), 0) 
          + COALESCE((SELECT acrescimo FROM comandas WHERE id = OLD.comanda_id), 0),
        updated_at = NOW()
    WHERE id = OLD.comanda_id;
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Recriar trigger de DELETE com a função correta
DROP TRIGGER IF EXISTS trigger_atualizar_totais_comanda_delete ON comanda_itens;
CREATE TRIGGER trigger_atualizar_totais_comanda_delete
    AFTER DELETE ON comanda_itens
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_totais_comanda_delete();

-- =====================================================
-- FIM DA MIGRAÇÃO
-- =====================================================

-- NOTA: Execute esta migration no Supabase SQL Editor
-- para corrigir o problema de totais não atualizarem ao remover itens.
