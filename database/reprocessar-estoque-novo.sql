-- ==========================================
-- REPROCESSAMENTO DE ESTOQUE - NOVA ESTRUTURA
-- Valida apenas ENTRADAS e SAÍDAS (não movimentações)
-- ==========================================

-- ⚠️ SEGURANÇA - LEIA ANTES DE USAR
-- ✅ PRODUTOS NÃO SÃO DELETADOS (apenas UPDATE no estoque_atual)
-- ✅ Tabela "produtos" é apenas lida, nunca deletada
-- ✅ Tabela "produto_lotes" é apenas atualizada (quantidade_atual), nunca deletada
-- ✅ As operações são: UPDATE, SELECT (nunca DELETE)
-- ✅ Resultado: Produtos continuam cadastrados, apenas com estoque recalculado
--
-- O que muda:
--   produtos.estoque_atual = 0 (zera) → recalcula → novo valor
--   produto_lotes.quantidade_atual = 0 (zera) → recalcula → novo valor
--
-- O que NÃO muda:
--   ❌ Produtos não são deletados
--   ❌ Lotes não são deletados
--   ❌ Dados de produtos (nome, SKU, etc) não são tocados
--   ❌ Nenhuma linha é removida de nenhuma tabela
-- ==========================================

-- 1️⃣ ZERAR TODOS OS ESTOQUES
CREATE OR REPLACE FUNCTION zerar_estoque_completo()
RETURNS void AS $$
BEGIN
    -- Zerar estoque dos produtos
    UPDATE public.produtos SET estoque_atual = 0;
    
    -- Zerar quantidade dos lotes
    UPDATE public.produto_lotes SET quantidade_atual = 0;
    
    RAISE NOTICE '✅ Estoque zerado com sucesso';
END;
$$ LANGUAGE plpgsql;

