# 📦 GUIA COMPLETO DE IMPLANTAÇÃO
# Sistema de Pedidos de Compra e Controle de Estoque

## 📋 SUMÁRIO
1. [Configuração do Supabase](#1-configuração-do-supabase)
2. [Configuração do Projeto](#2-configuração-do-projeto)
3. [Primeiro Acesso](#3-primeiro-acesso)
4. [Testando o Sistema](#4-testando-o-sistema)
5. [Configuração do WhatsApp](#5-configuração-do-whatsapp)
6. [Deploy em Produção](#6-deploy-em-produção)
7. [Solução de Problemas](#7-solução-de-problemas)

---

## 1. CONFIGURAÇÃO DO SUPABASE

### Passo 1.1: Criar Conta e Projeto

1. Acesse [supabase.com](https://supabase.com)
2. Clique em "Start your project"
3. Faça login com GitHub, Google ou Email
4. Clique em "New Project"
5. Preencha:
   - **Nome do projeto**: `pedidos-estoque` (ou nome de sua preferência)
   - **Database Password**: Crie uma senha forte e **ANOTE**
   - **Region**: Escolha a região mais próxima (ex: South America - São Paulo)
6. Clique em "Create new project"
7. Aguarde 2-3 minutos para o projeto ser criado

### Passo 1.2: Executar Script SQL

1. No painel do Supabase, vá em **SQL Editor** (ícone de banco de dados na lateral)
2. Clique em "+ New Query"
3. Abra o arquivo `database/schema.sql` deste projeto
4. **COPIE TODO O CONTEÚDO** do arquivo
5. **COLE** no editor SQL do Supabase
6. Clique em **RUN** (ou pressione Ctrl+Enter)
7. Aguarde a execução (pode levar 10-15 segundos)
8. Verifique se aparecer "Success. No rows returned" (isso é normal)

### Passo 1.3: Obter Credenciais

1. No painel do Supabase, vá em **Project Settings** (ícone de engrenagem)
2. Clique em **API** no menu lateral
3. Você verá duas informações importantes:

   **Project URL:**
   ```
   https://xxxxxxxxxxxxx.supabase.co
   ```

   **anon public (Key):**
   ```
   eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```

4. **COPIE E SALVE** essas informações em um lugar seguro

---

## 2. CONFIGURAÇÃO DO PROJETO

### Passo 2.1: Baixar o Projeto

Se você recebeu o projeto em um ZIP:
1. Extraia o arquivo ZIP
2. Você terá uma pasta chamada `pedidos-estoque-system`

### Passo 2.2: Configurar Credenciais do Supabase

1. Abra a pasta do projeto
2. Navegue até: `js/config.js`
3. Abra o arquivo em um editor de texto (Notepad, VS Code, etc.)
4. Localize as linhas:

```javascript
const SUPABASE_URL = 'https://seu-projeto.supabase.co';
const SUPABASE_ANON_KEY = 'sua-chave-anonima-aqui';
```

5. **SUBSTITUA** pelas suas credenciais:

```javascript
const SUPABASE_URL = 'https://xxxxxxxxxxxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

6. **SALVE** o arquivo

---

## 3. PRIMEIRO ACESSO

### Passo 3.1: Executar o Projeto Localmente

Você tem 3 opções:

**OPÇÃO A - Python (mais simples)**
1. Abra o terminal/prompt na pasta do projeto
2. Execute:
   ```bash
   python -m http.server 8000
   ```
3. Abra o navegador em: `http://localhost:8000`

**OPÇÃO B - Node.js**
1. Abra o terminal/prompt na pasta do projeto
2. Execute:
   ```bash
   npx http-server -p 8000
   ```
3. Abra o navegador em: `http://localhost:8000`

**OPÇÃO C - VS Code Live Server**
1. Abra a pasta do projeto no VS Code
2. Instale a extensão "Live Server"
3. Clique com botão direito em `index.html`
4. Selecione "Open with Live Server"

### Passo 3.2: Criar Primeiro Usuário

1. Na tela de login, clique em **"Cadastre-se"**
2. Preencha:
   - **Nome Completo**: Seu nome
   - **Email**: Seu email
   - **Senha**: Mínimo 6 caracteres
   - **Confirmar Senha**: Mesma senha
3. Clique em **"Cadastrar"**
4. Você será redirecionado para a tela de login

### Passo 3.3: Tornar Primeiro Usuário ADMIN

1. Volte ao **Supabase**
2. Vá em **Authentication** → **Users**
3. Você verá o usuário que acabou de criar
4. **COPIE o ID** do usuário (algo como: `a1b2c3d4-...`)
5. Vá em **SQL Editor**
6. Cole e execute:

```sql
UPDATE users SET role = 'ADMIN' WHERE id = 'f555e9ac-305b-4f5d-811f-2fdb9a5c38d6';
```

7. Clique em **RUN**

### Passo 3.4: Fazer Login como ADMIN

1. Volte ao sistema
2. Faça login com o email e senha cadastrados
3. Você terá acesso completo ao sistema!

---

## 4. TESTANDO O SISTEMA

### 4.1 Cadastrar Produtos

1. No menu lateral, clique em **"Produtos"**
2. Clique em **"+ Novo Produto"**
3. Preencha:
   - **Código**: PROD001
   - **Nome**: Papel A4
   - **Categoria**: Escritório
   - **Unidade**: CX (Caixa)
   - **Estoque Atual**: 10
   - **Estoque Mínimo**: 5
   - **Preço**: 25.00
4. Clique em **"Salvar"**

Cadastre mais alguns produtos para testar.

### 4.2 Cadastrar Fornecedores

1. Clique em **"Fornecedores"**
2. Clique em **"+ Novo Fornecedor"**
3. Preencha:
   - **Nome**: Papelaria Silva
   - **CNPJ**: 12345678000190
   - **WhatsApp**: 5511999999999
4. Clique em **"Salvar"**

### 4.3 Criar Usuários Adicionais

1. Clique em **"Usuários"**
2. Cadastre novos usuários diretamente na tela de registro
3. Depois, como ADMIN, altere o perfil deles:
   - Crie um usuário **COMPRADOR**
   - Crie um usuário **APROVADOR** (não esqueça de adicionar o WhatsApp!)

### 4.4 Testar Fluxo de Pedido

**Como COMPRADOR:**
1. Faça login com usuário COMPRADOR
2. Vá em **"Pedidos"** → **"+ Novo Pedido"**
3. Selecione um fornecedor (opcional)
4. Clique em **"Criar Pedido"**
5. Na tela de detalhes:
   - Clique em **"+ Adicionar Item"**
   - Selecione um produto
   - Informe quantidade e preço
   - Clique em **"Adicionar"**
6. Adicione mais itens se quiser
7. Clique em **"Enviar para Aprovação"**
8. Se o aprovador tiver WhatsApp, um link será aberto

**Como APROVADOR:**
1. Faça login com usuário APROVADOR
2. Vá em **"Aprovações"**
3. Veja o pedido pendente
4. Clique em **"Ver Detalhes"**
5. Clique em **"Aprovar"** ou **"Rejeitar"**

**Como ADMIN (Finalizar):**
1. Faça login como ADMIN
2. Vá em **"Pedidos"**
3. Clique em pedido aprovado
4. Clique em **"Finalizar Pedido"**
5. O estoque será baixado automaticamente!

### 4.5 Verificar Estoque

1. Vá em **"Estoque"**
2. Veja o histórico de movimentações
3. Crie movimentações manuais de entrada/saída

---

## 5. CONFIGURAÇÃO DO WHATSAPP

### 5.1 Formato do Número

O número de WhatsApp deve estar no formato internacional:
- **Formato**: `[Código País][DDD][Número]`
- **Exemplo Brasil**: `5511999999999`
  - 55 = Código do Brasil
  - 11 = DDD de São Paulo
  - 999999999 = Número do celular

### 5.2 Configurar Aprovador

1. Como ADMIN, vá em **"Usuários"**
2. Encontre o usuário APROVADOR
3. Clique em **"Editar"**
4. Preencha o campo **WhatsApp**: `5511999999999`
5. Salve

### 5.3 Testar Integração

1. Crie um pedido e envie para aprovação
2. Ao clicar em "Enviar para Aprovação", um link WhatsApp abrirá
3. A mensagem virá formatada com:
   - Número do pedido
   - Solicitante
   - Itens
   - Total
   - Link para aprovação

---

## 6. DEPLOY EM PRODUÇÃO

### Opção A: Netlify (Recomendado)

**Deploy Inicial:**
1. Crie conta em [netlify.com](https://netlify.com)
2. Clique em "Add new site" → "Deploy manually"
3. Arraste a pasta do projeto
4. Aguarde o deploy
5. Seu site estará online em: `https://seu-site.netlify.app`

**Atualizando o Site (após fazer mudanças no código):**

Você tem 2 opções:

**Opção 1 - Deploy Manual (mais simples)**
1. Faça suas alterações no código localmente
2. Acesse [app.netlify.com](https://app.netlify.com)
3. Clique no seu site
4. Vá na aba **"Deploys"**
5. Arraste a pasta do projeto novamente (ou clique em "Deploy manually")
6. Aguarde o deploy completar (30-60 segundos)
7. Seu site será atualizado automaticamente!

**Opção 2 - Deploy via GitHub (automático)**
1. Crie um repositório no GitHub
2. Suba seu código:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/seu-usuario/seu-repo.git
   git push -u origin main
   ```
3. No Netlify, delete o site manual
4. Clique em "Add new site" → "Import an existing project"
5. Conecte com GitHub e selecione o repositório
6. Configure:
   - Build command: (deixe em branco)
   - Publish directory: `/` ou `.`
7. Clique em "Deploy site"
8. **Agora, sempre que fizer `git push`, o Netlify atualiza automaticamente!**

**Dica**: Para projetos que você atualiza frequentemente, use a Opção 2. Para projetos estáveis, a Opção 1 funciona bem.

### Opção B: Vercel

1. Crie conta em [vercel.com](https://vercel.com)
2. Instale Vercel CLI: `npm install -g vercel`
3. Na pasta do projeto, execute: `vercel`
4. Siga as instruções
5. Site online em: `https://seu-site.vercel.app`

### Opção C: GitHub Pages

1. Suba o projeto para um repositório GitHub
2. Vá em Settings → Pages
3. Selecione branch "main" e pasta "/"
4. Aguarde deploy
5. Site em: `https://seu-usuario.github.io/nome-repo`

---

## 7. SOLUÇÃO DE PROBLEMAS

### ❌ Erro: "Failed to fetch" ao fazer login

**Causa**: Credenciais do Supabase incorretas

**Solução**:
1. Verifique `js/config.js`
2. Confirme se URL e KEY estão corretos
3. Limpe cache do navegador (Ctrl+Shift+Del)
4. Recarregue a página

### ❌ Erro: "Row Level Security" ou permissão negada

**Causa**: Script SQL não foi executado completamente

**Solução**:
1. Volte ao SQL Editor do Supabase
2. Execute novamente o `schema.sql` completo
3. Verifique se todas as policies foram criadas
4. Teste novamente

### ❌ Não consigo fazer login após cadastro

**Causa**: Email de confirmação não verificado

**Solução**:
1. No Supabase, vá em Authentication → Users
2. Encontre o usuário
3. Clique nos 3 pontos → "Confirm Email"
4. Tente fazer login novamente

### ❌ Usuário não aparece como ADMIN

**Causa**: Perfil não foi atualizado no banco

**Solução**:
1. Copie o ID do usuário no Supabase
2. Execute no SQL Editor:
   ```sql
   UPDATE users SET role = 'ADMIN' WHERE id = 'ID-AQUI';
   ```
3. Faça logout e login novamente

### ❌ WhatsApp não abre com mensagem

**Causa**: Formato de número incorreto

**Solução**:
1. Verifique se o número está no formato: `5511999999999`
2. Não use espaços, traços ou parênteses
3. Deve ter código do país + DDD + número

### ❌ Estoque não baixa ao finalizar pedido

**Causa**: Função SQL não foi criada

**Solução**:
1. No Supabase SQL Editor, execute:
   ```sql
   SELECT routine_name FROM information_schema.routines 
   WHERE routine_name = 'finalizar_pedido';
   ```
2. Se não retornar nada, execute o `schema.sql` completo novamente

---

## 📞 SUPORTE ADICIONAL

### Documentação do Supabase
- https://supabase.com/docs

### Verificar Logs de Erro
- Abra o Console do Navegador (F12)
- Vá na aba "Console"
- Veja mensagens de erro detalhadas

### Resetar Banco de Dados
Se precisar recomeçar do zero:

1. No Supabase, vá em **Database** → **Tables**
2. Delete todas as tabelas
3. Execute o `schema.sql` novamente
4. Recadastre o primeiro usuário

---

## ✅ CHECKLIST DE IMPLANTAÇÃO

- [ ] Projeto Supabase criado
- [ ] Script SQL executado com sucesso
- [ ] Credenciais configuradas em `js/config.js`
- [ ] Servidor local rodando
- [ ] Primeiro usuário cadastrado
- [ ] Primeiro usuário promovido a ADMIN
- [ ] Login como ADMIN funcionando
- [ ] Produtos cadastrados
- [ ] Fornecedores cadastrados
- [ ] Usuários COMPRADOR e APROVADOR criados
- [ ] WhatsApp configurado no APROVADOR
- [ ] Fluxo completo de pedido testado
- [ ] Sistema em produção (opcional)

---

**Sistema pronto para uso! 🎉**
