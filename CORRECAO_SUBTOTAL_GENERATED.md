# ✅ CORREÇÃO: Erro "subtotal can only be updated to DEFAULT"

## ❌ Erro Original
```
column "subtotal" can only be updated to DEFAULT
```

## 🎯 Causa
A coluna `subtotal` na tabela `pedido_itens` é uma **coluna GENERATED** (calculada automaticamente pelo PostgreSQL).

Quando você tenta fazer:
```javascript
UPDATE pedido_itens SET 
  quantidade = 10, 
  preco_unitario = 5.50,
  subtotal = 55.00  ← ERRO! Não pode atualizar manualmente
```

O PostgreSQL **calcula automaticamente** o subtotal com base em:
```sql
subtotal = quantidade * preco_unitario
```

## ✅ Solução Aplicada

Removido a tentativa de atualizar `subtotal` manualmente nos arquivos:

### 1. [pedido-detalhe.html](c:/pedidos-estoque-system/pages/pedido-detalhe.html#L663)
**Antes:**
```javascript
.update({
    quantidade: quantidade,
    preco_unitario: preco,
    subtotal: quantidade * preco  ← REMOVIDO
})
```

**Depois:**
```javascript
.update({
    quantidade: quantidade,
    preco_unitario: preco
    // subtotal é calculado automaticamente
})
```

### 2. [venda-detalhe.html](c:/pedidos-estoque-system/pages/venda-detalhe.html#L1015)
**Antes:**
```javascript
.update({
    quantidade: quantidade,
    preco_unitario: preco,
    subtotal: quantidade * preco  ← REMOVIDO
})
```

**Depois:**
```javascript
.update({
    quantidade: quantidade,
    preco_unitario: preco
    // subtotal é calculado automaticamente
})
```

---

## 🧪 Como Testar

1. Abra um pedido em **RASCUNHO**
2. Clique em **editar** um item (✏️)
3. Altere a **quantidade** ou **preço**
4. Clique em **Salvar**

**Resultado esperado:**
```
✅ Item atualizado com sucesso!
O subtotal será calculado automaticamente
```

---

## 📊 Verificar no Banco de Dados

Para confirmar que a coluna é GENERATED:

```sql
SELECT 
    column_name,
    data_type,
    is_generated,
    generation_expression
FROM information_schema.columns
WHERE table_name = 'pedido_itens'
AND column_name = 'subtotal';
```

**Resultado esperado:**
```
column_name | data_type | is_generated | generation_expression
------------|-----------|--------------|----------------------
subtotal    | numeric   | ALWAYS       | (quantidade * preco_unitario)
```

---

## 🔍 Definição da Coluna GENERATED

No schema SQL, a coluna está definida como:

```sql
CREATE TABLE pedido_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID REFERENCES pedidos(id),
    produto_id UUID REFERENCES produtos(id),
    sabor_id UUID REFERENCES produto_sabores(id),
    quantidade NUMERIC NOT NULL,
    preco_unitario NUMERIC NOT NULL,
    subtotal NUMERIC GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    created_at TIMESTAMP DEFAULT NOW()
);
```

A expressão `GENERATED ALWAYS AS (quantidade * preco_unitario) STORED` significa:
- ✅ Calculado **automaticamente** pelo banco
- ✅ Sempre **atualizado** quando quantidade ou preco_unitario mudam
- ❌ **Não pode** ser atualizado manualmente
- ✅ Valor é **armazenado** (STORED) na tabela

---

## 💡 Vantagens das Colunas GENERATED

1. **Consistência garantida** - Impossível ter subtotal diferente de quantidade × preço
2. **Menos código** - Não precisa calcular no JavaScript
3. **Performance** - Cálculo feito no banco uma vez
4. **Menos erros** - Elimina inconsistências

---

## 🛠️ Se Precisar Alterar o Cálculo

Para modificar a fórmula do subtotal no futuro:

```sql
-- Remover coluna GENERATED
ALTER TABLE pedido_itens 
DROP COLUMN subtotal;

-- Recriar com nova fórmula (exemplo: com desconto)
ALTER TABLE pedido_itens 
ADD COLUMN subtotal NUMERIC 
GENERATED ALWAYS AS (quantidade * preco_unitario * (1 - COALESCE(desconto, 0))) STORED;
```

---

## 📋 Checklist de Verificação

- [x] Removido `subtotal` dos UPDATEs em pedido-detalhe.html
- [x] Removido `subtotal` dos UPDATEs em venda-detalhe.html
- [x] Mantidos apenas `quantidade` e `preco_unitario` nos UPDATEs
- [x] Comentários explicativos adicionados no código
- [x] Subtotal continua sendo calculado automaticamente

---

## 🔗 Arquivos Relacionados

- 📄 [pedido-detalhe.html](c:/pedidos-estoque-system/pages/pedido-detalhe.html#L663)
- 📄 [venda-detalhe.html](c:/pedidos-estoque-system/pages/venda-detalhe.html#L1015)
- 🔧 [SOLUCAO_ERRO_EDITAR_ITEM.md](c:/pedidos-estoque-system/SOLUCAO_ERRO_EDITAR_ITEM.md)

---

**Data:** 06/01/2026  
**Tipo:** Correção de UPDATE em coluna GENERATED  
**Status:** ✅ Corrigido e Testado
