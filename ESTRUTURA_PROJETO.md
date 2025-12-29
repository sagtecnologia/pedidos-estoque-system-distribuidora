# 📁 ESTRUTURA COMPLETA DO PROJETO

## Sistema de Pedidos de Compra e Controle de Estoque

---

## 📂 Árvore de Diretórios

```
pedidos-estoque-system/
│
├── 📄 index.html                           # Página de login (entrada do sistema)
├── 📄 README.md                            # Documentação principal
├── 📄 INSTALACAO.md                        # Guia completo de instalação
├── 📄 DOCUMENTACAO_TECNICA.md              # Documentação técnica detalhada
├── 📄 CASOS_DE_USO.md                      # Casos de uso e exemplos práticos
├── 📄 RESUMO_EXECUTIVO.md                  # Visão executiva do projeto
├── 📄 ESTRUTURA_PROJETO.md                 # Este arquivo
├── 📄 .gitignore                           # Arquivos ignorados pelo Git
│
├── 📂 database/                            # Scripts de banco de dados
│   └── 📄 schema.sql                       # Schema completo do PostgreSQL
│
├── 📂 pages/                               # Páginas HTML do sistema
│   ├── 📄 register.html                    # Cadastro de novo usuário
│   ├── 📄 dashboard.html                   # Dashboard principal
│   ├── 📄 produtos.html                    # CRUD de produtos
│   ├── 📄 fornecedores.html                # CRUD de fornecedores
│   ├── 📄 usuarios.html                    # Gestão de usuários (ADMIN)
│   ├── 📄 estoque.html                     # Movimentações de estoque
│   ├── 📄 pedidos.html                     # Listagem de pedidos
│   ├── 📄 pedido-detalhe.html              # Detalhes e edição de pedido
│   └── 📄 aprovacao.html                   # Aprovação de pedidos
│
├── 📂 components/                          # Componentes JavaScript reutilizáveis
│   ├── 📄 navbar.js                        # Barra de navegação superior
│   ├── 📄 sidebar.js                       # Menu lateral
│   └── 📄 modal.js                         # Sistema de modais
│
├── 📂 js/                                  # JavaScript
│   ├── 📄 config.js                        # Configuração do Supabase
│   ├── 📄 auth.js                          # Autenticação (login, logout, etc)
│   ├── 📄 utils.js                         # Funções utilitárias
│   └── 📂 services/                        # Camada de serviços (API)
│       ├── 📄 produtos.js                  # CRUD e operações de produtos
│       ├── 📄 fornecedores.js              # CRUD e operações de fornecedores
│       ├── 📄 usuarios.js                  # CRUD e operações de usuários
│       ├── 📄 estoque.js                   # Movimentações de estoque
│       └── 📄 pedidos.js                   # Operações de pedidos e aprovações
│
├── 📂 css/                                 # Estilos
│   └── 📄 styles.css                       # Estilos customizados
│
└── 📂 assets/                              # Recursos estáticos
    └── 📄 logo.svg                         # Logo do sistema
```

---

## 📋 DESCRIÇÃO DOS ARQUIVOS

### 📄 Raiz do Projeto

#### index.html
- **Função**: Página inicial/login do sistema
- **Descrição**: Primeira página que o usuário vê, contém formulário de login
- **Tecnologias**: HTML5, Tailwind CSS, JavaScript

#### README.md
- **Função**: Documentação principal
- **Conteúdo**: Visão geral, funcionalidades, tecnologias, instruções básicas

#### INSTALACAO.md
- **Função**: Guia de instalação completo
- **Conteúdo**: Passo a passo detalhado, configuração do Supabase, troubleshooting

#### DOCUMENTACAO_TECNICA.md
- **Função**: Documentação técnica
- **Conteúdo**: Arquitetura, modelo de dados, segurança, APIs

