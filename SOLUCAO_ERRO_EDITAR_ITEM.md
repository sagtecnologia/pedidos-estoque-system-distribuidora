# 🔧 SOLUÇÃO: Erro ao Editar Sabor/Item do Pedido

## ❌ Problema
Ao tentar editar e salvar um item (sabor) no pedido, o sistema mostra erro:
```
Erro ao atualizar item: Object
```

## 🎯 Causa Raiz
O problema é **RLS (Row Level Security)** bloqueando o UPDATE na tabela `pedido_itens`.

Quando você tenta atualizar, o Supabase:
1. ✅ Executa o UPDATE
2. ❌ RLS bloqueia a operação
3. ❌ Retorna array vazio `[]`
4. ❌ Sistema mostra erro genérico

---

## ✅ SOLUÇÃO EM 3 PASSOS

### 1️⃣ Execute o SQL de Correção

Abra **Supabase SQL Editor** e execute:
```
database/EXECUTAR_fix-rls-pedido-itens.sql
```

Ou execute diretamente:

```sql
-- Criar política para ADMIN atualizar itens
DROP POLICY IF EXISTS "Admin pode atualizar qualquer item de pedido" ON pedido_itens;

CREATE POLICY "Admin pode atualizar qualquer item de pedido"
ON pedido_itens FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM users 
        WHERE users.id = auth.uid() 
        AND users.role = 'ADMIN'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM users 
        WHERE users.id = auth.uid() 
        AND users.role = 'ADMIN'
    )
);

-- Criar política para VENDEDOR atualizar seus itens em rascunho
DROP POLICY IF EXISTS "Vendedor pode atualizar itens de pedidos em rascunho" ON pedido_itens;

CREATE POLICY "Vendedor pode atualizar itens de pedidos em rascunho"
ON pedido_itens FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM pedidos p
        WHERE p.id = pedido_itens.pedido_id
        AND p.solicitante_id = auth.uid()
        AND p.status = 'RASCUNHO'
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM pedidos p
        WHERE p.id = pedido_itens.pedido_id
        AND p.solicitante_id = auth.uid()
        AND p.status = 'RASCUNHO'
    )
);
```

### 2️⃣ Faça Logout e Login
**Obrigatório** para renovar o token JWT com as novas permissões.

### 3️⃣ Limpe o Cache
**Ctrl+Shift+Delete** → Limpar cache → Recarregar página

---

## 🧪 COMO TESTAR

### Antes da Correção:
```
Console (F12):
❌ Erro no Supabase: Object
⚠️ Nenhum item foi atualizado. Possível problema de RLS.
```

### Depois da Correção:
```
Console (F12):
📝 Atualizando item: [uuid] {quantidade: 10, preco: 5.50}
✅ Item atualizado: [{...dados do item...}]
```

---

## 📊 O QUE FOI CORRIGIDO

### Arquivos Modificados:

1. **[pedido-detalhe.html](c:/pedidos-estoque-system/pages/pedido-detalhe.html)**
   - ✅ Adicionados logs detalhados no console
   - ✅ Detecção de RLS bloqueando
   - ✅ Mensagens de erro mais claras

2. **[venda-detalhe.html](c:/pedidos-estoque-system/pages/venda-detalhe.html)**
   - ✅ Mesmas melhorias para vendas

3. **[EXECUTAR_fix-rls-pedido-itens.sql](c:/pedidos-estoque-system/database/EXECUTAR_fix-rls-pedido-itens.sql)** (NOVO)
   - ✅ Políticas RLS para UPDATE em pedido_itens
   - ✅ Políticas RLS para DELETE em pedido_itens
   - ✅ Permissões para ADMIN e VENDEDOR

---

## 🔍 LOGS DETALHADOS

Agora o console mostra **exatamente** o que está acontecendo:

### Caso 1: UPDATE Bloqueado por RLS
```javascript
📝 Atualizando item: abc123... {quantidade: 10, preco: 5.50}
⚠️ Nenhum item foi atualizado. Possível problema de RLS.
❌ Erro completo: Não foi possível atualizar o item. Verifique suas permissões.
```
**Solução:** Execute o SQL de correção de RLS

### Caso 2: Erro de Validação
```javascript
📝 Atualizando item: abc123... {quantidade: 10, preco: 5.50}
❌ Erro no Supabase: {message: "new row violates check constraint..."}
```
**Solução:** Corrigir os dados enviados

### Caso 3: Sucesso ✅
```javascript
📝 Atualizando item: abc123... {quantidade: 10, preco: 5.50}
✅ Item atualizado: [{id: "abc123", quantidade: 10, ...}]
```
**Status:** Funcionando perfeitamente!

---

## 🛡️ POLÍTICAS RLS CRIADAS

### Para UPDATE:

| Política | Permite |
|----------|---------|
| **Admin pode atualizar qualquer item** | ADMIN atualiza qualquer item de qualquer pedido |
| **Vendedor pode atualizar itens em rascunho** | VENDEDOR atualiza apenas seus itens em pedidos RASCUNHO |

### Para DELETE:

| Política | Permite |
|----------|---------|
| **Admin pode excluir qualquer item** | ADMIN exclui qualquer item |
| **Vendedor pode excluir itens em rascunho** | VENDEDOR exclui apenas seus itens em RASCUNHO |

---

## 📋 CHECKLIST DE VERIFICAÇÃO

Após aplicar a correção:

- [ ] SQL executado sem erros no Supabase
- [ ] Logout e login realizados
- [ ] Cache do navegador limpo
- [ ] Console (F12) aberto para ver logs
- [ ] Ao editar item, console mostra logs detalhados
- [ ] Item é atualizado com sucesso
- [ ] Não aparece "Nenhum item foi atualizado"

---

## 🔗 ARQUIVOS RELACIONADOS

- 🔧 SQL: [EXECUTAR_fix-rls-pedido-itens.sql](c:/pedidos-estoque-system/database/EXECUTAR_fix-rls-pedido-itens.sql)
- 📄 Pedidos: [pedido-detalhe.html](c:/pedidos-estoque-system/pages/pedido-detalhe.html#L658)
- 📄 Vendas: [venda-detalhe.html](c:/pedidos-estoque-system/pages/venda-detalhe.html#L1012)
- 🔧 RLS Pedidos: [EXECUTAR_AGORA_fix-rls-cancelamento.sql](c:/pedidos-estoque-system/database/EXECUTAR_AGORA_fix-rls-cancelamento.sql)

---

**Data da Correção:** 06/01/2026  
**Tipo:** Correção de RLS + Logs detalhados  
**Status:** ✅ Implementado
