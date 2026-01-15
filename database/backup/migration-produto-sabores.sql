-- =====================================================
-- MIGRAÇÃO: Sistema de Produtos com Sabores
-- Data: 2025-12-19
-- Descrição: Reestruturação para suportar marcas, produtos e sabores individuais
-- =====================================================

-- 1. Adicionar campo 'marca' na tabela produtos (usar categoria como marca)
ALTER TABLE produtos 
    ADD COLUMN IF NOT EXISTS marca VARCHAR(100);

-- Copiar categorias existentes para marca (se houver dados)
UPDATE produtos 
SET marca = categoria 
WHERE marca IS NULL AND categoria IS NOT NULL;

-- 2. Criar tabela de sabores dos produtos
CREATE TABLE IF NOT EXISTS produto_sabores (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    produto_id UUID REFERENCES produtos(id) ON DELETE CASCADE NOT NULL,
    sabor VARCHAR(100) NOT NULL,
    quantidade DECIMAL(10,2) DEFAULT 0,
    ativo BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraint para evitar sabores duplicados no mesmo produto
    UNIQUE(produto_id, sabor)
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_produto_sabores_produto ON produto_sabores(produto_id);
CREATE INDEX IF NOT EXISTS idx_produto_sabores_sabor ON produto_sabores(sabor);
CREATE INDEX IF NOT EXISTS idx_produto_sabores_ativo ON produto_sabores(ativo);
CREATE INDEX IF NOT EXISTS idx_produtos_marca ON produtos(marca);

-- 3. Modificar tabela pedido_itens para incluir sabor_id
ALTER TABLE pedido_itens 
    ADD COLUMN IF NOT EXISTS sabor_id UUID REFERENCES produto_sabores(id);

-- Índice para sabor_id
CREATE INDEX IF NOT EXISTS idx_pedido_itens_sabor ON pedido_itens(sabor_id);

-- 4. Modificar tabela estoque_movimentacoes para incluir sabor_id
ALTER TABLE estoque_movimentacoes 
    ADD COLUMN IF NOT EXISTS sabor_id UUID REFERENCES produto_sabores(id);

-- Índice para sabor_id
CREATE INDEX IF NOT EXISTS idx_estoque_mov_sabor ON estoque_movimentacoes(sabor_id);

-- 5. Trigger para atualizar updated_at em produto_sabores
DROP TRIGGER IF EXISTS update_produto_sabores_updated_at ON produto_sabores;
CREATE TRIGGER update_produto_sabores_updated_at
    BEFORE UPDATE ON produto_sabores
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- 6. Função para atualizar estoque do produto (soma de todos os sabores)
CREATE OR REPLACE FUNCTION atualizar_estoque_produto()
RETURNS TRIGGER AS $$
BEGIN
    -- Atualizar estoque_atual do produto somando todos os sabores ativos
    UPDATE produtos
    SET estoque_atual = (
        SELECT COALESCE(SUM(quantidade), 0)
        FROM produto_sabores
        WHERE produto_id = COALESCE(NEW.produto_id, OLD.produto_id)
        AND ativo = true
    )
    WHERE id = COALESCE(NEW.produto_id, OLD.produto_id);
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 7. Trigger para atualizar estoque do produto quando sabores mudarem
DROP TRIGGER IF EXISTS trigger_atualizar_estoque_produto ON produto_sabores;
CREATE TRIGGER trigger_atualizar_estoque_produto
    AFTER INSERT OR UPDATE OR DELETE ON produto_sabores
    FOR EACH ROW
    EXECUTE FUNCTION atualizar_estoque_produto();

-- =====================================================
-- POLÍTICAS RLS (Row Level Security)
-- =====================================================

-- Habilitar RLS
ALTER TABLE produto_sabores ENABLE ROW LEVEL SECURITY;

-- Policy: Usuários autenticados podem visualizar sabores ativos
DROP POLICY IF EXISTS "Usuários podem visualizar sabores ativos" ON produto_sabores;
CREATE POLICY "Usuários podem visualizar sabores ativos"
    ON produto_sabores FOR SELECT
    TO authenticated
    USING (ativo = true);

-- Policy: Usuários autenticados podem inserir sabores
DROP POLICY IF EXISTS "Usuários podem inserir sabores" ON produto_sabores;
CREATE POLICY "Usuários podem inserir sabores"
    ON produto_sabores FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Policy: Usuários autenticados podem atualizar sabores
DROP POLICY IF EXISTS "Usuários podem atualizar sabores" ON produto_sabores;
CREATE POLICY "Usuários podem atualizar sabores"
    ON produto_sabores FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Policy: Apenas admins podem deletar sabores
DROP POLICY IF EXISTS "Admins podem deletar sabores" ON produto_sabores;
CREATE POLICY "Admins podem deletar sabores"
    ON produto_sabores FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users
            WHERE id = auth.uid()
            AND role = 'ADMIN'
        )
    );

-- =====================================================
-- VIEWS ÚTEIS
-- =====================================================

-- View: Estoque detalhado por marca, produto e sabor
CREATE OR REPLACE VIEW vw_estoque_sabores AS
SELECT 
    p.id as produto_id,
    p.marca,
    p.nome as produto,
    p.codigo,
    ps.id as sabor_id,
    ps.sabor,
    ps.quantidade,
    p.estoque_minimo,
    p.preco_compra,
    p.preco_venda,
    CASE 
        WHEN ps.quantidade <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produtos p
LEFT JOIN produto_sabores ps ON p.id = ps.produto_id
WHERE p.active = true AND ps.ativo = true
ORDER BY p.marca, p.nome, ps.sabor;

-- =====================================================
-- DADOS EXEMPLO (OPCIONAL - COMENTADO)
-- =====================================================

/*
-- Exemplo: Criar marca IGNITE com produtos e sabores
INSERT INTO produtos (codigo, nome, marca, categoria, unidade, estoque_minimo, preco_compra, preco_venda, preco)
VALUES 
    ('IGN-V250', 'V250', 'IGNITE', 'IGNITE', 'UN', 5, 10.00, 15.00, 15.00),
    ('IGN-V500', 'V500', 'IGNITE', 'IGNITE', 'UN', 5, 12.00, 18.00, 18.00),
    ('IGN-V600', 'V600', 'IGNITE', 'IGNITE', 'UN', 5, 14.00, 20.00, 20.00);

-- Sabores para V250
INSERT INTO produto_sabores (produto_id, sabor, quantidade)
SELECT id, 'MELANCIA', 10 FROM produtos WHERE codigo = 'IGN-V250'
UNION ALL
SELECT id, 'MORANGO', 15 FROM produtos WHERE codigo = 'IGN-V250'
UNION ALL
SELECT id, 'ABACAXI', 8 FROM produtos WHERE codigo = 'IGN-V250';

-- Sabores para V500
INSERT INTO produto_sabores (produto_id, sabor, quantidade)
SELECT id, 'UVA', 12 FROM produtos WHERE codigo = 'IGN-V500'
UNION ALL
SELECT id, 'LIMAO', 10 FROM produtos WHERE codigo = 'IGN-V500';
*/

-- =====================================================
-- VERIFICAÇÕES
-- =====================================================

-- Verificar estrutura criada
SELECT 
    'produto_sabores' as tabela,
    COUNT(*) as total_registros
FROM produto_sabores
UNION ALL
SELECT 
    'produtos com marca',
    COUNT(*) 
FROM produtos 
WHERE marca IS NOT NULL;

-- Listar sabores cadastrados
SELECT * FROM vw_estoque_sabores;
