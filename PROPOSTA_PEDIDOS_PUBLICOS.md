# 🌐 PROPOSTA: SISTEMA DE PEDIDOS PÚBLICOS
## Análise de Viabilidade e Arquitetura

---

## 📋 RESUMO EXECUTIVO

### ✅ Viabilidade: **ALTA**

O sistema atual possui toda a estrutura necessária para implementar essa funcionalidade:
- ✅ Tabela de pedidos com status e aprovações
- ✅ Sistema de itens de pedido
- ✅ Controle de estoque em tempo real
- ✅ Tela de aprovação existente (pode ser reaproveitada)
- ✅ Views de estoque disponíveis
- ✅ Sistema de autenticação e permissões

### 🎯 Complexidade Estimada
- **Desenvolvimento**: 3-5 dias
- **Testes**: 1-2 dias
- **Total**: 4-7 dias

---

## 🏗️ ARQUITETURA PROPOSTA

### 1. Novo Tipo de Pedido: `PRE_PEDIDO`

```sql
-- Adicionar novo tipo ao CHECK constraint
ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedido_tipo_check;
ALTER TABLE pedidos ADD CONSTRAINT pedido_tipo_check 
  CHECK (tipo_pedido IN ('COMPRA', 'VENDA', 'PRE_PEDIDO'));
```

### 2. Nova Tabela: `pre_pedidos`

```sql
CREATE TABLE IF NOT EXISTS pre_pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    numero VARCHAR(50) UNIQUE NOT NULL, -- Ex: PRE-2026-0001
    nome_solicitante VARCHAR(255) NOT NULL, -- Nome fornecido pelo cliente
    email_contato VARCHAR(255), -- Opcional
    telefone_contato VARCHAR(50), -- Opcional
    status VARCHAR(20) NOT NULL DEFAULT 'PENDENTE' 
      CHECK (status IN ('PENDENTE', 'EM_ANALISE', 'APROVADO', 'REJEITADO', 'EXPIRADO')),
    total DECIMAL(10,2) DEFAULT 0,
    observacoes TEXT,
    token_publico VARCHAR(100) UNIQUE NOT NULL, -- Token único para acesso público
    ip_origem VARCHAR(50), -- IP de quem fez o pedido
    user_agent TEXT, -- Navegador utilizado
    data_expiracao TIMESTAMP WITH TIME ZONE, -- 24h após criação
    
    -- Campos de processamento interno
    analisado_por UUID REFERENCES users(id),
    data_analise TIMESTAMP WITH TIME ZONE,
    cliente_vinculado_id UUID REFERENCES clientes(id),
    pedido_gerado_id UUID REFERENCES pedidos(id), -- ID do pedido de venda gerado
    motivo_rejeicao TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_pre_pedidos_status ON pre_pedidos(status);
CREATE INDEX idx_pre_pedidos_token ON pre_pedidos(token_publico);
CREATE INDEX idx_pre_pedidos_expiracao ON pre_pedidos(data_expiracao);
CREATE INDEX idx_pre_pedidos_created ON pre_pedidos(created_at DESC);
```

### 3. Tabela de Itens de Pré-Pedido

```sql
CREATE TABLE IF NOT EXISTS pre_pedido_itens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pre_pedido_id UUID REFERENCES pre_pedidos(id) ON DELETE CASCADE NOT NULL,
    produto_id UUID REFERENCES produtos(id) NOT NULL,
    sabor_id UUID REFERENCES produto_sabores(id), -- Opcional, para produtos com sabores
    quantidade DECIMAL(10,2) NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL, -- Preço no momento da solicitação
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED,
    estoque_disponivel_momento DECIMAL(10,2), -- Estoque no momento da solicitação
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices
CREATE INDEX idx_pre_pedido_itens_pre_pedido ON pre_pedido_itens(pre_pedido_id);
CREATE INDEX idx_pre_pedido_itens_produto ON pre_pedido_itens(produto_id);
CREATE INDEX idx_pre_pedido_itens_sabor ON pre_pedido_itens(sabor_id);
```

