# 🏢 GUIA DE TRANSFORMAÇÃO: DISTRIBUIDORA DE BEBIDAS

## Visão Geral da Transformação

Este documento descreve a transformação completa do sistema de estoque existente para um **Sistema de PDV de Alto Fluxo para Distribuidora de Bebidas**, com integração fiscal via **Focus NFe**.

---

## 📊 Arquitetura do Sistema

### Módulos Principais

```
┌─────────────────────────────────────────────────────────────────┐
│                    SISTEMA DISTRIBUIDORA                        │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │     PDV      │  │   ESTOQUE    │  │  FINANCEIRO  │          │
│  │ Alto Fluxo   │  │  Tempo Real  │  │    Caixa     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│         │                 │                 │                   │
│  ┌──────────────────────────────────────────────────────┐      │
│  │              CAMADA DE INTEGRAÇÃO                    │      │
│  └──────────────────────────────────────────────────────┘      │
│         │                 │                 │                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  FOCUS NFe   │  │  LEITOR CB   │  │  IMPRESSORA  │          │
│  │  NFC-e/NF-e  │  │   Câmera     │  │   Térmica    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Alterações no Banco de Dados

### Resumo das Mudanças

| Tabela | Ação | Descrição |
|--------|------|-----------|
| `produtos` | Alterada | Campos fiscais (NCM, CFOP, CST, código de barras) |
| `empresa_config` | Alterada | Dados fiscais e configuração Focus NFe |
| `vendas` | Nova | Vendas PDV de alto desempenho |
| `venda_itens` | Nova | Itens da venda com snapshot fiscal |
| `venda_pagamentos` | Nova | Pagamentos multiforma |
| `formas_pagamento` | Nova | Configuração de formas de pagamento |
| `caixas` | Nova | Terminais/caixas físicos |
| `caixa_sessoes` | Nova | Abertura/fechamento de caixa |
| `caixa_movimentacoes` | Nova | Sangria/suprimento |
| `documentos_fiscais` | Nova | NFC-e e NF-e emitidas |
| `contas_receber` | Nova | Financeiro a receber |
| `cotacoes_compra` | Nova | Análise de fornecedores |
| `produto_sabores` | Mantida (backup) | Legado, não mais utilizada |

### Campos Fiscais do Produto

```sql
-- Novos campos na tabela produtos
codigo_barras VARCHAR(20),         -- EAN-13/EAN-8
codigo_barras_embalagem VARCHAR(20), -- Código da caixa
ncm VARCHAR(10),                   -- Ex: 22021000 (bebidas)
cest VARCHAR(9),                   -- Substituição tributária
cfop VARCHAR(4) DEFAULT '5102',    -- Venda mercadoria
cst_icms VARCHAR(3),               -- Situação tributária
csosn VARCHAR(3),                  -- Simples Nacional
aliquota_icms DECIMAL(5,2),
aliquota_pis DECIMAL(5,4),
aliquota_cofins DECIMAL(5,4),
```

### Execução da Migração

```bash
# 1. Fazer backup do banco atual
pg_dump -U postgres -d seu_banco > backup_antes_migracao.sql

# 2. Executar script de migração
psql -U postgres -d seu_banco -f database/migrations/001_transformacao_distribuidora.sql

