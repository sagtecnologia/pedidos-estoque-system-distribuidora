# 📦 Schema Consolidado - Sistema de Pedidos e Estoque

## 📋 Visão Geral

Este diretório contém o **schema completo e consolidado** do banco de dados, integrando todas as features, correções e melhorias desenvolvidas ao longo do projeto.

---

## 📁 Arquivos Principais

### 🔷 `schema-completo.sql`
**O schema base completo do sistema**

**Contém:**
- ✅ 12 tabelas principais com todas as colunas
- ✅ Todas as funções de negócio (finalizar_pedido, reverter_movimentacoes, etc)
- ✅ Todos os triggers automáticos
- ✅ Constraints únicas para prevenir duplicações
- ✅ Índices de performance
- ✅ Views úteis (estoque, vendas, produtos públicos)
- ✅ Proteções contra race conditions e duplicações

**Execute PRIMEIRO este arquivo!**

---

### 🔐 `schema-rls-policies.sql`
**Todas as políticas de segurança Row Level Security**

**Contém:**
- ✅ ~60 políticas RLS para controle de acesso
- ✅ Permissões por perfil (ADMIN, COMPRADOR, APROVADOR, VENDEDOR)
- ✅ Políticas para acesso anônimo (pré-pedidos públicos)
- ✅ Configuração do storage bucket (logos)

**Execute APÓS o schema-completo.sql**

---

### 📘 `GUIA_INSTALACAO_SCHEMA.md`
**Guia completo passo a passo**

**Contém:**
- ✅ Instruções detalhadas de instalação
- ✅ Checklist de verificação
- ✅ Solução de problemas comuns
- ✅ Comandos SQL para validação
- ✅ Explicação de cada componente

**Leia ANTES de executar os schemas!**

---

## 🚀 Instalação Rápida (TL;DR)

```sql
-- 1. Executar schema base
-- Copiar e executar TODO o conteúdo de: schema-completo.sql

-- 2. Configurar segurança
-- Copiar e executar TODO o conteúdo de: schema-rls-policies.sql

-- 3. Criar usuário admin (via Supabase Auth UI)
-- Depois inserir na tabela users:
INSERT INTO users (id, email, full_name, role, active)
VALUES ('uuid-do-auth', 'seu-email@exemplo.com', 'Admin', 'ADMIN', true);
```

---

## 🏗️ Estrutura do Banco

### Módulos Principais

