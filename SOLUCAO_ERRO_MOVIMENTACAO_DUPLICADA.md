# 🔧 SOLUÇÃO: Erro ao Finalizar Venda

## ❌ Problema

**Erro:** "Já existe movimentação para o produto IGN-0010 no pedido especificado"

**Venda:** VENDA-20260114-00005

## 🔍 Causa

Este erro ocorre quando uma venda está com status **RASCUNHO** mas já possui **movimentações de estoque** registradas no banco de dados.

### Situações que causam isso:

1. **Venda finalizada e reaberta**: A venda foi finalizada (criando movimentações), depois foi reaberta como RASCUNHO, mas as movimentações antigas não foram removidas
2. **Erro durante finalização**: O processo de finalização foi interrompido no meio, deixando movimentações "órfãs"
3. **Clique duplo**: Usuário clicou duas vezes em "Finalizar" rapidamente
4. **Problemas de rede**: Retry automático criou movimentações duplicadas

## 🛡️ Proteção do Sistema

O sistema tem uma proteção no banco de dados (arquivo `EXECUTAR_protecao_duplicacao_movimentacoes.sql`) que:

- Verifica se já existe movimentação para cada produto antes de criar uma nova
- Impede duplicações de movimentações
- Lança erro se detectar tentativa de duplicação

**Código da proteção:**
```sql
-- Verifica se movimentação já existe
v_mov_existente := verificar_movimentacao_existente(
    p_pedido_id, 
    v_item.produto_id, 
    v_item.sabor_id
);

IF v_mov_existente THEN
    RAISE EXCEPTION 'Já existe movimentação para o produto % no pedido especificado', 
        v_item.produto_codigo;
END IF;
```

## ✅ Soluções

### 📋 Passo 1: Diagnosticar o Problema

Execute o arquivo SQL criado:
```
database/SOLUCAO_venda_com_movimentacao_duplicada.sql
```

Este arquivo vai mostrar:
- Status atual da venda
- Movimentações existentes
- Se há duplicações

### 🔧 Passo 2: Escolher a Solução

O arquivo SQL oferece **3 soluções**:

#### **Solução 1: Limpar e Refinalizar** (Recomendada)

**Quando usar:** Quando você quer começar do zero

**O que faz:**
- Deleta todas as movimentações da venda
- Mantém a venda como RASCUNHO
- Permite finalizar novamente pela interface

**Passos:**
1. Abra o SQL no Supabase
2. Descomente o bloco da Solução 1
3. Execute o SQL
4. Execute `COMMIT;`
5. Vá na interface e finalize a venda normalmente

---

#### **Solução 2: Reverter Estoque** (Se já afetou o estoque)

**Quando usar:** Quando as movimentações já alteraram o estoque e você precisa desfazer

**O que faz:**
- Reverte as saídas de estoque (devolve as quantidades)
- Deleta as movimentações
- Permite finalizar novamente

**Passos:**
1. Abra o SQL no Supabase
2. Descomente o bloco da Solução 2
3. Execute o SQL
4. Execute `COMMIT;`
5. Vá na interface e finalize a venda normalmente

---

#### **Solução 3: Marcar como Finalizada** (Se movimentações estão corretas)

**Quando usar:** Quando as movimentações estão corretas mas o status está errado

**O que faz:**
- Muda o status da venda para FINALIZADO
- Mantém as movimentações existentes
- Não permite refinalizar (já está finalizada)

**Passos:**
1. Abra o SQL no Supabase
2. Descomente o bloco da Solução 3
3. Execute o SQL
4. Execute `COMMIT;`

---

### 🎯 Qual Solução Usar?

```
┌─────────────────────────────────────────────────────────┐
│ Situação                       │ Solução Recomendada    │
├────────────────────────────────┼────────────────────────┤
│ Venda foi reaberta como        │ Solução 2              │
│ RASCUNHO e já tinha movimentado│ (Reverter Estoque)     │
│                                │                        │
│ Venda está RASCUNHO mas nunca  │ Solução 1              │
│ deveria ter movimentações      │ (Limpar e Refinalizar) │
│                                │                        │
│ Movimentações estão corretas   │ Solução 3              │
│ mas status está RASCUNHO       │ (Marcar Finalizada)    │
└────────────────────────────────┴────────────────────────┘
```

## 🚨 IMPORTANTE

### Antes de executar qualquer solução:

1. ✅ Execute primeiro os **PASSOS 1, 2 e 3** do SQL para diagnosticar
2. ✅ Analise as movimentações existentes
3. ✅ Entenda o que cada solução vai fazer
4. ✅ Use transações (BEGIN/COMMIT/ROLLBACK)

### Durante a execução:

1. ⚠️ Execute um bloco de cada vez
2. ⚠️ Revise os resultados antes de fazer COMMIT
3. ⚠️ Se algo der errado, execute `ROLLBACK;` imediatamente

### Depois da correção:

1. ✅ Execute a **VERIFICAÇÃO FINAL** do SQL
2. ✅ Confirme que não há mais movimentações duplicadas
3. ✅ Teste finalizar a venda pela interface

## 📊 Exemplo de Uso

### Cenário Real: VENDA-20260114-00005

```sql
-- 1. Diagnosticar
SELECT * FROM pedidos WHERE numero = 'VENDA-20260114-00005';
-- Resultado: status = 'RASCUNHO'

-- 2. Ver movimentações
SELECT * FROM estoque_movimentacoes 
WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005');
-- Resultado: 3 movimentações de SAÍDA encontradas!

-- 3. Problema identificado: Venda foi reaberta mas movimentações ficaram

-- 4. Aplicar Solução 2 (Reverter estoque)
BEGIN;

-- Reverter saídas
UPDATE produto_sabores ps
SET quantidade = ps.quantidade + em.quantidade
FROM estoque_movimentacoes em
WHERE em.pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005')
AND em.sabor_id = ps.id
AND em.tipo = 'SAIDA';

-- Deletar movimentações
DELETE FROM estoque_movimentacoes 
WHERE pedido_id = (SELECT id FROM pedidos WHERE numero = 'VENDA-20260114-00005');

COMMIT; -- ✅ Se tudo certo

-- 5. Agora pode finalizar pela interface!
```

## 🔮 Prevenção Futura

### O que o sistema já tem:

✅ Constraint única para evitar duplicações  
✅ Função de validação antes de criar movimentações  
✅ Lock pessimista (FOR UPDATE) durante finalização  
✅ Verificação de status antes de finalizar  

### Boas práticas:

1. **Não reabra vendas finalizadas** sem motivo forte
2. **Se precisar reabrir**, use o botão correto que já reverte as movimentações
3. **Não clique múltiplas vezes** em "Finalizar"
4. **Aguarde o loading** completar antes de qualquer ação

## 📚 Arquivos Relacionados

- `database/SOLUCAO_venda_com_movimentacao_duplicada.sql` - SQL para correção
- `database/EXECUTAR_protecao_duplicacao_movimentacoes.sql` - Proteção implementada
- `js/services/pedidos.js` - Função finalizarPedido()
- `pages/venda-detalhe.html` - Interface de vendas

## 🆘 Se Nada Funcionar

Entre em contato com o desenvolvedor fornecendo:

1. Número da venda (ex: VENDA-20260114-00005)
2. Resultado do diagnóstico (PASSO 1, 2, 3 do SQL)
3. Qual solução você tentou
4. Mensagem de erro completa
