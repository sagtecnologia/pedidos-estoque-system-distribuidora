# 📚 REFERÊNCIA RÁPIDA - API FOCUS NFE

## 🌐 URLs Base

| Ambiente | URL |
|----------|-----|
| **Produção** | https://api.focusnfe.com.br |
| **Homologação** | https://homologacao.focusnfe.com.br |

## 🔐 Autenticação

```
Authorization: Basic <base64(TOKEN:)>
```

**Tokens do Sistema:**
- Homologação: `91JZYsXZYgPVytOrcRkoL4BUAd9SJIOe`
- Produção: `NsplRrc28ad2xLO3ulgUCbLAidvbmeCf`

---

## 📋 ENDPOINTS NFC-e (Cupom Fiscal)

### 1️⃣ Emitir NFC-e (Síncrono)

**POST** `/v2/nfce?ref=REFERENCIA`

**Body (JSON):**
```json
{
  "natureza_operacao": "VENDA AO CONSUMIDOR",
  "data_emissao": "2024-02-04T10:30:00-03:00",
  "tipo_documento": "1",
  "presenca_comprador": "1",
  "consumidor_final": "1",
  "finalidade_emissao": "1",
  "cnpj_emitente": "51916585000125",
  "nome_destinatario": "João da Silva",
  "cpf_destinatario": "12345678901",
  "valor_produtos": "100.00",
  "valor_desconto": "0.00",
  "valor_total": "100.00",
  "forma_pagamento": "0",
  "modalidade_frete": "9",
  "items": [
    {
      "numero_item": "1",
      "codigo_ncm": "84713012",
      "codigo_produto": "999",
      "descricao": "PRODUTO TESTE",
      "quantidade_comercial": "1.00",
      "quantidade_tributavel": "1.00",
      "cfop": "5102",
      "valor_unitario_comercial": "100.00",
      "valor_unitario_tributavel": "100.00",
      "valor_bruto": "100.00",
      "unidade_comercial": "UN",
      "unidade_tributavel": "UN",
      "icms_origem": "0",
      "icms_situacao_tributaria": "102",
      "icms_modalidade_base_calculo": "3",
      "icms_base_calculo": "0.00",
      "icms_aliquota": "0.00"
    }
  ],
  "formas_pagamento": [
    {
      "forma_pagamento": "01",
      "valor_pagamento": "100.00"
    }
  ]
}
```

**Resposta Autorizado (200):**
```json
{
  "cnpj_emitente": "07504505000132",
  "ref": "referencia_000899",
  "status": "autorizado",
  "status_sefaz": "100",
  "mensagem_sefaz": "Autorizado o uso da NF-e",
  "chave_nfe": "NFe41190607504505000132650010000000121743484310",
  "numero": "12",
  "serie": "1",
  "caminho_xml_nota_fiscal": "/arquivos_development/...",
  "caminho_danfe": "/notas_fiscais_consumidor/...",
  "qrcode_url": "http://www.fazenda.pr.gov.br/nfce/qrcode/?p=...",
  "url_consulta_nf": "http://www.fazenda.pr.gov.br/nfce/consulta"
}
```

**Resposta Erro (400/422):**
```json
{
  "status": "erro_autorizacao",
  "status_sefaz": "591",
  "mensagem_sefaz": "Informado CSOSN para emissor que nao e do Simples Nacional"
}
```

---

### 2️⃣ Consultar NFC-e

**GET** `/v2/nfce/REFERENCIA?completa=(0|1)`

**Parâmetros:**
- `completa=0`: Retorna dados básicos
- `completa=1`: Retorna dados completos (requisição + protocolo)

**Resposta (200):**
```json
{
  "cnpj_emitente": "07504505000132",
  "ref": "referencia_000899",
  "status": "autorizado",
  "chave_nfe": "NFe41190607504505000132650010000000121743484310",
  "numero": "12",
  "serie": "1",
  "caminho_xml_nota_fiscal": "...",
  "caminho_danfe": "..."
}
```

**Status Possíveis:**
- `autorizado` - Nota autorizada pela SEFAZ
- `cancelado` - Nota cancelada
- `erro_autorizacao` - Erro ao autorizar (pode reenviar)
- `denegado` - Nota denegada (não pode reenviar, guardar XML)

---

### 3️⃣ Cancelar NFC-e

**DELETE** `/v2/nfce/REFERENCIA`

**Body (JSON):**
```json
{
  "justificativa": "Motivo do cancelamento com no mínimo 15 caracteres"
}
```

