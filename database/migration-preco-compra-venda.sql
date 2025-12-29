-- =====================================================
-- MIGRAÇÃO: ADICIONAR PREÇO DE COMPRA E VENDA
-- Execute este script se você já tem o sistema rodando
-- =====================================================

-- Adicionar colunas de preço de compra e venda
ALTER TABLE produtos 
ADD COLUMN IF NOT EXISTS preco_compra DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS preco_venda DECIMAL(10,2) DEFAULT 0;

-- Migrar valores existentes de "preco" para "preco_venda"
UPDATE produtos 
SET preco_venda = preco 
WHERE preco_venda = 0 AND preco > 0;

-- Atualizar campo "preco" para ser igual a preco_venda (compatibilidade)
UPDATE produtos 
SET preco = preco_venda 
WHERE preco != preco_venda;

-- Adicionar coluna tipo_pedido se não existir
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS tipo_pedido VARCHAR(10) DEFAULT 'COMPRA' CHECK (tipo_pedido IN ('COMPRA', 'VENDA'));

-- Adicionar coluna cliente_id se não existir
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS cliente_id UUID REFERENCES clientes(id);

-- Atualizar pedidos existentes para tipo COMPRA
UPDATE pedidos 
SET tipo_pedido = 'COMPRA' 
WHERE tipo_pedido IS NULL;

SELECT 'MIGRAÇÃO CONCLUÍDA!' as status;
SELECT 'Produtos agora têm preço de compra e preço de venda' as resultado;
