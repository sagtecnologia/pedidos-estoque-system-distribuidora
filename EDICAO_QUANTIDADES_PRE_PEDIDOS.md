# Edição de Quantidades em Pré-Pedidos

## 📋 Visão Geral

Implementação completa de funcionalidade que permite ajustar as quantidades dos itens de um pré-pedido quando não houver estoque suficiente, antes de gerar o pedido de venda.

## ✨ Funcionalidades Implementadas

### 1. **Edição Interativa de Quantidades**

#### Controles de Quantidade
- **Botões +/-**: Aumentar ou diminuir quantidade rapidamente
- **Campo numérico**: Edição manual com validação
- **Limites dinâmicos**: Máximo baseado no estoque disponível
- **Indicador visual**: Mostra estoque máximo disponível

#### Exemplo Visual
```
┌─────────────────────────────────────┐
│ Produto: Vape Descartável 2000 Puffs│
│ Sabor: Morango                      │
│                                     │
│ Quantidade:  [ - ] [5] [ + ]       │
│              Max: 10                │
└─────────────────────────────────────┘
```

### 2. **Validação em Tempo Real**

#### Status de Estoque
Cada item mostra seu status atual:

- **✅ Estoque OK**: Quantidade solicitada disponível
- **⚠️ Alerta**: Estoque diminuiu desde a criação
- **❌ Insuficiente**: Sem estoque para quantidade solicitada

#### Validações Automáticas
- Quantidade não pode exceder estoque disponível
- Quantidade não pode ser negativa
- Alerta ao tentar definir quantidade zero (remoção)
- Bloqueio do botão de gerar pedido se houver problemas

### 3. **Recálculo Automático**

#### Cálculos Dinâmicos
Ao alterar qualquer quantidade, o sistema recalcula automaticamente:

1. **Subtotal do item**: `quantidade × preço_unitário`
2. **Total do pedido**: Soma de todos os subtotais
3. **Status de validação**: Verifica estoque para cada item
4. **Estado do botão**: Habilita/desabilita conforme validação

#### Exemplo de Fluxo
```
Cliente solicita: 15 unidades
Estoque disponível: 10 unidades

↓ Usuário ajusta para 10

Novo subtotal: R$ 250,00 (10 × R$ 25,00)
Novo total: R$ 875,00
Status: ✅ Estoque OK
Botão: 🟢 HABILITADO
```

### 4. **Remoção de Itens**

#### Como Remover
- Diminuir quantidade até zero
- Sistema pergunta: "Remover este item do pedido?"
- Se confirmado, item é marcado para remoção

#### Indicadores Visuais
- Linha fica opaca (50% transparência)
- Fundo cinza claro
- Status: 🗑️ "Item será removido"

#### Proteção
- Se todos os itens forem removidos:
  - Botão muda para "Não há itens no pedido"
  - Alerta sugere rejeitar o pedido
  - Impossibilita geração do pedido

### 5. **Salvamento Inteligente**

#### Processo de Salvamento
Ao gerar o pedido com quantidades alteradas:

```
1. Sistema detecta alterações
   ↓
2. Confirma com usuário
   "Você alterou as quantidades. Deseja salvar?"
   ↓
3. Atualiza banco de dados
   - Remove itens com quantidade zero
   - Atualiza quantidades modificadas
   - Recalcula total do pré-pedido
   ↓
4. Gera pedido de venda
   ↓
5. Limpa dados temporários
```

## 🎨 Interface do Usuário

### Alertas Contextuais

#### Quando há problemas de estoque:
```
┌──────────────────────────────────────────────┐
│ ⚠️ Atenção: Estoque Insuficiente            │
├──────────────────────────────────────────────┤
│ Alguns itens não possuem estoque suficiente. │
│ Você pode:                                    │
│                                               │
│ • Ajustar as quantidades usando os botões    │
│ • Remover itens clicando em diminuir até zero│
│ • Rejeitar o pedido se não for possível      │
│                                               │
│ O pedido só poderá ser gerado quando todos   │
│ os itens tiverem estoque disponível.         │
└──────────────────────────────────────────────┘
```

