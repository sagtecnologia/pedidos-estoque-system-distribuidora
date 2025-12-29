# 📚 DOCUMENTAÇÃO TÉCNICA
## Sistema de Pedidos de Compra e Controle de Estoque

---

## 📐 ARQUITETURA DO SISTEMA

### Stack Tecnológico

```
┌─────────────────────────────────────────┐
│           FRONT-END                      │
│  HTML5 + CSS3 (Tailwind) + JavaScript   │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         SUPABASE CLIENT                  │
│     (JavaScript SDK v2)                  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│           SUPABASE                       │
│  PostgreSQL + Auth + RLS + Storage       │
└─────────────────────────────────────────┘
```

### Estrutura de Pastas

```
pedidos-estoque-system/
│
├── index.html                    # Página de login
├── README.md                     # Documentação principal
├── INSTALACAO.md                 # Guia de instalação
├── .gitignore                    # Arquivos ignorados pelo Git
│
├── database/
│   └── schema.sql                # Script SQL completo
│
├── pages/                        # Páginas HTML
│   ├── register.html             # Cadastro de usuário
│   ├── dashboard.html            # Dashboard principal
│   ├── produtos.html             # CRUD de produtos
│   ├── fornecedores.html         # CRUD de fornecedores
│   ├── usuarios.html             # Gestão de usuários
│   ├── estoque.html              # Movimentações de estoque
│   ├── pedidos.html              # Listagem de pedidos
│   ├── pedido-detalhe.html       # Detalhes e edição de pedido
│   └── aprovacao.html            # Aprovação de pedidos
│
├── components/                   # Componentes JavaScript
│   ├── navbar.js                 # Barra de navegação
│   ├── sidebar.js                # Menu lateral
│   └── modal.js                  # Sistema de modais
│
├── js/                           # Scripts JavaScript
│   ├── config.js                 # Configuração Supabase
│   ├── auth.js                   # Autenticação
│   ├── utils.js                  # Funções utilitárias
│   └── services/                 # Serviços de dados
│       ├── produtos.js
│       ├── fornecedores.js
│       ├── usuarios.js
│       ├── estoque.js
│       └── pedidos.js
│
├── css/
│   └── styles.css                # Estilos customizados
│
└── assets/
    └── logo.svg                  # Logo do sistema
```

---

## 🗄️ MODELO DE DADOS

### Diagrama ER

```
┌──────────────┐         ┌──────────────────┐
│    users     │────┬───▶│    produtos      │
│              │    │    │                  │
│ - id (PK)    │    │    │ - id (PK)        │
│ - email      │    │    │ - codigo         │
│ - full_name  │    │    │ - nome           │
│ - role       │    │    │ - categoria      │
│ - whatsapp   │    │    │ - estoque_atual  │
│ - active     │    │    │ - estoque_minimo │
└──────────────┘    │    │ - preco          │
        │           │    │ - created_by (FK)│
        │           │    └──────────────────┘
        │           │             │
        │           │             │
        │           │    ┌──────────────────────┐
        │           │    │ estoque_movimentacoes│
        │           │    │                      │
        │           └───▶│ - produto_id (FK)    │
        │                │ - tipo               │
        │                │ - quantidade         │
        │                │ - usuario_id (FK)    │
        │                │ - pedido_id (FK)     │
        │                └──────────────────────┘
        │
        │    ┌──────────────────┐
        └───▶│  fornecedores    │
             │                  │
             │ - id (PK)        │
             │ - nome           │
             │ - cnpj           │
             │ - whatsapp       │
             │ - created_by (FK)│
             └──────────────────┘
                      │
        ┌─────────────┴──────────────┐
        │                            │
┌──────────────┐            ┌─────────────────┐
│   pedidos    │────────────│ pedido_itens    │
│              │            │                 │
│ - id (PK)    │            │ - id (PK)       │
│ - numero     │◀───────────│ - pedido_id (FK)│
│ - status     │            │ - produto_id(FK)│
│ - total      │            │ - quantidade    │
│ - solicitante_id (FK)     │ - preco_unit    │
│ - aprovador_id (FK)       │ - subtotal      │
│ - fornecedor_id (FK)      └─────────────────┘
└──────────────┘
```

### Tabelas

#### 1. users
Estende `auth.users` do Supabase com informações adicionais.

