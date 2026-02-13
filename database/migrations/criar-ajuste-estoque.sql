-- Criar tabela de ajustes de estoque
CREATE TABLE IF NOT EXISTS public.ajuste_estoque (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    produto_id uuid NOT NULL REFERENCES public.produtos(id) ON DELETE CASCADE,
    quantidade_anterior numeric(10, 2) NOT NULL,
    quantidade_ajustada numeric(10, 2) NOT NULL,
    quantidade_diferenca numeric(10, 2) NOT NULL,  -- ajustada - anterior
    motivo varchar(255) NOT NULL,  -- "CORRECAO_INVENTARIO", "PERDA", "DANO", "ROUBO", "OUTRO"
    observacoes text,
    usuario_id uuid NOT NULL REFERENCES public.users(id),
    data_ajuste timestamptz DEFAULT now() NOT NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    updated_at timestamptz DEFAULT now() NOT NULL
);

-- Índices
CREATE INDEX idx_ajuste_estoque_produto ON public.ajuste_estoque(produto_id);
CREATE INDEX idx_ajuste_estoque_usuario ON public.ajuste_estoque(usuario_id);
CREATE INDEX idx_ajuste_estoque_data ON public.ajuste_estoque(data_ajuste);
CREATE INDEX idx_ajuste_estoque_motivo ON public.ajuste_estoque(motivo);

-- RLS
ALTER TABLE public.ajuste_estoque ENABLE ROW LEVEL SECURITY;

CREATE POLICY "ajuste_estoque_select_all" ON public.ajuste_estoque
    FOR SELECT TO authenticated USING (true);

CREATE POLICY "ajuste_estoque_insert_own" ON public.ajuste_estoque
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = usuario_id OR (SELECT role FROM users WHERE id = auth.uid()) IN ('ADMIN', 'GERENTE'));

CREATE POLICY "ajuste_estoque_update_own" ON public.ajuste_estoque
    FOR UPDATE TO authenticated 
    USING ((SELECT role FROM users WHERE id = auth.uid()) IN ('ADMIN', 'GERENTE'))
    WITH CHECK ((SELECT role FROM users WHERE id = auth.uid()) IN ('ADMIN', 'GERENTE'));

CREATE POLICY "ajuste_estoque_delete_own" ON public.ajuste_estoque
    FOR DELETE TO authenticated 
    USING ((SELECT role FROM users WHERE id = auth.uid()) IN ('ADMIN', 'GERENTE'));

-- Comentários
COMMENT ON TABLE public.ajuste_estoque IS 'Rastreamento de ajustes manuais de estoque para reprocessamento';
COMMENT ON COLUMN public.ajuste_estoque.quantidade_diferenca IS 'Sinal positivo = aumento, negativo = diminuição';

-- Permissões
GRANT INSERT, UPDATE, SELECT ON TABLE public.ajuste_estoque TO authenticated;
GRANT INSERT, UPDATE, SELECT ON TABLE public.ajuste_estoque TO anon;
