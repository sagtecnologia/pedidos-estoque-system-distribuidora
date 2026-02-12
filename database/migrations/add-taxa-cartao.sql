-- Adicionar campos de taxa de cartão à tabela empresa_config
ALTER TABLE empresa_config 
ADD COLUMN IF NOT EXISTS taxa_cartao_debito NUMERIC(5, 2) DEFAULT 1.09,
ADD COLUMN IF NOT EXISTS taxa_cartao_credito NUMERIC(5, 2) DEFAULT 3.16;

-- Comentários para documentação
COMMENT ON COLUMN empresa_config.taxa_cartao_debito IS 'Taxa de processamento para cartão débito (em percentual)';
COMMENT ON COLUMN empresa_config.taxa_cartao_credito IS 'Taxa de processamento para cartão crédito (em percentual)';