```sql
- id: UUID (PK, FK para auth.users)
- email: VARCHAR(255) UNIQUE
- full_name: VARCHAR(255)
- role: ENUM('ADMIN', 'COMPRADOR', 'APROVADOR')
- whatsapp: VARCHAR(20)
- active: BOOLEAN
- created_at, updated_at: TIMESTAMP
```

#### 2. produtos
Catálogo de produtos do sistema.

```sql
- id: UUID (PK)
- codigo: VARCHAR(50) UNIQUE
- nome: VARCHAR(255)
- categoria: VARCHAR(100)
- unidade: VARCHAR(20)
- estoque_atual: DECIMAL(10,2)
- estoque_minimo: DECIMAL(10,2)
- preco: DECIMAL(10,2)
- active: BOOLEAN
- created_by: UUID (FK users)
- created_at, updated_at: TIMESTAMP
```

#### 3. fornecedores
Cadastro de fornecedores.

```sql
- id: UUID (PK)
- nome: VARCHAR(255)
- cnpj: VARCHAR(18) UNIQUE
- contato: VARCHAR(255)
- whatsapp: VARCHAR(20)
- email: VARCHAR(255)
- endereco: TEXT
- active: BOOLEAN
- created_by: UUID (FK users)
- created_at, updated_at: TIMESTAMP
```

#### 4. pedidos
Pedidos de compra.

```sql
- id: UUID (PK)
- numero: VARCHAR(50) UNIQUE
- solicitante_id: UUID (FK users)
- fornecedor_id: UUID (FK fornecedores)
- aprovador_id: UUID (FK users)
- status: ENUM('RASCUNHO', 'ENVIADO', 'APROVADO', 'REJEITADO', 'FINALIZADO')
- total: DECIMAL(10,2)
- observacoes: TEXT
- motivo_rejeicao: TEXT
- data_aprovacao: TIMESTAMP
- data_finalizacao: TIMESTAMP
- created_at, updated_at: TIMESTAMP
```

#### 5. pedido_itens
Itens de cada pedido.

```sql
- id: UUID (PK)
- pedido_id: UUID (FK pedidos, ON DELETE CASCADE)
- produto_id: UUID (FK produtos)
- quantidade: DECIMAL(10,2)
- preco_unitario: DECIMAL(10,2)
- subtotal: DECIMAL(10,2) GENERATED (quantidade * preco_unitario)
- created_at: TIMESTAMP
```

#### 6. estoque_movimentacoes
Histórico de entradas e saídas de estoque.

```sql
- id: UUID (PK)
- produto_id: UUID (FK produtos)
- tipo: ENUM('ENTRADA', 'SAIDA')
- quantidade: DECIMAL(10,2)
- estoque_anterior: DECIMAL(10,2)
- estoque_novo: DECIMAL(10,2)
- pedido_id: UUID (FK pedidos, nullable)
- usuario_id: UUID (FK users)
- observacao: TEXT
- created_at: TIMESTAMP
```

---

## 🔐 SEGURANÇA (RLS)

### Row Level Security (RLS)

Todas as tabelas possuem RLS habilitado. As policies principais são:

#### Produtos
- **SELECT**: Todos usuários autenticados podem ver produtos ativos
- **INSERT/UPDATE**: ADMIN e COMPRADOR podem criar/editar
- **DELETE**: Apenas ADMIN

#### Fornecedores
- **SELECT**: Todos usuários autenticados podem ver fornecedores ativos
- **INSERT/UPDATE**: ADMIN e COMPRADOR podem criar/editar
- **DELETE**: Apenas ADMIN

#### Pedidos
- **SELECT**: 
  - Solicitante pode ver seus pedidos
  - APROVADOR pode ver pedidos enviados
  - ADMIN pode ver todos
- **INSERT**: COMPRADOR e ADMIN podem criar
- **UPDATE**: 
  - Solicitante pode editar RASCUNHO
  - APROVADOR pode aprovar/rejeitar ENVIADO
  - ADMIN pode finalizar APROVADO

#### Usuários
- **SELECT**: Todos podem ver usuários ativos
- **UPDATE**: Apenas ADMIN pode editar

#### Estoque
- **SELECT**: Todos podem ver movimentações
- **INSERT**: Apenas ADMIN (movimentações manuais)

---

## 🔄 FLUXO DE PROCESSOS

