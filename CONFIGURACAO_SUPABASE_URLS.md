# 🔧 CONFIGURAÇÃO DO SUPABASE PARA PRODUÇÃO

## ⚠️ IMPORTANTE: Configurar URLs de Produção

### 1️⃣ Acessar Configurações no Supabase

1. Acesse: https://supabase.com/dashboard
2. Selecione seu projeto
3. Vá em **Authentication** (menu lateral)
4. Clique em **URL Configuration**

### 2️⃣ Configurar Site URL

**Site URL** é a URL principal do seu site em produção.

```
Exemplo:
https://seu-sistema.netlify.app
```

**Como configurar:**
- Cole a URL do seu site em produção (sem barra no final)
- Clique em **Save**

### 3️⃣ Configurar Redirect URLs

**Redirect URLs** são as URLs permitidas para redirecionamento após autenticação.

**Adicione TODAS estas URLs:**

```
https://seu-sistema.netlify.app/**
https://seu-sistema.netlify.app/index.html
https://seu-sistema.netlify.app/pages/auth-callback.html
https://seu-sistema.netlify.app/pages/dashboard.html
```

**⚠️ Substitua `seu-sistema.netlify.app` pela URL real do seu site!**

**Como adicionar:**
1. Cole cada URL em uma linha separada
2. Use `**` para permitir todos os caminhos
3. Clique em **Save**

### 4️⃣ Configurar Email Templates (Opcional mas Recomendado)

1. No Supabase, vá em **Authentication** → **Email Templates**
2. Selecione **Confirm signup**
3. Atualize o link de confirmação:

**Template sugerido:**

```html
<h2>Confirme seu email</h2>
<p>Clique no link abaixo para confirmar seu cadastro:</p>
<p><a href="{{ .ConfirmationURL }}">Confirmar Email</a></p>
<p>Após confirmar, sua conta ficará pendente de aprovação do administrador.</p>
<p>Este link expira em 24 horas.</p>
```

### 5️⃣ Verificar Configuração

Após salvar, teste:

1. Faça um novo cadastro
2. Verifique se o email chega corretamente
3. Clique no link de confirmação
4. Deve redirecionar para: `https://seu-sistema.netlify.app/pages/auth-callback.html`
5. Deve mostrar mensagem de sucesso

### 6️⃣ Para Desenvolvimento Local

Se quiser testar em desenvolvimento, adicione também:

```
http://localhost:8000/**
http://127.0.0.1:8000/**
```

⚠️ **Mas lembre-se:** Em produção, emails SEMPRE redirecionarão para a URL configurada em **Site URL**.

---

## 📋 Checklist de Configuração

- [ ] Site URL configurada com URL de produção
- [ ] Redirect URLs adicionadas (com /**)
- [ ] Email template atualizado (opcional)
- [ ] Teste de cadastro realizado
- [ ] Confirmação de email funcionando
- [ ] Redirecionamento para auth-callback.html funcionando

---

## 🆘 Problemas Comuns

### "localhost:3000" no link do email

**Causa:** Site URL não foi configurada corretamente.

**Solução:** Configure Site URL para sua URL de produção e salve.

### "access_denied" ou "otp_expired"

**Causa:** Link expirou (24h) ou já foi usado.

**Solução:** Faça um novo cadastro.

### Redirecionamento para página errada

**Causa:** Redirect URLs não incluem a página de destino.

**Solução:** Adicione `https://seu-site.com/**` nas Redirect URLs.

---

## 📝 Nota sobre a página auth-callback.html

Esta página foi criada para:
- ✅ Processar confirmação de email
- ✅ Mostrar mensagem de sucesso/erro
- ✅ Deslogar automaticamente (usuário aguarda aprovação)
- ✅ Redirecionar para login

Ela melhora a experiência do usuário ao confirmar o email!