### 4. Função para Expirar Pré-Pedidos (24h)

```sql
-- Função para marcar pedidos como expirados
CREATE OR REPLACE FUNCTION expirar_pre_pedidos()
RETURNS void AS $$
BEGIN
    UPDATE pre_pedidos
    SET status = 'EXPIRADO',
        updated_at = NOW()
    WHERE status = 'PENDENTE'
      AND data_expiracao < NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger automático (executar a cada hora via cron job ou pg_cron)
-- Alternativamente, verificar na aplicação ao carregar a tela
```

### 5. View para Lista Pública de Produtos

```sql
CREATE OR REPLACE VIEW vw_produtos_publicos AS
SELECT 
    p.id,
    p.codigo,
    p.marca,
    p.nome,
    p.descricao,
    p.unidade,
    p.preco_venda,
    p.estoque_atual,
    p.estoque_minimo,
    p.tem_sabores,
    CASE 
        WHEN p.estoque_atual = 0 THEN 'ZERADO'
        WHEN p.estoque_atual <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produtos p
WHERE p.ativo = true
  AND p.estoque_atual > 0 -- Mostrar apenas com estoque
ORDER BY p.marca, p.nome;

-- View para sabores públicos
CREATE OR REPLACE VIEW vw_sabores_publicos AS
SELECT 
    s.id,
    s.produto_id,
    s.sabor,
    s.quantidade,
    s.preco_venda,
    s.estoque_minimo,
    p.marca,
    p.nome as produto_nome,
    CASE 
        WHEN s.quantidade = 0 THEN 'ZERADO'
        WHEN s.quantidade <= s.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produto_sabores s
INNER JOIN produtos p ON p.id = s.produto_id
WHERE s.ativo = true
  AND p.ativo = true
  AND s.quantidade > 0
ORDER BY p.marca, p.nome, s.sabor;
```

---

## 🔒 SEGURANÇA E POLÍTICAS RLS

### Políticas de Acesso Público (SEM autenticação)

```sql
-- Permitir acesso público às views de produtos
ALTER TABLE produtos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Produtos públicos para leitura anônima"
ON produtos FOR SELECT
TO anon
USING (ativo = true AND estoque_atual > 0);

-- Permitir criação de pré-pedidos sem autenticação
ALTER TABLE pre_pedidos ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Criação pública de pré-pedidos"
ON pre_pedidos FOR INSERT
TO anon
WITH CHECK (true);

CREATE POLICY "Leitura pública via token"
ON pre_pedidos FOR SELECT
TO anon
USING (true); -- Restringir por token na aplicação

CREATE POLICY "Usuários internos podem ver todos"
ON pre_pedidos FOR SELECT
TO authenticated
USING (true);

CREATE POLICY "Usuários internos podem atualizar"
ON pre_pedidos FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Itens de pré-pedido
ALTER TABLE pre_pedido_itens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Inserção pública de itens"
ON pre_pedido_itens FOR INSERT
TO anon
WITH CHECK (true);

CREATE POLICY "Leitura pública de itens"
ON pre_pedido_itens FOR SELECT
TO anon
USING (true);

CREATE POLICY "Usuários internos podem ver itens"
ON pre_pedido_itens FOR SELECT
TO authenticated
USING (true);
```

---

## 📱 COMPONENTES A DESENVOLVER

### 1. Página Pública: `pedido-publico.html`

**URL**: `https://seudominio.com/pedido-publico.html`

**Características**:
- ❌ Sem autenticação
- ✅ Design responsivo e limpo
- ✅ Lista produtos/sabores com estoque
- ✅ Carrinho de compras interativo
- ✅ Validação de quantidade vs estoque
- ✅ Campo para nome do solicitante
- ✅ Campos opcionais: email, telefone, observações
- ✅ Confirmação visual após envio
- ✅ Geração de token de acompanhamento

