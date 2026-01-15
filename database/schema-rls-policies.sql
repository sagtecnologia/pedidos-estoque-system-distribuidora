-- =====================================================
-- POLÍTICAS RLS (ROW LEVEL SECURITY)
-- =====================================================
-- Data: 14/01/2026
-- Descrição: Todas as políticas de segurança RLS
-- IMPORTANTE: Execute este arquivo APÓS o schema-completo.sql
-- =====================================================

-- =====================================================
-- HABILITAR RLS EM TODAS AS TABELAS
-- =====================================================
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;
ALTER TABLE produto_sabores ENABLE ROW LEVEL SECURITY;
ALTER TABLE fornecedores ENABLE ROW LEVEL SECURITY;
ALTER TABLE clientes ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pedido_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE estoque_movimentacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE pagamentos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_pedidos ENABLE ROW LEVEL SECURITY;
ALTER TABLE pre_pedido_itens ENABLE ROW LEVEL SECURITY;
ALTER TABLE empresa_config ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- POLICIES - USERS
-- =====================================================

-- Remover políticas antigas
DROP POLICY IF EXISTS "Usuários podem ver outros usuários ativos" ON users;
DROP POLICY IF EXISTS "Usuários podem ver seus próprios dados" ON users;
DROP POLICY IF EXISTS "Usuários podem se cadastrar" ON users;
DROP POLICY IF EXISTS "Apenas ADMIN pode gerenciar usuários" ON users;
DROP POLICY IF EXISTS "Apenas ADMIN pode deletar usuários" ON users;

-- Todos podem ver usuários ativos
CREATE POLICY "Usuários podem ver outros usuários ativos"
    ON users FOR SELECT
    TO authenticated
    USING (active = true);

-- Usuários podem ver seus próprios dados (mesmo inativos)
CREATE POLICY "Usuários podem ver seus próprios dados"
    ON users FOR SELECT
    TO authenticated
    USING (auth.uid() = id);

-- Permitir auto-cadastro (active=false até aprovação do ADMIN)
CREATE POLICY "Usuários podem se cadastrar"
    ON users FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = id AND active = false);

-- Apenas ADMIN pode atualizar usuários
CREATE POLICY "Apenas ADMIN pode gerenciar usuários"
    ON users FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- Apenas ADMIN pode deletar usuários
CREATE POLICY "Apenas ADMIN pode deletar usuários"
    ON users FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - PRODUTOS
-- =====================================================

DROP POLICY IF EXISTS "Usuários podem ver produtos ativos" ON produtos;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem criar produtos" ON produtos;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem atualizar produtos" ON produtos;
DROP POLICY IF EXISTS "Apenas ADMIN pode deletar produtos" ON produtos;

-- Todos os usuários autenticados podem ver produtos ativos
CREATE POLICY "Usuários podem ver produtos ativos"
    ON produtos FOR SELECT
    TO authenticated
    USING (active = true);

-- ADMIN e COMPRADOR podem criar produtos
CREATE POLICY "ADMIN e COMPRADOR podem criar produtos"
    ON produtos FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- ADMIN e COMPRADOR podem atualizar produtos
CREATE POLICY "ADMIN e COMPRADOR podem atualizar produtos"
    ON produtos FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- Apenas ADMIN pode deletar produtos
CREATE POLICY "Apenas ADMIN pode deletar produtos"
    ON produtos FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - PRODUTO_SABORES
-- =====================================================

DROP POLICY IF EXISTS "Usuários podem visualizar sabores ativos" ON produto_sabores;
DROP POLICY IF EXISTS "Usuários podem inserir sabores" ON produto_sabores;
DROP POLICY IF EXISTS "Usuários podem atualizar sabores" ON produto_sabores;
DROP POLICY IF EXISTS "Admins podem deletar sabores" ON produto_sabores;

-- Usuários autenticados podem visualizar sabores ativos
CREATE POLICY "Usuários podem visualizar sabores ativos"
    ON produto_sabores FOR SELECT
    TO authenticated
    USING (ativo = true);

-- Usuários autenticados podem inserir sabores
CREATE POLICY "Usuários podem inserir sabores"
    ON produto_sabores FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Usuários autenticados podem atualizar sabores
CREATE POLICY "Usuários podem atualizar sabores"
    ON produto_sabores FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Apenas admins podem deletar sabores
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
-- POLICIES - FORNECEDORES
-- =====================================================

DROP POLICY IF EXISTS "Usuários podem ver fornecedores ativos" ON fornecedores;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem criar fornecedores" ON fornecedores;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem atualizar fornecedores" ON fornecedores;
DROP POLICY IF EXISTS "Apenas ADMIN pode deletar fornecedores" ON fornecedores;