#### Quando tudo está OK:
```
┌──────────────────────────────────────────────┐
│          [Gerar Pedido de Venda]             │
│               (botão verde)                   │
└──────────────────────────────────────────────┘
```

#### Quando há ajustes pendentes:
```
┌──────────────────────────────────────────────┐
│    [Ajuste as quantidades para gerar]        │
│           (botão cinza desabilitado)          │
└──────────────────────────────────────────────┘
```

### Tabela de Itens

```
┌────────────────┬──────────┬────────┬──────────┬────────────┐
│ Produto        │ Qtd      │ Preço  │ Subtotal │ Estoque    │
├────────────────┼──────────┼────────┼──────────┼────────────┤
│ Vape 2000     │ [-][5][+]│ R$ 25  │ R$ 125   │ ✅ OK: 10  │
│ Puffs         │ Max: 10  │        │          │            │
├────────────────┼──────────┼────────┼──────────┼────────────┤
│ Essência      │ [-][3][+]│ R$ 15  │ R$ 45    │ ✅ OK: 20  │
│ Menta         │ Max: 20  │        │          │            │
├────────────────┼──────────┼────────┼──────────┼────────────┤
│ Pod           │    8     │ R$ 30  │ R$ 240   │ ❌ Insuf:7 │
│ Recarregável  │ (readonly)│        │          │            │
└────────────────┴──────────┴────────┴──────────┴────────────┘
                                  TOTAL: R$ 410
```

## 🔧 Aspectos Técnicos

### Estrutura de Dados

#### Objeto de Controle
```javascript
dadosAnaliseAtual = {
    prePedido: null,           // Dados completos do pré-pedido
    validacao: null,           // Resultados da validação
    itensAtualizados: {        // Quantidades modificadas
        'item-id-1': 5,        // itemId: novaQuantidade
        'item-id-2': 0,        // 0 = será removido
        'item-id-3': 10
    }
}
```

### Funções Principais

#### 1. `diminuirQuantidade(itemId, prePedidoId)`
- Decrementa quantidade em 1
- Respeita mínimo de 0
- Chama atualização

#### 2. `aumentarQuantidade(itemId, prePedidoId)`
- Incrementa quantidade em 1
- Respeita máximo de estoque disponível
- Chama atualização

#### 3. `atualizarQuantidadeItem(itemId, prePedidoId)`
- Valida nova quantidade
- Atualiza subtotal
- Verifica estoque
- Atualiza status visual
- Chama recálculo geral

#### 4. `recalcularTotalGeral(prePedidoId)`
- Soma todos os subtotais
- Valida estoque de todos os itens
- Atualiza total na tela
- Habilita/desabilita botão de gerar

#### 5. `gerarPedidoVendaModal(prePedidoId)`
- Detecta alterações
- Salva no banco se necessário
- Gera pedido de venda
- Limpa dados temporários

### Persistência de Dados

#### Momento do Salvamento
As alterações só são salvas no banco quando:
1. Usuário clica em "Gerar Pedido de Venda"
2. Confirma o salvamento das alterações
3. Sistema valida tudo está correto

#### Operações no Banco
```sql
-- Atualizar quantidade
UPDATE pre_pedido_itens 
SET quantidade = :nova_quantidade 
WHERE id = :item_id;

-- Remover item
DELETE FROM pre_pedido_itens 
WHERE id = :item_id;

-- Atualizar total
UPDATE pre_pedidos 
SET total = :novo_total 
WHERE id = :pre_pedido_id;
```

## 📊 Fluxo Completo de Uso

### Cenário: Cliente Solicita Mais do que Há em Estoque

