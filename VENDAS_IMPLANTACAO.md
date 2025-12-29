## 🎯 MÓDULO DE VENDAS - GUIA DE IMPLANTAÇÃO

### ✅ Arquivos Criados

1. **database/vendas-modulo.sql** - Script SQL completo
2. **js/services/clientes.js** - Serviço de clientes
3. Modificações em:
   - `js/services/pedidos.js` - Suporte a vendas
   - `js/utils.js` - Numeração VND para vendas

### 📋 PASSO A PASSO PARA ATIVAR VENDAS

#### 1️⃣ Execute o SQL no Supabase

```bash
# Abra o SQL Editor no Supabase e execute:
database/vendas-modulo.sql
```

Isso vai criar:
- ✅ Tabela `clientes` com CPF/CNPJ, endereço, etc
- ✅ Coluna `tipo_pedido` na tabela `pedidos` (COMPRA/VENDA)
- ✅ Coluna `cliente_id` na tabela `pedidos`
- ✅ Função `finalizar_pedido` atualizada para:
  - COMPRA → ENTRADA no estoque
  - VENDA → SAÍDA no estoque
- ✅ Políticas RLS para clientes
- ✅ 3 clientes de exemplo

#### 2️⃣ Estrutura do Banco Após Instalação

**Pedidos de COMPRA:**
```javascript
{
  tipo_pedido: 'COMPRA',
  fornecedor_id: 'uuid',
  cliente_id: null
}
```

**Pedidos de VENDA:**
```javascript
{
  tipo_pedido: 'VENDA',
  fornecedor_id: null,
  cliente_id: 'uuid'
}
```

#### 3️⃣ Como Usar os Serviços

**Cadastrar Cliente:**
```javascript
await createCliente({
    nome: 'João Silva',
    cpf_cnpj: '123.456.789-00',
    tipo: 'FISICA',
    email: 'joao@email.com',
    whatsapp: '5511999998888',
    endereco: 'Rua A, 123',
    cidade: 'São Paulo',
    estado: 'SP',
    cep: '01000-000'
});
```

**Criar Pedido de Venda:**
```javascript
const venda = await createPedido({
    tipo_pedido: 'VENDA',
    cliente_id: 'uuid-do-cliente',
    observacoes: 'Entrega urgente'
});
```

**Listar Vendas:**
```javascript
const vendas = await listPedidos({ 
    tipo_pedido: 'VENDA' 
});
```

**Listar Compras:**
```javascript
const compras = await listPedidos({ 
    tipo_pedido: 'COMPRA' 
});
```

#### 4️⃣ Fluxo de Venda Completo

1. **Criar Venda:**
   ```javascript
   const venda = await createPedido({
       tipo_pedido: 'VENDA',
       cliente_id: cliente.id,
       observacoes: 'Cliente preferencial'
   });
   ```

2. **Adicionar Itens:**
   ```javascript
   await addItemPedido(venda.id, {
       produto_id: produto.id,
       quantidade: 10,
       preco_unitario: 25.00
   });
   ```

3. **Enviar para Aprovação:**
   ```javascript
   await enviarParaAprovacao(venda.id);
   ```

4. **Aprovar:**
   ```javascript
   await aprovarPedido(venda.id);
   ```

5. **Finalizar (Baixa Automática de Estoque):**
   ```javascript
   await finalizarPedido(venda.id);
   // O estoque será REDUZIDO automaticamente!
   ```

### 🔄 Diferenças entre COMPRA e VENDA

| Característica | COMPRA | VENDA |
|---|---|---|
| **Relacionamento** | Fornecedor | Cliente |
| **Número** | PED20241218001 | VND20241218001 |
| **Ao Finalizar** | ENTRADA (+estoque) | SAÍDA (-estoque) |
| **Aprovação** | Sim | Sim |
| **Observação** | Detalhes da compra | Detalhes da entrega |

### 📊 Próximos Passos (Opcional)

Para ter interface completa, você pode criar:

1. **pages/clientes.html** - Gerenciar clientes
2. **pages/vendas.html** - Listar vendas
3. **pages/venda-detalhe.html** - Detalhes da venda
4. Atualizar `components/sidebar.js` - Adicionar links

### 🧪 Como Testar

1. Execute o SQL
2. No console do navegador (F12):

```javascript
// Criar cliente de teste
const cliente = await createCliente({
    nome: 'Cliente Teste',
    cpf_cnpj: '123.456.789-00',
    tipo: 'FISICA',
    email: 'teste@email.com'
});

// Criar venda
const venda = await createPedido({
    tipo_pedido: 'VENDA',
    cliente_id: cliente.id
});

// Adicionar item
await addItemPedido(venda.id, {
    produto_id: 'ID-DO-PRODUTO',
    quantidade: 5,
    preco_unitario: 10.00
});

// Ver a venda
const minhaVenda = await getPedido(venda.id);
console.log(minhaVenda);
```

### ✅ Checklist de Implementação

- [ ] Executar `vendas-modulo.sql` no Supabase
- [ ] Verificar se tabela `clientes` foi criada
- [ ] Verificar se coluna `tipo_pedido` foi adicionada em `pedidos`
- [ ] Testar criação de cliente via console
- [ ] Testar criação de venda via console
- [ ] Testar finalização de venda (baixa de estoque)
- [ ] Criar páginas HTML (opcional)
- [ ] Atualizar menu de navegação (opcional)

### 🚀 Sistema Pronto!

Após executar o SQL, o backend está **100% pronto** para vendas!

Os serviços JavaScript já estão configurados:
- ✅ `clientes.js` - CRUD completo
- ✅ `pedidos.js` - Suporte a COMPRA e VENDA
- ✅ `utils.js` - Numeração VND

Você pode começar a usar via console ou criar as páginas HTML conforme necessário.

---

**Dúvidas?**
- Consulte `CASOS_DE_USO.md` para exemplos
- Veja `DOCUMENTACAO_TECNICA.md` para detalhes
