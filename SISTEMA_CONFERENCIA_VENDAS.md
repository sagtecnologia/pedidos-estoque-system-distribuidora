# 📦 Sistema de Conferência e Despacho de Vendas

## 🎯 Objetivo

Este módulo implementa um fluxo completo de pós-venda, permitindo que após a finalização de um pedido, os produtos sejam conferidos/separados fisicamente e depois despachados ao cliente.

**🔑 Arquitetura:** Utiliza campo **`status_envio`** separado para controle logístico, **sem afetar** o campo `status` existente.

---

## 🔄 Fluxo Completo

```
┌──────────────┐      ┌──────────────┐      
│   PEDIDO     │      │   PEDIDO     │      
│              │      │              │      
│ status:      │ ───► │ status:      │ ◄─── FLUXO COMERCIAL
│ FINALIZADO   │      │ FINALIZADO   │      (não muda)
│              │      │              │      
│ status_envio:│      │ status_envio:│      
│ NULL         │      │ SEPARADO     │ ◄─── FLUXO LOGÍSTICO
└──────────────┘      └──────────────┘      (novo campo)
       │                      │
       │                      │
       ▼                      ▼
  Conferir itens        Despachar pedido
  no estoque            para cliente
```

### Detalhamento das Etapas

**Campo `status` (INALTERADO - Fluxo Comercial):**
```
RASCUNHO → ENVIADO → APROVADO → FINALIZADO
```

**Campo `status_envio` (NOVO - Fluxo Logístico):**
```
NULL/AGUARDANDO_SEPARACAO → SEPARADO → DESPACHADO
```

---

## 🗄️ Alterações no Banco de Dados

### ✅ Campo `status` - INALTERADO

O campo `status` **não foi modificado** e continua funcionando normalmente:

```sql
CHECK (status IN ('RASCUNHO', 'ENVIADO', 'APROVADO', 'REJEITADO', 'FINALIZADO', 'CANCELADO'))
```

### ✨ Novo Campo `status_envio`

Campo separado para controlar o fluxo logístico:

```sql
status_envio VARCHAR(30)
CHECK (status_envio IN ('AGUARDANDO_SEPARACAO', 'SEPARADO', 'DESPACHADO'))
```

| Valor | Descrição |
|-------|-----------|
| `NULL` ou `AGUARDANDO_SEPARACAO` | Aguardando separação física |
| `SEPARADO` | Todos itens conferidos, pronto para despacho |
| `DESPACHADO` | Pedido enviado ao cliente |

### Novos Campos na Tabela `pedidos`

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `status_envio` | VARCHAR(30) | Status logístico: NULL, AGUARDANDO_SEPARACAO, SEPARADO, DESPACHADO |
| `data_separacao` | TIMESTAMP | Data/hora em que foi separado |
| `separado_por` | UUID | ID do usuário que separou |
| `data_despacho` | TIMESTAMP | Data/hora em que foi despachado |
| `despachado_por` | UUID | ID do usuário que despachou |

### Novos Campos na Tabela `pedido_itens`

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `conferido` | BOOLEAN | Se o item foi conferido |
| `conferido_por` | UUID | ID do usuário que conferiu |
| `data_conferencia` | TIMESTAMP | Data/hora da conferência |

---

## 📊 Views Criadas

### `vw_vendas_aguardando_separacao`

Lista vendas finalizadas aguardando separação com progresso de conferência:

```sql
SELECT * FROM vw_vendas_aguardando_separacao;
```

**Campos principais:**
- `numero` - Número do pedido
- `cliente_nome` - Nome do cliente
- `total_itens` - Total de itens no pedido
- `itens_conferidos` - Quantos já foram conferidos
- `todos_conferidos` - TRUE se todos conferidos

**Filtro:** `status = 'FINALIZADO'` AND `status_envio IS NULL` ou `'AGUARDANDO_SEPARACAO'`

### `vw_vendas_aguardando_despacho`

Lista vendas separadas aguardando despacho:

```sql
SELECT * FROM vw_vendas_aguardando_despacho;
```

**Campos principais:**
- `numero` - Número do pedido
- `cliente_nome` - Nome do cliente
- `endereco`, `cidade`, `estado` - Endereço de entrega
- `separado_por_nome` - Quem separou
- `data_separacao` - Quando foi separado

