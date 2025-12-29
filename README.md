# Sistema de Pedidos de Compra e Controle de Estoque

Sistema web completo e profissional para gerenciamento de pedidos de compra, aprovações e controle de estoque.

## 🚀 Tecnologias

- **Front-end**: HTML5, CSS3 (Tailwind CSS), JavaScript puro
- **Back-end**: Supabase (PostgreSQL + Auth + RLS)
- **Integração**: WhatsApp (wa.me)

## 📋 Funcionalidades

### Autenticação e Perfis
- Login e cadastro via Supabase Auth
- 3 perfis: ADMIN, COMPRADOR, APROVADOR
- Controle de permissões via RLS

### Cadastros
- **Produtos**: código, nome, categoria, estoque, preços
- **Fornecedores**: dados cadastrais e WhatsApp
- **Usuários**: gerenciamento de perfis

### Controle de Estoque
- Entrada manual de estoque
- Saída automática após finalização de pedido
- Alertas de estoque mínimo
- Histórico completo de movimentações

### Pedidos de Compra
- Criação de pedidos com múltiplos itens
- Status: Rascunho → Enviado → Aprovado → Finalizado
- Cálculo automático de totais
- Integração com WhatsApp para notificações

### Dashboard
- Visão geral de pedidos
- Alertas de estoque baixo
- Estatísticas em tempo real

## 🛠️ Instalação

### 1. Configurar Supabase

1. Crie uma conta em [supabase.com](https://supabase.com)
2. Crie um novo projeto
3. Execute o script SQL em `database/schema.sql`
4. Copie a URL e a chave anônima do projeto

### 2. Configurar o Projeto

1. Clone ou baixe este repositório
2. Edite o arquivo `js/config.js`:

```javascript
const SUPABASE_URL = 'SUA_URL_AQUI';
const SUPABASE_ANON_KEY = 'SUA_CHAVE_AQUI';
```

### 3. Executar o Projeto

Você pode usar qualquer servidor web local:

**Opção 1: Python**
```bash
python -m http.server 8000
```

**Opção 2: Node.js (http-server)**
```bash
npx http-server -p 8000
```

**Opção 3: VS Code Live Server**
- Instale a extensão "Live Server"
- Clique com botão direito em `index.html` → "Open with Live Server"

Acesse: `http://localhost:8000`

## 👤 Primeiro Acesso

1. Registre o primeiro usuário em `/pages/register.html`
2. No Supabase, vá em Authentication → Users
3. Copie o ID do usuário criado
4. Execute no SQL Editor:

```sql
UPDATE users SET role = 'ADMIN' WHERE id = 'ID_DO_USUARIO';
```

5. Faça login novamente para carregar as permissões

## 📱 Configuração do WhatsApp

Para integração com WhatsApp:

1. Configure o número do aprovador no cadastro de usuários
2. O formato deve ser: `5511999999999` (código do país + DDD + número)
3. Ao enviar um pedido para aprovação, um link WhatsApp será gerado automaticamente

## 🗂️ Estrutura do Projeto

```
pedidos-estoque-system/
├── index.html                 # Página de login
├── database/
│   └── schema.sql            # Script SQL completo
├── pages/                     # Páginas do sistema
│   ├── register.html
│   ├── dashboard.html
│   ├── produtos.html
│   ├── fornecedores.html
│   ├── usuarios.html
│   ├── estoque.html
│   ├── pedidos.html
│   └── aprovacao.html
├── components/                # Componentes reutilizáveis
│   ├── navbar.js
│   ├── sidebar.js
│   └── modal.js
├── js/                       # JavaScript
│   ├── config.js            # Configuração Supabase
│   ├── auth.js              # Autenticação
│   ├── services/            # Serviços
│   │   ├── produtos.js
│   │   ├── fornecedores.js
│   │   ├── usuarios.js
│   │   ├── estoque.js
│   │   └── pedidos.js
│   └── utils.js             # Funções utilitárias
├── css/
│   └── styles.css           # Estilos customizados
└── assets/
    └── logo.png             # Logo do sistema
```

## 🔒 Segurança

- Todas as tabelas possuem RLS (Row Level Security) habilitado
- Políticas de acesso baseadas em perfis
- Autenticação via Supabase Auth (JWT)
- Proteção contra SQL Injection via prepared statements

## 📊 Banco de Dados

### Tabelas
- `users` - Usuários e perfis
- `produtos` - Catálogo de produtos
- `fornecedores` - Cadastro de fornecedores
- `pedidos` - Pedidos de compra
- `pedido_itens` - Itens dos pedidos
- `estoque_movimentacoes` - Histórico de movimentações

Ver detalhes em `database/schema.sql`

## 🎨 Personalização

### Cores
Edite as cores no arquivo `css/styles.css` ou nas classes Tailwind do HTML.

### Logo
Substitua `assets/logo.png` pela logo da sua empresa.

## 📞 Suporte

Para dúvidas e suporte, consulte a documentação do Supabase: https://supabase.com/docs

## 📄 Licença

Este projeto é fornecido como está, para uso educacional e comercial.
