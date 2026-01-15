# 📘 GUIA COMPLETO DE INSTALAÇÃO DO BANCO DE DADOS

## 🎯 Objetivo
Este guia te ajudará a configurar o banco de dados completo do sistema de pedidos e estoque do zero usando os schemas consolidados.

---

## 📋 Pré-requisitos

1. ✅ Conta no [Supabase](https://supabase.com) criada
2. ✅ Projeto Supabase criado
3. ✅ Acesso ao **SQL Editor** do Supabase

---

## 🚀 Passos de Instalação

### **PASSO 1: Criar Estrutura do Banco**

1. Acesse o **SQL Editor** do seu projeto Supabase
2. Clique em **"New Query"**
3. Copie **TODO** o conteúdo do arquivo `schema-completo.sql`
4. Cole no editor e clique em **"Run"**
5. ⏱️ Aguarde a execução (pode levar 10-30 segundos)
6. ✅ Verifique se apareceu a mensagem: **"SCHEMA COMPLETO CRIADO COM SUCESSO!"**

**O que foi criado:**
- ✅ 12 tabelas principais
- ✅ Todas as funções de negócio
- ✅ Todos os triggers automáticos
- ✅ Constraints de proteção
- ✅ Views úteis
- ✅ Índices de performance

---

### **PASSO 2: Configurar Segurança (RLS)**

1. No **SQL Editor**, crie uma **nova query**
2. Copie **TODO** o conteúdo do arquivo `schema-rls-policies.sql`
3. Cole e execute
4. ✅ Verifique a mensagem: **"POLÍTICAS RLS CONFIGURADAS COM SUCESSO!"**

**O que foi configurado:**
- ✅ Row Level Security habilitado em todas as tabelas
- ✅ ~60 políticas de acesso criadas
- ✅ Permissões por perfil (ADMIN, COMPRADOR, APROVADOR, VENDEDOR)
- ✅ Bucket de storage para logos

---

### **PASSO 3: Criar Usuário Administrador**

#### Opção A: Via Interface Supabase (RECOMENDADO)

1. Vá em **Authentication** > **Users**
2. Clique em **"Add user"** > **"Create new user"**
3. Preencha:
   - **Email:** `seu-email@exemplo.com`
   - **Password:** `SuaSenhaSegura123!`
   - ✅ Marque: **Auto Confirm User**
4. Clique em **"Create user"**
5. **Copie o UUID gerado** (você vai precisar)

#### Opção B: Via SQL

Execute esta query no SQL Editor (substitua o UUID e email):

```sql
-- Inserir admin na tabela users
INSERT INTO public.users (
    id,  -- UUID do usuário criado no Supabase Auth
    email,
    full_name,
    role,
    active
) VALUES (
    'COLE-AQUI-O-UUID-DO-USUARIO-CRIADO',
    'seu-email@exemplo.com',
    'Administrador do Sistema',
    'ADMIN',
    true
);
```

---

### **PASSO 4: Verificar Instalação**

Execute estas queries para validar:

```sql
-- 1. Verificar tabelas criadas
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_type = 'BASE TABLE'
ORDER BY table_name;
-- Esperado: 12 tabelas

-- 2. Verificar funções
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public'
ORDER BY routine_name;
-- Esperado: ~10 funções

-- 3. Verificar views
SELECT table_name 
FROM information_schema.views 
WHERE table_schema = 'public'
ORDER BY table_name;
-- Esperado: 6 views

-- 4. Verificar RLS habilitado
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY tablename;
-- Esperado: rowsecurity = true em todas

-- 5. Verificar usuário admin
SELECT id, email, full_name, role, active 
FROM users 
WHERE role = 'ADMIN';
-- Esperado: 1 registro com seu email
```

---

## 🏗️ Estrutura Criada

### Tabelas Principais

| Tabela | Descrição | Registros Iniciais |
|--------|-----------|-------------------|
| `users` | Usuários do sistema | 1 (seu admin) |
| `produtos` | Catálogo de produtos | 0 |
| `produto_sabores` | Sabores/variações de produtos | 0 |
| `fornecedores` | Cadastro de fornecedores | 0 |
| `clientes` | Cadastro de clientes | 0 |
| `pedidos` | Pedidos de compra e venda | 0 |
| `pedido_itens` | Itens dos pedidos | 0 |
| `estoque_movimentacoes` | Histórico de movimentações | 0 |
| `pagamentos` | Histórico de pagamentos | 0 |
| `pre_pedidos` | Pedidos públicos (formulário) | 0 |
| `pre_pedido_itens` | Itens dos pré-pedidos | 0 |
| `empresa_config` | Configurações da empresa | 1 (padrão) |

### Funções Importantes

- `finalizar_pedido()` - Finaliza pedido e atualiza estoque
- `reverter_movimentacoes_pedido()` - Reverte ao cancelar/reabrir
- `verificar_movimentacao_existente()` - Previne duplicações
- `expirar_pre_pedidos()` - Expira pedidos públicos antigos
- `gerar_numero_pre_pedido()` - Gera numeração automática
- `atualizar_estoque_produto()` - Sincroniza estoque com sabores
- `update_pedido_total()` - Calcula total do pedido

### Proteções Implementadas

- ✅ **Duplicação de movimentações:** Constraint única
- ✅ **Cancelamento duplo:** Trigger de validação
- ✅ **Estoque negativo:** Validação na finalização
- ✅ **Race conditions:** Locks pessimistas (FOR UPDATE)
- ✅ **Sessões expiradas:** Verificação de status antes de finalizar
- ✅ **Permissões:** RLS por perfil de usuário

---

## 🔐 Perfis e Permissões

| Perfil | Pode Ver | Pode Criar | Pode Editar | Pode Deletar |
|--------|----------|------------|-------------|--------------|
| **ADMIN** | Tudo | Tudo | Tudo | Tudo |
| **COMPRADOR** | Produtos, Fornecedores, Pedidos COMPRA | Pedidos COMPRA | Rascunhos próprios | Rascunhos próprios |
| **APROVADOR** | Pedidos enviados | Não | Aprovar/Rejeitar | Não |
| **VENDEDOR** | Clientes, Vendas | Pedidos VENDA, Clientes | Rascunhos próprios | Rascunhos próprios |

---

## 📊 Próximos Passos

Após a instalação, você pode:

1. **Configurar a Empresa**
   - Acesse a página de Configurações
   - Adicione logo, nome, CNPJ, etc.

2. **Cadastrar Produtos**
   - Acesse Produtos
   - Cadastre marca, nome, preços
   - Adicione sabores (se aplicável)

3. **Cadastrar Fornecedores e Clientes**
   - Acesse os respectivos menus
   - Preencha os dados de cadastro

4. **Criar Usuários Adicionais**
   - Como ADMIN, acesse Usuários
   - Crie contas com perfis apropriados
   - Aprove os usuários

5. **Fazer Primeiro Pedido**
   - Teste o fluxo completo:
     - COMPRADOR cria pedido → APROVADOR aprova → ADMIN finaliza

---

## 🆘 Solução de Problemas

### ❌ Erro: "relation already exists"

**Causa:** Você está executando o schema em um banco que já tem tabelas.

**Solução:**
```sql
-- ⚠️ CUIDADO: Isso apaga TUDO!
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;

-- Agora execute o schema-completo.sql novamente
```

### ❌ Erro: "permission denied" ao criar policy

**Causa:** RLS já está habilitado com policies antigas.

**Solução:**
```sql
-- Desabilitar RLS temporariamente
ALTER TABLE nome_da_tabela DISABLE ROW LEVEL SECURITY;

-- Remover policies antigas
DROP POLICY IF EXISTS "nome_da_policy" ON nome_da_tabela;

-- Executar schema-rls-policies.sql novamente
```

### ❌ Erro: "new row violates check constraint"

**Causa:** Você está tentando inserir dados que violam as regras.

**Exemplo comum - Status inválido:**
```sql
-- ❌ ERRADO
INSERT INTO pedidos (status) VALUES ('TESTE');

-- ✅ CORRETO
INSERT INTO pedidos (status) VALUES ('RASCUNHO');
-- Status válidos: RASCUNHO, ENVIADO, APROVADO, REJEITADO, FINALIZADO, CANCELADO
```

### ❌ Erro: "Este pedido já foi finalizado anteriormente"

**Causa:** Proteção contra dupla finalização está funcionando.

**Solução:** Verifique o status do pedido:
```sql
SELECT numero, status, data_finalizacao 
FROM pedidos 
WHERE id = 'uuid-do-pedido';
```

Se já está FINALIZADO, não precisa finalizar de novo!

### ❌ Erro: "Estoque insuficiente"

**Causa:** Tentando vender mais do que tem em estoque.

**Solução:**
```sql
-- Verificar estoque atual
SELECT p.codigo, p.nome, ps.sabor, ps.quantidade
FROM produtos p
LEFT JOIN produto_sabores ps ON p.id = ps.produto_id
WHERE p.codigo = 'SEU-CODIGO';

-- Ajustar quantidade no pedido ou comprar mais produtos
```

---

## 📞 Suporte

Se encontrar problemas não listados aqui:

1. Verifique os logs do Supabase (aba Logs)
2. Consulte a documentação técnica (`DOCUMENTACAO_TECNICA.md`)
3. Revise os casos de uso (`CASOS_DE_USO.md`)

---

## ✅ Checklist de Instalação

- [ ] Schema base executado (`schema-completo.sql`)
- [ ] Políticas RLS executadas (`schema-rls-policies.sql`)
- [ ] Usuário ADMIN criado no Authentication
- [ ] Usuário ADMIN inserido na tabela `users`
- [ ] Verificações executadas (12 tabelas, funções, views)
- [ ] Login no sistema funcionando
- [ ] Teste de criação de produto
- [ ] Teste de criação de pedido
- [ ] Teste de finalização de pedido

---

## 🎉 Conclusão

Parabéns! Você configurou com sucesso o banco de dados completo do sistema.

**Recursos disponíveis:**
- ✅ Gestão de Produtos com Sabores
- ✅ Pedidos de Compra e Venda
- ✅ Controle de Estoque em Tempo Real
- ✅ Movimentações Rastreáveis
- ✅ Pré-Pedidos Públicos
- ✅ Pagamentos Parciais
- ✅ Proteções contra Duplicação
- ✅ Segurança por Perfil (RLS)

**Próxima etapa:** Configure a aplicação frontend para se conectar ao banco.

---

**Última atualização:** 14/01/2026  
**Versão do Schema:** 2.0 (Consolidado)
