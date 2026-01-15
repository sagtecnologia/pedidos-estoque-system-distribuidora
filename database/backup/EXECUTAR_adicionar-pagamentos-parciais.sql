-- =====================================================
-- MIGRATION: Adicionar Sistema de Pagamentos Parciais
-- =====================================================

-- Adicionar colunas para controle de pagamento
ALTER TABLE pedidos
ADD COLUMN IF NOT EXISTS pagamento_status TEXT DEFAULT 'PENDENTE' CHECK (pagamento_status IN ('PENDENTE', 'PARCIAL', 'PAGO')),
ADD COLUMN IF NOT EXISTS valor_pago DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS valor_pendente DECIMAL(10,2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS data_pagamento_completo TIMESTAMP;

-- Criar tabela de histórico de pagamentos
CREATE TABLE IF NOT EXISTS pagamentos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    valor DECIMAL(10,2) NOT NULL,
    forma_pagamento TEXT,
    observacao TEXT,
    usuario_id UUID REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Criar índices
CREATE INDEX IF NOT EXISTS idx_pedidos_pagamento_status ON pedidos(pagamento_status);
CREATE INDEX IF NOT EXISTS idx_pedidos_valor_pendente ON pedidos(valor_pendente);
CREATE INDEX IF NOT EXISTS idx_pagamentos_pedido_id ON pagamentos(pedido_id);

-- Habilitar RLS
ALTER TABLE pagamentos ENABLE ROW LEVEL SECURITY;

-- Políticas de acesso para pagamentos
CREATE POLICY "Usuários autenticados podem ver pagamentos"
    ON pagamentos FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "Apenas ADMIN e VENDEDOR podem inserir pagamentos"
    ON pagamentos FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE users.id = auth.uid() 
            AND users.role IN ('ADMIN', 'VENDEDOR')
        )
    );

-- Atualizar vendas finalizadas existentes para marcá-las como pagas
UPDATE pedidos 
SET 
    pagamento_status = 'PAGO',
    valor_pago = total,
    valor_pendente = 0,
    data_pagamento_completo = NOW()
WHERE tipo_pedido = 'VENDA' 
AND status = 'FINALIZADO'
AND pagamento_status IS NULL;

-- Comentários
COMMENT ON COLUMN pedidos.pagamento_status IS 'Status do pagamento: PENDENTE, PARCIAL ou PAGO';
COMMENT ON COLUMN pedidos.valor_pago IS 'Valor total já pago pelo cliente';
COMMENT ON COLUMN pedidos.valor_pendente IS 'Valor ainda pendente de pagamento';
COMMENT ON COLUMN pedidos.data_pagamento_completo IS 'Data em que o pagamento foi quitado completamente';
COMMENT ON TABLE pagamentos IS 'Histórico de pagamentos recebidos dos pedidos';