### Fluxo de Pedido de Compra

```
┌─────────────┐
│  RASCUNHO   │ ──▶ COMPRADOR cria pedido e adiciona itens
└─────────────┘
       │
       │ Enviar para Aprovação
       ▼
┌─────────────┐
│   ENVIADO   │ ──▶ Notificação via WhatsApp (opcional)
└─────────────┘
       │
       ├──────────────┬──────────────┐
       │ Aprovar      │ Rejeitar     │
       ▼              ▼              │
┌─────────────┐  ┌──────────────┐   │
│  APROVADO   │  │  REJEITADO   │◀──┘
└─────────────┘  └──────────────┘
       │
       │ Finalizar (ADMIN)
       ▼
┌─────────────┐
│ FINALIZADO  │ ──▶ Baixa automática de estoque
└─────────────┘
```

### Movimentação de Estoque

**Entrada Manual:**
```
ADMIN → Cria movimentação ENTRADA
      → Produto.estoque_atual += quantidade
      → Registra em estoque_movimentacoes
```

**Saída Manual:**
```
ADMIN → Cria movimentação SAIDA
      → Produto.estoque_atual -= quantidade
      → Registra em estoque_movimentacoes
```

**Saída Automática (Finalização de Pedido):**
```
ADMIN → Finaliza pedido APROVADO
      → Para cada item do pedido:
          • Produto.estoque_atual -= quantidade
          • Cria movimentação SAIDA
          • Vincula à movimentação o pedido_id
      → Atualiza pedido.status = FINALIZADO
```

---

## 🔧 FUNÇÕES SQL PRINCIPAIS

### 1. processar_movimentacao_estoque

Processa entrada ou saída de estoque:

```sql
processar_movimentacao_estoque(
    p_produto_id UUID,
    p_tipo VARCHAR,
    p_quantidade DECIMAL,
    p_usuario_id UUID,
    p_pedido_id UUID DEFAULT NULL,
    p_observacao TEXT DEFAULT NULL
) RETURNS UUID
```

**Funcionalidade:**
- Valida estoque disponível (para saídas)
- Atualiza estoque do produto
- Cria registro de movimentação
- Retorna ID da movimentação criada

### 2. finalizar_pedido

Finaliza pedido e baixa estoque automaticamente:

```sql
finalizar_pedido(
    p_pedido_id UUID,
    p_usuario_id UUID
) RETURNS BOOLEAN
```

**Funcionalidade:**
- Valida se pedido está APROVADO
- Para cada item do pedido:
  - Chama `processar_movimentacao_estoque`
  - Registra saída vinculada ao pedido
- Atualiza status para FINALIZADO
- Retorna TRUE em sucesso

### 3. update_pedido_total (Trigger)

Atualiza automaticamente o total do pedido quando itens são adicionados/removidos/editados.

---

## 🎨 COMPONENTES DO FRONT-END

### Navbar (`components/navbar.js`)

```javascript
createNavbar() → HTML string
initNavbar() → Carrega dados do usuário
```

### Sidebar (`components/sidebar.js`)

```javascript
createSidebar() → HTML string
initSidebar() → Marca item ativo, controla permissões
```

### Modal (`components/modal.js`)

```javascript
createModal(id, title, content, size)
openModal(id)
closeModal(id)
```

---

## 📡 SERVIÇOS (API)

### produtos.js

```javascript
listProdutos(filters)           → Promise<Produto[]>
getProduto(id)                  → Promise<Produto>
createProduto(produto)          → Promise<Produto>
updateProduto(id, produto)      → Promise<Produto>
deleteProduto(id)               → Promise<boolean>
getProdutosEstoqueBaixo()       → Promise<Produto[]>
getCategorias()                 → Promise<string[]>
```

### fornecedores.js

```javascript
listFornecedores(filters)       → Promise<Fornecedor[]>
getFornecedor(id)               → Promise<Fornecedor>
createFornecedor(fornecedor)    → Promise<Fornecedor>
updateFornecedor(id, fornec.)   → Promise<Fornecedor>
deleteFornecedor(id)            → Promise<boolean>
```

### pedidos.js

