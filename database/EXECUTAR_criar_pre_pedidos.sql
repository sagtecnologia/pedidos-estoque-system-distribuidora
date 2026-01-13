-- =====================================================
-- SISTEMA DE PRÉ-PEDIDOS PÚBLICOS
-- Criado em: 13/01/2026
-- =====================================================

-- =====================================================
-- 1. CRIAR TABELA DE PRÉ-PEDIDOS
-- =====================================================

CREATE TABLE IF NOT EXISTS pre_pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(50) UNIQUE NOT NULL,
    nome_solicitante VARCHAR(255) NOT NULL,
    email_contato VARCHAR(255),
    telefone_contato VARCHAR(50),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDENTE' 
      CHECK (status IN ('PENDENTE', 'EM_ANALISE', 'APROVADO', 'REJEITADO', 'EXPIRADO')),
    total DECIMAL(10,2) DEFAULT 0,
    observacoes TEXT,
    token_publico VARCHAR(100) UNIQUE NOT NULL,
    ip_origem VARCHAR(50),
    user_agent TEXT,
    data_expiracao TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Campos de processamento interno
    analisado_por UUID REFERENCES users(id),
    data_analise TIMESTAMP WITH TIME ZONE,
    cliente_vinculado_id UUID REFERENCES clientes(id),
    pedido_gerado_id UUID REFERENCES pedidos(id),
    motivo_rejeicao TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para performance
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_status ON pre_pedidos(status);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_token ON pre_pedidos(token_publico);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_expiracao ON pre_pedidos(data_expiracao);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_created ON pre_pedidos(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pre_pedidos_numero ON pre_pedidos(numero);

-- =====================================================
-- 2. CRIAR TABELA DE ITENS DE PRÉ-PEDIDO
-- =====================================================

CREATE TABLE IF NOT EXISTS pre_pedido_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pre_pedido_id UUID REFERENCES pre_pedidos(id) ON DELETE CASCADE NOT NULL,
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    sabor_id UUID REFERENCES produto_sabores(id),
    quantidade DECIMAL(10,2) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    estoque_disponivel_momento DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_pre_pedido_itens_pre_pedido ON pre_pedido_itens(pre_pedido_id);
CREATE INDEX IF NOT EXISTS idx_pre_pedido_itens_produto ON pre_pedido_itens(produto_id);
CREATE INDEX IF NOT EXISTS idx_pre_pedido_itens_sabor ON pre_pedido_itens(sabor_id);

-- =====================================================
-- 3. CRIAR VIEWS PARA CATÁLOGO PÚBLICO
-- =====================================================

-- View de produtos públicos
CREATE OR REPLACE VIEW vw_produtos_publicos AS
SELECT 
    p.id,
    p.codigo,
    p.marca,
    p.nome,
    p.unidade,
    p.preco_venda,
    p.estoque_atual,
    p.estoque_minimo,
    CASE 
        WHEN p.estoque_atual = 0 THEN 'ZERADO'
        WHEN p.estoque_atual <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produtos p
WHERE p.active = true
  AND p.estoque_atual > 0
ORDER BY p.marca, p.nome;

-- View de sabores públicos
CREATE OR REPLACE VIEW vw_sabores_publicos AS
SELECT 
    s.id,
    s.produto_id,
    s.sabor,
    s.quantidade,
    p.preco_venda,
    p.estoque_minimo,
    p.marca,
    p.nome as produto_nome,
    p.codigo as produto_codigo,
    CASE 
        WHEN s.quantidade = 0 THEN 'ZERADO'
        WHEN s.quantidade <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produto_sabores s
INNER JOIN produtos p ON p.id = s.produto_id
WHERE s.ativo = true
  AND p.active = true
  AND s.quantidade > 0
ORDER BY p.marca, p.nome, s.sabor;

-- =====================================================
-- 4. FUNÇÃO PARA EXPIRAR PRÉ-PEDIDOS
-- =====================================================

CREATE OR REPLACE FUNCTION expirar_pre_pedidos()
RETURNS INTEGER AS $$
DECLARE
    quantidade_expirados INTEGER;
BEGIN
    UPDATE pre_pedidos
    SET status = 'EXPIRADO',
        updated_at = NOW()
    WHERE status IN ('PENDENTE', 'EM_ANALISE')
      AND data_expiracao < NOW();
    
    GET DIAGNOSTICS quantidade_expirados = ROW_COUNT;
    RETURN quantidade_expirados;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 5. FUNÇÃO PARA GERAR NÚMERO DE PRÉ-PEDIDO
-- =====================================================

CREATE OR REPLACE FUNCTION gerar_numero_pre_pedido()
RETURNS TRIGGER AS $$
DECLARE
    ano_atual TEXT;
    proximo_numero INTEGER;
    novo_numero TEXT;
BEGIN
    -- Obter ano atual
    ano_atual := TO_CHAR(NOW(), 'YYYY');
    
    -- Obter próximo número
    SELECT COALESCE(MAX(
        CAST(
            SUBSTRING(numero FROM 'PRE-' || ano_atual || '-(\d+)')
            AS INTEGER
        )
    ), 0) + 1
    INTO proximo_numero
    FROM pre_pedidos
    WHERE numero LIKE 'PRE-' || ano_atual || '-%';
    
    -- Gerar número formatado
    novo_numero := 'PRE-' || ano_atual || '-' || LPAD(proximo_numero::TEXT, 4, '0');
    
    NEW.numero := novo_numero;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger
DROP TRIGGER IF EXISTS trigger_gerar_numero_pre_pedido ON pre_pedidos;
CREATE TRIGGER trigger_gerar_numero_pre_pedido
    BEFORE INSERT ON pre_pedidos
    FOR EACH ROW
    WHEN (NEW.numero IS NULL OR NEW.numero = '')
    EXECUTE FUNCTION gerar_numero_pre_pedido();

-- =====================================================
-- 6. CONFIGURAR POLÍTICAS RLS
-- =====================================================

-- Habilitar RLS
ALTER TABLE pre_pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_pedido_itens ENABLE ROW LEVEL SECURITY;

-- Políticas para pre_pedidos

-- Usuários autenticados podem ver todos
DROP POLICY IF EXISTS "Usuários internos veem todos pre_pedidos" ON pre_pedidos;
CREATE POLICY "Usuários internos veem todos pre_pedidos"
ON pre_pedidos FOR SELECT
TO authenticated
USING (true);

-- Usuários autenticados podem atualizar
DROP POLICY IF EXISTS "Usuários internos atualizam pre_pedidos" ON pre_pedidos;
CREATE POLICY "Usuários internos atualizam pre_pedidos"
ON pre_pedidos FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Acesso público para inserção (anônimo)
DROP POLICY IF EXISTS "Criação pública de pre_pedidos" ON pre_pedidos;
CREATE POLICY "Criação pública de pre_pedidos"
ON pre_pedidos FOR INSERT
TO anon
WITH CHECK (true);

-- Acesso público para leitura via token
DROP POLICY IF EXISTS "Leitura pública via token" ON pre_pedidos;
CREATE POLICY "Leitura pública via token"
ON pre_pedidos FOR SELECT
TO anon
USING (true);

-- Políticas para pre_pedido_itens

-- Usuários autenticados podem ver todos itens
DROP POLICY IF EXISTS "Usuários internos veem itens" ON pre_pedido_itens;
CREATE POLICY "Usuários internos veem itens"
ON pre_pedido_itens FOR SELECT
TO authenticated
USING (true);

-- Acesso público para inserção
DROP POLICY IF EXISTS "Inserção pública de itens" ON pre_pedido_itens;
CREATE POLICY "Inserção pública de itens"
ON pre_pedido_itens FOR INSERT
TO anon
WITH CHECK (true);

-- Acesso público para leitura
DROP POLICY IF EXISTS "Leitura pública de itens" ON pre_pedido_itens;
CREATE POLICY "Leitura pública de itens"
ON pre_pedido_itens FOR SELECT
TO anon
USING (true);

-- =====================================================
-- 7. TRIGGER PARA ATUALIZAR updated_at
-- =====================================================

CREATE OR REPLACE FUNCTION update_pre_pedidos_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_pre_pedidos_updated_at ON pre_pedidos;
CREATE TRIGGER trigger_update_pre_pedidos_updated_at
    BEFORE UPDATE ON pre_pedidos
    FOR EACH ROW
    EXECUTE FUNCTION update_pre_pedidos_updated_at();

-- =====================================================
-- 8. VERIFICAÇÃO E RESULTADO
-- =====================================================

SELECT 
    '✅ Sistema de Pré-Pedidos criado com sucesso!' as status,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'pre_pedidos') as tabela_pre_pedidos,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_name = 'pre_pedido_itens') as tabela_itens,
    (SELECT COUNT(*) FROM information_schema.views WHERE table_name = 'vw_produtos_publicos') as view_produtos,
    (SELECT COUNT(*) FROM information_schema.views WHERE table_name = 'vw_sabores_publicos') as view_sabores,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'expirar_pre_pedidos') as funcao_expirar,
    (SELECT COUNT(*) FROM information_schema.routines WHERE routine_name = 'gerar_numero_pre_pedido') as funcao_numero;

-- Testar geração de número
DO $$
DECLARE
    teste_id UUID;
BEGIN
    INSERT INTO pre_pedidos (nome_solicitante, token_publico, data_expiracao)
    VALUES ('Teste Sistema', 'TOKEN_TESTE_' || FLOOR(RANDOM() * 999999), NOW() + INTERVAL '24 hours')
    RETURNING id INTO teste_id;
    
    RAISE NOTICE 'Número gerado: %', (SELECT numero FROM pre_pedidos WHERE id = teste_id);
    
    -- Limpar teste
    DELETE FROM pre_pedidos WHERE id = teste_id;
END $$;