**Prazo:** 30 minutos após emissão

**Resposta (200):**
```json
{
  "status": "cancelado",
  "status_sefaz": "135",
  "mensagem_sefaz": "Evento registrado e vinculado a NF-e",
  "caminho_xml_cancelamento": "...",
  "numero_protocolo": "141230000025397"
}
```

---

### 4️⃣ Inutilizar Numeração

**POST** `/v2/nfce/inutilizacao`

**Body (JSON):**
```json
{
  "cnpj": "51916585000125",
  "serie": "1",
  "numero_inicial": "700",
  "numero_final": "703",
  "justificativa": "Motivo da inutilizacao com minimo 15 caracteres"
}
```

**Resposta (200):**
```json
{
  "status": "autorizado",
  "status_sefaz": "102",
  "mensagem_sefaz": "Inutilizacao de numero homologado",
  "serie": "1",
  "numero_inicial": "999",
  "numero_final": "1000",
  "modelo": "65",
  "cnpj": "1807504405000132",
  "caminho_xml": "..."
}
```

---

### 5️⃣ Consultar Inutilizações

**GET** `/v2/nfce/inutilizacoes?cnpj=CNPJ`

**Parâmetros Opcionais:**
- `data_recebimento_inicial` - Data inicial (YYYY-MM-DD)
- `data_recebimento_final` - Data final (YYYY-MM-DD)
- `numero_inicial` - Filtrar por número inicial
- `numero_final` - Filtrar por número final

**Resposta (200):**
```json
[
  {
    "status": "autorizado",
    "status_sefaz": "102",
    "mensagem_sefaz": "Inutilizacao de numero homologado",
    "cnpj": "12345678000123",
    "modelo": "65",
    "serie": "1",
    "numero_inicial": "685246",
    "numero_final": "685246",
    "caminho_xml": "...",
    "protocolo_sefaz": "141240068698039"
  }
]
```

---

## 🔴 CÓDIGOS DE ERRO HTTP

| HTTP Code | Status API | Descrição | Correção |
|-----------|------------|-----------|----------|
| 400 | `requisicao_invalida` | Parâmetro inválido ou ausente | Verificar JSON enviado |
| 400 | `justificativa_nao_informada` | Justificativa não informada | Adicionar "justificativa" no body |
| 400 | `ref_ausente` | Parâmetro "ref" não informado | Adicionar ?ref=XXX na URL |
| 400 | `certificado_vencido` | Certificado digital vencido | Renovar certificado A1 |
| 404 | `nfce_nao_encontrada` | NFCe não encontrada | Verificar se existe e está autorizada |
| 404 | `nfce_nao_autorizada` | NFCe não autorizada | Só pode cancelar notas autorizadas |
| 422 | `ambiente_nao_configurado` | Ambiente não configurado | Contatar suporte Focus NFe |
| 422 | `empresa_nao_configurada` | CSC/id_token não configurados | Configurar no Painel API Focus |

---

## 📊 CAMPOS OBRIGATÓRIOS NFC-e

### Cabeçalho
✅ `natureza_operacao` - Descrição da operação  
✅ `data_emissao` - Data/hora com timezone (ISO 8601)  
✅ `tipo_documento` - "1" (Saída)  
✅ `presenca_comprador` - "1" (Presencial)  
✅ `consumidor_final` - "1" (Consumidor final)  
✅ `finalidade_emissao` - "1" (Normal)  
✅ `cnpj_emitente` - CNPJ sem formatação  
✅ `valor_produtos` - Valor sem desconto  
✅ `valor_total` - Valor final  
✅ `forma_pagamento` - "0" (à vista) ou "1" (à prazo)  
✅ `modalidade_frete` - "9" (Sem frete)

### Itens (cada item deve ter)
✅ `numero_item` - Sequencial (string)  
✅ `codigo_produto` - Código interno  
✅ `descricao` - Descrição do produto  
✅ `codigo_ncm` - NCM do produto (8 dígitos)  
✅ `cfop` - CFOP da operação  
✅ `unidade_comercial` - Unidade (UN, KG, etc)  
✅ `unidade_tributavel` - Unidade tributável  
✅ `quantidade_comercial` - Quantidade  
✅ `quantidade_tributavel` - Quantidade tributável  
✅ `valor_unitario_comercial` - Preço unitário  
✅ `valor_unitario_tributavel` - Preço tributável  
✅ `valor_bruto` - Valor total do item  
✅ `icms_origem` - "0" a "8" (origem mercadoria)  
✅ `icms_situacao_tributaria` - CST/CSOSN  
✅ `icms_modalidade_base_calculo` - "3" (valor operação)

