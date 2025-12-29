# PERMISSÕES POR PERFIL

## 📊 Resumo de Acessos

### 👤 VENDEDOR
**Acesso:** Apenas vendas e clientes
- ✅ Dashboard
- ✅ Clientes
- ✅ Vendas
- ❌ Produtos
- ❌ Fornecedores
- ❌ Usuários
- ❌ Aprovações de Usuários
- ❌ Configurações da Empresa
- ❌ Estoque
- ❌ Pedidos de Compra
- ❌ Aprovações de Pedidos
- ❌ Análise de Lucros

### 🛒 COMPRADOR
**Acesso:** Compras, estoque e cadastros relacionados
- ✅ Dashboard
- ✅ Produtos
- ✅ Fornecedores
- ✅ Estoque
- ✅ Pedidos de Compra
- ❌ Clientes
- ❌ Vendas
- ❌ Usuários
- ❌ Aprovações de Usuários
- ❌ Configurações da Empresa
- ❌ Aprovações de Pedidos
- ❌ Análise de Lucros

### ✅ APROVADOR
**Acesso:** Apenas aprovações de pedidos
- ✅ Dashboard
- ✅ Aprovações de Pedidos
- ❌ Produtos
- ❌ Fornecedores
- ❌ Clientes
- ❌ Usuários
- ❌ Aprovações de Usuários
- ❌ Configurações da Empresa
- ❌ Estoque
- ❌ Pedidos de Compra
- ❌ Vendas
- ❌ Análise de Lucros

### 👑 ADMIN
**Acesso:** Total (tudo)
- ✅ Dashboard
- ✅ Produtos
- ✅ Fornecedores
- ✅ Clientes
- ✅ Usuários
- ✅ Aprovações de Usuários
- ✅ Configurações da Empresa
- ✅ Estoque
- ✅ Pedidos de Compra
- ✅ Vendas
- ✅ Aprovações de Pedidos
- ✅ **Análise de Lucros** (exclusivo)

## 🔐 Implementação

### Schema
- Constraint atualizada: `CHECK (role IN ('ADMIN', 'COMPRADOR', 'APROVADOR', 'VENDEDOR'))`

### Sidebar
- Controle dinâmico de visibilidade via `hideMenuItems()` baseado em `user.role`

### Migração
- Arquivo: `migration-add-vendedor-role.sql`
- Remove constraint antiga e adiciona nova com VENDEDOR

### Badge de Cores
- ADMIN: Roxo
- COMPRADOR: Azul
- VENDEDOR: Laranja
- APROVADOR: Verde
