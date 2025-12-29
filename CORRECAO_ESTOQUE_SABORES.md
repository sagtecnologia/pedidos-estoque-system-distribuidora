# 🔧 CORREÇÃO: Estoque de Sabores

## Problema Identificado

O sistema estava mostrando **estoque incorreto dos sabores** nas vendas porque:

1. ❌ A função `processar_movimentacao_estoque()` não recebia o `sabor_id`
2. ❌ A função `finalizar_pedido()` não passava o `sabor_id` para as movimentações
3. ❌ As movimentações de estoque (compra/venda) não atualizavam a tabela `produto_sabores`
4. ❌ O estoque dos sabores ficava estático, mostrando sempre a quantidade inicial cadastrada

## Solução Implementada

✅ **Arquivo criado:** `database/migration-fix-estoque-sabores.sql`

### Alterações:

1. **Função `processar_movimentacao_estoque()`:**
   - Adicionado parâmetro `p_sabor_id UUID`
   - Agora atualiza `produto_sabores.quantidade` quando sabor_id é informado
   - O trigger `atualizar_estoque_produto()` recalcula automaticamente o estoque total

2. **Função `finalizar_pedido()`:**
   - Agora busca `sabor_id` da tabela `pedido_itens`
   - Passa o `sabor_id` para `processar_movimentacao_estoque()`
   - Movimentações de compra/venda atualizam sabores individuais

3. **Fluxo correto:**
   ```
   Compra/Venda → finalizar_pedido() → processar_movimentacao_estoque(sabor_id) 
   → UPDATE produto_sabores.quantidade → TRIGGER atualiza estoque_atual do produto
   ```

## 📋 Como Aplicar a Correção

### Passo 1: Executar Migração no Supabase

1. Acesse o **Supabase Dashboard**
2. Vá em **SQL Editor**
3. Clique em **New Query**
4. Copie todo o conteúdo do arquivo `database/migration-fix-estoque-sabores.sql`
5. Cole no editor SQL
6. Clique em **Run** para executar

### Passo 2: Verificar

Após executar, você verá as mensagens:
```
✅ Funções atualizadas com sucesso!
✅ processar_movimentacao_estoque agora aceita p_sabor_id
✅ finalizar_pedido agora passa sabor_id para movimentações
✅ Quantidade de sabores será atualizada automaticamente
```

### Passo 3: Testar

1. **Criar um pedido de compra:**
   - Adicione um produto com sabor
   - Envie para aprovação
   - Aprove o pedido
   - **Finalize o pedido**
   - Verifique se o estoque do sabor aumentou

2. **Criar uma venda:**
   - Selecione o mesmo produto e sabor
   - Verifique se mostra o estoque correto (2 UN, por exemplo)
   - Tente vender 1 unidade
   - Deve permitir e mostrar "✅ Estoque disponível: 2"
   - Finalize a venda
   - Verifique se o estoque do sabor diminuiu para 1

## 🔍 Detalhes Técnicos

### Antes:
```sql
-- Função antiga ignorava sabor_id
processar_movimentacao_estoque(produto_id, tipo, quantidade, usuario_id, ...)

-- Apenas atualizava estoque_atual do produto
UPDATE produtos SET estoque_atual = ...
```

### Depois:
```sql
-- Função nova recebe sabor_id
processar_movimentacao_estoque(produto_id, tipo, quantidade, usuario_id, ..., sabor_id)

-- Atualiza quantidade do sabor específico
UPDATE produto_sabores SET quantidade = ... WHERE id = sabor_id

-- Trigger atualizar_estoque_produto() soma todos os sabores automaticamente
```

## 📊 Exemplo Prático

### Situação:
- **Produto:** V250
- **Marca:** IGNITE
- **Sabores:**
  - Melancia: 10 unidades
  - Morango: 5 unidades
  - **Estoque Total Produto:** 15 unidades (soma automática)

### Compra:
- Compra de **20 unidades** do sabor **Melancia**
- Após finalizar:
  - Melancia: **30 unidades** (10 + 20)
  - Morango: **5 unidades** (sem alteração)
  - **Estoque Total:** **35 unidades** (soma automática)

### Venda:
- Venda de **8 unidades** do sabor **Melancia**
- Sistema valida: ✅ **30 disponíveis**
- Após finalizar:
  - Melancia: **22 unidades** (30 - 8)
  - Morango: **5 unidades** (sem alteração)
  - **Estoque Total:** **27 unidades** (soma automática)

## ⚠️ Importante

- A migração **não afeta** dados existentes
- Apenas atualiza as **funções** do banco de dados
- **Compatível** com todo o código frontend existente
- **Não requer** mudanças no código JavaScript
- O trigger `atualizar_estoque_produto()` continua funcionando normalmente

## ✅ Checklist Final

- [ ] Migração executada no Supabase
- [ ] Mensagens de sucesso confirmadas
- [ ] Teste de compra realizado
- [ ] Teste de venda realizado
- [ ] Estoque dos sabores atualizando corretamente
- [ ] Validação de estoque funcionando

---

**Status:** 🟢 Correção pronta para aplicação  
**Arquivo:** `database/migration-fix-estoque-sabores.sql`  
**Impacto:** Apenas funções do banco de dados  
**Breaking Changes:** Nenhum