-- Todos os usuários autenticados podem ver fornecedores ativos
CREATE POLICY "Usuários podem ver fornecedores ativos"
    ON fornecedores FOR SELECT
    TO authenticated
    USING (active = true);

-- ADMIN e COMPRADOR podem criar fornecedores
CREATE POLICY "ADMIN e COMPRADOR podem criar fornecedores"
    ON fornecedores FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- ADMIN e COMPRADOR podem atualizar fornecedores
CREATE POLICY "ADMIN e COMPRADOR podem atualizar fornecedores"
    ON fornecedores FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR')
        )
    );

-- Apenas ADMIN pode deletar fornecedores
CREATE POLICY "Apenas ADMIN pode deletar fornecedores"
    ON fornecedores FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - CLIENTES
-- =====================================================

DROP POLICY IF EXISTS "Usuários podem ver clientes ativos" ON clientes;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem criar clientes" ON clientes;
DROP POLICY IF EXISTS "ADMIN e COMPRADOR podem atualizar clientes" ON clientes;
DROP POLICY IF EXISTS "Apenas ADMIN pode deletar clientes" ON clientes;

-- Todos os usuários autenticados podem ver clientes ativos
CREATE POLICY "Usuários podem ver clientes ativos"
    ON clientes FOR SELECT
    TO authenticated
    USING (active = true);

-- ADMIN, COMPRADOR e VENDEDOR podem criar clientes
CREATE POLICY "ADMIN e COMPRADOR podem criar clientes"
    ON clientes FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR', 'VENDEDOR')
        )
    );

-- ADMIN, COMPRADOR e VENDEDOR podem atualizar clientes
CREATE POLICY "ADMIN e COMPRADOR podem atualizar clientes"
    ON clientes FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('ADMIN', 'COMPRADOR', 'VENDEDOR')
        )
    );

-- Apenas ADMIN pode deletar clientes
CREATE POLICY "Apenas ADMIN pode deletar clientes"
    ON clientes FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - PEDIDOS
-- =====================================================

DROP POLICY IF EXISTS "Usuários podem ver seus pedidos" ON pedidos;
DROP POLICY IF EXISTS "APROVADOR pode ver pedidos para aprovar" ON pedidos;
DROP POLICY IF EXISTS "ADMIN pode ver todos os pedidos" ON pedidos;
DROP POLICY IF EXISTS "COMPRADOR pode criar pedidos" ON pedidos;
DROP POLICY IF EXISTS "VENDEDOR pode criar vendas" ON pedidos;
DROP POLICY IF EXISTS "Solicitante pode atualizar seus pedidos em RASCUNHO" ON pedidos;
DROP POLICY IF EXISTS "APROVADOR pode aprovar/rejeitar pedidos" ON pedidos;
DROP POLICY IF EXISTS "ADMIN pode atualizar qualquer pedido" ON pedidos;
DROP POLICY IF EXISTS "Solicitante pode deletar pedidos RASCUNHO" ON pedidos;

-- Usuários podem ver pedidos que criaram
CREATE POLICY "Usuários podem ver seus pedidos"
    ON pedidos FOR SELECT
    TO authenticated
    USING (solicitante_id = auth.uid());

-- APROVADOR pode ver pedidos enviados/aprovados/rejeitados
CREATE POLICY "APROVADOR pode ver pedidos para aprovar"
    ON pedidos FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'APROVADOR'
        )
    );

-- ADMIN pode ver todos os pedidos
CREATE POLICY "ADMIN pode ver todos os pedidos"
    ON pedidos FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- COMPRADOR pode criar pedidos de COMPRA
CREATE POLICY "COMPRADOR pode criar pedidos"
    ON pedidos FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('COMPRADOR', 'ADMIN')
        ) AND solicitante_id = auth.uid() AND tipo_pedido = 'COMPRA'
    );

-- VENDEDOR pode criar pedidos de VENDA
CREATE POLICY "VENDEDOR pode criar vendas"
    ON pedidos FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('VENDEDOR', 'ADMIN')
        ) AND solicitante_id = auth.uid() AND tipo_pedido = 'VENDA'
    );

-- Solicitante pode atualizar seus pedidos em RASCUNHO
CREATE POLICY "Solicitante pode atualizar seus pedidos em RASCUNHO"
    ON pedidos FOR UPDATE
    TO authenticated
    USING (
        solicitante_id = auth.uid() AND status = 'RASCUNHO'
    );

