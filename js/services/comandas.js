/**
 * Serviço de Gerenciamento de Comandas (Vendas Abertas)
 * Para controle de vendas em aberto no local (mesas, balcão, delivery)
 */

class ServicoComandas {
    constructor() {
        this.comandaAtual = null;
        this.cachesProdutos = {}; // 🚀 Cache para evitar re-queries de produtos
    }

    /**
     * 🔍 CALCULAR ESTOQUE REALMENTE DISPONÍVEL
     * Considera: estoque_atual - quantidades em comandas abertas (excluindo comanda atual)
     * @param {uuid} produtoId - ID do produto
     * @param {uuid} comandaIdAtual - ID da comanda atual (para excluir)
     * @returns {Promise<number>} Estoque disponível real
     */
    async calcularEstoqueDisponivel(produtoId, comandaIdAtual = null) {
        try {
            // 1️⃣ Buscar estoque atual do produto
            const { data: produtos, error: erroProduto } = await supabase
                .from('produtos')
                .select('estoque_atual')
                .eq('id', produtoId)
                .limit(1);

            if (erroProduto) throw erroProduto;

            const estoqueAtual = produtos && produtos.length > 0 ? produtos[0].estoque_atual : 0;

            // 2️⃣ BUSCAR QUANTIDADES EM TODAS as comandas abertas com esse produto
            // Precisa selecionar 'comandas(status)' para poder filtrar por comandas.status
            const { data: todosItensAbertas, error: erroTodos } = await supabase
                .from('comanda_itens')
                .select('comanda_id, quantidade, comandas(status)')
                .eq('produto_id', produtoId)
                .eq('status', 'pendente')
                .eq('comandas.status', 'aberta');

            if (erroTodos) {
                console.warn('⚠️ Erro ao buscar itens em comandas, usando estoque direto:', erroTodos);
                return estoqueAtual;
            }

            // 3️⃣ FILTRAR apenas itens de comandas abertas (validar status)
            let totalEmComandas = 0;
            let quantidadeNaComandaAtual = 0;

            if (todosItensAbertas && todosItensAbertas.length > 0) {
                todosItensAbertas.forEach(item => {
                    // ✅ Validar que a comanda está realmente aberta
                    if (item.comandas?.status === 'aberta') {
                        totalEmComandas += item.quantidade || 0;
                        
                        // Se é item da comanda atual, guardar para descontar
                        if (comandaIdAtual && item.comanda_id === comandaIdAtual) {
                            quantidadeNaComandaAtual += item.quantidade || 0;
                        }
                    }
                });
            }

            // 4️⃣ CALCULAR: Estoque - (Total de outras comandas)
            const quantidadeEmOutrasComandas = totalEmComandas - quantidadeNaComandaAtual;
            const estoqueDisponivel = estoqueAtual - quantidadeEmOutrasComandas;

            console.log(`📊 Produto ${produtoId}: Estoque=${estoqueAtual}, Total em Comandas=${totalEmComandas}, Nesta Comanda=${quantidadeNaComandaAtual}, Em Outras=${quantidadeEmOutrasComandas}, Disponível=${estoqueDisponivel}`);

            return Math.max(0, estoqueDisponivel);
        } catch (erro) {
            console.error('Erro ao calcular estoque disponível:', erro);
            throw erro;
        }
    }

    /**
     * Buscar todas as comandas abertas
     */
    async buscarComandasAbertas() {
        try {
            const { data: comandas, error } = await supabase
                .from('comandas')
                .select(`
                    *,
                    clientes (
                        id,
                        nome,
                        telefone
                    ),
                    comanda_itens (
                        id,
                        produto_id,
                        nome_produto,
                        quantidade,
                        preco_unitario,
                        subtotal,
                        desconto,
                        status,
                        observacoes
                    )
                `)
                .eq('status', 'aberta')
                .order('data_abertura', { ascending: false });

            if (error) throw error;

            return comandas.map(c => ({
                ...c,
                itens: c.comanda_itens || [],
                cliente: c.clientes
            }));
        } catch (erro) {
            console.error('Erro ao buscar comandas abertas:', erro);
            throw erro;
        }
    }

