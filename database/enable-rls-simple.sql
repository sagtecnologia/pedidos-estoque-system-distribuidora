-- =====================================================
-- HABILITAR RLS COM POLÍTICAS SIMPLES
-- Execute APÓS criar o primeiro usuário e torná-lo ADMIN
-- =====================================================

-- PASSO 1: HABILITAR RLS novamente
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE fornecedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE estoque_movimentacoes ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- POLÍTICAS USERS - SIMPLES E SEM RECURSÃO
-- =====================================================

-- SELECT: Todos usuários autenticados podem ver todos os usuários
CREATE POLICY "users_select"
    ON users FOR SELECT
    TO authenticated
    USING (true);

-- INSERT: Qualquer pessoa autenticada pode inserir (necessário para cadastro)
CREATE POLICY "users_insert"
    ON users FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id);

-- UPDATE: Todos podem atualizar (vamos simplificar por enquanto)
CREATE POLICY "users_update"
    ON users FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- DELETE: Apenas service_role pode deletar (mais seguro)
CREATE POLICY "users_delete"
    ON users FOR DELETE
    TO service_role
    USING (true);

-- =====================================================
-- POLÍTICAS PRODUTOS
-- =====================================================

-- SELECT: Todos podem ver produtos
CREATE POLICY "produtos_select"
    ON produtos FOR SELECT
    TO authenticated
    USING (true);

-- INSERT: Todos podem criar
CREATE POLICY "produtos_insert"
    ON produtos FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- UPDATE: Todos podem atualizar
CREATE POLICY "produtos_update"
    ON produtos FOR UPDATE
    TO authenticated
    USING (true);

-- DELETE: Todos podem deletar
CREATE POLICY "produtos_delete"
    ON produtos FOR DELETE
    TO authenticated
    USING (true);

-- =====================================================
-- POLÍTICAS FORNECEDORES
-- =====================================================

CREATE POLICY "fornecedores_select"
    ON fornecedores FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "fornecedores_insert"
    ON fornecedores FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "fornecedores_update"
    ON fornecedores FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "fornecedores_delete"
    ON fornecedores FOR DELETE
    TO authenticated
    USING (true);

-- =====================================================
-- POLÍTICAS PEDIDOS
-- =====================================================

CREATE POLICY "pedidos_select"
    ON pedidos FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "pedidos_insert"
    ON pedidos FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "pedidos_update"
    ON pedidos FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "pedidos_delete"
    ON pedidos FOR DELETE
    TO authenticated
    USING (true);

-- =====================================================
-- POLÍTICAS PEDIDO_ITENS
-- =====================================================

CREATE POLICY "pedido_itens_select"
    ON pedido_itens FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "pedido_itens_insert"
    ON pedido_itens FOR INSERT
    TO authenticated
    WITH CHECK (true);

CREATE POLICY "pedido_itens_update"
    ON pedido_itens FOR UPDATE
    TO authenticated
    USING (true);

CREATE POLICY "pedido_itens_delete"
    ON pedido_itens FOR DELETE
    TO authenticated
    USING (true);

-- =====================================================
-- POLÍTICAS ESTOQUE_MOVIMENTACOES
-- =====================================================

CREATE POLICY "estoque_movimentacoes_select"
    ON estoque_movimentacoes FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "estoque_movimentacoes_insert"
    ON estoque_movimentacoes FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Confirmação
SELECT 'RLS HABILITADO COM POLÍTICAS SIMPLES!' as status;
SELECT 'Agora você pode usar o sistema normalmente!' as resultado;