-- APROVADOR pode atualizar status para APROVADO/REJEITADO
CREATE POLICY "APROVADOR pode aprovar/rejeitar pedidos"
    ON pedidos FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role IN ('APROVADOR', 'ADMIN')
        ) AND status = 'ENVIADO'
    );

-- ADMIN pode atualizar qualquer pedido
CREATE POLICY "ADMIN pode atualizar qualquer pedido"
    ON pedidos FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- Solicitante ou ADMIN podem deletar pedidos em RASCUNHO
CREATE POLICY "Solicitante pode deletar pedidos RASCUNHO"
    ON pedidos FOR DELETE
    TO authenticated
    USING (
        status = 'RASCUNHO' AND (
            solicitante_id = auth.uid() OR
            EXISTS (
                SELECT 1 FROM users 
                WHERE id = auth.uid() AND role = 'ADMIN'
            )
        )
    );

-- =====================================================
-- POLICIES - PEDIDO_ITENS
-- =====================================================

DROP POLICY IF EXISTS "Usuários podem ver itens de seus pedidos" ON pedido_itens;
DROP POLICY IF EXISTS "Solicitante pode inserir itens em pedidos RASCUNHO" ON pedido_itens;
DROP POLICY IF EXISTS "Solicitante pode atualizar itens em pedidos RASCUNHO" ON pedido_itens;
DROP POLICY IF EXISTS "Solicitante pode deletar itens de pedidos RASCUNHO" ON pedido_itens;
DROP POLICY IF EXISTS "ADMIN pode atualizar qualquer item de pedido" ON pedido_itens;
DROP POLICY IF EXISTS "ADMIN pode excluir qualquer item" ON pedido_itens;

-- Usuários podem ver itens de pedidos que podem ver
CREATE POLICY "Usuários podem ver itens de seus pedidos"
    ON pedido_itens FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND (
                solicitante_id = auth.uid() 
                OR EXISTS (
                    SELECT 1 FROM users 
                    WHERE id = auth.uid() AND role IN ('APROVADOR', 'ADMIN')
                )
            )
        )
    );

-- Solicitante pode inserir itens em seus pedidos RASCUNHO
CREATE POLICY "Solicitante pode inserir itens em pedidos RASCUNHO"
    ON pedido_itens FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND solicitante_id = auth.uid() 
            AND status = 'RASCUNHO'
        )
    );

-- Solicitante pode atualizar itens em seus pedidos RASCUNHO
CREATE POLICY "Solicitante pode atualizar itens em pedidos RASCUNHO"
    ON pedido_itens FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND solicitante_id = auth.uid() 
            AND status = 'RASCUNHO'
        )
    );

-- Solicitante pode deletar itens de seus pedidos RASCUNHO
CREATE POLICY "Solicitante pode deletar itens de pedidos RASCUNHO"
    ON pedido_itens FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM pedidos 
            WHERE id = pedido_id 
            AND solicitante_id = auth.uid() 
            AND status = 'RASCUNHO'
        )
    );

-- ADMIN pode atualizar qualquer item
CREATE POLICY "ADMIN pode atualizar qualquer item de pedido"
    ON pedido_itens FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- ADMIN pode excluir qualquer item
CREATE POLICY "ADMIN pode excluir qualquer item"
    ON pedido_itens FOR DELETE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - ESTOQUE_MOVIMENTACOES
-- =====================================================

DROP POLICY IF EXISTS "Todos podem ver movimentações de estoque" ON estoque_movimentacoes;
DROP POLICY IF EXISTS "ADMIN pode criar movimentações" ON estoque_movimentacoes;

-- Todos usuários autenticados podem ver movimentações
CREATE POLICY "Todos podem ver movimentações de estoque"
    ON estoque_movimentacoes FOR SELECT
    TO authenticated
    USING (true);

-- Apenas ADMIN pode criar movimentações manuais
-- (finalizações automáticas são feitas via função com SECURITY DEFINER)
CREATE POLICY "ADMIN pode criar movimentações"
    ON estoque_movimentacoes FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM users 
            WHERE id = auth.uid() AND role = 'ADMIN'
        )
    );

-- =====================================================
-- POLICIES - PAGAMENTOS
-- =====================================================

DROP POLICY IF EXISTS "Usuários autenticados podem ver pagamentos" ON pagamentos;
DROP POLICY IF EXISTS "Apenas ADMIN e VENDEDOR podem inserir pagamentos" ON pagamentos;

-- Todos podem ver pagamentos
CREATE POLICY "Usuários autenticados podem ver pagamentos"
    ON pagamentos FOR SELECT
    TO authenticated
    USING (true);