    /**
     * Buscar comanda por ID com todos os itens
     */
    async buscarComandaPorId(comandaId) {
        try {
            const { data: comandas, error } = await supabase
                .from('comandas')
                .select(`
                    *,
                    clientes (
                        id,
                        nome,
                        cpf_cnpj,
                        telefone,
                        email
                    ),
                    comanda_itens (
                        id,
                        produto_id,
                        nome_produto,
                        quantidade,
                        preco_unitario,
                        subtotal,
                        desconto,
                        status,
                        observacoes,
                        created_at
                    )
                `)
                .eq('id', comandaId)
                .limit(1);

            if (error) throw error;
            
            if (!comandas || comandas.length === 0) {
                throw new Error(`Comanda com ID ${comandaId} não encontrada`);
            }
            
            const comanda = comandas[0];

            return {
                ...comanda,
                itens: comanda.comanda_itens || [],
                cliente: comanda.clientes
            };
        } catch (erro) {
            console.error('Erro ao buscar comanda:', erro);
            throw erro;
        }
    }

    /**
     * Buscar comanda por número
     */
    async buscarComandaPorNumero(numeroComanda) {
        try {
            const { data: comandas, error } = await supabase
                .from('comandas')
                .select(`
                    *,
                    comanda_itens (*)
                `)
                .eq('numero_comanda', numeroComanda)
                .limit(1);

            if (error) {
                // Se não encontrar, retornar null sem logar erro
                if (error.code === 'PGRST116') {
                    return null;
                }
                throw error;
            }
            return comandas && comandas.length > 0 ? comandas[0] : null;
        } catch (erro) {
            console.error('Erro ao buscar comanda por número:', erro);
            return null;
        }
    }

    /**
     * 🚀 Atualizar apenas os itens da comanda (otimizado - mais rápido que recarregar tudo)
     */
    async atualizarItensComanda(comandaId) {
        try {
            const { data: itens, error } = await supabase
                .from('comanda_itens')
                .select('id, produto_id, nome_produto, quantidade, preco_unitario, subtotal, desconto, status, observacoes, created_at')
                .eq('comanda_id', comandaId)
                .order('created_at', { ascending: true });

            if (error) throw error;
            return itens || [];
        } catch (erro) {
            console.error('Erro ao atualizar itens:', erro);
            return [];
        }
    }

    /**
     * Abrir nova comanda
     * @param {Object} dados - { numero_comanda, tipo, numero_mesa, cliente_id, cliente_nome }
     */
    async abrirComanda(dados) {
        try {
            // Buscar usuário atual
            const { data: { user } } = await supabase.auth.getUser();

            const { data: comanda, error } = await supabase
                .from('comandas')
                .insert({
                    numero_comanda: dados.numero_comanda,
                    tipo: dados.tipo || 'mesa',
                    numero_mesa: dados.numero_mesa || null,
                    cliente_id: dados.cliente_id || null,
                    cliente_nome: dados.cliente_nome || null,
                    status: 'aberta',
                    usuario_abertura_id: user?.id,
                    data_abertura: new Date().toISOString()
                })
                .select()
                .limit(1);

            if (error) throw error;
            
            const comandaInserida = comanda && comanda.length > 0 ? comanda[0] : null;

            console.log('✅ Comanda aberta:', comandaInserida);
            return comandaInserida;
        } catch (erro) {
            console.error('Erro ao abrir comanda:', erro);
            throw erro;
        }
    }

