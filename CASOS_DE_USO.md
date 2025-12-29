# 💡 CASOS DE USO E EXEMPLOS
## Sistema de Pedidos de Compra e Controle de Estoque

---

## 📋 CASOS DE USO

### 1. CADASTRO E GESTÃO DE PRODUTOS

**Caso de Uso:** Empresa precisa cadastrar produtos para controle de estoque

**Ator:** Comprador ou Administrador

**Fluxo Principal:**
1. Usuário acessa "Produtos"
2. Clica em "+ Novo Produto"
3. Preenche formulário:
   - Código: SKU001
   - Nome: Mouse Óptico USB
   - Categoria: Informática
   - Unidade: UN
   - Estoque Atual: 50
   - Estoque Mínimo: 10
   - Preço: 25.90
4. Sistema salva e exibe na lista
5. Sistema monitora automaticamente estoque baixo

**Resultado:** Produto cadastrado e monitorado

---

### 2. ENTRADA DE ESTOQUE

**Caso de Uso:** Chegou um novo lote de produtos

**Ator:** Administrador

**Fluxo Principal:**
1. Admin acessa "Estoque"
2. Clica em "+ Nova Movimentação"
3. Seleciona:
   - Tipo: ENTRADA
   - Produto: Mouse Óptico USB
   - Quantidade: 100
   - Observação: "Lote 2024-001"
4. Sistema:
   - Atualiza estoque: 50 + 100 = 150
   - Registra movimentação no histórico
5. Exibe confirmação

**Resultado:** Estoque atualizado e rastreado

---

### 3. CRIAR PEDIDO DE COMPRA

**Caso de Uso:** Empresa precisa comprar materiais de escritório

**Ator:** Comprador

**Fluxo Principal:**
1. Comprador faz login
2. Acessa "Pedidos" → "+ Novo Pedido"
3. Seleciona fornecedor (Papelaria Silva)
4. Adiciona observação: "Urgente - Entregar até sexta"
5. Sistema cria pedido em RASCUNHO
6. Comprador adiciona itens:
   - Papel A4 (10 caixas x R$ 25,00)
   - Caneta Azul (50 unidades x R$ 1,50)
   - Grampeador (5 unidades x R$ 12,00)
7. Sistema calcula total automaticamente: R$ 385,00
8. Comprador revisa e clica "Enviar para Aprovação"
9. Sistema:
   - Muda status para ENVIADO
   - Gera link WhatsApp para aprovador
   - Formata mensagem com dados do pedido

**Resultado:** Pedido criado e enviado para aprovação

---

### 4. APROVAR PEDIDO

**Caso de Uso:** Aprovador recebe notificação de novo pedido

**Ator:** Aprovador

**Fluxo Principal:**

**Opção A - Via WhatsApp:**
1. Aprovador recebe mensagem no WhatsApp
2. Lê detalhes do pedido
3. Clica no link da mensagem
4. Sistema abre página de aprovação
5. Aprovador revisa itens e total
6. Clica em "Aprovar"
7. Sistema registra aprovação com data/hora e usuário

**Opção B - Via Sistema:**
1. Aprovador faz login
2. Acessa "Aprovações"
3. Vê pedido pendente
4. Clica em "Ver Detalhes"
5. Revisa itens
6. Clica em "Aprovar"

**Resultado:** Pedido aprovado e pronto para finalização

---

### 5. REJEITAR PEDIDO

**Caso de Uso:** Pedido não pode ser aprovado

**Ator:** Aprovador

**Fluxo Principal:**
1. Aprovador acessa "Aprovações"
2. Visualiza pedido
3. Clica em "Rejeitar"
4. Sistema abre modal
5. Aprovador informa motivo:
   "Orçamento do mês já esgotado. Solicitar novamente em janeiro."
6. Clica em "Rejeitar Pedido"
7. Sistema:
   - Muda status para REJEITADO
   - Registra motivo, aprovador e data
   - Notifica solicitante

**Resultado:** Pedido rejeitado com justificativa

---

### 6. FINALIZAR PEDIDO E BAIXAR ESTOQUE

**Caso de Uso:** Pedido aprovado precisa ser finalizado e estoque atualizado

**Ator:** Administrador

