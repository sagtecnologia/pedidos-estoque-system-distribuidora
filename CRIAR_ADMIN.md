# 🔐 GUIA: CRIAR USUÁRIO ADMINISTRADOR

## 📋 Opções Disponíveis

### Opção 1: Criar Admin Manualmente no Supabase (RECOMENDADO)

**1. Acesse o Supabase Dashboard:**
   - Vá em: https://supabase.com/dashboard
   - Selecione seu projeto
   - Clique em **Authentication** → **Users**

**2. Criar usuário:**
   - Clique em **Add user** → **Create new user**
   - Email: `brunoallencar@hotmail.com`
   - Senha: `Bb93163087@@`
   - ✅ Marque **Auto Confirm User** (confirma email automaticamente)
   - Clique em **Create user**
   - **COPIE o UUID** gerado (ex: `a1b2c3d4-e5f6-7890-...`)

**3. Execute a migração:**
   - No Supabase, vá em **SQL Editor**
   - Abra o arquivo [migration-create-admin-user.sql](database/migration-create-admin-user.sql)
   - **SUBSTITUA** `'SEU-UUID-AQUI'` pelo UUID copiado
   - Execute o script
   - ✅ Admin criado e ativado!

**4. Faça login:**
   - Acesse o sistema
   - Email: `brunoallencar@hotmail.com`
   - Senha: `Bb93163087@@`
   - ⚠️ **ALTERE A SENHA** após primeiro login!

---

### Opção 2: Cadastro via Sistema (após ter um ADMIN)

**Após ter pelo menos um ADMIN ativo:**

1. Faça login como ADMIN
2. Vá em **Usuários**
3. Clique em **Novo Usuário**
4. Preencha os dados:
   - Nome completo
   - Email
   - Senha (mínimo 6 caracteres)
   - Perfil (ADMIN, COMPRADOR, VENDEDOR, APROVADOR)
   - WhatsApp (opcional)
   - ✅ Ativo (marque para liberar imediatamente)
5. Clique em **Cadastrar**

**Vantagens:**
- ✅ Usuário criado e ativo imediatamente
- ✅ Email confirmado automaticamente
- ✅ Não precisa ir no banco de dados
- ✅ ADMIN pode criar outros ADMINs

---

## 🔒 Regras de Segurança

- ✅ Apenas usuários com perfil **ADMIN** podem cadastrar novos usuários
- ✅ O cadastro público (register.html) cria usuários **inativos** aguardando aprovação
- ✅ O cadastro pelo admin pode criar usuários **ativos** imediatamente
- ✅ Admin pode criar outros admins sem restrições

---

## ⚠️ IMPORTANTE

1. **Altere a senha padrão** do admin após primeiro acesso
2. **Não compartilhe** as credenciais do admin
3. Crie outros admins apenas se necessário
4. Use perfis adequados para cada usuário (VENDEDOR, COMPRADOR, etc)

---

## 🆘 Problemas Comuns

### "Admin API not available"
**Solução:** A API admin do Supabase só funciona server-side. Use a Opção 1 (manual).

### "Email já cadastrado"
**Solução:** O usuário já existe. Faça login ou recupere a senha.

### "Não consigo criar usuários"
**Solução:** Verifique se você está logado como ADMIN (o menu "Usuários" só aparece para admins).