### Formas de Pagamento
✅ `forma_pagamento` - Código da forma (01-99)  
✅ `valor_pagamento` - Valor pago

---

## 💳 FORMAS DE PAGAMENTO (Códigos)

| Código | Descrição |
|--------|-----------|
| 01 | Dinheiro |
| 02 | Cheque |
| 03 | Cartão de Crédito |
| 04 | Cartão de Débito |
| 05 | Crediário |
| 10 | Vale Alimentação |
| 11 | Vale Refeição |
| 12 | Vale Presente |
| 13 | Vale Combustível |
| 15 | Boleto Bancário |
| 16 | Depósito Bancário |
| 17 | PIX |
| 18 | Transferência |
| 19 | Cashback |
| 90 | Sem Pagamento |
| 99 | Outros |

---

## 🏷️ CSOSN - Simples Nacional

| Código | Descrição |
|--------|-----------|
| 101 | Tributada pelo Simples Nacional com permissão de crédito |
| 102 | Tributada pelo Simples Nacional sem permissão de crédito |
| 103 | Isenção do ICMS no Simples Nacional |
| 201 | Tributada pelo Simples Nacional com permissão de crédito e com cobrança do ICMS por substituição tributária |
| 202 | Tributada pelo Simples Nacional sem permissão de crédito e com cobrança do ICMS por substituição tributária |
| 500 | ICMS cobrado anteriormente por substituição tributária |
| 900 | Outros |

---

## 🔄 CONTINGÊNCIA OFFLINE

### Emissão Automática
A API emite automaticamente em contingência quando a SEFAZ está fora do ar.

**Resposta:**
```json
{
  "status": "autorizado",
  "contingencia_offline": true,
  "contingencia_offline_efetivada": false,
  "tentativa_anterior": {
    "status": "processando_autorizacao",
    "chave_nfe": "..."
  }
}
```

### Emissão Manual
Para offline da sua aplicação, envie com `forma_emissao=offline`:

**POST** `/v2/nfce?ref=REFERENCIA&forma_emissao=offline`

**Body adicional:**
```json
{
  "numero": "123",
  "serie": "600",
  "codigo_unico": "12345678"
}
```

---

## 📥 DOWNLOAD DE ARQUIVOS

### XML da NFC-e
**GET** `{baseUrl}{caminho_xml_nota_fiscal}`

Exemplo:
```
https://api.focusnfe.com.br/arquivos/07504505000132/202106/XMLs/42210607504505000132650010000000541799075218-nfe.xml
```

### DANFE (HTML)
**GET** `{baseUrl}{caminho_danfe}`

Exemplo:
```
https://api.focusnfe.com.br/notas_fiscais_consumidor/NFe42210607504505000132650010000000541799075218.html
```

### PDF e XML via API
**GET** `/v2/nfce/REFERENCIA.pdf` - Download DANFE em PDF  
**GET** `/v2/nfce/REFERENCIA.xml` - Download XML

---

## ⚠️ REGRAS IMPORTANTES

### Prazo de Cancelamento
- **NFC-e:** 30 minutos após autorização

### Numeração
- A API controla automaticamente (recomendado)
- Ou você pode informar `numero` e `serie`

### Armazenamento XML
- **Obrigatório:** Guardar XMLs por 5 anos
- A API guarda automaticamente

### Homologação
- CNPJ do emitente deve estar cadastrado na Focus NFe
- Usar descrição: "NOTA FISCAL EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL"

---

## 🛠️ IMPLEMENTAÇÃO NO SISTEMA

### Via Edge Functions (RECOMENDADO)
```javascript
const result = await fetch(`${SUPABASE_URL}/functions/v1/proxy-focus-nfe`, {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    endpoint: '/v2/nfce?ref=REFERENCIA',
    method: 'POST',
    data: payloadNFCe
  })
});
```

**Vantagens:**
- ✅ Sem CORS
- ✅ Token seguro no servidor
- ✅ Funciona em qualquer navegador

---

## 📞 SUPORTE

**Documentação Oficial:** https://focusnfe.com.br/doc/  
**Painel API:** https://app.focusnfe.com.br  
**Suporte:** suporte@acrasstec.com.br

---

**Atualizado em:** 04/02/2026  
**Versão da API:** v2