**Fluxo Principal:**
1. Admin acessa "Pedidos"
2. Filtra por status "Aprovado"
3. Seleciona pedido
4. Clica em "Finalizar Pedido"
5. Sistema exibe confirmação:
   "Ao finalizar, o estoque será baixado automaticamente. Confirma?"
6. Admin confirma
7. Sistema:
   - Para cada item do pedido:
     * Busca produto
     * Reduz estoque
     * Cria movimentação SAIDA
     * Vincula movimentação ao pedido
   - Atualiza status para FINALIZADO
   - Registra data de finalização
8. Sistema exibe sucesso

**Resultado:** Pedido finalizado e estoque atualizado

**Exemplo:**
- Papel A4: estava 100, comprou 10, ficou 90
- Sistema registra: SAIDA de 10 unidades, pedido PED20241218001

---

### 7. ALERTA DE ESTOQUE BAIXO

**Caso de Uso:** Sistema detecta produtos com estoque abaixo do mínimo

**Ator:** Sistema (automático)

**Fluxo:**
1. Usuário acessa Dashboard
2. Sistema consulta produtos onde estoque_atual <= estoque_minimo
3. Exibe card "Produtos com Estoque Baixo" (em vermelho)
4. Lista produtos:
   - Mouse Óptico: 8 UN (mínimo: 10)
   - Teclado USB: 3 UN (mínimo: 5)
5. Comprador visualiza alerta
6. Cria pedido de reposição

**Resultado:** Reposição de estoque iniciada proativamente

---

### 8. CONSULTAR HISTÓRICO DE MOVIMENTAÇÕES

**Caso de Uso:** Auditar movimentações de um produto específico

**Ator:** Administrador ou Comprador

**Fluxo:**
1. Usuário acessa "Estoque"
2. Vê histórico completo de movimentações
3. Cada linha mostra:
   - Data/hora
   - Produto
   - Tipo (ENTRADA/SAIDA)
   - Quantidade
   - Estoque antes/depois
   - Usuário responsável
   - Pedido vinculado (se houver)
4. Pode filtrar por produto, tipo, data

**Resultado:** Rastreabilidade completa

**Exemplo de Histórico:**
```
18/12/2024 10:30 | Mouse Óptico | ENTRADA | +100 | 50→150 | João (Admin) | -
18/12/2024 14:15 | Mouse Óptico | SAIDA   | -10  | 150→140| Sistema      | PED001
19/12/2024 09:00 | Mouse Óptico | SAIDA   | -5   | 140→135| Maria (Admin)| Manual
```

---

### 9. GESTÃO DE USUÁRIOS E PERMISSÕES

**Caso de Uso:** Novo funcionário precisa acessar o sistema

**Ator:** Administrador

**Fluxo:**
1. Novo funcionário se cadastra no sistema
2. Admin acessa "Usuários"
3. Vê novo usuário com perfil "Comprador"
4. Clica em "Editar"
5. Altera perfil para "Aprovador"
6. Adiciona WhatsApp: 5511988887777
7. Salva
8. Funcionário faz logout e login novamente
9. Agora tem acesso ao menu "Aprovações"

**Resultado:** Usuário configurado com permissões corretas

---

### 10. RELATÓRIO DE PEDIDOS

**Caso de Uso:** Gestão precisa visualizar pedidos do mês

**Ator:** Administrador

**Fluxo:**
1. Admin acessa Dashboard
2. Visualiza cards:
   - Total de Pedidos: 45
   - Pendentes: 3
   - Aprovados: 8
   - Finalizados: 30
   - Rejeitados: 4
3. Acessa "Pedidos"
4. Filtra por status "Finalizado"
5. Visualiza lista completa
6. Para análise detalhada, exporta dados

**Resultado:** Visão gerencial dos pedidos

---

## 🎯 CENÁRIOS REAIS

### Cenário 1: Empresa de Manutenção

**Contexto:** Empresa de manutenção predial com 5 técnicos

**Usuários:**
- 1 Admin (Gerente)
- 3 Compradores (Técnicos)
- 1 Aprovador (Supervisor)

**Produtos:**
- Ferramentas
- Material elétrico
- Material hidráulico
- EPIs

**Fluxo Típico:**
1. Técnico vai a obra e verifica material necessário
2. Cria pedido pelo celular (sistema responsivo)
3. Supervisor recebe WhatsApp
4. Aprova pelo celular
5. Gerente finaliza pedido no escritório
6. Estoque é baixado
7. Material é separado para entrega na obra