**Filtro:** `status = 'FINALIZADO'` AND `status_envio = 'SEPARADO'`

---

## 🔧 Funções do Banco

### `conferir_item_pedido()`

Marca um item individual como conferido:

```sql
SELECT conferir_item_pedido(
    'uuid-do-item',     -- ID do item
    'uuid-do-usuario'   -- ID de quem está conferindo
);
```

### `marcar_pedido_separado()`

Finaliza a conferência e marca pedido como SEPARADO:

```sql
SELECT marcar_pedido_separado(
    'uuid-do-pedido',   -- ID do pedido
    'uuid-do-usuario'   -- ID de quem separou
);
```

**Validações:**
- ✅ Pedido deve estar FINALIZADO (campo `status`)
- ✅ Todos os itens devem estar conferidos

**Resultado:** Atualiza `status_envio = 'SEPARADO'`

### `marcar_pedido_despachado()`

Marca pedido como despachado/enviado:

```sql
SELECT marcar_pedido_despachado(
    'uuid-do-pedido',   -- ID do pedido
    'uuid-do-usuario'   -- ID de quem despachou
);
```

**Validações:**
- ✅ Pedido deve ter `status_envio = 'SEPARADO'`

**Resultado:** Atualiza `status_envio = 'DESPACHADO'`

---

## 🖥️ Interface Web

### Página: `conferencia-vendas.html`

Localização: `/pages/conferencia-vendas.html`

#### Abas Disponíveis

**1. Aguardando Separação**
- Lista vendas finalizadas
- Mostra progresso de conferência (%)
- Botão para iniciar/continuar conferência

**2. Aguardando Despacho**
- Lista vendas separadas
- Mostra endereço de entrega
- Botão para despachar

**3. Histórico**
- Lista vendas despachadas
- Filtro por período
- Informações completas do fluxo

---

## 📋 Como Usar

### 1. Conferir/Separar Pedido

1. Acesse **Conferência de Vendas** no menu
2. Na aba **"Aguardando Separação"**, clique em um pedido
3. No modal, marque cada item conforme for separando fisicamente
4. Quando todos estiverem marcados, clique em **"Finalizar Separação"**
5. Pedido muda para status **SEPARADO**

### 2. Despachar Pedido

1. Na aba **"Aguardando Despacho"**, clique em um pedido
2. Confira o endereço de entrega
3. (Opcional) Adicione observações do despacho
4. Clique em **"Confirmar Despacho"**
5. Pedido muda para status **DESPACHADO**

### 3. Consultar Histórico

1. Na aba **"Histórico"**, defina o período
2. Clique em **"Buscar"**
3. Visualize todos os pedidos despachados no período

---

## 🎨 Features da Interface

### ✅ Card de Pedido (Separação)

- 📊 Barra de progresso visual
- 📱 Link direto para WhatsApp do cliente
- 💰 Valor total destacado
- 👤 Nome do vendedor
- 📅 Data de finalização

### ✅ Modal de Conferência

- ☑️ Checkbox para cada item
- 📊 Progresso em tempo real
- 🔒 Botão de finalizar só ativa com 100%
- 💾 Salvamento automático ao marcar item
- 👤 Informações do cliente

### ✅ Modal de Despacho

- 📍 Endereço completo de entrega
- 📱 Link para WhatsApp
- 📝 Campo para observações (rastreio, etc)
- ✅ Confirmação antes de despachar

### ✅ Histórico

- 🔍 Filtro por período
- 📊 Timeline completa (finalizado → separado → despachado)
- 👥 Quem separou e quem despachou
- 📅 Todas as datas registradas

---

## 🔐 Permissões

| Perfil | Ver | Conferir | Despachar |
|--------|-----|----------|-----------|
| **ADMIN** | ✅ | ✅ | ✅ |
| **VENDEDOR** | ✅ | ✅ | ✅ |
| **COMPRADOR** | ❌ | ❌ | ❌ |
| **APROVADOR** | ❌ | ❌ | ❌ |

---

## 📱 Badges no Menu

O menu lateral mostra badges indicando quantidade de pendências:

- 🔵 **Badge Azul** → Vendas aguardando separação
- 🟢 **Badge Verde** → Vendas aguardando despacho

---

## 🚀 Instalação

