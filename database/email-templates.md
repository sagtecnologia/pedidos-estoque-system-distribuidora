# 📧 Configuração de Templates de Email - Supabase

## Problema

O email padrão do Supabase está em inglês e não fica claro para o usuário:
```
Confirm your signup
Follow this link to confirm your user:
Confirm your mail
```

## Solução

Personalizar os templates de email no painel do Supabase.

---

## 🔧 Como Configurar

### Passo 1: Acessar Templates de Email

1. Acesse seu projeto no [Supabase Dashboard](https://supabase.com)
2. No menu lateral, vá em **Authentication** → **Email Templates**
3. Você verá várias opções de templates

### Passo 2: Configurar "Confirm signup"

Clique em **"Confirm signup"** e substitua o conteúdo por:

---

## 📝 Template: Confirmação de Cadastro

### Subject (Assunto):
```
Confirme seu cadastro - Sistema de Pedidos
```

### Body (Corpo do Email):

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background-color: #f8f9fa; border-radius: 10px; padding: 30px; margin-bottom: 20px;">
        <h1 style="color: #2563eb; margin-top: 0;">🎉 Bem-vindo ao Sistema de Pedidos!</h1>
        
        <p style="font-size: 16px; margin-bottom: 20px;">
            Olá! Obrigado por se cadastrar em nosso sistema.
        </p>
        
        <p style="font-size: 16px; margin-bottom: 30px;">
            Para completar seu cadastro e começar a usar o sistema, 
            <strong>clique no botão abaixo para confirmar seu email:</strong>
        </p>
        
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{ .ConfirmationURL }}" 
               style="background-color: #2563eb; 
                      color: white; 
                      padding: 15px 40px; 
                      text-decoration: none; 
                      border-radius: 8px; 
                      display: inline-block;
                      font-weight: bold;
                      font-size: 16px;">
                ✅ Confirmar Meu Email
            </a>
        </div>
        
        <p style="font-size: 14px; color: #666; margin-top: 30px;">
            <strong>Ou copie e cole este link no seu navegador:</strong><br>
            <a href="{{ .ConfirmationURL }}" style="color: #2563eb; word-break: break-all;">
                {{ .ConfirmationURL }}
            </a>
        </p>
        
        <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin-top: 30px; border-radius: 4px;">
            <p style="margin: 0; color: #856404;">
                ⏰ <strong>Importante:</strong> Este link expira em 24 horas.
            </p>
        </div>
    </div>
    
    <div style="text-align: center; color: #666; font-size: 14px; margin-top: 30px;">
        <p>Se você não se cadastrou em nosso sistema, ignore este email.</p>
        <p style="margin-top: 20px;">
            <strong>Sistema de Pedidos e Controle de Estoque</strong><br>
            © 2025 - Todos os direitos reservados
        </p>
    </div>
</body>
</html>
```

---

## 📝 Template: Redefinição de Senha

### Subject:
```
Redefinir sua senha - Sistema de Pedidos
```

### Body:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background-color: #f8f9fa; border-radius: 10px; padding: 30px; margin-bottom: 20px;">
        <h1 style="color: #dc2626; margin-top: 0;">🔐 Redefinir Senha</h1>
        
        <p style="font-size: 16px; margin-bottom: 20px;">
            Olá! Você solicitou a redefinição de senha do Sistema de Pedidos.
        </p>
        
        <p style="font-size: 16px; margin-bottom: 30px;">
            <strong>Clique no botão abaixo para criar uma nova senha:</strong>
        </p>
        
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{ .ConfirmationURL }}" 
               style="background-color: #dc2626; 
                      color: white; 
                      padding: 15px 40px; 
                      text-decoration: none; 
                      border-radius: 8px; 
                      display: inline-block;
                      font-weight: bold;
                      font-size: 16px;">
                🔑 Redefinir Minha Senha
            </a>
        </div>
        
        <p style="font-size: 14px; color: #666; margin-top: 30px;">
            <strong>Ou copie e cole este link no seu navegador:</strong><br>
            <a href="{{ .ConfirmationURL }}" style="color: #dc2626; word-break: break-all;">
                {{ .ConfirmationURL }}
            </a>
        </p>
        
        <div style="background-color: #fff3cd; border-left: 4px solid #ffc107; padding: 15px; margin-top: 30px; border-radius: 4px;">
            <p style="margin: 0; color: #856404;">
                ⏰ <strong>Importante:</strong> Este link expira em 1 hora.
            </p>
        </div>
        
        <div style="background-color: #fee; border-left: 4px solid #dc2626; padding: 15px; margin-top: 20px; border-radius: 4px;">
            <p style="margin: 0; color: #991b1b;">
                ⚠️ <strong>Não solicitou?</strong> Se você não pediu para redefinir sua senha, ignore este email. Sua senha atual continua segura.
            </p>
        </div>
    </div>
    
    <div style="text-align: center; color: #666; font-size: 14px; margin-top: 30px;">
        <p style="margin-top: 20px;">
            <strong>Sistema de Pedidos e Controle de Estoque</strong><br>
            © 2025 - Todos os direitos reservados
        </p>
    </div>
</body>
</html>
```

---

## 📝 Template: Mudança de Email

### Subject:
```
Confirme a alteração do seu email - Sistema de Pedidos
```

