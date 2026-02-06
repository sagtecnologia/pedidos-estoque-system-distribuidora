-- =====================================================
-- MIGRAÇÃO: Proteger contra duração de venda em comanda
-- Descrição: Implementar constraint para garantir que cada comanda tem no máximo uma venda
-- Data: 06/02/2026
-- =====================================================

-- PROBLEMA:
-- Uma mesma comanda pode ser finalizada múltiplas vezes, gerando múltiplas vendas
-- Isso acontece se houver erro na primeira tentativa e o usuário clicar em "Confirmar" novamente

-- SOLUÇÃO:
-- 1. Validação no código: só atualizar comanda se venda_id for null
-- 2. Validação no banco: criar constraint que impede venda_id duplicado para comanda_id

-- Criar índice único para garantir 1 venda por comanda (quando venda_id não é null)
-- Isso funciona porque NULL != NULL no SQL, permitindo múltiplas colunas NULL
CREATE UNIQUE INDEX IF NOT EXISTS idx_comandas_venda_id_unica
ON comandas(venda_id)
WHERE venda_id IS NOT NULL;

-- Comentário explicativo
COMMENT ON INDEX idx_comandas_venda_id_unica IS 
'Garante que cada venda está ligada a no máximo uma comanda. O índice ignora linhas com venda_id NULL.';

-- =====================================================
-- FIM DA MIGRAÇÃO
-- =====================================================

-- TESTE:
-- 1. Tentar finalizar comanda e gerar venda A
-- 2. Tentar finalizar mesma comanda novamente
-- ❌ Deve falhar com erro: "duplicate key value violates unique constraint"
-- Isso é intencional! Protege contra duplicação acidental.
