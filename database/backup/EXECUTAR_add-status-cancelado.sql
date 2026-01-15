-- CORREÇÃO: Adicionar status CANCELADO na constraint de pedidos
-- Execute este SQL no Supabase

-- Remover a constraint antiga
ALTER TABLE pedidos 
    DROP CONSTRAINT IF EXISTS pedidos_status_check;

-- Adicionar a constraint com o status CANCELADO incluído
ALTER TABLE pedidos 
    ADD CONSTRAINT pedidos_status_check 
    CHECK (status IN ('RASCUNHO', 'ENVIADO', 'APROVADO', 'REJEITADO', 'FINALIZADO', 'CANCELADO'));

SELECT 'Status CANCELADO adicionado com sucesso!' as resultado;