#### CASOS_DE_USO.md
- **Função**: Exemplos práticos
- **Conteúdo**: Casos de uso, cenários reais, fluxos de trabalho

#### RESUMO_EXECUTIVO.md
- **Função**: Visão executiva
- **Conteúdo**: Benefícios, ROI, métricas, custos

#### .gitignore
- **Função**: Configuração do Git
- **Conteúdo**: Lista de arquivos/pastas a serem ignorados

---

### 📂 database/

#### schema.sql
- **Tamanho**: ~15KB
- **Linhas**: ~700 linhas
- **Conteúdo**:
  - Criação de 6 tabelas principais
  - Relacionamentos (foreign keys)
  - Triggers e funções SQL
  - Row Level Security (RLS) policies
  - Views úteis
  - Índices para performance

**Tabelas criadas:**
1. users
2. produtos
3. fornecedores
4. pedidos
5. pedido_itens
6. estoque_movimentacoes

---

### 📂 pages/

#### register.html
- **Função**: Cadastro de novos usuários
- **Campos**: Nome, email, senha
- **Perfil padrão**: COMPRADOR

#### dashboard.html
- **Função**: Dashboard principal do sistema
- **Exibe**:
  - Cards de estatísticas
  - Produtos com estoque baixo
  - Últimos pedidos
  - Alertas importantes

#### produtos.html
- **Função**: CRUD completo de produtos
- **Operações**:
  - Listar produtos
  - Criar produto
  - Editar produto
  - Excluir produto (soft delete)
  - Filtrar por categoria
  - Buscar por nome/código

#### fornecedores.html
- **Função**: CRUD completo de fornecedores
- **Operações**:
  - Listar fornecedores
  - Criar fornecedor
  - Editar fornecedor
  - Excluir fornecedor (soft delete)
  - Buscar por nome/CNPJ

#### usuarios.html
- **Função**: Gestão de usuários (apenas ADMIN)
- **Operações**:
  - Listar usuários
  - Editar perfil de usuário
  - Ativar/desativar usuário
  - Configurar WhatsApp

#### estoque.html
- **Função**: Controle de movimentações de estoque
- **Operações**:
  - Criar entrada manual
  - Criar saída manual
  - Visualizar histórico completo
  - Filtrar por produto/tipo

#### pedidos.html
- **Função**: Listagem de pedidos de compra
- **Operações**:
  - Listar pedidos
  - Criar novo pedido
  - Filtrar por status
  - Buscar por número
  - Acessar detalhes

#### pedido-detalhe.html
- **Função**: Detalhes e edição de pedido
- **Operações**:
  - Visualizar informações completas
  - Adicionar/remover itens (se RASCUNHO)
  - Enviar para aprovação
  - Finalizar pedido (se ADMIN e APROVADO)

#### aprovacao.html
- **Função**: Aprovação de pedidos (APROVADOR/ADMIN)
- **Operações**:
  - Listar pedidos pendentes
  - Visualizar detalhes
  - Aprovar pedido
  - Rejeitar pedido com motivo
  - Enviar via WhatsApp

---

### 📂 components/

#### navbar.js
- **Função**: Barra de navegação superior
- **Exibe**:
  - Logo e nome do sistema
  - Nome do usuário logado
  - Perfil do usuário
  - Botão de logout
  - Toggle do menu (mobile)

#### sidebar.js
- **Função**: Menu lateral de navegação
- **Exibe**:
  - Links para todas as páginas
  - Controle de visibilidade por permissão
  - Destaque do item ativo
  - Responsivo (mobile)

#### modal.js
- **Função**: Sistema de modais reutilizáveis
- **Recursos**:
  - Criar modal dinamicamente
  - Abrir/fechar modal
  - Backdrop clicável
  - Fechamento com ESC
  - Tamanhos configuráveis (sm, md, lg, xl)

---

### 📂 js/

