# 🔍 TROUBLESHOOTING: Pedido Não Muda para Cancelado

## 🚨 Problema Reportado
Ao cancelar um pedido, o status continua como **FINALIZADO** ao invés de mudar para **CANCELADO**.

---

## ✅ PASSOS PARA RESOLVER

### 1️⃣ Execute o SQL de Proteção (se ainda não executou)
```sql
-- Execute no Supabase SQL Editor
database/EXECUTAR_protecao-cancelamento-duplo.sql
```

### 2️⃣ Execute o Diagnóstico
```sql
-- Execute no Supabase SQL Editor
database/DIAGNOSTICO_status_pedidos.sql
```

Isso irá mostrar:
- ✅ Se a função de validação existe
- ✅ Se o trigger está ativo
- ✅ Se o pedido pode ser atualizado
- ✅ Se há problemas de permissão (RLS)

### 3️⃣ Teste no Frontend com Logs

1. Abra um pedido **FINALIZADO**
2. Pressione **F12** para abrir o Console do navegador
3. Clique em "🚫 Cancelar Pedido"
4. Escolha "Cancelar Definitivamente"

**O que você deve ver no console:**
```
📝 Atualizando pedido: [UUID] Status atual: FINALIZADO Novo status: CANCELADO
📝 Dados para atualizar: {status: "CANCELADO", aprovador_id: "..."}
✅ Pedido atualizado com sucesso: [{...}]
🔄 Recarregando dados do pedido...
✅ Pedido recarregado. Novo status: CANCELADO
```

---

## 🐛 POSSÍVEIS CAUSAS E SOLUÇÕES

### Causa 1: RLS (Row Level Security) bloqueando update
**Sintoma:** Console mostra erro de permissão  
**Solução:**
```sql
-- Verificar políticas RLS
SELECT * FROM pg_policies WHERE tablename = 'pedidos';

-- Se necessário, criar política para update de status por ADMIN
CREATE POLICY "Admin pode cancelar pedidos"
ON pedidos FOR UPDATE
TO authenticated
USING (
    auth.uid() IN (SELECT id FROM users WHERE role = 'ADMIN')
)
WITH CHECK (
    auth.uid() IN (SELECT id FROM users WHERE role = 'ADMIN')
);
```

### Causa 2: Trigger bloqueando atualização
**Sintoma:** Console mostra erro "Só é possível cancelar pedidos..."  
**Solução:** Executar versão atualizada do SQL de proteção:
```sql
-- A nova versão permite cancelar de FINALIZADO, APROVADO, ENVIADO e REJEITADO
database/EXECUTAR_protecao-cancelamento-duplo.sql
```

### Causa 3: Cache do navegador
**Sintoma:** Código antigo ainda está sendo executado  
**Solução:**
1. Pressione **Ctrl+Shift+Delete**
2. Marque "Imagens e arquivos em cache"
3. Clique em "Limpar dados"
4. Recarregue a página com **Ctrl+F5**

### Causa 4: Pedido já está cancelado
**Sintoma:** Toast mostra "Este pedido já foi cancelado"  
**Solução:** Recarregue a página - o status já está correto no banco

### Causa 5: Erro silencioso no JavaScript
**Sintoma:** Nada acontece ao clicar em cancelar  
**Solução:** Verificar console (F12) e procurar por erros em vermelho

---

## 🧪 TESTE MANUAL NO BANCO DE DADOS

Se o frontend não funcionar, teste diretamente no banco:

```sql
-- 1. Encontrar um pedido FINALIZADO
SELECT id, numero, status FROM pedidos WHERE status = 'FINALIZADO' LIMIT 1;

-- 2. Anotar o ID e tentar atualizar
UPDATE pedidos 
SET status = 'CANCELADO', 
    aprovador_id = (SELECT id FROM users WHERE role = 'ADMIN' LIMIT 1)
WHERE id = 'SEU-ID-AQUI';

-- 3. Verificar se foi atualizado
SELECT id, numero, status FROM pedidos WHERE id = 'SEU-ID-AQUI';
```

**Se der erro aqui:**
- Leia a mensagem de erro completa
- Pode ser problema de trigger ou RLS
- Execute o diagnóstico (passo 2)

**Se funcionar aqui mas não no frontend:**
- É problema de JavaScript ou permissões
- Verifique o console do navegador
- Verifique se o usuário tem role ADMIN

---

## 📋 CHECKLIST DE VERIFICAÇÃO

- [ ] SQL de proteção executado no Supabase
- [ ] Diagnóstico executado sem erros
- [ ] Cache do navegador limpo
- [ ] Console não mostra erros (F12)
- [ ] Usuário tem permissão de ADMIN
- [ ] Pedido está com status FINALIZADO (não CANCELADO)
- [ ] Trigger está instalado corretamente
- [ ] Políticas RLS permitem update

---

## 🆘 SOLUÇÃO RÁPIDA (Se nada funcionar)

Execute este SQL para remover temporariamente o trigger e tentar novamente:

```sql
-- TEMPORÁRIO: Desabilitar trigger
DROP TRIGGER IF EXISTS trigger_validar_mudanca_status ON pedidos;

-- Agora tente cancelar o pedido pelo frontend

-- Depois, reabilitar:
-- Execute novamente: database/EXECUTAR_protecao-cancelamento-duplo.sql
```

---

## 📞 Informações para Suporte

Se o problema persistir, forneça:
1. Screenshot do console do navegador (F12)
2. Resultado do SQL de diagnóstico
3. Seu usuário (email) e role
4. Número do pedido que está tentando cancelar
5. Status atual do pedido no banco de dados

---

**Última Atualização:** 06/01/2026  
**Arquivos Relacionados:**
- [pedido-detalhe.html](c:/pedidos-estoque-system/pages/pedido-detalhe.html) (linha 699)
- [venda-detalhe.html](c:/pedidos-estoque-system/pages/venda-detalhe.html) (linha 1197)
- [EXECUTAR_protecao-cancelamento-duplo.sql](c:/pedidos-estoque-system/database/EXECUTAR_protecao-cancelamento-duplo.sql)