-- 2️⃣ PROCESSAR ENTRADAS (Compras Recebidas)
CREATE OR REPLACE FUNCTION processar_entradas_compras()
RETURNS TABLE (
    produto_id UUID,
    produto_nome VARCHAR,
    quantidade_total NUMERIC,
    preco_custo NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH entradas AS (
        SELECT 
            pci.produto_id,
            p.nome AS produto_nome,
            SUM(pci.quantidade) AS quantidade_total,
            pci.preco_unitario AS preco_custo
        FROM public.pedido_compra_itens pci
        JOIN public.pedidos_compra pc ON pci.pedido_id = pc.id
        JOIN public.produtos p ON pci.produto_id = p.id
        WHERE pc.status = 'RECEBIDO'  -- Apenas pedidos recebidos
        GROUP BY pci.produto_id, p.nome, pci.preco_unitario
    )
    UPDATE public.produtos p
    SET estoque_atual = estoque_atual + e.quantidade_total
    FROM entradas e
    WHERE p.id = e.produto_id
    RETURNING 
        e.produto_id,
        e.produto_nome,
        e.quantidade_total,
        e.preco_custo;
END;
$$ LANGUAGE plpgsql;

-- 3️⃣ PROCESSAR SAÍDAS (Vendas Finalizadas)
CREATE OR REPLACE FUNCTION processar_saidas_vendas()
RETURNS TABLE (
    produto_id UUID,
    produto_nome VARCHAR,
    quantidade_total NUMERIC,
    preco_venda NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH saidas AS (
        SELECT 
            vi.produto_id,
            p.nome AS produto_nome,
            SUM(vi.quantidade) AS quantidade_total,
            vi.preco_unitario AS preco_venda
        FROM public.vendas_itens vi
        JOIN public.vendas v ON vi.venda_id = v.id
        JOIN public.produtos p ON vi.produto_id = p.id
        WHERE v.status = 'FINALIZADA'  -- Apenas vendas finalizadas
        GROUP BY vi.produto_id, p.nome, vi.preco_unitario
    )
    UPDATE public.produtos p
    SET estoque_atual = estoque_atual - s.quantidade_total
    FROM saidas s
    WHERE p.id = s.produto_id
    AND estoque_atual >= s.quantidade_total  -- Validação!
    RETURNING 
        s.produto_id,
        s.produto_nome,
        s.quantidade_total,
        s.preco_venda;
END;
$$ LANGUAGE plpgsql;

-- 4️⃣ ATUALIZAR LOTES
CREATE OR REPLACE FUNCTION atualizar_quantidade_lotes()
RETURNS TABLE (
    lote_id UUID,
    numero_lote VARCHAR,
    quantidade_atual NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH lote_saidas AS (
        SELECT 
            vi.lote_id,
            pl.numero_lote,
            SUM(vi.quantidade) AS quantidade_saida
        FROM public.vendas_itens vi
        JOIN public.vendas v ON vi.venda_id = v.id
        JOIN public.produto_lotes pl ON vi.lote_id = pl.id
        WHERE v.status = 'FINALIZADA'
        AND vi.lote_id IS NOT NULL
        GROUP BY vi.lote_id, pl.numero_lote
    )
    UPDATE public.produto_lotes pl
    SET quantidade_atual = GREATEST(quantidade_inicial - ls.quantidade_saida, 0)
    FROM lote_saidas ls
    WHERE pl.id = ls.lote_id
    RETURNING 
        pl.id,
        pl.numero_lote,
        pl.quantidade_atual;
END;
$$ LANGUAGE plpgsql;

-- 5️⃣ VALIDAR CONSISTÊNCIA
CREATE OR REPLACE FUNCTION validar_consistencia_estoque()
RETURNS TABLE (
    produto_id UUID,
    produto_nome VARCHAR,
    estoque_atual NUMERIC,
    entradas_total NUMERIC,
    saidas_total NUMERIC,
    estoque_calculado NUMERIC,
    status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH movimentacao AS (
        -- Entradas de compras
        SELECT 
            pci.produto_id,
            'ENTRADA'::VARCHAR AS tipo,
            SUM(pci.quantidade) AS quantidade
        FROM public.pedido_compra_itens pci
        JOIN public.pedidos_compra pc ON pci.pedido_id = pc.id
        WHERE pc.status = 'RECEBIDO'
        GROUP BY pci.produto_id
        
        UNION ALL
        
        -- Saídas de vendas
        SELECT 
            vi.produto_id,
            'SAIDA'::VARCHAR,
            -SUM(vi.quantidade)
        FROM public.vendas_itens vi
        JOIN public.vendas v ON vi.venda_id = v.id
        WHERE v.status = 'FINALIZADA'
        GROUP BY vi.produto_id
    ),
    resumo AS (
        SELECT 
            p.id AS produto_id,
            p.nome AS produto_nome,
            p.estoque_atual,
            COALESCE(
                SUM(CASE WHEN m.tipo = 'ENTRADA' THEN m.quantidade ELSE 0 END), 0
            ) AS entradas_total,
            COALESCE(
                SUM(CASE WHEN m.tipo = 'SAIDA' THEN -m.quantidade ELSE 0 END), 0
            ) AS saidas_total
        FROM public.produtos p
        LEFT JOIN movimentacao m ON p.id = m.produto_id
        GROUP BY p.id, p.nome, p.estoque_atual
    )
    SELECT 
        r.produto_id,
        r.produto_nome,
        r.estoque_atual,
        r.entradas_total,
        r.saidas_total,
        (r.entradas_total - r.saidas_total)::NUMERIC AS estoque_calculado,
        CASE 
            WHEN r.estoque_atual = (r.entradas_total - r.saidas_total) THEN 'OK'::VARCHAR
            ELSE 'DIVERGÊNCIA'::VARCHAR
        END AS status
    FROM resumo r
    WHERE r.estoque_atual > 0 OR r.entradas_total > 0 OR r.saidas_total > 0
    ORDER BY r.produto_nome;
END;
$$ LANGUAGE plpgsql;

-- 6️⃣ EXECUTAR REPROCESSAMENTO COMPLETO
CREATE OR REPLACE FUNCTION reprocessar_estoque_novo()
RETURNS TABLE (
    etapa VARCHAR,
    status VARCHAR,
    registros_afetados INTEGER
) AS $$
DECLARE
    v_registros INTEGER;
BEGIN
    -- Log de início
    RAISE NOTICE '========================================';
    RAISE NOTICE 'INICIANDO REPROCESSAMENTO DE ESTOQUE';
    RAISE NOTICE '========================================';
    
    -- ETAPA 1: Zerar
    RAISE NOTICE '1️⃣  Zerando estoque...';
    PERFORM zerar_estoque_completo();
    INSERT INTO (etapa, status, registros_afetados) VALUES 
        ('ZERAR_ESTOQUE', 'CONCLUÍDO', 1);
    RETURN NEXT;
    
    -- ETAPA 2: Processar Entradas
    RAISE NOTICE '2️⃣  Processando entradas de compras...';
    SELECT COUNT(*)::INTEGER INTO v_registros 
    FROM processar_entradas_compras();
    INSERT INTO (etapa, status, registros_afetados) VALUES 
        ('PROCESSAR_ENTRADAS', 'CONCLUÍDO', v_registros);
    RETURN NEXT;
    RAISE NOTICE '   ✅ %s produtos atualizados com entradas', v_registros;
    
    -- ETAPA 3: Processar Saídas
    RAISE NOTICE '3️⃣  Processando saídas de vendas...';
    SELECT COUNT(*)::INTEGER INTO v_registros 
    FROM processar_saidas_vendas();
    INSERT INTO (etapa, status, registros_afetados) VALUES 
        ('PROCESSAR_SAIDAS', 'CONCLUÍDO', v_registros);
    RETURN NEXT;
    RAISE NOTICE '   ✅ %s produtos atualizados com saídas', v_registros;
    
    -- ETAPA 4: Atualizar Lotes
    RAISE NOTICE '4️⃣  Atualizando quantidade de lotes...';
    SELECT COUNT(*)::INTEGER INTO v_registros 
    FROM atualizar_quantidade_lotes();
    INSERT INTO (etapa, status, registros_afetados) VALUES 
        ('ATUALIZAR_LOTES', 'CONCLUÍDO', v_registros);
    RETURN NEXT;
    RAISE NOTICE '   ✅ %s lotes atualizados', v_registros;
    
    -- ETAPA 5: Validar
    RAISE NOTICE '5️⃣  Validando consistência...';
    SELECT COUNT(*)::INTEGER INTO v_registros 
    FROM validar_consistencia_estoque();
    INSERT INTO (etapa, status, registros_afetados) VALUES 
        ('VALIDAR_CONSISTENCIA', 'CONCLUÍDO', v_registros);
    RETURN NEXT;
    RAISE NOTICE '   ✅ %s produtos validados', v_registros;
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'REPROCESSAMENTO CONCLUÍDO COM SUCESSO!';
    RAISE NOTICE '========================================';
END;
$$ LANGUAGE plpgsql;