```
1. Cliente solicita pré-pedido
   ├─ Produto A: 15 unidades
   ├─ Produto B: 8 unidades
   └─ Produto C: 5 unidades
   
2. Vendedor abre para análise
   ├─ ✅ Produto A: OK (estoque: 20)
   ├─ ❌ Produto B: Insuficiente (estoque: 5)
   └─ ✅ Produto C: OK (estoque: 10)
   
3. Sistema mostra alertas
   ├─ Destaca Produto B em vermelho
   ├─ Mostra botões +/- habilitados
   ├─ Exibe alerta de estoque insuficiente
   └─ Desabilita botão de gerar pedido
   
4. Vendedor ajusta quantidades
   ├─ Produto B: Reduz de 8 para 5
   ├─ Sistema valida em tempo real
   ├─ ✅ Produto B: Agora está OK
   └─ Recalcula total: R$ 875,00 → R$ 800,00
   
5. Sistema habilita geração
   ├─ Todos os itens com estoque OK
   ├─ Botão fica verde
   └─ Pronto para gerar pedido
   
6. Vendedor confirma geração
   ├─ Seleciona cliente
   ├─ Clica em "Gerar Pedido"
   ├─ Sistema pergunta sobre alterações
   ├─ Vendedor confirma
   ├─ Quantidades são salvas
   ├─ Pedido de venda é criado
   └─ Estoque é movimentado automaticamente
```

## 🎯 Casos de Uso

### Caso 1: Ajuste Simples
**Situação**: Cliente pediu 10, tem apenas 8 em estoque
**Ação**: Ajustar para 8 e gerar pedido
**Resultado**: Pedido gerado com quantidade ajustada

### Caso 2: Remoção de Item
**Situação**: Um dos 3 itens não tem estoque
**Ação**: Remover item sem estoque
**Resultado**: Pedido gerado com 2 itens

### Caso 3: Impossível Atender
**Situação**: Todos os itens sem estoque
**Ação**: Rejeitar pedido com justificativa
**Resultado**: Cliente é notificado

### Caso 4: Ajuste Múltiplo
**Situação**: Vários itens precisam de ajuste
**Ação**: Ajustar cada um individualmente
**Resultado**: Pedido gerado com todas as alterações

## ⚠️ Validações e Proteções

### Validações Implementadas

1. **Quantidade Mínima**: Não permite valores negativos
2. **Quantidade Máxima**: Limitada ao estoque disponível
3. **Remoção Acidental**: Confirma antes de remover item
4. **Pedido Vazio**: Impede gerar pedido sem itens
5. **Estoque Insuficiente**: Bloqueia geração se houver problemas
6. **Cliente Obrigatório**: Exige seleção de cliente
7. **Confirmação de Alterações**: Pede confirmação antes de salvar

### Mensagens de Erro

```javascript
// Quantidade inválida
"Quantidade inválida"

// Excede estoque
"Quantidade máxima disponível: X"

// Sem cliente
"Selecione um cliente"

// Sem itens
"Não há itens no pedido"
```

## 🔄 Integração com Outras Funcionalidades

### Relacionamentos

1. **Validação de Estoque**
   - Usa mesma lógica de `validarEstoquePrePedido()`
   - Sincronizado com estoque em tempo real

2. **Geração de Pedido**
   - Altera quantidades antes de chamar `gerarPedidoVenda()`
   - Mantém integridade referencial

3. **Movimentação de Estoque**
   - Triggers automáticos continuam funcionando
   - Estoque movimentado com quantidades corretas

4. **Auditoria**
   - Observações do pedido registram alterações
   - Histórico de análise preservado

## 📱 Responsividade

A interface é totalmente responsiva:

### Desktop
- Botões +/- ao lado do campo
- Tabela completa visível
- Alertas expandidos

### Tablet
- Layout mantido
- Controles reduzidos
- Scroll horizontal na tabela

### Mobile
- Botões empilhados
- Cards em vez de tabela
- Alertas compactos

## 🎨 Feedback Visual

### Estados dos Componentes

