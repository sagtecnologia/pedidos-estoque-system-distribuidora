-- Função para processar ajustes de estoque
CREATE OR REPLACE FUNCTION public.processar_ajustes_estoque()
RETURNS TABLE(
    id uuid,
    produto_id uuid,
    produto_nome varchar,
    quantidade_diferenca numeric,
    motivo varchar
) LANGUAGE plpgsql AS $function$
DECLARE
    v_ajuste RECORD;
    v_estoque_atual numeric;
BEGIN
    -- Processar cada ajuste registrado
    FOR v_ajuste IN 
        SELECT 
            ae.id,
            ae.produto_id,
            p.nome,
            ae.quantidade_diferenca,
            ae.motivo,
            ae.quantidade_ajustada
        FROM ajuste_estoque ae
        JOIN produtos p ON p.id = ae.produto_id
        ORDER BY ae.data_ajuste  -- Processar em ordem cronológica
    LOOP
        -- Aplicar o ajuste ao estoque
        UPDATE produtos 
        SET estoque_atual = v_ajuste.quantidade_ajustada,
            updated_at = now()
        WHERE id = v_ajuste.produto_id;
        
        -- Retornar informação do ajuste processado
        RETURN QUERY SELECT 
            v_ajuste.id,
            v_ajuste.produto_id,
            v_ajuste.nome,
            v_ajuste.quantidade_diferenca,
            v_ajuste.motivo;
    END LOOP;
END;
$function$;

-- Comentário
COMMENT ON FUNCTION public.processar_ajustes_estoque() IS 'Processa ajustes manuais de estoque para reprocessamento correto';

-- Permissões
GRANT EXECUTE ON FUNCTION public.processar_ajustes_estoque() TO authenticated;
GRANT EXECUTE ON FUNCTION public.processar_ajustes_estoque() TO anon;