**Estrutura HTML**:
```html
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Solicitar Pedido - [Nome da Empresa]</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-gray-50">
    <!-- Header -->
    <header class="bg-white shadow">
        <div class="max-w-7xl mx-auto px-4 py-6">
            <h1 class="text-3xl font-bold text-gray-900">
                Catálogo de Produtos
            </h1>
            <p class="text-gray-600 mt-2">
                Selecione os produtos e envie sua solicitação
            </p>
        </div>
    </header>

    <main class="max-w-7xl mx-auto px-4 py-8">
        <!-- Filtros -->
        <div class="bg-white rounded-lg shadow p-4 mb-6">
            <select id="filter-marca">...</select>
        </div>

        <!-- Grid de Produtos -->
        <div id="produtos-grid" class="grid grid-cols-1 md:grid-cols-3 gap-6">
            <!-- Cards de produtos -->
        </div>

        <!-- Carrinho Flutuante -->
        <div id="carrinho-float" class="fixed bottom-4 right-4">
            <button class="bg-blue-600 text-white px-6 py-3 rounded-full shadow-lg">
                🛒 Carrinho (<span id="qtd-itens">0</span>)
            </button>
        </div>

        <!-- Modal Carrinho -->
        <div id="modal-carrinho" class="hidden">...</div>

        <!-- Modal Finalizar -->
        <div id="modal-finalizar" class="hidden">
            <form id="form-pedido-publico">
                <input type="text" name="nome" required placeholder="Seu nome completo">
                <input type="email" name="email" placeholder="Email (opcional)">
                <input type="tel" name="telefone" placeholder="Telefone (opcional)">
                <textarea name="observacoes" placeholder="Observações"></textarea>
                <button type="submit">Enviar Solicitação</button>
            </form>
        </div>
    </main>

    <script src="js/pedido-publico.js"></script>
</body>
</html>
```

### 2. JavaScript Service: `js/services/pre-pedidos.js`

```javascript
// Funções principais

// Listar produtos públicos
async function listarProdutosPublicos(filtros = {}) {
    const { data, error } = await supabase
        .from('vw_produtos_publicos')
        .select('*')
        .order('marca', { ascending: true })
        .order('nome', { ascending: true });
    
    if (error) throw error;
    return data;
}

// Listar sabores públicos
async function listarSaboresPublicos(produtoId = null) {
    let query = supabase
        .from('vw_sabores_publicos')
        .select('*');
    
    if (produtoId) {
        query = query.eq('produto_id', produtoId);
    }
    
    const { data, error } = await query;
    if (error) throw error;
    return data;
}

// Criar pré-pedido
async function criarPrePedido(dadosPedido) {
    // Gerar token único
    const token = gerarToken();
    const dataExpiracao = new Date();
    dataExpiracao.setHours(dataExpiracao.getHours() + 24);

    // Inserir pré-pedido
    const { data: prePedido, error: errorPedido } = await supabase
        .from('pre_pedidos')
        .insert({
            nome_solicitante: dadosPedido.nome,
            email_contato: dadosPedido.email || null,
            telefone_contato: dadosPedido.telefone || null,
            observacoes: dadosPedido.observacoes || null,
            token_publico: token,
            ip_origem: await obterIP(),
            user_agent: navigator.userAgent,
            data_expiracao: dataExpiracao.toISOString(),
            status: 'PENDENTE'
        })
        .select()
        .single();
    
    if (errorPedido) throw errorPedido;

    // Gerar número do pedido
    await atualizarNumeroPedido(prePedido.id);

    // Inserir itens
    const itens = dadosPedido.itens.map(item => ({
        pre_pedido_id: prePedido.id,
        produto_id: item.produto_id,
        sabor_id: item.sabor_id || null,
        quantidade: item.quantidade,
        preco_unitario: item.preco_unitario,
        estoque_disponivel_momento: item.estoque_atual
    }));

    const { error: errorItens } = await supabase
        .from('pre_pedido_itens')
        .insert(itens);
    
    if (errorItens) throw errorItens;

    // Calcular e atualizar total
    const total = dadosPedido.itens.reduce((sum, item) => 
        sum + (item.quantidade * item.preco_unitario), 0
    );

    await supabase
        .from('pre_pedidos')
        .update({ total })
        .eq('id', prePedido.id);

    return { ...prePedido, token };
}

function gerarToken() {
    return 'PRE_' + Date.now() + '_' + Math.random().toString(36).substring(7);
}

async function obterIP() {
    try {
        const response = await fetch('https://api.ipify.org?format=json');
        const data = await response.json();
        return data.ip;
    } catch {
        return 'desconhecido';
    }
}
```

