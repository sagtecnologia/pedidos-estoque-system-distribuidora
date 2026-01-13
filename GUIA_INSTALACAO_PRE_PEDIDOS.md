# 🚀 SISTEMA DE PRÉ-PEDIDOS PÚBLICOS - GUIA DE INSTALAÇÃO

## ✅ Arquivos Criados

### 1. **Banco de Dados**
- `database/EXECUTAR_criar_pre_pedidos.sql` - Script completo para criar tabelas, views, funções e políticas RLS

### 2. **JavaScript Services**
- `js/services/pre-pedidos.js` - Funções para gerenciar pré-pedidos (público e interno)

### 3. **Páginas HTML**
- `pedido-publico.html` - Catálogo público (SEM autenticação)
- `pages/pre-pedidos.html` - Tela interna de análise (COM autenticação)

### 4. **Componentes**
- `components/sidebar.js` - Atualizado com menu "Pré-Pedidos Públicos"

---

## 📋 PASSO A PASSO PARA INSTALAÇÃO

### **ETAPA 1: Executar Script SQL**

1. Acesse o **Supabase Dashboard**
2. Vá em **SQL Editor**
3. Abra o arquivo `database/EXECUTAR_criar_pre_pedidos.sql`
4. **Copie todo o conteúdo**
5. Cole no SQL Editor
6. Clique em **RUN**

✅ **Verificação**: O script irá retornar uma mensagem de sucesso com contadores das tabelas/views criadas.

---

### **ETAPA 2: Verificar Criação das Estruturas**

Execute no SQL Editor para confirmar:

```sql
-- Verificar tabelas
SELECT table_name FROM information_schema.tables 
WHERE table_name IN ('pre_pedidos', 'pre_pedido_itens');

-- Verificar views
SELECT table_name FROM information_schema.views 
WHERE table_name IN ('vw_produtos_publicos', 'vw_sabores_publicos');

-- Verificar funções
SELECT routine_name FROM information_schema.routines 
WHERE routine_name IN ('expirar_pre_pedidos', 'gerar_numero_pre_pedido');
```

---

### **ETAPA 3: Configurar Acesso Público (Importante!)**

Por padrão, o Supabase bloqueia acesso anônimo. Você precisa:

1. No **Supabase Dashboard**, vá em **Authentication** → **Policies**
2. Verifique se as políticas RLS foram criadas para:
   - `pre_pedidos`
   - `pre_pedido_itens`
   - `produtos` (para vw_produtos_publicos)
   - `produto_sabores` (para vw_sabores_publicos)

3. Se necessário, adicione políticas de leitura pública manualmente:

```sql
-- Produtos públicos (leitura anônima)
CREATE POLICY "Leitura pública de produtos ativos"
ON produtos FOR SELECT
TO anon
USING (ativo = true AND estoque_atual > 0);

-- Sabores públicos (leitura anônima)
CREATE POLICY "Leitura pública de sabores ativos"
ON produto_sabores FOR SELECT
TO anon
USING (ativo = true AND quantidade > 0);
```

---

### **ETAPA 4: Testar Acesso Público**

1. Abra o arquivo `pedido-publico.html` no navegador
   - URL: `http://seu-dominio.com/pedido-publico.html`

2. **Teste:**
   - Deve listar produtos com estoque
   - Adicionar ao carrinho
   - Preencher formulário
   - Enviar pedido

3. Se der erro de autenticação/permissão:
   - Verifique as políticas RLS
   - Confirme que o usuário `anon` tem permissão

---

### **ETAPA 5: Configurar Permissões Internas**

A tela interna (`pages/pre-pedidos.html`) requer autenticação.

**Perfis com acesso:**
- ✅ VENDEDOR
- ✅ APROVADOR  
- ✅ ADMIN

Para adicionar outros perfis, edite a verificação em `pages/pre-pedidos.html` (linha ~32):

```javascript
if (!['VENDEDOR', 'APROVADOR', 'ADMIN'].includes(currentUser.role)) {
    // Adicione outros perfis aqui
}
```

---

### **ETAPA 6: Configurar Expiração Automática (Opcional)**

Para expirar pré-pedidos automaticamente após 24h, você tem 2 opções:

#### **Opção A: Manual (via tela)**
- A função `expirarPrePedidosAntigos()` é chamada automaticamente ao carregar a tela `pre-pedidos.html`
- Funciona quando um usuário interno acessa a tela

#### **Opção B: Automático (Cron Job)**

Se você tem o **pg_cron** habilitado no Supabase (planos pagos):

```sql
-- Criar cron job para expirar a cada hora
SELECT cron.schedule(
    'expirar-pre-pedidos-24h',
    '0 * * * *', -- A cada hora
    $$ SELECT expirar_pre_pedidos(); $$
);
```

---

## 🔗 URLS DO SISTEMA

### **Público (Sem Login)**
- Catálogo: `https://seu-dominio.com/pedido-publico.html`

### **Interno (Com Login)**
- Análise: `https://seu-dominio.com/pages/pre-pedidos.html`

---

## 🧪 TESTES RECOMENDADOS

### **1. Teste de Criação de Pré-Pedido**

1. Acesse `pedido-publico.html`
2. Selecione produtos
3. Adicione ao carrinho
4. Preencha nome (email/telefone opcional)
5. Envie
6. **Verifique**: Deve mostrar número do pedido