```
┌─────────────────────────────────────────────────────┐
│                    SISTEMA                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐         ┌──────────────┐         │
│  │   PRODUTOS   │◄────────┤    SABORES   │         │
│  └──────────────┘         └──────────────┘         │
│         ▲                                           │
│         │                                           │
│         │                                           │
│  ┌──────┴────────┐                                  │
│  │   PEDIDOS     │                                  │
│  │ (COMPRA/VENDA)│                                  │
│  └──────┬────────┘                                  │
│         │                                           │
│         ├───► PEDIDO_ITENS                          │
│         ├───► ESTOQUE_MOVIMENTACOES                 │
│         └───► PAGAMENTOS                            │
│                                                     │
│  ┌──────────────┐         ┌──────────────┐         │
│  │ FORNECEDORES │         │   CLIENTES   │         │
│  └──────────────┘         └──────────────┘         │
│                                                     │
│  ┌──────────────────────────────────────┐          │
│  │       PRÉ-PEDIDOS PÚBLICOS           │          │
│  │  (Formulário de pedidos externos)    │          │
│  └──────────────────────────────────────┘          │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Fluxos Principais

**1. Fluxo de Compra:**
```
COMPRADOR cria pedido → 
APROVADOR aprova → 
ADMIN finaliza → 
Estoque ENTRA automaticamente
```

**2. Fluxo de Venda:**
```
VENDEDOR cria venda → 
(pode pular aprovação) →
ADMIN finaliza → 
Estoque SAI automaticamente
```

**3. Fluxo de Pré-Pedido:**
```
Cliente preenche formulário público → 
Sistema cria pré-pedido → 
VENDEDOR analisa → 
Converte em venda/pedido
```

**4. Fluxo de Cancelamento/Reabertura:**
```
Pedido FINALIZADO → 
ADMIN cancela/reabre → 
Trigger reverte movimentações → 
Estoque volta ao estado anterior
```

---

## 🔒 Proteções Implementadas

### 1. Constraint Única de Movimentações
**Problema resolvido:** Duplicação de movimentações causando estoque errado

**Solução:**
```sql
CREATE UNIQUE INDEX idx_movimentacao_finalização_unica 
ON estoque_movimentacoes (pedido_id, produto_id, sabor_id)
WHERE observacao LIKE '%Finalização%';
```

### 2. Lock Pessimista (FOR UPDATE)
**Problema resolvido:** Race conditions em finalizações simultâneas

**Solução:**
```sql
SELECT status FROM pedidos WHERE id = p_pedido_id FOR UPDATE;
-- Bloqueia o registro até o fim da transação
```

### 3. Trigger de Reversão Automática
**Problema resolvido:** Estoque ficava inconsistente ao cancelar

**Solução:**
```sql
CREATE TRIGGER trigger_reverter_movimentacoes
BEFORE UPDATE ON pedidos
FOR EACH ROW
WHEN (OLD.status = 'FINALIZADO' AND NEW.status IN ('RASCUNHO', 'CANCELADO'))
EXECUTE FUNCTION reverter_movimentacoes_pedido();
```

### 4. Validação de Status
**Problema resolvido:** Cancelar pedido já cancelado (cancelamento duplo)

**Solução:**
```sql
CREATE TRIGGER trigger_validar_mudanca_status
BEFORE UPDATE OF status ON pedidos
EXECUTE FUNCTION validar_mudanca_status_pedido();
-- Bloqueia mudanças inválidas de status
```

---

## 📊 Diferenças do Schema Antigo

| Aspecto | Schema Antigo | Schema Novo (Consolidado) |
|---------|---------------|---------------------------|
| **Arquivos** | 69 arquivos SQL separados | 2 arquivos principais |
| **Sabores** | ❌ Não tinha | ✅ Suporte completo |
| **Pré-Pedidos** | ❌ Não tinha | ✅ Sistema público |
| **Pagamentos Parciais** | ❌ Não tinha | ✅ Histórico completo |
| **Proteção Duplicação** | ❌ Não tinha | ✅ Constraint única |
| **Proteção Race Condition** | ❌ Não tinha | ✅ Locks pessimistas |
| **Reversão Automática** | ❌ Manual | ✅ Trigger automático |
| **Cancelamento Duplo** | ❌ Permitia | ✅ Bloqueado |
| **Status CANCELADO** | ❌ Não tinha | ✅ Implementado |
| **Empresa Config** | ❌ Não tinha | ✅ Tabela própria |
| **Views Públicas** | ❌ Não tinha | ✅ Para catálogo |
| **RLS Organizado** | ⚠️ Espalhado | ✅ Arquivo único |

---

## 🔄 Migrando do Schema Antigo

Se você já tem um banco com o schema antigo e quer migrar:

### ⚠️ **ATENÇÃO: Faça backup antes!**

```sql
-- 1. Backup completo
pg_dump sua_database > backup_$(date +%Y%m%d).sql
```

### Opção A: Instalação Limpa (RECOMENDADO)

```sql
-- 1. Exportar dados importantes
-- (usuários, produtos, clientes, fornecedores)

-- 2. Dropar schema antigo
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- 3. Executar schema-completo.sql

-- 4. Executar schema-rls-policies.sql

-- 5. Reimportar dados
```

### Opção B: Migração Incremental (MAIS TRABALHOSO)

```sql
-- 1. Adicionar colunas novas nas tabelas existentes
ALTER TABLE pedidos ADD COLUMN IF NOT EXISTS pagamento_status TEXT;
-- ... (várias alterações necessárias)

-- 2. Criar tabelas novas (produto_sabores, pagamentos, etc)

-- 3. Substituir funções antigas
CREATE OR REPLACE FUNCTION finalizar_pedido...