```javascript
listPedidos(filters)            → Promise<Pedido[]>
getPedido(id)                   → Promise<Pedido>
getItensPedido(pedidoId)        → Promise<PedidoItem[]>
createPedido(pedido)            → Promise<Pedido>
addItemPedido(pedidoId, item)   → Promise<PedidoItem>
removeItemPedido(itemId)        → Promise<boolean>
enviarPedido(pedidoId)          → Promise<Pedido>
aprovarPedido(pedidoId)         → Promise<Pedido>
rejeitarPedido(pedidoId, motivo)→ Promise<Pedido>
finalizarPedido(pedidoId)       → Promise<boolean>
enviarWhatsAppAprovacao(id)     → void
getEstatisticasPedidos()        → Promise<Object>
```

### estoque.js

```javascript
listMovimentacoes(filters)      → Promise<Movimentacao[]>
criarEntradaEstoque(prodId, qtd, obs) → Promise<UUID>
criarSaidaEstoque(prodId, qtd, obs)   → Promise<UUID>
getHistoricoProduto(produtoId)  → Promise<Movimentacao[]>
getRelatorioEstoque()           → Promise<Object[]>
```

---

## 🧪 TESTES

### Cenários de Teste

#### 1. Autenticação
- [ ] Cadastro de novo usuário
- [ ] Login com credenciais válidas
- [ ] Login com credenciais inválidas
- [ ] Logout

#### 2. Produtos
- [ ] Criar produto
- [ ] Editar produto
- [ ] Excluir produto (soft delete)
- [ ] Listar produtos
- [ ] Filtrar por categoria
- [ ] Buscar por nome/código

#### 3. Estoque
- [ ] Criar entrada manual
- [ ] Criar saída manual
- [ ] Verificar estoque após movimentação
- [ ] Alerta de estoque baixo
- [ ] Histórico de movimentações

#### 4. Pedidos
- [ ] Criar pedido como COMPRADOR
- [ ] Adicionar/remover itens
- [ ] Enviar para aprovação
- [ ] Aprovar como APROVADOR
- [ ] Rejeitar com motivo
- [ ] Finalizar como ADMIN
- [ ] Verificar baixa de estoque

#### 5. WhatsApp
- [ ] Link gerado corretamente
- [ ] Mensagem formatada
- [ ] Link funcional

---

## 🚀 PERFORMANCE

### Otimizações Implementadas

1. **Índices no Banco**
   - Índices em colunas frequentemente consultadas
   - Índice composto para estoque baixo
   - Índices em foreign keys

2. **Consultas Otimizadas**
   - SELECT com campos específicos
   - JOIN apenas quando necessário
   - LIMIT em listagens

3. **Front-end**
   - Debounce em buscas
   - Loading states
   - Caching de dados estáticos

4. **RLS**
   - Policies específicas por operação
   - Uso de EXISTS para validações

---

## 📊 MONITORAMENTO

### Logs do Supabase

Acesse: **Supabase → Logs**

- **API**: Requisições e erros
- **Database**: Queries lentas
- **Auth**: Tentativas de login

### Console do Navegador

Pressione F12 para ver:
- Erros JavaScript
- Requisições de rede
- Mensagens de debug

---

## 🔄 MANUTENÇÃO

### Backup do Banco

```sql
-- Executar no SQL Editor do Supabase
pg_dump nome_do_banco > backup.sql
```

### Atualização de Schema

1. Sempre faça backup antes
2. Teste em ambiente de desenvolvimento
3. Execute migrações incrementais
4. Verifique policies RLS

### Monitoramento de Estoque

Configure alertas automáticos:
- Email quando estoque < mínimo
- Relatório semanal de produtos baixos

---

## 📝 CHANGELOG

### v1.0.0 (2024)
- ✅ Sistema completo de autenticação
- ✅ CRUD de produtos, fornecedores e usuários
- ✅ Controle de estoque com entrada/saída
- ✅ Fluxo completo de pedidos
- ✅ Aprovação de pedidos
- ✅ Integração WhatsApp
- ✅ Dashboard com estatísticas
- ✅ RLS completo
- ✅ Documentação técnica

---

## 📞 SUPORTE TÉCNICO

### Links Úteis

- **Supabase Docs**: https://supabase.com/docs
- **Tailwind CSS**: https://tailwindcss.com/docs
- **PostgreSQL**: https://www.postgresql.org/docs/

### Troubleshooting

Consulte `INSTALACAO.md` seção 7 para problemas comuns.

---

**Documentação Versão 1.0**