### **2. Teste de Análise Interna**

1. Faça login no sistema
2. Acesse menu "Pré-Pedidos Públicos"
3. Deve listar o pedido criado
4. Clique em "Analisar"
5. Selecione um cliente
6. Clique em "Gerar Pedido de Venda"
7. **Verifique**: Deve criar pedido de venda normal

### **3. Teste de Validação de Estoque**

1. Crie pré-pedido com quantidade > estoque
2. Na análise, deve mostrar alerta de estoque insuficiente
3. Botão "Gerar Pedido" deve ficar desabilitado

### **4. Teste de Expiração**

1. Altere manualmente a data de expiração de um pré-pedido:

```sql
UPDATE pre_pedidos 
SET data_expiracao = NOW() - INTERVAL '1 hour'
WHERE numero = 'PRE-2026-0001';
```

2. Acesse a tela interna
3. O pedido deve ser marcado como EXPIRADO automaticamente

---

## 🎨 PERSONALIZAÇÃO

### **Alterar Logo/Nome da Empresa**

Edite `pedido-publico.html` (linha ~21):

```html
<h1 class="text-4xl font-bold text-gray-900 mb-2">
    🛒 Catálogo de [SUA EMPRESA]
</h1>
```

### **Alterar Cores do Tema**

Cores atuais:
- **Primária**: Azul (`bg-blue-600`)
- **Sucesso**: Verde (`bg-green-600`)
- **Pendente**: Amarelo (`bg-yellow-600`)
- **Pré-Pedidos**: Roxo (`bg-purple-500`)

Para mudar, use as classes do Tailwind CSS.

### **Adicionar Imagens de Produtos**

1. Adicione coluna `imagem_url` na tabela `produtos`
2. Atualize a view `vw_produtos_publicos` para incluir a imagem
3. Modifique o card de produto em `pedido-publico.html`

---

## 🔒 SEGURANÇA

### **Configurações Importantes:**

1. ✅ **RLS está habilitado** em todas as tabelas
2. ✅ **Acesso anônimo controlado** por políticas específicas
3. ✅ **Dados sensíveis protegidos** (preços de compra não aparecem no público)
4. ✅ **IP e User-Agent registrados** para auditoria
5. ✅ **Token único** para cada pré-pedido

### **Rate Limiting (Recomendado)**

Para evitar spam, configure no seu servidor/proxy:
- Limite: 5 pedidos por IP por hora
- Usar Cloudflare ou similar

---

## 📊 MONITORAMENTO

### **Consultas Úteis**

```sql
-- Total de pré-pedidos por status
SELECT status, COUNT(*) as total
FROM pre_pedidos
GROUP BY status;

-- Pré-pedidos pendentes há mais de 12h
SELECT numero, nome_solicitante, created_at
FROM pre_pedidos
WHERE status = 'PENDENTE'
  AND created_at < NOW() - INTERVAL '12 hours';

-- Taxa de conversão
SELECT 
    COUNT(*) FILTER (WHERE status = 'APROVADO') * 100.0 / COUNT(*) as taxa_conversao
FROM pre_pedidos
WHERE created_at > NOW() - INTERVAL '30 days';
```

---

## 🆘 TROUBLESHOOTING

### **Problema: "Erro ao carregar produtos"**

**Solução:**
1. Verifique se existem produtos ativos com estoque > 0
2. Confirme as políticas RLS para `produtos`
3. Verifique console do navegador (F12)

### **Problema: "Acesso negado ao criar pré-pedido"**

**Solução:**
1. Verifique política RLS `TO anon` em `pre_pedidos`
2. Confirme que o Supabase permite acesso anônimo
3. Teste com `supabase.auth.signOut()` para garantir modo anônimo

### **Problema: "Cliente não vê o menu Pré-Pedidos"**

**Solução:**
1. Verifique o perfil do usuário (VENDEDOR, APROVADOR ou ADMIN)
2. Limpe cache do navegador
3. Verifique `components/sidebar.js` se o menu não foi ocultado

### **Problema: "Pedidos não expiram"**

**Solução:**
1. Execute manualmente: `SELECT expirar_pre_pedidos();`
2. Verifique se a função foi criada corretamente
3. Configure cron job (pg_cron) se necessário

---

## 📚 DOCUMENTAÇÃO ADICIONAL

- [PROPOSTA_PEDIDOS_PUBLICOS.md](PROPOSTA_PEDIDOS_PUBLICOS.md) - Documentação completa da arquitetura
- Supabase RLS: https://supabase.com/docs/guides/auth/row-level-security
- Tailwind CSS: https://tailwindcss.com/docs

---

## ✨ PRÓXIMOS PASSOS (Melhorias Futuras)

1. **Notificações por Email**
   - Enviar confirmação ao cliente
   - Alertar equipe de novos pedidos

2. **Acompanhamento por Token**
   - Página onde cliente vê status do pedido

3. **Imagens de Produtos**
   - Upload e galeria

4. **Cupons de Desconto**
   - Sistema de promoções

5. **Multi-idiomas**
   - Suporte a inglês/espanhol

---

**Sistema criado em:** 13/01/2026  
**Versão:** 1.0  
**Status:** ✅ Pronto para Produção