# 3. Verificar se migração foi bem sucedida
SELECT '✅ Migração concluída!' WHERE EXISTS (SELECT 1 FROM vendas LIMIT 1);
```

---

## 🛒 Fluxo de Vendas Rápidas (PDV)

### Fluxo Completo

```
┌─────────────────────────────────────────────────────────────────┐
│                    FLUXO DE VENDA PDV                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. ABERTURA DE CAIXA                                            │
│    • Operador faz login                                         │
│    • Informa valor inicial (fundo de troco)                     │
│    • Sistema cria sessão do caixa                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. INICIAR VENDA                                                │
│    • F2 ou automático ao abrir                                  │
│    • Cria registro em `vendas` com status EM_ANDAMENTO          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. ADICIONAR ITENS (Loop)                                       │
│    • Escanear código de barras (leitor USB ou câmera)           │
│    • OU digitar código/nome do produto                          │
│    • Sistema busca produto via função otimizada                 │
│    • Valida estoque (configurável)                              │
│    • Adiciona item com snapshot de dados fiscais                │
│    • Atualiza totais em tempo real                              │
│    • Beep de confirmação                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. AJUSTES (Opcional)                                           │
│    • F5: Aplicar desconto (validado contra limite)              │
│    • F6: Identificar cliente                                    │
│    • Alterar quantidades (+/-)                                  │
│    • Remover itens                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. FINALIZAR (F10)                                              │
│    • Escolher forma de pagamento                                │
│    • Dinheiro: informar valor recebido → calcular troco         │
│    • Cartão: integrar com TEF (futuro)                          │
│    • PIX: gerar QR Code (futuro)                                │
│    • Múltiplas formas: dividir valor                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. PROCESSAMENTO                                                │
│    • Registrar pagamentos                                       │
│    • Baixar estoque (atômico)                                   │
│    • Atualizar totais do caixa                                  │
│    • Marcar venda como FINALIZADA                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. EMISSÃO FISCAL                                               │
│    • Montar payload NFC-e/NF-e                                  │
│    • Enviar para Focus NFe                                      │
│    • Aguardar autorização SEFAZ                                 │
│    • Salvar documento fiscal                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. IMPRESSÃO                                                    │
│    • Gerar cupom (DANFE ou não-fiscal)                          │
│    • Enviar para impressora térmica                             │
│    • Exibir na tela se não houver impressora                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. NOVA VENDA                                                   │
│    • Sistema automaticamente inicia nova venda                  │
│    • Foco retorna ao campo de código de barras                  │
└─────────────────────────────────────────────────────────────────┘
```

### Atalhos de Teclado

| Tecla | Ação |
|-------|------|
| F2 | Nova venda |
| F3 | Buscar produto |
| F4 | Cancelar venda |
| F5 | Aplicar desconto |
| F6 | Selecionar cliente |
| F10 | Finalizar venda |
| ESC | Fechar modal |
| Enter | Confirmar código de barras |

---

## 📋 Integração Fiscal (Focus NFe)

### Configuração Inicial

1. **Criar conta Focus NFe**: https://focusnfe.com.br
2. **Obter token de API**: Painel > Configurações > API
3. **Enviar certificado digital A1**: Painel > Certificados
4. **Cadastrar CSC da NFC-e**: Obtido na SEFAZ do estado

### Fluxo de Emissão NFC-e

```javascript
// Exemplo de emissão
const resultado = await FocusNFe.emitirNFCe(
    venda,      // Dados da venda
    itens,      // Itens com dados fiscais
    pagamentos, // Formas de pagamento
    cliente     // Opcional
);

// Resultado
{
    success: true,
    status: 'autorizado',
    chave_nfe: '35260212345678000190650010000001231234567890',
    protocolo: '135260000001234',
    caminho_danfe: 'https://...',
    caminho_xml_nota_fiscal: 'https://...'
}
```

### Ambiente de Homologação

**Sempre inicie em homologação!**

- URL: `https://homologacao.focusnfe.com.br`
- Notas não têm valor fiscal
- Ideal para testes completos

### Checklist Fiscal

- [ ] Certificado digital A1 válido
- [ ] CNPJ cadastrado na SEFAZ
- [ ] CSC obtido e configurado (NFC-e)
- [ ] NCM correto nos produtos
- [ ] CFOP apropriado para a operação
- [ ] Regime tributário configurado
- [ ] Token Focus NFe válido

---

## 📱 Leitor de Código de Barras

### Opções de Leitura

1. **Leitor USB/Serial** (Recomendado)
   - Funciona como teclado emulado
   - Mais rápido e confiável
   - Suporta qualquer formato

2. **Câmera do Dispositivo**
   - Ideal para dispositivos móveis
   - Usa API BarcodeDetector (Chrome 83+)
   - Fallback para biblioteca externa

3. **Entrada Manual**
   - Digitação do código
   - Busca por nome/descrição

### Formatos Suportados

- EAN-13 (produtos de varejo)
- EAN-8 (produtos pequenos)
- Code 128 (logística)
- Code 39 (industrial)
- QR Code (PIX)
- UPC-A/UPC-E (importados)

### Configuração do Leitor USB

```javascript
// O leitor USB funciona automaticamente
// Basta focar no campo de código de barras
BarcodeScanner.iniciarLeitorFisico(async (codigo) => {
    await PDV.adicionarPorCodigo(codigo);
});
```

### Configuração da Câmera