### Body:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    <div style="background-color: #f8f9fa; border-radius: 10px; padding: 30px; margin-bottom: 20px;">
        <h1 style="color: #2563eb; margin-top: 0;">📧 Confirmar Novo Email</h1>
        
        <p style="font-size: 16px; margin-bottom: 20px;">
            Você solicitou a alteração do email da sua conta no Sistema de Pedidos.
        </p>
        
        <p style="font-size: 16px; margin-bottom: 30px;">
            <strong>Clique no botão abaixo para confirmar este novo email:</strong>
        </p>
        
        <div style="text-align: center; margin: 30px 0;">
            <a href="{{ .ConfirmationURL }}" 
               style="background-color: #2563eb; 
                      color: white; 
                      padding: 15px 40px; 
                      text-decoration: none; 
                      border-radius: 8px; 
                      display: inline-block;
                      font-weight: bold;
                      font-size: 16px;">
                ✅ Confirmar Novo Email
            </a>
        </div>
        
        <p style="font-size: 14px; color: #666; margin-top: 30px;">
            <strong>Ou copie e cole este link no seu navegador:</strong><br>
            <a href="{{ .ConfirmationURL }}" style="color: #2563eb; word-break: break-all;">
                {{ .ConfirmationURL }}
            </a>
        </p>
        
        <div style="background-color: #fee; border-left: 4px solid #dc2626; padding: 15px; margin-top: 20px; border-radius: 4px;">
            <p style="margin: 0; color: #991b1b;">
                ⚠️ <strong>Não solicitou?</strong> Se você não pediu para alterar seu email, entre em contato com o administrador imediatamente.
            </p>
        </div>
    </div>
    
    <div style="text-align: center; color: #666; font-size: 14px; margin-top: 30px;">
        <p style="margin-top: 20px;">
            <strong>Sistema de Pedidos e Controle de Estoque</strong><br>
            © 2025 - Todos os direitos reservados
        </p>
    </div>
</body>
</html>
```

---

## 🎨 Personalização Adicional

Você pode personalizar ainda mais os templates:

1. **Trocar cores**: Altere os valores hexadecimais (#2563eb para azul, #dc2626 para vermelho, etc.)
2. **Adicionar logo**: Inclua uma imagem da empresa
3. **Alterar textos**: Adapte a mensagem conforme sua empresa

### Exemplo com Logo:

Adicione no topo do body:

```html
<div style="text-align: center; margin-bottom: 30px;">
    <img src="https://seu-dominio.com/logo.png" alt="Logo" style="max-width: 200px;">
</div>
```

---

## ⚙️ Configurações Adicionais

### 1. Desabilitar Confirmação de Email (Não Recomendado)

Se quiser **desabilitar** a confirmação de email:

1. Vá em **Authentication** → **Settings**
2. Em **Email Auth**, desmarque **"Enable email confirmations"**

⚠️ **Não recomendado** para produção por questões de segurança!

### 2. Configurar SMTP Personalizado

Para usar seu próprio servidor de email:

1. Vá em **Project Settings** → **Auth**
2. Role até **SMTP Settings**
3. Configure:
   - **Host**: smtp.seu-provedor.com
   - **Port**: 587
   - **Username**: seu-email@dominio.com
   - **Password**: sua-senha
   - **Sender email**: noreply@seu-dominio.com
   - **Sender name**: Sistema de Pedidos

---

## 🧪 Testar os Templates

Após configurar:

1. Faça logout do sistema
2. Clique em **"Cadastrar"**
3. Preencha os dados com um email de teste
4. Verifique sua caixa de entrada
5. O email deve chegar em português e formatado

---

## 📱 Exemplo Visual do Email

```
┌────────────────────────────────────────────┐
│                                            │
│  🎉 Bem-vindo ao Sistema de Pedidos!      │
│                                            │
│  Olá! Obrigado por se cadastrar em        │
│  nosso sistema.                           │
│                                            │
│  Para completar seu cadastro e começar    │
│  a usar o sistema, clique no botão        │
│  abaixo para confirmar seu email:         │
│                                            │
│     ┌──────────────────────────┐         │
│     │ ✅ Confirmar Meu Email   │         │
│     └──────────────────────────┘         │
│                                            │
│  Ou copie e cole este link:               │
│  https://seu-projeto.supabase.co/...      │
│                                            │
│  ⏰ Importante: Este link expira em       │
│     24 horas.                             │
│                                            │
│  Se você não se cadastrou, ignore este    │
│  email.                                   │
│                                            │
│  Sistema de Pedidos                       │
│  © 2025                                   │
└────────────────────────────────────────────┘
```

---

## ✅ Checklist de Configuração

- [ ] Acessar Supabase Dashboard
- [ ] Ir em Authentication → Email Templates
- [ ] Configurar "Confirm signup" (em português)
- [ ] Configurar "Reset Password" (em português)
- [ ] Configurar "Change Email" (em português)
- [ ] Testar com email real
- [ ] Verificar se chegou corretamente
- [ ] Clicar no link de confirmação
- [ ] Confirmar que o login funciona

---

## 🆘 Problemas Comuns

### Email não chega

1. Verifique spam/lixo eletrônico
2. Aguarde até 5 minutos
3. Confira se o email está correto
4. Verifique logs em Supabase: **Logs** → **Auth Logs**

### Link expirado

- Links expiram em 24h (signup) ou 1h (password)
- Solicite novo email de confirmação

### Template não atualiza

- Limpe cache do navegador
- Aguarde alguns minutos
- Teste com novo usuário

---

## 💡 Dica Extra

Adicione uma mensagem na tela de registro informando:

> "📧 Um email de confirmação foi enviado para **seu-email@dominio.com**. 
> Verifique sua caixa de entrada e clique no link para ativar sua conta."

---

**Templates prontos para copiar e colar no Supabase!** 🎉