### 3. Página Interna: `pages/pre-pedidos.html`

**Características**:
- ✅ Requer autenticação
- ✅ Permissões: VENDEDOR, APROVADOR, ADMIN
- ✅ Lista pré-pedidos pendentes e em análise
- ✅ Filtro por status e data
- ✅ Indicador de expiração (contador regressivo)
- ✅ Ações: Analisar, Rejeitar
- ✅ Modal de análise com:
  - Visualização dos itens
  - Seleção de cliente do sistema
  - Validação de estoque atual
  - Botão "Gerar Pedido de Venda"

**Estrutura**:
```html
<main class="lg:ml-64 pt-16">
    <div class="max-w-7xl mx-auto px-4 py-8">
        <h2 class="text-3xl font-bold mb-6">Pré-Pedidos Recebidos</h2>

        <!-- Filtros -->
        <div class="bg-white rounded-lg shadow p-4 mb-6">
            <select id="filter-status">
                <option value="PENDENTE">Pendentes</option>
                <option value="EM_ANALISE">Em Análise</option>
                <option value="APROVADO">Aprovados</option>
                <option value="REJEITADO">Rejeitados</option>
                <option value="EXPIRADO">Expirados</option>
            </select>
        </div>

        <!-- Cards de Pré-Pedidos -->
        <div id="pre-pedidos-container" class="space-y-4">
            <!-- Card exemplo -->
            <div class="bg-white rounded-lg shadow p-6">
                <div class="flex justify-between items-start mb-4">
                    <div>
                        <h3 class="font-bold text-lg">PRE-2026-0001</h3>
                        <p class="text-gray-600">João Silva</p>
                        <p class="text-sm text-gray-500">joao@email.com</p>
                    </div>
                    <div class="text-right">
                        <span class="px-3 py-1 bg-yellow-100 text-yellow-800 rounded-full text-sm">
                            Expira em 18h
                        </span>
                        <p class="text-sm text-gray-500 mt-2">
                            Recebido em 13/01/2026 10:30
                        </p>
                    </div>
                </div>

                <!-- Resumo dos itens -->
                <div class="border-t pt-4 mb-4">
                    <p class="text-sm font-medium mb-2">Itens solicitados:</p>
                    <ul class="text-sm text-gray-600 space-y-1">
                        <li>• Produto A - Sabor X: 10 unidades</li>
                        <li>• Produto B: 5 unidades</li>
                    </ul>
                </div>

                <!-- Total e Ações -->
                <div class="flex justify-between items-center border-t pt-4">
                    <p class="text-xl font-bold">Total: R$ 450,00</p>
                    <div class="space-x-2">
                        <button onclick="analisarPrePedido('id')" 
                                class="px-4 py-2 bg-blue-600 text-white rounded-lg">
                            🔍 Analisar
                        </button>
                        <button onclick="rejeitarPrePedido('id')" 
                                class="px-4 py-2 bg-red-600 text-white rounded-lg">
                            ❌ Rejeitar
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </div>
</main>
```

### 4. Modal de Análise

**Fluxo de Aprovação**:
1. Usuário clica em "Analisar"
2. Sistema abre modal com detalhes completos
3. Valida estoque atual vs solicitado
4. Usuário seleciona cliente do cadastro
5. Sistema cria Pedido de Venda (status RASCUNHO)
6. Itens são copiados para pedido_itens
7. Estoque é validado e reservado
8. Status do pré-pedido: APROVADO
9. Pedido de venda segue fluxo normal