#### config.js
- **Função**: Configuração central do Supabase
- **Conteúdo**:
  - URL do projeto Supabase
  - Chave anônima (anon key)
  - Inicialização do cliente Supabase

#### auth.js
- **Função**: Gerenciamento de autenticação
- **Funções**:
  - `login(email, password)`
  - `register(email, password, fullName, role)`
  - `logout()`
  - `changePassword(newPassword)`
  - `resetPassword(email)`

#### utils.js
- **Função**: Funções utilitárias globais
- **Funções**:
  - `showToast()` - Notificações
  - `formatCurrency()` - Formatação de moeda
  - `formatDate()` - Formatação de data
  - `formatCNPJ()` - Formatação de CNPJ
  - `generateOrderNumber()` - Gerar número de pedido
  - `generateWhatsAppLink()` - Criar link WhatsApp
  - `checkAuth()` - Verificar autenticação
  - `getCurrentUser()` - Obter usuário atual
  - `hasRole()` - Verificar permissão
  - `getStatusBadge()` - Badge de status
  - `debounce()` - Debounce para buscas
  - `handleError()` - Tratamento de erros

---

### 📂 js/services/

#### produtos.js
- **Funções**:
  - `listProdutos(filters)` - Listar produtos
  - `getProduto(id)` - Buscar produto por ID
  - `createProduto(produto)` - Criar produto
  - `updateProduto(id, produto)` - Atualizar produto
  - `deleteProduto(id)` - Excluir produto
  - `getProdutosEstoqueBaixo()` - Produtos com estoque baixo
  - `getCategorias()` - Listar categorias

#### fornecedores.js
- **Funções**:
  - `listFornecedores(filters)` - Listar fornecedores
  - `getFornecedor(id)` - Buscar fornecedor por ID
  - `createFornecedor(fornecedor)` - Criar fornecedor
  - `updateFornecedor(id, fornecedor)` - Atualizar fornecedor
  - `deleteFornecedor(id)` - Excluir fornecedor

#### usuarios.js
- **Funções**:
  - `listUsuarios(filters)` - Listar usuários
  - `getUsuario(id)` - Buscar usuário por ID
  - `updateUsuario(id, usuario)` - Atualizar usuário
  - `deactivateUsuario(id)` - Desativar usuário
  - `activateUsuario(id)` - Ativar usuário
  - `getAprovadores()` - Listar aprovadores

#### estoque.js
- **Funções**:
  - `listMovimentacoes(filters)` - Listar movimentações
  - `criarEntradaEstoque(prodId, qtd, obs)` - Entrada de estoque
  - `criarSaidaEstoque(prodId, qtd, obs)` - Saída de estoque
  - `getHistoricoProduto(produtoId)` - Histórico de produto
  - `getRelatorioEstoque()` - Relatório geral

#### pedidos.js
- **Funções**:
  - `listPedidos(filters)` - Listar pedidos
  - `getPedido(id)` - Buscar pedido por ID
  - `getItensPedido(pedidoId)` - Itens do pedido
  - `createPedido(pedido)` - Criar pedido
  - `addItemPedido(pedidoId, item)` - Adicionar item
  - `removeItemPedido(itemId)` - Remover item
  - `enviarPedido(pedidoId)` - Enviar para aprovação
  - `aprovarPedido(pedidoId)` - Aprovar pedido
  - `rejeitarPedido(pedidoId, motivo)` - Rejeitar pedido
  - `finalizarPedido(pedidoId)` - Finalizar e baixar estoque
  - `enviarWhatsAppAprovacao(id)` - Enviar notificação WhatsApp
  - `getEstatisticasPedidos()` - Estatísticas

---

### 📂 css/

#### styles.css
- **Conteúdo**:
  - Animações (fade-in, fade-out, pulse)
  - Loading spinner
  - Scrollbar customizada
  - Cards com hover
  - Tabelas responsivas
  - Badges de status
  - Modal backdrop
  - Sidebar responsiva
  - Inputs com foco
  - Alertas de estoque
  - Print styles
  - Utilities (truncate, line-clamp)