-- 4. Recriar policies RLS
```

⚠️ **Recomendamos a Opção A** para garantir que tudo funcione perfeitamente.

---

## 📈 Performance

### Índices Criados (23 total)

**Produtos:**
- `idx_produtos_codigo`, `idx_produtos_nome`, `idx_produtos_marca`, `idx_produtos_categoria`, `idx_produtos_active`

**Pedidos:**
- `idx_pedidos_numero`, `idx_pedidos_tipo`, `idx_pedidos_status`, `idx_pedidos_solicitante`, `idx_pedidos_created_at`

**Estoque:**
- `idx_estoque_mov_produto`, `idx_estoque_mov_sabor`, `idx_estoque_mov_pedido`, `idx_estoque_mov_created_at`

**Sabores:**
- `idx_produto_sabores_produto`, `idx_produto_sabores_sabor`, `idx_produto_sabores_ativo`

### Estimativas de Performance

| Operação | Registros | Tempo Estimado |
|----------|-----------|----------------|
| Listar produtos ativos | 1.000 | < 10ms |
| Criar pedido | 1 | < 50ms |
| Finalizar pedido (10 itens) | 10 | < 200ms |
| Buscar movimentações (últimos 30 dias) | 5.000 | < 100ms |
| View estoque_sabores | 500 produtos | < 50ms |

---

## 🧪 Testes Recomendados

Após instalação, execute estes testes:

```sql
-- 1. Teste de criação de produto com sabores
BEGIN;
  -- Criar produto
  INSERT INTO produtos (codigo, nome, marca, unidade, estoque_minimo, preco_venda)
  VALUES ('TEST-001', 'Produto Teste', 'MARCA', 'UN', 5, 10.00)
  RETURNING id; -- Copie o ID
  
  -- Adicionar sabores
  INSERT INTO produto_sabores (produto_id, sabor, quantidade)
  VALUES 
    ('cole-id-aqui', 'Sabor A', 10),
    ('cole-id-aqui', 'Sabor B', 15);
  
  -- Verificar estoque automático
  SELECT codigo, estoque_atual FROM produtos WHERE id = 'cole-id-aqui';
  -- Esperado: estoque_atual = 25
COMMIT;

-- 2. Teste de pedido completo
BEGIN;
  -- Criar pedido
  INSERT INTO pedidos (numero, tipo_pedido, solicitante_id, status)
  VALUES ('TESTE-001', 'VENDA', auth.uid(), 'RASCUNHO')
  RETURNING id; -- Copie o ID
  
  -- Adicionar item
  INSERT INTO pedido_itens (pedido_id, produto_id, sabor_id, quantidade, preco_unitario)
  VALUES ('pedido-id', 'produto-id', 'sabor-id', 5, 10.00);
  
  -- Verificar total automático
  SELECT numero, total FROM pedidos WHERE id = 'pedido-id';
  -- Esperado: total = 50.00
COMMIT;

-- 3. Teste de finalização
SELECT finalizar_pedido('pedido-id', auth.uid());
-- Esperado: true
-- Verificar estoque diminuiu

-- 4. Teste de reabertura
UPDATE pedidos SET status = 'RASCUNHO' WHERE id = 'pedido-id';
-- Verificar estoque voltou
```

---

## 📞 Suporte e Documentações Relacionadas

- 📘 **Instalação:** `GUIA_INSTALACAO_SCHEMA.md`
- 📗 **Técnico:** `../DOCUMENTACAO_TECNICA.md`
- 📙 **Casos de Uso:** `../CASOS_DE_USO.md`
- 📕 **Troubleshooting:** `../TROUBLESHOOTING_*.md`

---

## 🎯 Conclusão

Este schema consolidado representa a **versão estável e testada** do sistema, incorporando:

- ✅ Todas as funcionalidades desenvolvidas
- ✅ Todas as correções aplicadas
- ✅ Todas as proteções implementadas
- ✅ Todas as otimizações realizadas

**Use este schema para novas instalações!**

---

**Última atualização:** 14/01/2026  
**Versão:** 2.0 (Consolidado Final)  
**Compatibilidade:** Supabase PostgreSQL 15+
