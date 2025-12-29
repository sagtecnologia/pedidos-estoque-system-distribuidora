# 📱 Notificações WhatsApp - Guia Completo

## Como Funciona

O sistema envia notificações via WhatsApp quando um pedido (compra ou venda) é enviado para aprovação.

## 📋 Requisitos

### 1. Cadastrar Aprovadores com WhatsApp

Os usuários com role **APROVADOR** devem ter o campo WhatsApp preenchido:

**Formato Correto do Número:**
```
5562996951427
```

⚠️ **IMPORTANTE - Formato do Número:**

- ✅ **CORRETO:** `5562996951427` (apenas números)
- ❌ **ERRADO:** `+556296951427` (não use +)
- ❌ **ERRADO:** `+55 62 99695-1427` (não use espaços ou hífens)
- ❌ **ERRADO:** `(62) 99695-1427` (não use parênteses)

**Estrutura do Número:**
```
55 = Código do Brasil
62 = DDD (Goiás)
996951427 = Número do celular
```

### 2. Como Cadastrar

#### Opção 1: Através da Tela de Usuários

1. Acesse **Menu → Usuários**
2. Edite o usuário APROVADOR
3. Preencha o campo **WhatsApp**: `5562996951427`
4. Salve

#### Opção 2: Direto no Supabase

Execute no SQL Editor:

```sql
-- Atualizar WhatsApp do aprovador
UPDATE users 
SET whatsapp = '5562996951427'
WHERE role = 'APROVADOR' 
  AND email = 'seu.aprovador@email.com';
```

### 3. Verificar Configuração

Para confirmar que está correto, execute:

```sql
SELECT full_name, email, whatsapp, role
FROM users
WHERE role = 'APROVADOR'
  AND active = true;
```

**Resultado esperado:**
```
full_name       | email                  | whatsapp       | role
----------------|------------------------|----------------|----------
João Aprovador  | joao@empresa.com       | 5562996951427  | APROVADOR
```

## 🚀 Como Usar

### Fluxo de Aprovação

1. **Comprador** cria pedido (compra ou venda)
2. Adiciona itens ao pedido
3. Clica em **"Enviar para Aprovação"**
4. Sistema busca aprovadores cadastrados com WhatsApp
5. Abre WhatsApp Web/App com mensagem pré-formatada

### Mensagem Enviada

O WhatsApp abrirá automaticamente com uma mensagem como:

```
🔔 *Novo Pedido de Compra para Aprovação*

📋 *Pedido:* PED-001
👤 *Solicitante:* Maria Silva
🏢 *Fornecedor:* Fornecedor XYZ
💰 *Total:* R$ 1.500,00

*Itens:*
1. Produto A
   Qtd: 10 UN x R$ 50,00 = R$ 500,00
2. Produto B
   Qtd: 20 UN x R$ 50,00 = R$ 1.000,00

📱 Acesse o sistema para aprovar ou rejeitar:
http://localhost:8000/pages/aprovacao.html?id=abc123
```

### Múltiplos Aprovadores

Se houver **mais de um aprovador** cadastrado com WhatsApp:

1. Sistema mostra modal com lista de aprovadores
2. Usuário seleciona para qual aprovador enviar
3. WhatsApp abre com a mensagem

Se houver **apenas um aprovador**:
- WhatsApp abre direto, sem modal de seleção

## 🔧 Solução de Problemas

### ❌ "Nenhum aprovador com WhatsApp cadastrado"

**Causa:** Nenhum usuário APROVADOR tem WhatsApp configurado.

**Solução:**
```sql
-- Verificar aprovadores
SELECT id, full_name, email, whatsapp, active
FROM users
WHERE role = 'APROVADOR';

-- Cadastrar WhatsApp
UPDATE users 
SET whatsapp = '5562996951427'
WHERE role = 'APROVADOR' 
  AND id = 'uuid-do-aprovador';
```

### ❌ WhatsApp não abre

**Possíveis causas:**

1. **Navegador bloqueou popup**
   - Solução: Permitir popups para o site

2. **Número com formato errado**
   - ✅ Correto: `5562996951427`
   - ❌ Errado: `+556296951427`

3. **WhatsApp não instalado**
   - Solução: Usar WhatsApp Web

### ❌ Mensagem não aparece no WhatsApp

**Causa:** Caracteres especiais no pedido

**Solução:** Evite caracteres especiais (`, ", ', &) nos nomes de produtos e observações

## 📊 Verificação Rápida

### Teste o Link Manualmente

Copie e cole no navegador (substitua o número):

```
https://wa.me/5562996951427?text=Teste%20de%20notificação
```

Se abrir o WhatsApp com "Teste de notificação", o número está correto!

### Script de Teste Completo

Execute no console do navegador (F12):

```javascript
// Testar função de WhatsApp
const teste = generateWhatsAppLink('5562996951427', 'Teste do sistema');
console.log('Link gerado:', teste);
window.open(teste, '_blank');
```

## 🎯 Exemplos de Números

### Formato Internacional (sem +)

```
Brasil (Goiás):     5562996951427
Brasil (São Paulo): 5511987654321
Brasil (Rio):       5521987654321
Portugal:           351912345678
```

### Como Converter Seu Número

Se seu número é: `(62) 99695-1427`

1. Remove parênteses: `62 99695-1427`
2. Remove espaços: `6299695-1427`
3. Remove hífen: `62996951427`
4. Adiciona código do país (55): `5562996951427`

✅ **Resultado final:** `5562996951427`

## 📝 Boas Práticas

1. **Sempre teste** após cadastrar o WhatsApp
2. **Use apenas números** (sem símbolos)
3. **Inclua DDD e código do país**
4. **Verifique se o aprovador está ativo**
5. **Confirme que o número está correto no WhatsApp**

## 🔄 Fluxo Completo

```
┌─────────────────┐
│   Comprador     │
│  Cria Pedido    │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  Adiciona Itens │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Enviar p/ Aprovação │  ◄── Sistema busca aprovadores
└────────┬────────────┘     com WhatsApp cadastrado
         │
         ▼
┌─────────────────────┐
│  Modal (se múltiplos│
│   aprovadores)      │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Abre WhatsApp Web  │  ◄── Mensagem pré-formatada
│  com mensagem       │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Aprovador recebe   │
│  notificação        │
└────────┬────────────┘
         │
         ▼
┌─────────────────────┐
│  Acessa link e      │
│  aprova/rejeita     │
└─────────────────────┘
```

## 💡 Dicas

- Cadastre WhatsApp de **todos os aprovadores**
- Use o **número pessoal** do aprovador (não da empresa)
- Teste a funcionalidade após cadastrar
- O aprovador precisa ter WhatsApp instalado (Web ou App)

## ⚡ Atalhos

**Testar link direto no navegador:**
```
https://wa.me/SEUNUMERO?text=Teste
```

**SQL rápido para atualizar:**
```sql
UPDATE users SET whatsapp = 'SEUNUMERO' WHERE email = 'email@dominio.com';
```

---

📌 **Lembre-se:** O formato correto é `5562996951427` (apenas números, sem + ou espaços)