```javascript
async function analisarPrePedido(prePedidoId) {
    // Buscar dados completos
    const { data: prePedido } = await supabase
        .from('pre_pedidos')
        .select(`
            *,
            pre_pedido_itens (
                *,
                produto:produtos (*),
                sabor:produto_sabores (*)
            )
        `)
        .eq('id', prePedidoId)
        .single();

    // Validar estoque atual
    const validacao = await validarEstoqueItens(prePedido.pre_pedido_itens);

    // Abrir modal com formulário
    abrirModalAnalise(prePedido, validacao);
}

async function gerarPedidoVenda(prePedidoId, clienteId) {
    try {
        showLoading(true);

        // 1. Buscar pré-pedido
        const { data: prePedido } = await supabase
            .from('pre_pedidos')
            .select('*, pre_pedido_itens(*)')
            .eq('id', prePedidoId)
            .single();

        // 2. Validar estoque novamente
        const estoqueOk = await validarEstoque(prePedido.pre_pedido_itens);
        if (!estoqueOk) {
            throw new Error('Estoque insuficiente');
        }

        // 3. Criar pedido de venda
        const { data: pedido } = await supabase
            .from('pedidos')
            .insert({
                tipo_pedido: 'VENDA',
                solicitante_id: (await getCurrentUser()).id,
                cliente_id: clienteId,
                status: 'RASCUNHO',
                observacoes: `Gerado a partir do pré-pedido ${prePedido.numero}\nSolicitante: ${prePedido.nome_solicitante}`
            })
            .select()
            .single();

        // 4. Copiar itens
        const itens = prePedido.pre_pedido_itens.map(item => ({
            pedido_id: pedido.id,
            produto_id: item.produto_id,
            quantidade: item.quantidade,
            preco_unitario: item.preco_unitario
        }));

        await supabase
            .from('pedido_itens')
            .insert(itens);

        // 5. Atualizar pré-pedido
        await supabase
            .from('pre_pedidos')
            .update({
                status: 'APROVADO',
                analisado_por: (await getCurrentUser()).id,
                data_analise: new Date().toISOString(),
                cliente_vinculado_id: clienteId,
                pedido_gerado_id: pedido.id
            })
            .eq('id', prePedidoId);

        showToast('Pedido de venda criado com sucesso!', 'success');
        window.location.href = `/pages/pedido-detalhe.html?id=${pedido.id}`;

    } catch (error) {
        handleError(error, 'Erro ao gerar pedido de venda');
    } finally {
        showLoading(false);
    }
}
```

---

## 🔄 REAPROVEITAMENTO DA TELA DE APROVAÇÃO

### Opção 1: Integrar na Tela Existente

Adicionar uma nova aba na `aprovacao.html`:

```html
<nav class="flex border-b">
    <button onclick="switchTab('pedidos')" class="tab-button active">
        Pedidos de Compra
    </button>
    <button onclick="switchTab('pre-pedidos')" class="tab-button">
        Pré-Pedidos (Público)
    </button>
</nav>
```

**Vantagens**:
- ✅ Centraliza aprovações em um só lugar
- ✅ Menos páginas para manter
- ✅ UX consistente

**Desvantagens**:
- ⚠️ Pode ficar confuso misturar tipos diferentes
- ⚠️ Fluxos de aprovação diferentes

### Opção 2: Criar Página Separada (RECOMENDADO)

Criar `pages/pre-pedidos.html` específica.

**Vantagens**:
- ✅ Separação clara de responsabilidades
- ✅ Fluxo específico e otimizado
- ✅ Permissões específicas
- ✅ Mais fácil de manter

**Desvantagens**:
- ⚠️ Mais uma página no sistema

---

## ⚠️ PONTOS DE ATENÇÃO

### 1. Segurança

#### ✅ Proteções Implementadas:
- Token único por pré-pedido
- RLS com políticas específicas
- Registro de IP e User-Agent
- Expiração automática em 24h
- Sem acesso a dados sensíveis
- Rate limiting (implementar no servidor)

#### 🚨 Riscos e Mitigações:
| Risco | Mitigação |
|-------|-----------|
| Spam de pedidos | Rate limiting por IP (max 5 pedidos/hora) |
| DDoS | Cloudflare ou similar |
| Dados falsos | Validação manual obrigatória antes de gerar venda |
| Estoque fictício | Validação em tempo real no momento da aprovação |

