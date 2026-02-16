# 🔧 Solução: Sincronização de Vendas Canceladas

## Problema Identificado
Algumas vendas estão aparecendo como **"Autorizado"** em `vendas.html`, mas como **"Cancelado"** em `documentos-fiscais.html`. Isso ocorre quando:

- Uma NFC-e foi cancelada em `documentos_fiscais` mas a venda em `vendas` não foi sincronizada
- Há inconsistência entre as duas tabelas

## 📋 Solução Implementada

### 1️⃣ Melhoria no Código (JavaScript)
- **Arquivo**: `js/services/fiscal.js`
- **O que foi feito**:
  - Adicionada sincronização automática quando um cancelamento é bem-sucedido
  - Adicionada sincronização bidirecional quando detecta um documento já cancelado
  - Agora fiscal.js sincroniza vendas ↔ documentos_fiscais automaticamente

### 2️⃣ Migração SQL para Sincronizar Histórico
- **Arquivo**: `database/migrations/sincronizar-vendas-com-documentos.sql`
- **O que faz**:
  - Encontra todas as vendas desincronizadas (EMITIDA_NFCE mas CANCELADA em documentos_fiscais)
  - Atualiza o status_fiscal para CANCELADA_NFCE
  - Cria um trigger automático para futuras sincronizações

### 3️⃣ Trigger Automático no Banco
Quando um documento em `documentos_fiscais` é cancelado (status_sefaz = '135'), o trigger automatically sincroniza a venda correspondente.

---

## ✅ Como Executar a Sincronização

### Opção 1: Executar via Supabase SQL Editor

1. Abra o [Supabase Dashboard](https://app.supabase.com/)
2. Vá para **SQL Editor**
3. Copie o conteúdo de `database/migrations/sincronizar-vendas-com-documentos.sql`
4. Cole no editor e clique em **RUN**

### Opção 2: Sincronizar Uma Venda Específica

Se você conhece a **chave de acesso** da venda problemática:

```sql
-- Substituir 'SUA_CHAVE_AQUI' pela chave correta
SELECT * FROM sincronizar_venda_por_chave('SUA_CHAVE_AQUI');
```

Exemplo:
```sql
SELECT * FROM sincronizar_venda_por_chave('35241412345678901234567890123456789012');
```

### Opção 3: Sincronizar Automaticamente (Sem SQL)

O sistema agora já sincroniza automaticamente:
- ✅ Quando cancela via vendas.html ou venda-detalhe.html
- ✅ Quando cancela via documentos-fiscais.html
- ✅ Quando detecta um documento já cancelado

---

## 🔍 Verificar Status Após Sincronização

### Verificar uma Venda Específica

```sql
-- Por número da NFC-e
SELECT 
    id,
    numero,
    numero_nfce,
    chave_acesso_nfce,
    status_fiscal,
    data_cancelamento,
    updated_at
FROM vendas
WHERE numero_nfce = '12345'
ORDER BY updated_at DESC;
```

### Verificar Todas as Vendas Canceladas Recentemente

```sql
SELECT 
    id,
    numero,
    numero_nfce,
    status_fiscal,
    data_cancelamento,
    updated_at
FROM vendas
WHERE status_fiscal = 'CANCELADA_NFCE'
  AND updated_at > NOW() - INTERVAL '1 day'
ORDER BY updated_at DESC
LIMIT 20;
```

---

## 📊 Monitorar a Sincronização

### Ver o Log de Sincronizações Recentes

```sql
-- Vendas sincronizadas nos últimos 30 minutos
SELECT 
    id,
    numero,
    numero_nfce,
    status_fiscal,
    data_cancelamento,
    updated_at
FROM vendas
WHERE status_fiscal In ('CANCELADA_NFCE', 'CANCELADA')
  AND updated_at > NOW() - INTERVAL '30 minutes'
ORDER BY updated_at DESC;
```

### Diagnosticos: Documentos Desincronizados Atualmente

```sql
-- Encontrar vendas que ainda estão desincronizadas
SELECT 
    v.id,
    v.numero,
    v.numero_nfce,
    v.chave_acesso_nfce,
    v.status_fiscal as status_venda,
    d.status_sefaz,
    d.numero_documento,
    'DESINCRONIZADO' as situacao
FROM vendas v
LEFT JOIN documentos_fiscais d ON (
    v.numero_nfce::text = d.numero_documento::text OR
    v.chave_acesso_nfce = d.chave_acesso
)
WHERE 
    v.status_fiscal = 'EMITIDA_NFCE'
    AND d.status_sefaz = '135'
ORDER BY v.updated_at DESC;
```

---

## 🚀 Próximas Melhorias

### Real-Time Updates (Futuro)
Adicionar listeners de real-time em vendas.html para que a página se atualize automaticamente quando uma venda é cancelada em outra aba.

### Webhook de Sincronização (Futuro)
Adicionar webhooks para sincronizar automaticamente quando a SEFAZ notifica de um cancelamento.

---

## 📞 Suporte

Se persistirem problemas:

1. **Verificar o console do navegador** (F12) - procure por mensagens com `[FiscalSystem]`
2. **Executar o diagnóstico SQL** acima para ver o estado atual
3. **Executar a migração SQL** completa para sincronizar todo o histórico

---

## 📝 Histórico de Alterações

- **16/02/2026**: Implementada sincronização automática em fiscal.js
- **16/02/2026**: Criada migração SQL com trigger automático
- **16/02/2026**: Documentação de sincronização

