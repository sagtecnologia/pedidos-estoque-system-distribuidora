-- CRIAR FUNÇÃO: atualizar_estoque_sabor
-- Execute este SQL no Supabase ANTES de usar cancelamento

CREATE OR REPLACE FUNCTION atualizar_estoque_sabor(
    p_sabor_id UUID,
    p_quantidade NUMERIC
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_estoque_atual NUMERIC;
BEGIN
    -- Buscar estoque atual
    SELECT quantidade INTO v_estoque_atual
    FROM produto_sabores
    WHERE id = p_sabor_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sabor não encontrado';
    END IF;
    
    -- Atualizar quantidade (pode ser positivo para adicionar ou negativo para remover)
    UPDATE produto_sabores
    SET quantidade = quantidade + p_quantidade
    WHERE id = p_sabor_id;
    
END;
$$;

SELECT 'Função atualizar_estoque_sabor criada com sucesso!' as resultado;