### 2. Estoque

#### ⚠️ Desafios:
- Pré-pedido não reserva estoque
- Estoque pode mudar entre solicitação e aprovação
- Múltiplos pré-pedidos podem solicitar mesmo produto

#### ✅ Soluções:
1. **Validação em Duas Etapas**:
   - Mostrar estoque disponível no momento da solicitação
   - Validar novamente no momento da aprovação
   - Alertar se estoque mudou

2. **Indicador Visual**:
   ```javascript
   function verificarMudancaEstoque(item) {
       const estoqueAtual = await getEstoqueAtual(item.produto_id);
       if (estoqueAtual < item.estoque_disponivel_momento) {
           return {
               status: 'ALERTA',
               mensagem: `Estoque diminuiu de ${item.estoque_disponivel_momento} para ${estoqueAtual}`
           };
       }
   }
   ```

3. **Política de Prioridade**:
   - Primeiro a pedir, primeiro a ser analisado
   - Alertas de estoque crítico

### 3. Expiração (24h)

#### Implementação:
```javascript
// No carregamento da tela
async function carregarPrePedidos() {
    // Expirar pedidos vencidos
    await supabase.rpc('expirar_pre_pedidos');
    
    // Carregar lista atualizada
    const { data } = await supabase
        .from('pre_pedidos')
        .select('*')
        .in('status', ['PENDENTE', 'EM_ANALISE'])
        .order('created_at', { ascending: true });
    
    renderizarComContador(data);
}

function renderizarComContador(prePedidos) {
    prePedidos.forEach(pp => {
        const horasRestantes = calcularHorasRestantes(pp.data_expiracao);
        // Atualizar UI com contador
    });
}
```

### 4. Experiência do Usuário

#### Cliente Externo:
- ✅ Design limpo e intuitivo
- ✅ Validação em tempo real
- ✅ Feedback visual claro
- ✅ Confirmação por email (opcional)
- ✅ Token de acompanhamento

#### Usuário Interno:
- ✅ Notificações de novos pré-pedidos
- ✅ Dashboard com contador
- ✅ Filtros e busca
- ✅ Análise rápida e eficiente
- ✅ Histórico completo

---

## 📊 FLUXOGRAMA COMPLETO

```
┌─────────────────────────┐
│ Cliente Externo         │
│ Acessa Link Público     │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Visualiza Catálogo      │
│ (Produtos com Estoque)  │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Adiciona ao Carrinho    │
│ (Valida Estoque)        │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Informa Nome e Contato  │
│ (Opcional: Email/Tel)   │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Envia Pré-Pedido        │
│ Status: PENDENTE        │
│ Expira em: 24h          │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Confirmação + Token     │
└─────────────────────────┘
            │
            │ (Notificação)
            ▼
┌─────────────────────────┐
│ Usuário Interno         │
│ Visualiza em Tela       │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Clica "Analisar"        │
│ Status: EM_ANALISE      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Modal de Análise        │
│ - Ver itens             │
│ - Validar estoque       │
│ - Selecionar cliente    │
└───────────┬─────────────┘
            │
       ┌────┴────┐
       │         │
       ▼         ▼
   ┌──────┐  ┌──────┐
   │Aprovar│  │Rejeitar│
   └───┬──┘  └───┬──┘
       │         │
       │         ▼
       │    ┌─────────────┐
       │    │Status:      │
       │    │REJEITADO    │
       │    └─────────────┘
       │
       ▼
┌─────────────────────────┐
│ Gera Pedido de Venda    │
│ - Copia itens           │
│ - Vincula cliente       │
│ - Status: RASCUNHO      │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Pré-Pedido: APROVADO    │
│ Link para Pedido Gerado │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│ Fluxo Normal de Vendas  │
│ - Finalizar             │
│ - Gerar NF              │
│ - Baixar Estoque        │
└─────────────────────────┘
```

---

## 📝 CHECKLIST DE IMPLEMENTAÇÃO

