-- =====================================================
-- CRIAR PEDIDO DE TESTE PARA VALIDAR CANCELAMENTO
-- =====================================================

-- Selecione um produto e usuário existente
WITH produto_teste AS (
    SELECT id, nome FROM produtos LIMIT 1
),
usuario_teste AS (
    SELECT id FROM users LIMIT 1
)

-- 1. Criar pedido
INSERT INTO pedidos_compra (id, numero, status, total, data_pedido, usuario_id)
SELECT 
    gen_random_uuid(),
    'PC-TESTE-' || to_char(now(), 'YYYYMMDD-HH24MISS'),
    'RASCUNHO',
    100.00,
    current_date,
    (SELECT id FROM usuario_teste)
RETURNING id, numero, status;

-- ANOTE O ID RETORNADO E EXECUTE OS PRÓXIMOS PASSOS SUBSTITUINDO {pedido_id}

-- 2. Adicionar item ao pedido
-- SUBSTITUA {pedido_id} pelo ID retornado acima
-- SUBSTITUA {produto_id} por um ID de produto válido
/*
INSERT INTO pedido_compra_itens (id, pedido_id, produto_id, quantidade, preco_unitario)
VALUES (
    gen_random_uuid(),
    '{pedido_id}',
    '{produto_id}',
    10,
    10.00
);
*/

-- 3. Aprovar o pedido (isso criará a movimentação ENTRADA_COMPRA)
/*
UPDATE pedidos_compra 
SET status = 'APROVADO' 
WHERE id = '{pedido_id}';
*/

-- 4. Verificar a movimentação criada
/*
SELECT 
    tipo_movimento,
    quantidade,
    motivo,
    created_at
FROM estoque_movimentacoes
WHERE referencia_id = '{pedido_id}'
ORDER BY created_at DESC;
*/

-- 5. Agora cancele pelo sistema e veja se cria SAIDA_AJUSTE