---

### 📂 assets/

#### logo.svg
- **Formato**: SVG
- **Tamanho**: 200x200px
- **Conteúdo**: Logo "SC" (Sistema de Compras)
- **Personalizável**: Sim, substitua por sua logo

---

## 📊 ESTATÍSTICAS DO PROJETO

### Resumo Geral

```
Total de Arquivos: 31
Total de Linhas de Código: ~8.000
Total de Funções JavaScript: ~80
Total de Páginas HTML: 9
Total de Tabelas no Banco: 6
Total de Políticas RLS: ~25
```

### Distribuição por Tipo

| Tipo        | Quantidade | Linhas |
|-------------|------------|--------|
| HTML        | 9          | ~2.000 |
| JavaScript  | 13         | ~4.000 |
| SQL         | 1          | ~700   |
| CSS         | 1          | ~200   |
| Markdown    | 7          | ~1.100 |
| SVG         | 1          | ~10    |

### Complexidade

- **Simples**: pages/register.html, components/modal.js
- **Média**: js/services/*, pages/produtos.html
- **Complexa**: database/schema.sql, js/services/pedidos.js

---

## 🔧 MANUTENÇÃO

### Arquivos que você DEVE modificar

✅ **js/config.js**
- Inserir suas credenciais do Supabase
- OBRIGATÓRIO para funcionamento

✅ **assets/logo.svg** (opcional)
- Substituir pela logo da sua empresa

✅ **css/styles.css** (opcional)
- Ajustar cores e estilos conforme identidade visual

### Arquivos que você NÃO deve modificar

❌ **database/schema.sql**
- Apenas execute no Supabase
- Não altere a menos que saiba o que está fazendo

❌ **components/***
- Componentes base do sistema
- Alterações podem quebrar funcionalidades

❌ **js/utils.js**
- Funções essenciais
- Use mas não modifique

### Arquivos que você PODE customizar

🔧 **pages/***
- Adicionar campos
- Alterar layout
- Incluir validações extras

🔧 **js/services/***
- Adicionar novas funções
- Estender funcionalidades
- Incluir validações de negócio

---

## 📝 CHECKLIST DE ARQUIVOS

Use este checklist para verificar se todos os arquivos foram criados:

### Raiz
- [x] index.html
- [x] README.md
- [x] INSTALACAO.md
- [x] DOCUMENTACAO_TECNICA.md
- [x] CASOS_DE_USO.md
- [x] RESUMO_EXECUTIVO.md
- [x] ESTRUTURA_PROJETO.md
- [x] .gitignore

### Database
- [x] database/schema.sql

### Pages
- [x] pages/register.html
- [x] pages/dashboard.html
- [x] pages/produtos.html
- [x] pages/fornecedores.html
- [x] pages/usuarios.html
- [x] pages/estoque.html
- [x] pages/pedidos.html
- [x] pages/pedido-detalhe.html
- [x] pages/aprovacao.html

### Components
- [x] components/navbar.js
- [x] components/sidebar.js
- [x] components/modal.js

### JavaScript
- [x] js/config.js
- [x] js/auth.js
- [x] js/utils.js
- [x] js/services/produtos.js
- [x] js/services/fornecedores.js
- [x] js/services/usuarios.js
- [x] js/services/estoque.js
- [x] js/services/pedidos.js

### CSS
- [x] css/styles.css

### Assets
- [x] assets/logo.svg

---

## ✅ PROJETO COMPLETO!

Todos os arquivos foram criados e documentados.

**Sistema pronto para implantação!** 🚀

Próximos passos:
1. Leia `INSTALACAO.md`
2. Configure o Supabase
3. Execute localmente
4. Teste todas as funcionalidades
5. Publique em produção

---

**Versão:** 1.0.0  
**Data:** Dezembro 2024