    /**
     * Adicionar item à comanda
    /**
     * Adicionar item à comanda com otimizações de performance
     */
    async adicionarItem(comandaId, produtoId, quantidade, observacoes = null) {
        try {
            const inicio = performance.now();

            // 🚀 OTIMIZAÇÃO 1: Usar cache se produto já foi buscado
            let produto = this.cacheProdutos?.[produtoId];
            
            if (!produto) {
                const { data: produtos, error: erroProduto } = await supabase
                    .from('produtos')
                    .select('id, nome, preco_venda, estoque_atual')
                    .eq('id', produtoId)
                    .limit(1);

                if (erroProduto) throw erroProduto;
                
                produto = produtos && produtos.length > 0 ? produtos[0] : null;
                if (!produto) throw new Error('Produto não encontrado');
                
                // Armazenar em cache
                if (!this.cacheProdutos) this.cacheProdutos = {};
                this.cacheProdutos[produtoId] = produto;
            }

            // 🚀 OTIMIZAÇÃO 2: Buscar item existente E usuário em PARALELO
            const [
                { data: itemExistente },
                { data: { user } }
            ] = await Promise.all([
                supabase
                    .from('comanda_itens')
                    .select('id, quantidade, preco_unitario')
                    .eq('comanda_id', comandaId)
                    .eq('produto_id', produtoId)
                    .eq('status', 'pendente')
                    .maybeSingle(),
                supabase.auth.getUser()
            ]);

            // ✅ VALIDAR ESTOQUE CONSIDERANDO COMANDAS ABERTAS (NÃO SÓ ESSA COMANDA)
            const estoqueDisponivel = await this.calcularEstoqueDisponivel(produtoId, comandaId);
            const quantidadeJaAdicionada = itemExistente ? itemExistente.quantidade : 0;
            const quantidadeTotalNecessaria = quantidadeJaAdicionada + quantidade;

            if (quantidadeTotalNecessaria > estoqueDisponivel) {
                throw new Error(
                    `Estoque insuficiente para ${produto.nome}\n` +
                    `Já adicionado nesta comanda: ${quantidadeJaAdicionada.toFixed(2)}\n` +
                    `Novo: ${quantidade.toFixed(2)}\n` +
                    `Total solicitado: ${quantidadeTotalNecessaria.toFixed(2)}\n` +
                    `Disponível (outras comandas descontadas): ${estoqueDisponivel.toFixed(2)}`
                );
            }

            const precoUnitario = parseFloat(produto.preco_venda);
            let result;

            // Se produto já existe, AUMENTAR A QUANTIDADE
            if (itemExistente) {
                console.log('✅ Produto já existe. Incrementando...');
                
                const novaQuantidade = itemExistente.quantidade + quantidade;
                const novoSubtotal = novaQuantidade * precoUnitario;

                const { data: itensAtualizados, error: erroUpdate } = await supabase
                    .from('comanda_itens')
                    .update({
                        quantidade: novaQuantidade,
                        subtotal: novoSubtotal,
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', itemExistente.id)
                    .select()
                    .limit(1);

                if (erroUpdate) throw erroUpdate;
                result = itensAtualizados && itensAtualizados.length > 0 ? itensAtualizados[0] : null;
            } else {
                // Se NÃO existe, CRIAR NOVO ITEM
                console.log('✅ Produto novo. Criando item...');

                const subtotal = precoUnitario * quantidade;

                const { data: itens, error } = await supabase
                    .from('comanda_itens')
                    .insert({
                        comanda_id: comandaId,
                        produto_id: produtoId,
                        nome_produto: produto.nome,
                        quantidade,
                        preco_unitario: precoUnitario,
                        subtotal,
                        observacoes,
                        usuario_id: user?.id,
                        status: 'pendente'
                    })
                    .select()
                    .limit(1);

                if (error) throw error;
                result = itens && itens.length > 0 ? itens[0] : null;
            }

            // 🚀 OTIMIZAÇÃO 3: Recalcular totais em background (não bloqueia UX)
            this.recalcularTotaisComanda(comandaId).catch(err => 
                console.error('Erro ao recalcular totais:', err)
            );

            const tempo = (performance.now() - inicio).toFixed(0);
            console.log(`✅ Item adicionado em ${tempo}ms`);
            
            return result;
        } catch (erro) {
            console.error('Erro ao adicionar item:', erro);
            throw erro;
        }
    }

    /**
     * Remover item da comanda
     */
    async removerItem(itemId) {
        try {
            // Buscar o item para pegar o comanda_id antes de deletar
            const { data: itens, error: errorItem } = await supabase
                .from('comanda_itens')
                .select('comanda_id')
                .eq('id', itemId)
                .limit(1);

            if (errorItem) throw errorItem;
            
            if (!itens || itens.length === 0) {
                throw new Error('Item não encontrado');
            }
            
            const item = itens[0];

            const { error } = await supabase
                .from('comanda_itens')
                .delete()
                .eq('id', itemId);

            if (error) throw error;

            // Recalcular totais da comanda após remover o item
            await this.recalcularTotaisComanda(item.comanda_id);

            console.log('✅ Item removido da comanda');
            return true;
        } catch (erro) {
            console.error('Erro ao remover item:', erro);
            throw erro;
        }
    }

    /**
     * Alterar quantidade de um item
     */
    async alterarQuantidadeItem(itemId, novaQuantidade) {
        try {
            // Buscar item atual
            const { data: itens, error: erroItem } = await supabase
                .from('comanda_itens')
                .select('produto_id, preco_unitario, comanda_id')
                .eq('id', itemId)
                .limit(1);

            if (erroItem) throw erroItem;
            
            if (!itens || itens.length === 0) {
                throw new Error('Item não encontrado');
            }
            
            const item = itens[0];

            // ✅ VALIDAR ESTOQUE CONSIDERANDO COMANDAS ABERTAS
            const estoqueDisponivel = await this.calcularEstoqueDisponivel(item.produto_id, item.comanda_id);
            
            // 🔓 Pular validação se exige_estoque = false (serviços, vouchers, etc)
            if (produto?.exige_estoque !== false) {
                if (novaQuantidade > estoqueDisponivel) {
                    throw new Error(
                        `Estoque insuficiente para ${produto.nome}\n` +
                        `Disponível (outras comandas descontadas): ${estoqueDisponivel.toFixed(2)}\n` +
                        `Solicitado: ${novaQuantidade.toFixed(2)}`
                    );
                }
            } else {
                console.log(`ℹ️ Produto ${produto?.nome} não exige validação de estoque`);
            }

            const novoSubtotal = item.preco_unitario * novaQuantidade;

            const { error } = await supabase
                .from('comanda_itens')
                .update({
                    quantidade: novaQuantidade,
                    subtotal: novoSubtotal,
                    updated_at: new Date().toISOString()
                })
                .eq('id', itemId);

            if (error) throw error;

            // Recalcular totais da comanda após alterar a quantidade
            await this.recalcularTotaisComanda(item.comanda_id);

            console.log('✅ Quantidade alterada');
            return true;
        } catch (erro) {
            console.error('Erro ao alterar quantidade:', erro);
            throw erro;
        }
    }

    /**
     * Recalcular totais da comanda somando os itens ativos
     */
    async recalcularTotaisComanda(comandaId) {
        try {
            // Buscar todos os itens ativos (não cancelados) da comanda
            const { data: itens, error: errorItens } = await supabase
                .from('comanda_itens')
                .select('subtotal')
                .eq('comanda_id', comandaId)
                .neq('status', 'cancelado');

            if (errorItens) throw errorItens;

            // Buscar valores atuais de desconto e acréscimo
            const { data: comandas, error: errorComanda } = await supabase
                .from('comandas')
                .select('desconto, acrescimo')
                .eq('id', comandaId)
                .limit(1);

            if (errorComanda) throw errorComanda;
            
            if (!comandas || comandas.length === 0) {
                throw new Error('Comanda não encontrada');
            }
            
            const comanda = comandas[0];

            // Calcular subtotal somando todos os itens
            const subtotal = itens.reduce((sum, item) => sum + (item.subtotal || 0), 0);

            // Calcular valor total aplicando desconto e acréscimo
            const desconto = comanda.desconto || 0;
            const acrescimo = comanda.acrescimo || 0;
            const valorTotal = subtotal - desconto + acrescimo;

            // Atualizar totais na comanda
            const { error } = await supabase
                .from('comandas')
                .update({
                    subtotal: subtotal,
                    valor_total: valorTotal,
                    updated_at: new Date().toISOString()
                })
                .eq('id', comandaId);

            if (error) throw error;

            console.log(`✅ Totais recalculados - Subtotal: ${subtotal.toFixed(2)}, Total: ${valorTotal.toFixed(2)}`);
            return { subtotal, valorTotal };
        } catch (erro) {
            console.error('Erro ao recalcular totais:', erro);
            throw erro;
        }
    }

    /**
     * Aplicar desconto/acréscimo na comanda
     */
    async aplicarDescontoAcrescimo(comandaId, desconto = 0, acrescimo = 0) {
        try {
            // Atualizar desconto e acréscimo na comanda
            const { error } = await supabase
                .from('comandas')
                .update({
                    desconto,
                    acrescimo,
                    updated_at: new Date().toISOString()
                })
                .eq('id', comandaId);

            if (error) throw error;

            // Recalcular totais usando a função centralizada
            await this.recalcularTotaisComanda(comandaId);

            console.log('✅ Desconto/acréscimo aplicado');
            return true;
        } catch (erro) {
            console.error('Erro ao aplicar desconto/acréscimo:', erro);
            throw erro;
        }
    }

    /**
     * Fechar comanda e gerar venda
     * @param {number} comandaId - ID da comanda
     * @param {string} formaPagamento - Forma de pagamento
     * @param {number} valorPago - Valor pago pelo cliente
     * @param {number} acrescimoTarifa - Acrescimo de tarifa de cartao (opcional)
     * @param {number} descontoFinal - Desconto aplicado na finalização (opcional)
     */
    async fecharComanda(comandaId, formaPagamento, valorPago, acrescimoTarifa = 0, descontoFinal = 0) {
        try {
            // Buscar comanda completa
            const comanda = await this.buscarComandaPorId(comandaId);

            // ✅ VALIDAR STATUS DA COMANDA
            if (comanda.status === 'cancelada') {
                throw new Error('Não é possível fechar uma comanda cancelada');
            }

            if (comanda.status !== 'aberta') {
                throw new Error(`Comanda não está aberta. Status atual: ${comanda.status}`);
            }

            // ✅ VALIDAR DUPLICAÇÃO - verificar se já tem venda_id
            if (comanda.venda_id) {
                throw new Error(`Esta comanda já foi finalizada. Venda ID: ${comanda.venda_id}`);
            }

            if (comanda.itens.length === 0) {
                throw new Error('Não é possível fechar comanda sem itens');
            }

            // Buscar usuário atual
            const { data: { user } } = await supabase.auth.getUser();

            // ✅ EXIGIR CAIXA ABERTO (mesma regra do PDV)
            // Buscar sessão de caixa aberta do usuário (operador_id)
            console.log('🔍 [COMANDA] Buscando caixa aberto para operador:', user?.id);
            const { data: movimentacoes, error: erroMovimentacao } = await supabase
                .from('caixa_sessoes')
                .select('id, caixa_id')
                .eq('operador_id', user?.id)
                .eq('status', 'ABERTO')
                .order('data_abertura', { ascending: false })
                .limit(1);

            if (erroMovimentacao) {
                console.error('❌ Erro ao buscar caixa:', erroMovimentacao);
                throw erroMovimentacao;
            }

            if (!movimentacoes || movimentacoes.length === 0) {
                throw new Error('Nenhum caixa aberto. Abra um caixa antes de fechar a comanda.');
            }

            const movimentacao = movimentacoes[0];
            console.log('✅ Caixa encontrado:', movimentacao.id);
            const caixaId = movimentacao.caixa_id;
            const movimentacaoId = movimentacao.id;

            // ✅ VALIDAR ESTOQUE ANTES DE FINALIZAR (considerando TODAS as comandas abertas)
            console.log('🔍 [COMANDA] Validando estoque disponível (outras comandas descontadas)...');
            for (const item of comanda.itens) {
                if (item.status === 'cancelado') continue;

                const { data: produtos } = await supabase
                    .from('produtos')
                    .select('nome, exige_estoque')
                    .eq('id', item.produto_id)
                    .limit(1);
                
                const produto = produtos && produtos.length > 0 ? produtos[0] : null;
                
                if (!produto) {
                    throw new Error(`Produto não encontrado: ${item.nome_produto}`);
                }
                
                // 🔓 Pular validação se exige_estoque = false (serviços, vouchers, etc)
                if (produto.exige_estoque === false) {
                    console.log(`ℹ️ [COMANDA] Produto ${produto.nome} não exige validação de estoque`);
                    continue;
                }
                
                // ✅ CALCULAR ESTOQUE DISPONÍVEL (DESCONTANDO OUTRAS COMANDAS)
                const estoqueDisponivel = await this.calcularEstoqueDisponivel(item.produto_id, comandaId);
                if (item.quantidade > estoqueDisponivel) {
                    throw new Error(
                        `Estoque insuficiente para ${produto.nome}\n` +
                        `Disponível (outras comandas descontadas): ${estoqueDisponivel.toFixed(2)}\n` +
                        `Solicitado nesta comanda: ${item.quantidade.toFixed(2)}`
                    );
                }
            }
            console.log('✅ [COMANDA] Estoque validado - todos os itens com estoque disponível');

            // Criar venda
            const valorTotal = comanda.valor_total;
            const valorComDesconto = valorTotal - descontoFinal;
            const troco = valorPago > valorComDesconto ? valorPago - valorComDesconto : 0;

            // ✅ CALCULAR TAXA NO BACKEND (apenas informativo na tela, debitada ao gravar)
            let acrescimoTarifa_Calculado = 0;
            if (formaPagamento === 'CARTAO_CREDITO') {
                acrescimoTarifa_Calculado = (valorComDesconto * 3.16) / 100; // 3,16% para crédito
            } else if (formaPagamento === 'CARTAO_DEBITO') {
                acrescimoTarifa_Calculado = (valorComDesconto * 1.09) / 100; // 1,09% para débito
            }
            
            console.log(`💳 Taxa de ${formaPagamento}: R$ ${acrescimoTarifa_Calculado.toFixed(2)} (desconto: R$ ${descontoFinal.toFixed(2)})`);

            // ✅ CALCULAR VALOR FINAL DA VENDA
            // Se é cartão: SUBTRAIR a taxa do valor gravado
            // Se não é cartão: manter o valor com desconto
            let valorFinalVenda = valorComDesconto;
            if (formaPagamento === 'CARTAO_CREDITO' || formaPagamento === 'CARTAO_DEBITO') {
                // Taxa é debitada ao gravar (reduz o valor da venda)
                valorFinalVenda = valorComDesconto - acrescimoTarifa_Calculado;
                console.log(`💳 Valor da venda após debitar taxa: R$ ${valorFinalVenda.toFixed(2)}`);
            }

            // ✅ VALIDAR DADOS OBRIGATÓRIOS
            if (!caixaId) throw new Error('Caixa ID não encontrado');
            if (!movimentacaoId) throw new Error('Movimentação ID não encontrado');
            if (!user?.id) throw new Error('Usuário não autenticado');

            // Gerar número da venda usando o mesmo padrão do PDV
            const numeroVenda = this.gerarNumeroVenda();

            // Preparar dados da venda - SÓ CAMPOS COM VALOR (como no PDV)
            const vendaData = {
                numero: numeroVenda, // ✅ USAR MESMO PADRÃO QUE O PDV (PED-YYYYMMDD-000001)
                caixa_id: caixaId,
                movimentacao_caixa_id: movimentacaoId,
                sessao_id: movimentacaoId,
                operador_id: user.id,
                vendedor_id: user.id,
                subtotal: comanda.subtotal,
                desconto: (comanda.desconto || 0) + descontoFinal,
                desconto_valor: (comanda.desconto || 0) + descontoFinal,
                acrescimo: acrescimoTarifa_Calculado,
                total: valorFinalVenda,
                forma_pagamento: formaPagamento,
                valor_pago: valorPago,
                troco: troco,
                data_venda: new Date().toISOString(),
                status: 'FINALIZADA',
                status_venda: 'FINALIZADA',
                observacoes: `Comanda: ${comanda.numero_comanda}${comanda.numero_mesa ? ' - Mesa ' + comanda.numero_mesa : ''}`
            };

            // Adicionar cliente_id APENAS se existir
            if (comanda.cliente_id && comanda.cliente_id !== 'null' && comanda.cliente_id !== '') {
                vendaData.cliente_id = comanda.cliente_id;
            }

            console.log('💾 Inserindo venda com dados:', vendaData);

            // ✅ GERAR UUID ANTES para evitar problemas com .select()
            const vendaId = crypto.randomUUID();
            vendaData.id = vendaId;

            // Inserir APENAS, sem fazer select() para evitar PGRST116
            const { error: erroVenda } = await supabase
                .from('vendas')
                .insert([vendaData]);

            if (erroVenda) {
                console.error('❌ Erro ao inserir venda:', erroVenda);
                console.error('📋 Dados tentados:', vendaData);
                throw erroVenda;
            }

            // Usar o ID que geramos
            const venda = { id: vendaId };

            console.log('✅ Venda criada:', venda.id);
            console.log('📦 Comanda tem', comanda.itens.length, 'itens para processar');

            // Criar itens da venda
            let itensInseridos = 0;
            for (const item of comanda.itens) {
                if (item.status === 'cancelado') {
                    console.log('⏭️ Item cancelado, pulando:', item.id);
                    continue;
                }

                console.log('🔄 Processando item:', { id: item.id, produto: item.nome_produto, qtd: item.quantidade });

                // Buscar preço de custo atual do produto (para análise financeira)
                const { data: produtos } = await supabase
                    .from('produtos')
                    .select('preco_custo')
                    .eq('id', item.produto_id)
                    .limit(1);
                
                const precoCusto = produtos && produtos.length > 0 ? produtos[0].preco_custo : 0;

                const itemData = {
                    venda_id: venda.id,
                    produto_id: item.produto_id,
                    quantidade: item.quantidade,
                    preco_unitario: item.preco_unitario,
                    preco_custo: precoCusto,
                    subtotal: item.subtotal
                };

                // Adicionar desconto apenas se houver
                if (item.desconto || item.desconto_percentual) {
                    itemData.desconto_valor = item.desconto || 0;
                    itemData.desconto_percentual = item.desconto_percentual || 0;
                }

                console.log('📝 Inserindo item com dados:', itemData);

                const { error: erroItem } = await supabase
                    .from('venda_itens')
                    .insert([itemData]);

                if (erroItem) {
                    console.error('❌ Erro ao inserir item:', erroItem);
                    console.error('📋 Dados do item:', itemData);
                    throw erroItem;
                }

                itensInseridos++;
                console.log(`✅ Item ${itensInseridos} inserido com sucesso`);
            }

            console.log(`✅ Total de itens inseridos: ${itensInseridos}/${comanda.itens.length}`);

            if (itensInseridos === 0) {
                throw new Error('Nenhum item foi inserido na venda. Verifique se a comanda possui itens.');
            }

            // ✅ REGISTRAR MOVIMENTO DE ESTOQUE (mesma lógica do PDV)
            console.log('📦 [COMANDA] Registrando saída de estoque...');
            const resultado = await EstoqueService.saidaPorVenda(venda.id);
            
            if (!resultado.sucesso) {
                throw new Error(resultado.mensagem || 'Erro ao processar saída de estoque');
            }
            
            console.log(`✅ [COMANDA] ${resultado.itens_processados} produtos baixados do estoque`);

            // ✅ ATUALIZAR COMANDA COM VENDA_ID (simples como no PDV)
            const { error: erroFechar } = await supabase
                .from('comandas')
                .update({
                    status: 'fechada',
                    data_fechamento: new Date().toISOString(),
                    usuario_fechamento_id: user?.id,
                    venda_id: venda.id,
                    updated_at: new Date().toISOString()
                })
                .eq('id', comandaId);

            if (erroFechar) {
                console.error('❌ Erro ao atualizar comanda:', erroFechar);
                throw erroFechar;
            }

            console.log('✅ Comanda fechada e venda gerada:', { venda_id: venda.id, comanda_id: comandaId });
            return { comanda, venda };
        } catch (erro) {
            console.error('❌ Erro ao fechar comanda:', erro);
            throw erro;
        }
    }

    /**
     * Cancelar comanda
     */
    async cancelarComanda(comandaId, motivo = null) {
        try {
            const { data: { user } } = await supabase.auth.getUser();

            const { error } = await supabase
                .from('comandas')
                .update({
                    status: 'cancelada',
                    data_fechamento: new Date().toISOString(),
                    usuario_fechamento_id: user?.id,
                    observacoes: motivo ? `CANCELADA: ${motivo}` : 'CANCELADA',
                    updated_at: new Date().toISOString()
                })
                .eq('id', comandaId);

            if (error) throw error;

            console.log('✅ Comanda cancelada');
            return true;
        } catch (erro) {
            console.error('Erro ao cancelar comanda:', erro);
            throw erro;
        }
    }

    /**
     * Transferir comanda para outra mesa/número
     */
    async transferirComanda(comandaId, novoNumero, novoNumeroMesa = null) {
        try {
            // Verificar se novo número já está em uso
            const comandaExistente = await this.buscarComandaPorNumero(novoNumero);
            
            if (comandaExistente && comandaExistente.status === 'aberta' && comandaExistente.id !== comandaId) {
                throw new Error(`Já existe uma comanda aberta com o número "${novoNumero}"`);
            }

            const { error } = await supabase
                .from('comandas')
                .update({
                    numero_comanda: novoNumero,
                    numero_mesa: novoNumeroMesa,
                    updated_at: new Date().toISOString()
                })
                .eq('id', comandaId);

            if (error) throw error;

            console.log('✅ Comanda transferida');
            return true;
        } catch (erro) {
            console.error('Erro ao transferir comanda:', erro);
            throw erro;
        }
    }

    /**
     * Gerar número automático de comanda
     */
    async gerarNumeroComanda() {
        try {
            // Buscar todas as comandas existentes (abertas, fechadas e canceladas)
            const { data: comandas } = await supabase
                .from('comandas')
                .select('numero_comanda')
                .like('numero_comanda', 'CMD-%')
                .order('id', { ascending: false });

            if (!comandas || comandas.length === 0) {
                return 'CMD-0001';
            }

            // Extrair todos os números já usados
            const numerosUsados = new Set();
            comandas.forEach(c => {
                const match = c.numero_comanda.match(/CMD-(\d+)/);
                if (match) {
                    numerosUsados.add(parseInt(match[1]));
                }
            });

            // Encontrar o próximo número disponível (menor número não usado)
            let proxNumero = 1;
            while (numerosUsados.has(proxNumero)) {
                proxNumero++;
            }

            return `CMD-${String(proxNumero).padStart(4, '0')}`;
        } catch (erro) {
            console.error('Erro ao gerar número de comanda:', erro);
            // Fallback: usar timestamp para garantir unicidade
            const timestamp = Date.now().toString().slice(-6);
            return `CMD-${timestamp}`;
        }
    }

    /**
     * Contar comandas abertas por tipo
     */
    async contarComandasAbertas() {
        try {
            const { data: comandas, error } = await supabase
                .from('comandas')
                .select('tipo')
                .eq('status', 'aberta');

            if (error) throw error;

            const contagem = {
                total: comandas.length,
                mesa: comandas.filter(c => c.tipo === 'mesa').length,
                balcao: comandas.filter(c => c.tipo === 'balcao').length,
                delivery: comandas.filter(c => c.tipo === 'delivery').length
            };

            return contagem;
        } catch (erro) {
            console.error('Erro ao contar comandas:', erro);
            return { total: 0, mesa: 0, balcao: 0, delivery: 0 };
        }
    }

    /**
     * Gerar número de venda no mesmo padrão do PDV
     * Formato: PED-YYYYMMDD-000001
     */
    gerarNumeroVenda() {
        const sequencia = Math.floor(Math.random() * 999999).toString().padStart(6, '0');
        return `PED-${new Date().toISOString().split('T')[0].replace(/-/g, '')}-${sequencia}`;
    }
}

// Exportar instância única
const ServicoComandasService = new ServicoComandas();

// Para ambientes que não suportam ES6 modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ServicoComandasService };
}
