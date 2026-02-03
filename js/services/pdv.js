// =====================================================
// SERVIÇO: PDV (PONTO DE VENDA)
// =====================================================
// Sistema de vendas rápidas para alto fluxo
// =====================================================

const PDV = {
    // Estado atual da venda
    vendaAtual: null,
    itens: [],
    sessaoCaixa: null,
    vendedor: null,

    // =====================================================
    // INICIALIZAÇÃO
    // =====================================================

    /**
     * Inicializar PDV
     */
    async init() {
        try {
            // Obter usuário autenticado
            const { data: { user }, error } = await window.supabase.auth.getUser();
            if (error || !user) {
                throw new Error('Usuário não autenticado');
            }
            
            this.vendedor = user;
            
            // Verificar/abrir sessão do caixa
            await this.verificarSessaoCaixa();
            
            console.log('✅ PDV inicializado');
            return true;
        } catch (error) {
            console.error('❌ Erro ao inicializar PDV:', error);
            throw error;
        }
    },

    /**
     * Verificar sessão do caixa
     */
    async verificarSessaoCaixa() {
        try {
            // Buscar sessão aberta do usuário
            const { data, error } = await window.supabase
                .from('caixa_sessoes')
                .select('*, caixas(*)')
                .eq('operador_id', this.vendedor.id)
                .is('data_fechamento', null)
                .single();

            if (error && error.code !== 'PGRST116') {
                throw error;
            }

            this.sessaoCaixa = data;
            return data;
        } catch (error) {
            console.error('Erro ao verificar sessão:', error);
            return null;
        }
    },

    /**
     * Abrir caixa
     */
    async abrirCaixa(caixaId, valorAbertura) {
        try {
            const { data, error } = await window.supabase
                .from('caixa_sessoes')
                .insert([{
                    caixa_id: caixaId,
                    operador_id: this.vendedor.id,
                    valor_abertura: valorAbertura,
                    status: 'ABERTO'
                }])
                .select('*, caixa:caixas(*)')
                .single();

            if (error) throw error;

            this.sessaoCaixa = data;
            showToast('Caixa aberto com sucesso!', 'success');
            return data;
        } catch (error) {
            handleError(error, 'Erro ao abrir caixa');
            throw error;
        }
    },

    /**
     * Fechar caixa
     */
    async fecharCaixa(valorInformado, observacoes = '') {
        try {
            if (!this.sessaoCaixa) {
                throw new Error('Nenhum caixa aberto');
            }

            // Calcular valor do sistema
            const valorSistema = (this.sessaoCaixa.valor_abertura || 0)
                + (this.sessaoCaixa.total_dinheiro || 0)
                + (this.sessaoCaixa.total_suprimentos || 0)
                - (this.sessaoCaixa.total_sangrias || 0);

            const diferenca = valorInformado - valorSistema;

            const { data, error } = await window.supabase
                .from('caixa_sessoes')
                .update({
                    status: 'FECHADO',
                    valor_fechamento_sistema: valorSistema,
                    valor_fechamento_informado: valorInformado,
                    diferenca,
                    data_fechamento: new Date().toISOString(),
                    usuario_fechamento_id: this.vendedor.id,
                    observacoes
                })
                .eq('id', this.sessaoCaixa.id)
                .select()
                .single();

            if (error) throw error;

            this.sessaoCaixa = null;
            showToast('Caixa fechado com sucesso!', 'success');
            return { ...data, valorSistema, diferenca };
        } catch (error) {
            handleError(error, 'Erro ao fechar caixa');
            throw error;
        }
    },

    // =====================================================
    // OPERAÇÕES DE VENDA
    // =====================================================

    /**
     * Iniciar nova venda
     */
    async novaVenda(clienteId = null) {
        try {
            const { data, error } = await window.supabase.rpc('iniciar_venda_pdv', {
                p_vendedor_id: this.vendedor.id,
                p_cliente_id: clienteId
            });

            if (error) throw error;

            // Buscar venda criada
            const { data: venda } = await window.supabase
                .from('vendas')
                .select('*')
                .eq('id', data)
                .single();

            this.vendaAtual = venda;
            this.itens = [];

            this.atualizarUI();
            return venda;
        } catch (error) {
            handleError(error, 'Erro ao iniciar venda');
            throw error;
        }
    },

    /**
     * Buscar produto por código de barras
     */
    async buscarProduto(codigo) {
        try {
            const { data, error } = await window.supabase.rpc('buscar_produto_codigo_barras', {
                p_codigo: codigo.trim()
            });

            if (error) throw error;

            if (!data || data.length === 0) {
                showToast('Produto não encontrado', 'warning');
                return null;
            }

            return data[0];
        } catch (error) {
            handleError(error, 'Erro ao buscar produto');
            return null;
        }
    },

    /**
     * Buscar produtos por nome
     */
    async buscarProdutosPorNome(termo) {
        try {
            const { data, error } = await window.supabase.rpc('buscar_produtos_nome', {
                p_termo: termo.trim()
            });

            if (error) throw error;

            return data || [];
        } catch (error) {
            handleError(error, 'Erro ao buscar produtos');
            return [];
        }
    },

    /**
     * Busca universal (código ou nome)
     */
    async buscarProdutoUniversal(busca) {
        try {
            const { data, error } = await window.supabase.rpc('buscar_produto_universal', {
                p_busca: busca.trim()
            });

            if (error) throw error;

            return data || [];
        } catch (error) {
            console.error('Erro na busca:', error);
            // Fallback para busca por nome se função universal não existir
            if (error.message.includes('could not find function') || error.message.includes('buscar_produto_universal')) {
                return await this.buscarProdutosPorNome(busca);
            }
            handleError(error, 'Erro na busca de produtos');
            return [];
        }
    },

    /**
     * Adicionar item à venda
     */
    async adicionarItem(produtoId, quantidade = 1, descontoPercentual = 0) {
        try {
            console.log('📦 Adicionando item:', { produtoId, quantidade, descontoPercentual });
            
            if (!this.vendaAtual) {
                console.log('Sem venda atual, criando nova...');
                await this.novaVenda();
            }

            console.log('Chamando RPC adicionar_item_venda...');
            const { data, error } = await window.supabase.rpc('adicionar_item_venda', {
                p_venda_id: this.vendaAtual.id,
                p_produto_id: produtoId,
                p_quantidade: quantidade,
                p_desconto_percentual: descontoPercentual
            });

            if (error) {
                console.error('❌ Erro na RPC:', error);
                throw error;
            }

            console.log('✅ Item adicionado:', data);

            // Recarregar itens e venda
            console.log('Recarregando itens e venda...');
            await this.carregarItens();
            await this.carregarVenda();

            // Feedback sonoro
            this.beep();
            
            // Mostrar toast de sucesso
            showToast('Produto adicionado à venda!', 'success');

            return data;
        } catch (error) {
            console.error('❌ Erro ao adicionar item:', error);
            handleError(error, 'Erro ao adicionar item');
            throw error;
        }
    },

    /**
     * Adicionar produto (aceita código ou objeto produto)
     */
    async adicionarPorCodigo(produtoOuCodigo, quantidade = 1) {
        try {
            let produto;
            
            // Se recebeu um objeto produto, usar diretamente
            if (typeof produtoOuCodigo === 'object' && produtoOuCodigo.id) {
                produto = produtoOuCodigo;
            } else {
                // Se recebeu uma string, buscar o produto
                const busca = produtoOuCodigo;
                
                // Primeiro tentar busca exata por código de barras
                produto = await this.buscarProduto(busca);
                
                if (!produto) {
                    // Se não encontrou por código, tentar busca universal
                    const resultados = await this.buscarProdutoUniversal(busca);
                    
                    if (resultados.length === 1) {
                        // Se só encontrou um produto, adicionar automaticamente
                        produto = resultados[0];
                    } else if (resultados.length > 1) {
                        // Se encontrou múltiplos produtos, mostrar seleção
                        produto = await this.mostrarSelecaoProdutos(resultados, busca);
                    }
                }
            }
            
            if (produto) {
                await this.adicionarItem(produto.id, quantidade);
                return produto;
            } else {
                showToast(`Nenhum produto encontrado`, 'warning');
                return null;
            }
        } catch (error) {
            console.error('Erro ao adicionar produto:', error);
            handleError(error, 'Erro ao buscar produto');
            return null;
        }
    },

    /**
     * Mostrar seleção de produtos quando há múltiplos resultados
     */
    async mostrarSelecaoProdutos(produtos, termoBusca) {
        // Versão simplificada - apenas retorna o primeiro
        if (produtos.length > 0) {
            return produtos[0];
        }
        return null;
    },

    /**
     * Remover item da venda
     */
    async removerItem(itemId) {
        try {
            const { error } = await window.supabase
                .from('venda_itens')
                .update({ cancelado: true })
                .eq('id', itemId);

            if (error) throw error;

            // Recalcular totais
            await window.supabase.rpc('atualizar_totais_venda', {
                p_venda_id: this.vendaAtual.id
            });

            await this.carregarItens();
            await this.carregarVenda();

            showToast('Item removido', 'info');
        } catch (error) {
            handleError(error, 'Erro ao remover item');
        }
    },

    /**
     * Alterar quantidade do item
     */
    async alterarQuantidade(itemId, novaQuantidade) {
        try {
            if (novaQuantidade <= 0) {
                return this.removerItem(itemId);
            }

            const item = this.itens.find(i => i.id === itemId);
            if (!item) return;

            const novoSubtotal = item.preco_unitario * novaQuantidade * (1 - (item.desconto_percentual / 100));

            const { error } = await window.supabase
                .from('venda_itens')
                .update({
                    quantidade: novaQuantidade,
                    subtotal: novoSubtotal
                })
                .eq('id', itemId);

            if (error) throw error;

            await window.supabase.rpc('atualizar_totais_venda', {
                p_venda_id: this.vendaAtual.id
            });

            await this.carregarItens();
            await this.carregarVenda();
        } catch (error) {
            handleError(error, 'Erro ao alterar quantidade');
        }
    },

    /**
     * Aplicar desconto na venda
     */
    async aplicarDesconto(tipo, valor) {
        try {
            // Verificar limite de desconto
            const config = await getEmpresaConfig();
            const limiteDesconto = config?.desconto_maximo_percentual || 10;

            let descontoPercentual = 0;
            let descontoValor = 0;

            if (tipo === 'percentual') {
                if (valor > limiteDesconto) {
                    showToast(`Desconto máximo permitido: ${limiteDesconto}%`, 'warning');
                    return;
                }
                descontoPercentual = valor;
                descontoValor = this.vendaAtual.subtotal * (valor / 100);
            } else {
                descontoValor = valor;
                descontoPercentual = (valor / this.vendaAtual.subtotal) * 100;
                
                if (descontoPercentual > limiteDesconto) {
                    showToast(`Desconto máximo permitido: ${limiteDesconto}%`, 'warning');
                    return;
                }
            }

            const { error } = await window.supabase
                .from('vendas')
                .update({
                    desconto_percentual: descontoPercentual,
                    desconto_valor: descontoValor,
                    total: this.vendaAtual.subtotal - descontoValor + (this.vendaAtual.acrescimo_valor || 0)
                })
                .eq('id', this.vendaAtual.id);

            if (error) throw error;

            await this.carregarVenda();
            showToast('Desconto aplicado!', 'success');
        } catch (error) {
            handleError(error, 'Erro ao aplicar desconto');
        }
    },

    /**
     * Selecionar cliente
     */
    async selecionarCliente(clienteId) {
        try {
            const { error } = await window.supabase
                .from('vendas')
                .update({ cliente_id: clienteId })
                .eq('id', this.vendaAtual.id);

            if (error) throw error;

            await this.carregarVenda();
        } catch (error) {
            handleError(error, 'Erro ao selecionar cliente');
        }
    },

    // =====================================================
    // FINALIZAÇÃO E PAGAMENTO
    // =====================================================

    /**
     * Finalizar venda com pagamentos
     */
    async finalizarVenda(pagamentos, tipoDocumento = 'NFCE') {
        try {
            if (!this.vendaAtual || this.itens.length === 0) {
                showToast('Nenhum item na venda', 'warning');
                return null;
            }

            // Validar pagamentos
            const totalPago = pagamentos.reduce((sum, p) => sum + p.valor, 0);
            if (totalPago < this.vendaAtual.total) {
                showToast('Pagamento insuficiente', 'warning');
                return null;
            }

            // Chamar função de finalização
            const { data, error } = await window.supabase.rpc('finalizar_venda_pdv', {
                p_venda_id: this.vendaAtual.id,
                p_pagamentos: JSON.stringify(pagamentos),
                p_tipo_documento: tipoDocumento
            });

            if (error) throw error;

            const resultado = data;

            // Emitir documento fiscal se configurado
            if (tipoDocumento === 'NFCE' || tipoDocumento === 'NFE') {
                try {
                    await this.emitirDocumentoFiscal(tipoDocumento);
                } catch (fiscalError) {
                    console.error('Erro ao emitir documento fiscal:', fiscalError);
                    showToast('Venda finalizada, mas houve erro na emissão fiscal', 'warning');
                }
            }

            // Imprimir cupom
            await this.imprimirCupom();

            showToast('Venda finalizada com sucesso!', 'success');

            // Iniciar nova venda
            await this.novaVenda();

            return resultado;
        } catch (error) {
            handleError(error, 'Erro ao finalizar venda');
            throw error;
        }
    },

    /**
     * Emitir documento fiscal
     */
    async emitirDocumentoFiscal(tipo) {
        try {
            // Buscar cliente se houver
            let cliente = null;
            if (this.vendaAtual.cliente_id) {
                const { data } = await window.supabase
                    .from('clientes')
                    .select('*')
                    .eq('id', this.vendaAtual.cliente_id)
                    .single();
                cliente = data;
            }

            // Buscar pagamentos
            const { data: pagamentos } = await window.supabase
                .from('venda_pagamentos')
                .select('*, forma_pagamento:formas_pagamento(*)')
                .eq('venda_id', this.vendaAtual.id);

            if (tipo === 'NFCE') {
                return await FocusNFe.emitirNFCe(
                    this.vendaAtual,
                    this.itens,
                    pagamentos.map(p => ({
                        tipo: p.forma_pagamento.tipo,
                        valor: p.valor,
                        nsu: p.nsu,
                        bandeira: p.bandeira
                    })),
                    cliente
                );
            } else if (tipo === 'NFE') {
                if (!cliente) {
                    throw new Error('NF-e requer cliente identificado');
                }
                return await FocusNFe.emitirNFe(
                    this.vendaAtual,
                    this.itens,
                    cliente
                );
            }
        } catch (error) {
            console.error('Erro ao emitir documento fiscal:', error);
            throw error;
        }
    },

    /**
     * Cancelar venda atual
     */
    async cancelarVenda(motivo = 'Cancelamento pelo operador') {
        try {
            if (!this.vendaAtual) return;

            const { error } = await window.supabase
                .from('vendas')
                .update({
                    status: 'CANCELADA',
                    motivo_cancelamento: motivo,
                    cancelado_por: this.vendedor.id,
                    data_cancelamento: new Date().toISOString()
                })
                .eq('id', this.vendaAtual.id);

            if (error) throw error;

            showToast('Venda cancelada', 'info');
            await this.novaVenda();
        } catch (error) {
            handleError(error, 'Erro ao cancelar venda');
        }
    },

    // =====================================================
    // IMPRESSÃO
    // =====================================================

    /**
     * Imprimir cupom não fiscal
     */
    async imprimirCupom() {
        try {
            const config = await getEmpresaConfig();
            
            let cupom = this.gerarCupomTexto(config);
            
            // Se houver impressora configurada, usar ESC/POS
            if (config?.impressora_padrao) {
                await this.imprimirESCPOS(cupom);
            } else {
                // Fallback: abrir janela de impressão
                this.imprimirNavegador(cupom);
            }
        } catch (error) {
            console.error('Erro ao imprimir:', error);
        }
    },

    /**
     * Gerar texto do cupom
     */
    gerarCupomTexto(config) {
        const largura = config?.largura_cupom || 48;
        const linha = '='.repeat(largura);
        const linhaSeparadora = '-'.repeat(largura);

        let cupom = '';
        
        // Cabeçalho
        cupom += this.centralizar(config?.nome_empresa || 'MINHA EMPRESA', largura) + '\n';
        if (config?.endereco) {
            cupom += this.centralizar(config.endereco, largura) + '\n';
        }
        cupom += this.centralizar(`CNPJ: ${config?.cnpj || ''}`, largura) + '\n';
        cupom += linha + '\n';
        
        // Info da venda
        cupom += `Venda: ${this.vendaAtual.numero_venda}\n`;
        cupom += `Data: ${new Date().toLocaleString('pt-BR')}\n`;
        cupom += `Vendedor: ${this.vendedor.full_name}\n`;
        cupom += linhaSeparadora + '\n';
        
        // Itens
        cupom += 'ITEM  DESCRICAO          QTD    TOTAL\n';
        cupom += linhaSeparadora + '\n';
        
        this.itens.forEach((item, index) => {
            const num = String(index + 1).padStart(3, '0');
            const desc = item.descricao.substring(0, 18).padEnd(18);
            const qtd = String(item.quantidade).padStart(5);
            const total = this.formatarMoeda(item.subtotal).padStart(10);
            cupom += `${num} ${desc} ${qtd} ${total}\n`;
        });
        
        cupom += linhaSeparadora + '\n';
        
        // Totais
        cupom += `SUBTOTAL: ${this.formatarMoeda(this.vendaAtual.subtotal).padStart(largura - 10)}\n`;
        if (this.vendaAtual.desconto_valor > 0) {
            cupom += `DESCONTO: -${this.formatarMoeda(this.vendaAtual.desconto_valor).padStart(largura - 11)}\n`;
        }
        cupom += linha + '\n';
        cupom += `TOTAL: ${this.formatarMoeda(this.vendaAtual.total).padStart(largura - 7)}\n`;
        cupom += linha + '\n';
        
        // Mensagem
        if (config?.mensagem_cupom) {
            cupom += '\n' + this.centralizar(config.mensagem_cupom, largura) + '\n';
        }
        
        return cupom;
    },

    centralizar(texto, largura) {
        const espacos = Math.max(0, Math.floor((largura - texto.length) / 2));
        return ' '.repeat(espacos) + texto;
    },

    formatarMoeda(valor) {
        return valor.toLocaleString('pt-BR', { style: 'currency', currency: 'BRL' });
    },

    imprimirNavegador(texto) {
        const janela = window.open('', '_blank');
        janela.document.write(`<pre style="font-family: monospace; font-size: 12px;">${texto}</pre>`);
        janela.document.close();
        janela.print();
    },

    // =====================================================
    // UTILITÁRIOS
    // =====================================================

    /**
     * Carregar itens da venda atual
     */
    async carregarItens() {
        if (!this.vendaAtual) {
            console.warn('Nenhuma venda atual para carregar itens');
            return;
        }

        try {
            const { data, error } = await window.supabase
                .from('venda_itens')
                .select('*, produto:produtos(*)')
                .eq('venda_id', this.vendaAtual.id)
                .order('created_at');

            if (error) {
                console.warn('Erro ao carregar itens:', error);
                // Continuar mesmo com erro
            } else if (data) {
                this.itens = data || [];
                console.log('✅ Itens carregados:', this.itens.length);
            }
        } catch (err) {
            console.warn('Exceção ao carregar itens:', err);
        }
    },

    /**
     * Carregar dados da venda atual
     */
    async carregarVenda() {
        if (!this.vendaAtual) {
            console.warn('Nenhuma venda atual para carregar');
            return;
        }

        try {
            const { data, error } = await window.supabase
                .from('vendas')
                .select('*, cliente:clientes(*)')
                .eq('id', this.vendaAtual.id)
                .single();

            if (error) {
                console.warn('Erro ao carregar venda:', error);
                // Continuar mesmo com erro
            } else if (data) {
                this.vendaAtual = data;
            }
        } catch (err) {
            console.warn('Exceção ao carregar venda:', err);
        }
        
        // Sempre atualizar UI, mesmo se houver erro
        this.atualizarUI();
    },

    /**
     * Atualizar interface
     */
    atualizarUI() {
        // Disparar evento customizado para a UI
        window.dispatchEvent(new CustomEvent('pdv-atualizado', {
            detail: {
                venda: this.vendaAtual,
                itens: this.itens,
                sessaoCaixa: this.sessaoCaixa
            }
        }));
    },

    /**
     * Beep de confirmação
     */
    beep() {
        try {
            const audioContext = new (window.AudioContext || window.webkitAudioContext)();
            const oscillator = audioContext.createOscillator();
            const gainNode = audioContext.createGain();
            
            oscillator.connect(gainNode);
            gainNode.connect(audioContext.destination);
            
            oscillator.frequency.value = 800;
            oscillator.type = 'sine';
            gainNode.gain.value = 0.1;
            
            oscillator.start(audioContext.currentTime);
            oscillator.stop(audioContext.currentTime + 0.1);
        } catch (e) {
            // Ignorar erro de áudio
        }
    },

    /**
     * Configurar eventos de teclado
     */
    configurarEventos() {
        document.addEventListener('keydown', async (e) => {
            // F2 - Nova venda
            if (e.key === 'F2') {
                e.preventDefault();
                await this.novaVenda();
            }
            // F3 - Buscar produto
            if (e.key === 'F3') {
                e.preventDefault();
                document.getElementById('input-codigo')?.focus();
            }
            // F4 - Cancelar venda
            if (e.key === 'F4') {
                e.preventDefault();
                if (await confirmAction('Cancelar venda atual?')) {
                    await this.cancelarVenda();
                }
            }
            // F5 - Desconto
            if (e.key === 'F5') {
                e.preventDefault();
                document.getElementById('modal-desconto')?.classList.remove('hidden');
            }
            // F6 - Cliente
            if (e.key === 'F6') {
                e.preventDefault();
                document.getElementById('modal-cliente')?.classList.remove('hidden');
            }
            // F10 - Finalizar
            if (e.key === 'F10') {
                e.preventDefault();
                document.getElementById('modal-pagamento')?.classList.remove('hidden');
            }
            // ESC - Cancelar operação
            if (e.key === 'Escape') {
                document.querySelectorAll('.modal-backdrop').forEach(m => m.classList.add('hidden'));
            }
        });
    }
};

// Exportar para uso global
window.PDV = PDV;