---

### Cenário 2: Escritório de Advocacia

**Contexto:** Escritório com 15 advogados

**Usuários:**
- 1 Admin (Sócio)
- 2 Compradores (Assistentes administrativos)
- 1 Aprovador (Gerente administrativo)

**Produtos:**
- Material de escritório
- Livros e legislação
- Material de limpeza
- Equipamentos de TI

**Fluxo Típico:**
1. Sistema alerta estoque baixo de papel
2. Assistente cria pedido de reposição
3. Gerente aprova via WhatsApp
4. Sócio finaliza no final do dia
5. Pedido é enviado ao fornecedor

---

### Cenário 3: Clínica Médica

**Contexto:** Clínica com 3 consultórios

**Usuários:**
- 1 Admin (Proprietário)
- 2 Compradores (Enfermeiras)
- 1 Aprovador (Coordenador médico)

**Produtos:**
- Medicamentos
- Material descartável
- Equipamentos médicos
- Material de limpeza

**Fluxo Típico:**
1. Enfermeira verifica estoque durante plantão
2. Identifica falta de luvas
3. Cria pedido emergencial
4. Coordenador aprova imediatamente
5. Admin finaliza
6. Fornecedor é acionado

---

## 📊 MÉTRICAS E INDICADORES

### KPIs que o Sistema Permite Monitorar

1. **Tempo Médio de Aprovação**
   - Data de envio → Data de aprovação
   - Meta: < 24 horas

2. **Taxa de Rejeição**
   - Pedidos rejeitados / Total de pedidos
   - Meta: < 5%

3. **Acuracidade de Estoque**
   - Produtos com estoque < mínimo
   - Meta: 0 produtos críticos

4. **Valor Médio de Pedidos**
   - Soma de totais / Quantidade de pedidos

5. **Produtos Mais Comprados**
   - Contagem de itens por produto

---

## 🔄 INTEGRAÇÕES FUTURAS (Roadmap)

### Possíveis Expansões

1. **Email Notifications**
   - Enviar email além de WhatsApp
   - Relatórios periódicos automáticos

2. **Anexos em Pedidos**
   - Upload de orçamentos
   - Notas fiscais digitalizadas

3. **Multi-aprovadores**
   - Pedidos acima de X reais precisam de 2 aprovações

4. **Integração ERP**
   - Sincronização com sistemas existentes
   - API REST para terceiros

5. **Código de Barras**
   - Leitura de código de barras para produtos
   - QR Code para rastreamento

6. **App Mobile**
   - App nativo iOS/Android
   - Notificações push

---

## 🎓 TREINAMENTO DE USUÁRIOS

### Roteiro de Treinamento (2 horas)

**Módulo 1 - Introdução (15 min)**
- Visão geral do sistema
- Login e navegação

**Módulo 2 - Cadastros (30 min)**
- Produtos
- Fornecedores
- Demonstração prática

**Módulo 3 - Pedidos (45 min)**
- Criar pedido
- Adicionar itens
- Enviar para aprovação
- Aprovar/rejeitar
- Finalizar
- Prática guiada

**Módulo 4 - Estoque (20 min)**
- Movimentações
- Histórico
- Alertas

**Módulo 5 - Dúvidas (10 min)**
- Perguntas e respostas

---

## ✅ CHECKLIST DE IMPLANTAÇÃO EM PRODUÇÃO

- [ ] Banco de dados criado e configurado
- [ ] Todas as tabelas criadas
- [ ] RLS habilitado e testado
- [ ] Primeiro usuário ADMIN configurado
- [ ] Produtos cadastrados
- [ ] Fornecedores cadastrados
- [ ] Usuários criados (COMPRADOR, APROVADOR)
- [ ] WhatsApp dos aprovadores configurado
- [ ] Fluxo completo testado
- [ ] Backup configurado
- [ ] Documentação entregue
- [ ] Treinamento realizado
- [ ] Sistema em produção
- [ ] Monitoramento ativo

---

**Sistema pronto para uso! 🚀**

Para dúvidas, consulte:
- `README.md` - Visão geral
- `INSTALACAO.md` - Instalação passo a passo
- `DOCUMENTACAO_TECNICA.md` - Detalhes técnicos
