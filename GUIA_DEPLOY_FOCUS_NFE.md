# 🚀 GUIA DE DEPLOY - INTEGRAÇÃO FOCUS NFe

## 📋 Pré-requisitos

- [ ] Conta na Focus NFe (https://focusnfe.com.br)
- [ ] Token de API da Focus NFe
- [ ] Certificado Digital A1 (.pfx)
- [ ] Dados fiscais da empresa (CNPJ, IE, etc.)
- [ ] Supabase CLI instalado

---

## 1️⃣ CONFIGURAR NO SUPABASE (BANCO DE DADOS)

### Campos já criados na tabela `empresa_config`:

```sql
-- Verificar se os campos existem
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'empresa_config'
AND column_name IN (
    'focusnfe_token',
    'focusnfe_ambiente',
    'csc_id',
    'csc_token',
    'nfce_serie',
    'nfe_serie',
    'nfce_numero',
    'nfe_numero',
    'pdv_emitir_nfce_automatico',
    'certificado_validade'
);
```

Se algum campo não existir, executar:

```sql
-- Adicionar campos Focus NFe
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_token TEXT;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS focusnfe_ambiente INTEGER DEFAULT 2;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS csc_id VARCHAR;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS csc_token VARCHAR;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS certificado_validade DATE;
ALTER TABLE empresa_config ADD COLUMN IF NOT EXISTS pdv_emitir_nfce_automatico BOOLEAN DEFAULT FALSE;

-- Comentários
COMMENT ON COLUMN empresa_config.focusnfe_token IS 'Token de API da Focus NFe';
COMMENT ON COLUMN empresa_config.focusnfe_ambiente IS '1=Produção, 2=Homologação';
COMMENT ON COLUMN empresa_config.csc_id IS 'ID do CSC para NFC-e';
COMMENT ON COLUMN empresa_config.csc_token IS 'Token CSC da SEFAZ';
```

---

## 2️⃣ INSTALAR SUPABASE CLI

### Windows (PowerShell):
```powershell
scoop install supabase
```

Ou baixe em: https://github.com/supabase/cli/releases

### Linux/Mac:
```bash
brew install supabase/tap/supabase
```

---

## 3️⃣ LOGIN E LINK DO PROJETO

```bash
# Login no Supabase
supabase login

# Listar projetos
supabase projects list

# Linkar ao seu projeto
supabase link --project-ref seu-project-id
```

**Como encontrar o project-id:**
- Acesse seu projeto no Supabase Dashboard
- URL: `https://app.supabase.com/project/SEU_PROJECT_ID`

---

## 4️⃣ CONFIGURAR SECRETS (VARIÁVEIS DE AMBIENTE)

⚠️ **NUNCA coloque o token no código!** Use secrets:

```bash
# Configurar token da Focus NFe (não salvar no código!)
supabase secrets set FOCUS_NFE_TOKEN=seu_token_focus_nfe_aqui

# Verificar se foi salvo
supabase secrets list
```

---

## 5️⃣ DEPLOY DAS EDGE FUNCTIONS

```bash
# Ir para a pasta do projeto
cd /caminho/do/seu/projeto

# Deploy de todas as functions
supabase functions deploy emitir-nfce
supabase functions deploy emitir-nfe
supabase functions deploy consultar-nf
supabase functions deploy cancelar-nf

# Ou deploy de todas de uma vez
supabase functions deploy
```

**Verificar deploy:**
```bash
supabase functions list
```

---

## 6️⃣ CONFIGURAR NA INTERFACE WEB

Acesse: `http://localhost:porta/pages/configuracoes-empresa.html`

### Aba "NF-e / NFC-e":
1. **Ambiente:** 
   - Escolha `2 - Homologação` para testes
   - `1 - Produção` apenas quando validado
2. **Token Focus NFe:** Cole o token obtido no site da Focus NFe
3. **Série NFC-e:** Geralmente `1`
4. **Série NF-e:** Geralmente `1`
5. **Próximo número:** Iniciar com `1` ou conforme sua numeração
6. **CSC ID:** Obter no portal da SEFAZ (ex: `000001`)
7. **CSC Token:** Código fornecido pela SEFAZ

### Aba "PDV":
- Marque: **"Emitir NFC-e automaticamente ao finalizar venda"** se desejar

### Enviar Certificado:
1. Selecione o arquivo `.pfx`
2. Digite a senha do certificado
3. Clique em "Enviar Certificado para Focus NFe"

**Salvar configurações!**

---

## 7️⃣ TESTAR A INTEGRAÇÃO

Acesse: `http://localhost:porta/pages/teste-focus-nfe.html`

### Executar testes na ordem:
1. ✅ **Teste 1:** Conexão com API
2. ✅ **Teste 2:** Dados da Empresa
3. ✅ **Teste 3:** Verificar Certificado
4. ⚠️ **Teste 4:** Emitir NFC-e de Teste (somente em homologação!)

---

## 8️⃣ RESOLVER PROBLEMAS DE CORS

### Para Desenvolvimento Local:

#### Opção 1: Extensão de Navegador (Temporário)
- Chrome/Edge: [Allow CORS](https://chrome.google.com/webstore/detail/allow-cors-access-control/lhobafahddgcelffkeicbaginigeejlf)
- Firefox: [CORS Everywhere](https://addons.mozilla.org/pt-BR/firefox/addon/cors-everywhere/)

⚠️ **Lembre de desabilitar após o teste!**

#### Opção 2: Usar Edge Functions (Recomendado)
As Edge Functions já resolvem o problema de CORS automaticamente!

### Para Produção:
**SEMPRE use Edge Functions!** Nunca chame a API Focus NFe direto do JavaScript.

```javascript
// ❌ ERRADO (CORS + Inseguro)
fetch('https://api.focusnfe.com.br/v2/nfce', {...})

// ✅ CORRETO (Sem CORS + Seguro)
const { data, error } = await supabase.functions.invoke('emitir-nfce', {
    body: { venda_id, itens, pagamentos, cliente }
})
```

---

## 9️⃣ ATUALIZAR CÓDIGO DO FRONTEND

Edite `js/services/focus-nfe.js` para usar Edge Functions:

```javascript
// Adicionar no início da função emitirNFCe
async emitirNFCe(venda, itens, pagamentos, cliente = null) {
    try {
        // ✅ Usar Edge Function em vez de chamada direta
        const { data, error } = await supabase.functions.invoke('emitir-nfce', {
            body: {
                venda_id: venda.id,
                itens: itens,
                pagamentos: pagamentos,
                cliente: cliente
            }
        });

        if (error) throw error;
        return data;
    } catch (error) {
        console.error('❌ Erro ao emitir NFC-e:', error);
        throw error;
    }
}
```

---

## 🔟 VALIDAÇÃO EM HOMOLOGAÇÃO

Antes de ir para produção:

- [ ] Emitir pelo menos 5 NFC-e de teste
- [ ] Verificar se o DANFE é gerado corretamente
- [ ] Testar cancelamento de nota
- [ ] Validar dados do XML
- [ ] Conferir CSC está funcionando
- [ ] Verificar se os itens aparecem corretos

---

## 1️⃣1️⃣ IR PARA PRODUÇÃO

### ⚠️ ATENÇÃO: Após isso, as notas serão REAIS!

1. Altere o ambiente para **Produção (1)**:
```sql
UPDATE empresa_config SET focusnfe_ambiente = 1;
```

2. Ou pela interface web: Configurações > NF-e/NFC-e > Ambiente > `1 - Produção`

3. **Teste com uma venda real de baixo valor primeiro!**

4. Monitore os logs das Edge Functions:
```bash
supabase functions logs emitir-nfce
```

---

## 📊 MONITORAMENTO

### Ver logs em tempo real:
```bash
supabase functions logs emitir-nfce --follow
```

### Verificar documentos fiscais no banco:
```sql
SELECT 
    tipo, 
    status, 
    chave, 
    valor_total, 
    created_at 
FROM documentos_fiscais 
ORDER BY created_at DESC 
LIMIT 20;
```

---

## 🆘 TROUBLESHOOTING

### Erro: "Token inválido"
- Verifique se o token está correto
- Teste direto na API: https://focusnfe.com.br/doc/#introducao

### Erro: "Certificado expirado"
- Certificado A1 tem validade de 1 ano
- Renove no portal da SEFAZ

### Erro: "CSC inválido"
- Verifique ID e Token do CSC no portal da SEFAZ
- Alguns estados exigem cadastro prévio

### Erro de CORS:
- Use Edge Functions (não chame direto a API)
- Em dev local, use extensão CORS Unblock

### Nota rejeitada pela SEFAZ:
- Verifique o campo `motivo_sefaz` na tabela `documentos_fiscais`
- Corrija os dados conforme mensagem da SEFAZ

---

## 📞 SUPORTE

- **Focus NFe:** https://focusnfe.com.br/suporte
- **Supabase:** https://supabase.com/docs
- **SEFAZ:** Portal da SEFAZ do seu estado

---

## ✅ CHECKLIST FINAL

- [ ] Banco de dados configurado
- [ ] Supabase CLI instalado
- [ ] Edge Functions deployadas
- [ ] Secrets configurados
- [ ] Token Focus NFe cadastrado
- [ ] Certificado A1 enviado
- [ ] CSC configurado
- [ ] Testado em homologação
- [ ] CORS resolvido (Edge Functions)
- [ ] Código frontend atualizado
- [ ] Validado 5+ notas de teste
- [ ] Pronto para produção! 🎉

---

**Desenvolvido para:** Sistema de Gestão de Distribuidora  
**Data:** Fevereiro de 2026  
**Versão:** 1.0