```javascript
// Solicitar permissão e iniciar
await BarcodeScanner.iniciarCamera('video-element', async (codigo) => {
    await PDV.adicionarPorCodigo(codigo);
});
```

---

## 💰 Controle Financeiro

### Abertura de Caixa

```javascript
await PDV.abrirCaixa(caixaId, valorAbertura);
// valorAbertura = fundo de troco (ex: R$ 200,00)
```

### Fechamento de Caixa

```javascript
const resultado = await PDV.fecharCaixa(valorInformado);
// Sistema calcula:
// - Valor esperado (abertura + vendas dinheiro + suprimentos - sangrias)
// - Diferença (valor informado - valor esperado)
```

### Conciliação por Forma de Pagamento

```sql
-- View para relatório de conciliação
SELECT * FROM vw_conciliacao_pagamentos
WHERE data = CURRENT_DATE;
```

### Contas a Receber (Crediário)

Vendas no crediário geram automaticamente registros em `contas_receber`:

```javascript
// Ao finalizar venda com crediário
// Sistema cria parcelas automaticamente
```

---

## 🏎️ Performance e Escalabilidade

### Otimizações Implementadas

1. **Índices Otimizados**
   - Código de barras
   - Status de venda
   - Data de criação
   - Sessão do caixa

2. **Funções PL/pgSQL**
   - Processamento no banco
   - Menos round-trips
   - Transações atômicas

3. **Snapshot de Dados**
   - Itens salvam dados fiscais
   - Independente de alterações futuras

### Boas Práticas

```sql
-- 1. Usar LIMIT em consultas de listagem
SELECT * FROM vendas ORDER BY created_at DESC LIMIT 50;

-- 2. Usar funções otimizadas
SELECT * FROM buscar_produto_codigo_barras('7891234567890');

-- 3. Índices parciais para consultas frequentes
CREATE INDEX idx_vendas_abertas ON vendas(id) WHERE status = 'EM_ANDAMENTO';
```

### Escalabilidade

| Métrica | Capacidade Estimada |
|---------|---------------------|
| Vendas/dia | 10.000+ |
| Itens/venda | 100+ |
| Produtos cadastrados | 50.000+ |
| Usuários simultâneos | 50+ |

---

## 🚀 Próximos Passos

### Fase 1: Migração (Semana 1-2)
- [ ] Executar script de migração
- [ ] Cadastrar produtos com dados fiscais
- [ ] Configurar empresa com dados fiscais
- [ ] Obter certificado digital A1
- [ ] Criar conta Focus NFe

### Fase 2: Testes (Semana 3-4)
- [ ] Testar PDV em homologação
- [ ] Emitir NFC-e de teste
- [ ] Validar fluxo completo de venda
- [ ] Testar leitor de código de barras
- [ ] Treinar equipe

### Fase 3: Produção (Semana 5)
- [ ] Migrar para ambiente de produção
- [ ] Configurar caixas físicos
- [ ] Configurar impressoras térmicas
- [ ] Go-live com monitoramento

### Futuras Implementações
- [ ] Integração TEF (pagamentos por cartão)
- [ ] PIX integrado (QR Code dinâmico)
- [ ] App mobile para vendedores externos
- [ ] Dashboard de análise em tempo real
- [ ] Integração com balanças
- [ ] Controle de validade de produtos

---

## 📁 Arquivos Criados

| Arquivo | Descrição |
|---------|-----------|
| `database/migrations/001_transformacao_distribuidora.sql` | Script de migração do banco |
| `js/services/pdv.js` | Serviço principal do PDV |
| `js/services/focus-nfe.js` | Integração Focus NFe |
| `js/services/barcode-scanner.js` | Leitor de código de barras |
| `pages/pdv.html` | Interface do PDV |
| `pages/configuracoes-empresa-fiscal.html` | Configurações fiscais |
| `docs/GUIA_TRANSFORMACAO_DISTRIBUIDORA.md` | Este documento |

---

## 🆘 Suporte

### Documentação Focus NFe
- https://focusnfe.com.br/doc/

### Códigos NCM Bebidas
- 2201: Águas minerais
- 2202: Refrigerantes, sucos
- 2203: Cervejas
- 2204: Vinhos
- 2208: Destilados

### Tabela CFOP Principais
- 5102: Venda de mercadoria (dentro do estado)
- 6102: Venda de mercadoria (fora do estado)
- 5405: Venda com ST (dentro do estado)
