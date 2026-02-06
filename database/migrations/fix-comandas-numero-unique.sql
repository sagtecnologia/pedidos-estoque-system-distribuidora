-- =====================================================
-- MIGRAÇÃO: Permitir Reutilizar Números de Mesa/Comanda
-- Descrição: Permite criar novas comandas com números já usados (desde que a anterior esteja fechada/cancelada)
-- Data: 06/02/2026
-- =====================================================

-- PROBLEMA: 
-- A constraint UNIQUE em numero_comanda impede reutilizar números de mesa
-- Exemplo: Mesa 3 foi fechada, mas não consigo abrir nova comanda "Mesa 3"

-- SOLUÇÃO:
-- Usar UNIQUE INDEX parcial que só aplica unicidade para comandas ABERTAS
-- Permite múltiplas comandas fechadas/canceladas com mesmo número

-- 1. Remover constraint UNIQUE existente
ALTER TABLE comandas DROP CONSTRAINT IF EXISTS comandas_numero_comanda_key;

-- 2. Criar índice UNIQUE parcial apenas para comandas abertas
-- Isso permite: Mesa 3 fechada + Mesa 3 aberta (OK)
-- Mas impede: Mesa 3 aberta + Mesa 3 aberta (ERRO)
CREATE UNIQUE INDEX IF NOT EXISTS comandas_numero_comanda_aberta_unique
ON comandas(numero_comanda)
WHERE status = 'aberta';

-- 3. Manter índice normal para performance de buscas
CREATE INDEX IF NOT EXISTS idx_comandas_numero_comanda 
ON comandas(numero_comanda);

-- =====================================================
-- FIM DA MIGRAÇÃO
-- =====================================================

-- TESTE:
-- 1. Fechar uma comanda: UPDATE comandas SET status = 'fechada' WHERE numero_comanda = 'MESA 1';
-- 2. Criar nova com mesmo número: INSERT INTO comandas (numero_comanda, tipo, status) VALUES ('MESA 1', 'mesa', 'aberta');
-- ✅ Deve funcionar!
--
-- 3. Tentar criar outra aberta com mesmo número:
-- INSERT INTO comandas (numero_comanda, tipo, status) VALUES ('MESA 1', 'mesa', 'aberta');
-- ❌ Deve dar erro (esperado)