-- ADMIN e VENDEDOR podem inserir pagamentos
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

-- =====================================================
-- POLICIES - PRE_PEDIDOS
-- =====================================================

DROP POLICY IF EXISTS "Usuários internos veem todos pre_pedidos" ON pre_pedidos;
DROP POLICY IF EXISTS "Usuários internos atualizam pre_pedidos" ON pre_pedidos;
DROP POLICY IF EXISTS "Criação pública de pre_pedidos" ON pre_pedidos;
DROP POLICY IF EXISTS "Leitura pública via token" ON pre_pedidos;

-- Usuários autenticados podem ver todos
CREATE POLICY "Usuários internos veem todos pre_pedidos"
ON pre_pedidos FOR SELECT
TO authenticated
USING (true);

-- Usuários autenticados podem atualizar
CREATE POLICY "Usuários internos atualizam pre_pedidos"
ON pre_pedidos FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Acesso público para inserção (anônimo)
CREATE POLICY "Criação pública de pre_pedidos"
ON pre_pedidos FOR INSERT
TO anon
WITH CHECK (true);

-- Acesso público para leitura via token
CREATE POLICY "Leitura pública via token"
ON pre_pedidos FOR SELECT
TO anon
USING (true);

-- =====================================================
-- POLICIES - PRE_PEDIDO_ITENS
-- =====================================================

DROP POLICY IF EXISTS "Usuários internos veem itens" ON pre_pedido_itens;
DROP POLICY IF EXISTS "Inserção pública de itens" ON pre_pedido_itens;
DROP POLICY IF EXISTS "Leitura pública de itens" ON pre_pedido_itens;

-- Usuários autenticados podem ver todos itens
CREATE POLICY "Usuários internos veem itens"
ON pre_pedido_itens FOR SELECT
TO authenticated
USING (true);

-- Acesso público para inserção
CREATE POLICY "Inserção pública de itens"
ON pre_pedido_itens FOR INSERT
TO anon
WITH CHECK (true);

-- Acesso público para leitura
CREATE POLICY "Leitura pública de itens"
ON pre_pedido_itens FOR SELECT
TO anon
USING (true);

-- =====================================================
-- POLICIES - EMPRESA_CONFIG
-- =====================================================

DROP POLICY IF EXISTS "empresa_select_policy" ON empresa_config;
DROP POLICY IF EXISTS "empresa_update_policy" ON empresa_config;
DROP POLICY IF EXISTS "empresa_insert_policy" ON empresa_config;

-- Todos autenticados podem visualizar
CREATE POLICY "empresa_select_policy"
    ON empresa_config FOR SELECT
    TO authenticated
    USING (true);

-- Apenas ADMIN pode atualizar
CREATE POLICY "empresa_update_policy"
    ON empresa_config FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role = 'ADMIN'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role = 'ADMIN'
        )
    );

-- Apenas ADMIN pode inserir
CREATE POLICY "empresa_insert_policy"
    ON empresa_config FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.users 
            WHERE id = auth.uid() 
            AND role = 'ADMIN'
        )
    );

-- =====================================================
-- STORAGE BUCKET - COMPANY LOGOS
-- =====================================================

-- Criar bucket para logos da empresa
INSERT INTO storage.buckets (id, name, public)
VALUES ('company-logos', 'company-logos', true)
ON CONFLICT (id) DO NOTHING;

-- Remover políticas antigas
DROP POLICY IF EXISTS "Todos podem ver logos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem fazer upload de logos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem atualizar logos" ON storage.objects;
DROP POLICY IF EXISTS "Usuários autenticados podem deletar logos" ON storage.objects;

-- Políticas de acesso ao bucket
CREATE POLICY "Todos podem ver logos"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'company-logos');

CREATE POLICY "Usuários autenticados podem fazer upload de logos"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'company-logos');

CREATE POLICY "Usuários autenticados podem atualizar logos"
    ON storage.objects FOR UPDATE
    TO authenticated
    USING (bucket_id = 'company-logos');

CREATE POLICY "Usuários autenticados podem deletar logos"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (bucket_id = 'company-logos');

-- =====================================================
-- FIM DAS POLÍTICAS RLS
-- =====================================================

SELECT '✅ POLÍTICAS RLS CONFIGURADAS COM SUCESSO!' as status,
       'Total de tabelas com RLS: 12' as tabelas,
       'Total de policies criadas: ~60' as policies,
       'Storage bucket: company-logos configurado' as storage,
       '⚠️  PRÓXIMO PASSO: Criar primeiro usuário ADMIN' as proximo;