#### Input de Quantidade
```css
/* Normal (readonly) */
border: gray, background: light-gray

/* Editável */
border: blue, background: white

/* Com erro */
border: red, background: light-red
```

#### Botões
```css
/* + e - habilitados */
background: green/red, cursor: pointer

/* Desabilitados */
background: gray, cursor: not-allowed

/* Hover */
background: darker-shade
```

#### Status
```css
/* OK */
color: green, icon: ✅

/* Alerta */
color: yellow, icon: ⚠️

/* Erro */
color: red, icon: ❌

/* Removido */
color: gray, icon: 🗑️
```

## 📖 Documentação para Usuários

### Como Usar

1. **Abrir Pré-Pedido para Análise**
   - Acesse "Pré-Pedidos Públicos"
   - Clique em "Analisar" no pedido desejado

2. **Identificar Problemas de Estoque**
   - Itens com ❌ vermelho = sem estoque
   - Itens com ⚠️ amarelo = estoque reduzido
   - Itens com ✅ verde = tudo OK

3. **Ajustar Quantidades**
   - Use os botões + e - para ajustar
   - Ou digite diretamente no campo
   - Veja o total sendo recalculado automaticamente

4. **Remover Itens (se necessário)**
   - Diminua quantidade até zero
   - Confirme a remoção
   - Item fica marcado como removido

5. **Gerar Pedido**
   - Quando todos os itens estiverem OK
   - Botão ficará verde
   - Selecione o cliente
   - Clique em "Gerar Pedido de Venda"

6. **Confirmar Alterações**
   - Sistema mostrará resumo das alterações
   - Confirme para salvar e gerar
   - Pedido será criado com quantidades ajustadas

## 🚀 Benefícios

### Para o Negócio
- ✅ Maior flexibilidade no atendimento
- ✅ Redução de pedidos rejeitados
- ✅ Melhor aproveitamento de estoque
- ✅ Agilidade no processo de venda

### Para o Vendedor
- ✅ Interface intuitiva
- ✅ Validação em tempo real
- ✅ Menos erros manuais
- ✅ Processo mais rápido

### Para o Cliente
- ✅ Pedidos atendidos mesmo com ajustes
- ✅ Comunicação clara sobre mudanças
- ✅ Agilidade na resposta
- ✅ Transparência no processo

## 🔮 Melhorias Futuras

### Possíveis Aprimoramentos

1. **Sugestão Automática**
   - Sistema sugere quantidade máxima disponível
   - Botão "Ajustar para Máximo"

2. **Produtos Substitutos**
   - Sugerir produtos similares em estoque
   - Permitir substituição com um clique

3. **Histórico de Alterações**
   - Log de todas as mudanças feitas
   - Quem alterou, quando e o que

4. **Notificação ao Cliente**
   - Email/WhatsApp automático informando ajustes
   - Pedido de confirmação antes de gerar

5. **Ajuste em Lote**
   - Botão para ajustar todos os itens de uma vez
   - Aplicar porcentagem de redução

6. **Comparação Visual**
   - Mostrar quantidade original vs ajustada
   - Destacar diferenças

## 📞 Suporte

### Dúvidas Comuns

**P: As alterações são salvas automaticamente?**
R: Não, só são salvas quando você clica em "Gerar Pedido" e confirma.

**P: Posso desfazer alterações?**
R: Sim, basta recarregar a página ou fechar e abrir o pedido novamente.

**P: O que acontece se eu remover todos os itens?**
R: O botão será desabilitado e você deverá rejeitar o pedido.

**P: O cliente é notificado das alterações?**
R: Atualmente não, mas isso pode ser configurado futuramente.

**P: Posso aumentar além do estoque?**
R: Não, o sistema limita ao estoque disponível no momento.

---

## ✅ Implementação Completa

Esta funcionalidade está **100% implementada e funcional** no arquivo:
- **[pages/pre-pedidos.html](pages/pre-pedidos.html)**

Todas as funções estão documentadas e testadas para garantir uma experiência fluida e sem erros.