### Fase 1: Banco de Dados (1 dia)
- [ ] Criar tabela `pre_pedidos`
- [ ] Criar tabela `pre_pedido_itens`
- [ ] Criar views `vw_produtos_publicos` e `vw_sabores_publicos`
- [ ] Implementar função `expirar_pre_pedidos()`
- [ ] Configurar políticas RLS
- [ ] Testar permissões anônimas

### Fase 2: API/Services (1 dia)
- [ ] Criar `js/services/pre-pedidos.js`
- [ ] Funções de listagem pública
- [ ] Funções de criação de pré-pedido
- [ ] Funções de análise e aprovação
- [ ] Validação de estoque
- [ ] Geração de pedido de venda

### Fase 3: Página Pública (1-2 dias)
- [ ] Criar `pedido-publico.html`
- [ ] Grid de produtos com filtros
- [ ] Carrinho de compras
- [ ] Modal de finalização
- [ ] Validações de estoque
- [ ] Confirmação e token
- [ ] Design responsivo
- [ ] Testes de usabilidade

### Fase 4: Página Interna (1 dia)
- [ ] Criar `pages/pre-pedidos.html`
- [ ] Lista com filtros
- [ ] Contador de expiração
- [ ] Modal de análise
- [ ] Seletor de cliente
- [ ] Integração com pedidos
- [ ] Histórico

### Fase 5: Integrações (1 dia)
- [ ] Adicionar menu no sidebar
- [ ] Notificações de novos pré-pedidos
- [ ] Dashboard: contador de pendentes
- [ ] Email de confirmação (opcional)
- [ ] WhatsApp notificação (opcional)

### Fase 6: Testes e Ajustes (1-2 dias)
- [ ] Testes de segurança
- [ ] Testes de RLS
- [ ] Testes de estoque
- [ ] Testes de expiração
- [ ] Testes de fluxo completo
- [ ] Ajustes de UX
- [ ] Documentação

---

## 💡 MELHORIAS FUTURAS

### Fase 2 (Opcional):
1. **Acompanhamento por Token**
   - Página onde cliente pode ver status do pedido
   - Sem login, apenas com token

2. **Notificações Automáticas**
   - Email ao cliente quando aprovado/rejeitado
   - WhatsApp para equipe interna

3. **Catálogo com Imagens**
   - Upload de fotos dos produtos
   - Gallery view

4. **Promoções Públicas**
   - Produtos em destaque
   - Ofertas especiais

5. **Multi-idiomas**
   - Catálogo em inglês/espanhol

6. **Analytics**
   - Produtos mais solicitados
   - Taxa de conversão
   - Tempo médio de aprovação

---

## 🎯 CONCLUSÃO

### ✅ Viabilidade: **CONFIRMADA**

O sistema atual possui toda infraestrutura necessária. A implementação é viável e pode ser feita de forma modular, sem impactar funcionalidades existentes.

### 🚀 Recomendações:

1. **Começar pela Fase 1** (Banco de Dados)
2. **Criar página separada** para pré-pedidos (não integrar com aprovação)
3. **Implementar em produção** após testes extensivos
4. **Monitorar** primeiras semanas para ajustes
5. **Coletar feedback** dos usuários internos

### 📈 Benefícios Esperados:

- ✅ Aumento de vendas (acesso fácil ao catálogo)
- ✅ Redução de trabalho manual (menos WhatsApp/telefone)
- ✅ Melhor experiência do cliente
- ✅ Rastreabilidade completa
- ✅ Validação de estoque automática

---

## 📞 PRÓXIMOS PASSOS

1. **Aprovação do Projeto**: Validar proposta com stakeholders
2. **Definir Prioridades**: Quais features da Fase 1 são essenciais
3. **Estimar Recursos**: Tempo e pessoas necessárias
4. **Planejar Sprint**: Dividir tarefas
5. **Iniciar Desenvolvimento**: Começar pelo banco de dados

---

**Documento criado em**: 13/01/2026  
**Versão**: 1.0  
**Status**: Proposta para Análise