### 1. Atualizar Banco de Dados

Execute o arquivo SQL no Supabase:

```bash
database/EXECUTAR_adicionar_conferencia_vendas.sql
```

### 2. Verificar Instalação

```sql
-- Verificar novos status
SELECT DISTINCT status FROM pedidos ORDER BY status;
-- Deve incluir: SEPARADO, DESPACHADO

-- Verificar views
SELECT * FROM vw_vendas_aguardando_separacao LIMIT 1;
SELECT * FROM vw_vendas_aguardando_despacho LIMIT 1;

-- Verificar funções
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_name LIKE '%conferir%' 
   OR routine_name LIKE '%separado%'
   OR routine_name LIKE '%despachado%';
```

### 3. Acessar Interface

Faça login e acesse:
- Menu lateral → **Conferência de Vendas**
- Ou diretamente: `/pages/conferencia-vendas.html`

---

## 📊 Estatísticas e Relatórios

### Vendas por Status Logístico

```sql
SELECT 
    COALESCE(status_envio, 'AGUARDANDO') as status_logistico,
    COUNT(*) as quantidade,
    SUM(total) as valor_total
FROM pedidos
WHERE tipo_pedido = 'VENDA'
  AND status = 'FINALIZADO'
GROUP BY status_envio
ORDER BY status_envio NULLS FIRST;
```

### Performance de Separação

```sql
SELECT 
    u.full_name as separador,
    COUNT(*) as total_separacoes,
    AVG(EXTRACT(EPOCH FROM (data_separacao - data_finalizacao))/3600) as tempo_medio_horas
FROM pedidos p
JOIN users u ON p.separado_por = u.id
WHERE p.status_envio IN ('SEPARADO', 'DESPACHADO')
GROUP BY u.full_name
ORDER BY total_separacoes DESC;
```

### Tempo Médio de Entrega

```sql
SELECT 
    AVG(EXTRACT(EPOCH FROM (data_despacho - data_finalizacao))/86400) as dias_finalizacao_ate_despacho,
    AVG(EXTRACT(EPOCH FROM (data_despacho - data_separacao))/3600) as horas_separacao_ate_despacho
FROM pedidos
WHERE status_envio = 'DESPACHADO'
  AND data_despacho IS NOT NULL;
```

---

## 🐛 Troubleshooting

### ❌ Erro: "Todos os itens devem ser conferidos"

**Causa:** Tentou finalizar separação sem marcar todos os itens.

**Solução:** Confira o progresso (ex: 4/5) e marque todos os itens.

### ❌ Erro: "Apenas pedidos FINALIZADOS podem ser marcados como SEPARADO"

**Causa:** Tentou separar um pedido que ainda não está com `status = 'FINALIZADO'`.

**Solução:** Finalize o pedido primeiro na tela de vendas.

### ❌ Erro: "Apenas pedidos SEPARADOS podem ser marcados como DESPACHADO"

**Causa:** Tentou despachar sem ter `status_envio = 'SEPARADO'`.

**Solução:** Faça a conferência completa primeiro.

### ⚠️ Badge não atualiza

**Causa:** Cache do navegador.

**Solução:** Recarregue a página (F5) ou limpe o cache.

---

## 🔄 Integrações Futuras

### Possíveis Melhorias

1. **📧 Notificações por Email**
   - Avisar cliente quando pedido for despachado
   - Incluir código de rastreio

2. **📱 Integração WhatsApp API**
   - Enviar mensagem automática ao despachar
   - Template: "Seu pedido #XXX foi despachado!"

3. **📦 Código de Rastreio**
   - Campo específico para rastreio
   - Consulta automática nos Correios/transportadora

4. **📊 Relatório de Produtividade**
   - Tempo médio de separação por usuário
   - Ranking de eficiência

5. **📸 Foto da Conferência**
   - Upload de foto dos produtos separados
   - Comprovação visual

---

## 📚 Documentação Relacionada

- 📘 [Schema Completo](database/schema-completo.sql)
- 📗 [Políticas RLS](database/schema-rls-policies.sql)
- 📙 [Documentação Técnica](DOCUMENTACAO_TECNICA.md)

---

**Última atualização:** 14/01/2026  
**Versão:** 1.0  
**Autor:** Sistema de Pedidos e Estoque
