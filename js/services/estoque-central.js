/**
 * =====================================================
 * SERVIÇO CENTRALIZADO DE CONTROLE DE ESTOQUE
 * =====================================================
 * 
 * TODAS as movimentações de estoque devem passar por este serviço.
 * Garante rastreabilidade, auditoria e integridade dos dados.
 * 
 * REGRAS:
 * 1. NUNCA atualizar estoque_atual diretamente na tabela produtos
 * 2. SEMPRE registrar movimentação na tabela estoque_movimentacoes
 * 3. SEMPRE validar estoque antes de saídas
 * 4. SEMPRE manter referência do documento de origem
 */

class EstoqueService {
    /**
     * Tipos de movimentação permitidos
     */
    static TIPOS = {
        ENTRADA_COMPRA: 'ENTRADA_COMPRA',           // Entrada por pedido de compra
        SAIDA_VENDA: 'SAIDA_VENDA',                 // Saída por venda (PDV ou pedido)
        ENTRADA_DEVOLUCAO: 'ENTRADA_DEVOLUCAO',     // Devolução de cliente
        SAIDA_DEVOLUCAO: 'SAIDA_DEVOLUCAO',         // Devolução para fornecedor
        ENTRADA_AJUSTE: 'ENTRADA_AJUSTE',           // Ajuste manual positivo
        SAIDA_AJUSTE: 'SAIDA_AJUSTE',               // Ajuste manual negativo
        SAIDA_PERDA: 'SAIDA_PERDA',                 // Perdas, avarias, quebras
        TRANSFERENCIA: 'TRANSFERENCIA'               // Transferência entre depósitos
    };

    /**
     * Normaliza unidade de medida para valores válidos do enum
     * Converte unidades comuns do XML/NFe para o padrão do sistema
     */
    static normalizarUnidadeMedida(unidade) {
        if (!unidade) return 'UN';
        
        const unidadeUpper = String(unidade).toUpperCase().trim();
        
        // Mapeamento de unidades comuns
        const mapeamento = {
            // Unidades básicas
            'UN': 'UN',
            'UNIDADE': 'UN',
            'PC': 'UN',
            'PÇ': 'UN',
            'PEÇA': 'UN',
            'PECAS': 'UN',
            
            // Pacote/Caixa
            'PT': 'CX',  // Pacote vira Caixa
            'PACOTE': 'CX',
            'PCT': 'CX',
            'CX': 'CX',
            'CAIXA': 'CX',
            'CAIXAS': 'CX',
            
            // Peso
            'KG': 'KG',
            'KILO': 'KG',
            'QUILOGRAMA': 'KG',
            'G': 'KG',
            'GRAMA': 'KG',
            'GRAMAS': 'KG',
            
            // Volume
            'L': 'L',
            'LITRO': 'L',
            'LITROS': 'L',
            'LT': 'L',
            'ML': 'L',
            'MILILITRO': 'L',
            
            // Comprimento
            'M': 'M',
            'METRO': 'M',
            'METROS': 'M',
            'MT': 'M',
            
            // Fardo
            'FD': 'FD',
            'FARDO': 'FD',
            'FARDOS': 'FD'
        };
        
        const unidadeNormalizada = mapeamento[unidadeUpper];
        
        if (!unidadeNormalizada) {
            console.warn(`⚠️ Unidade "${unidade}" não reconhecida, usando UN como padrão`);
            return 'UN';
        }
        
        return unidadeNormalizada;
    }

    /**
     * =========================================
     * ENTRADA DE ESTOQUE - PEDIDO DE COMPRA
     * =========================================
     * Usado quando APROVA ou RECEBE um pedido de compra
     */
    static async entradaPorCompra(pedidoCompraId) {
        try {
            console.log('📦 [ESTOQUE] Iniciando entrada por compra:', pedidoCompraId);
            console.log('📦 [ESTOQUE] Tipo do ID:', typeof pedidoCompraId);

            // ⚠️ PROTEÇÃO CONTRA DUPLICAÇÃO INTELIGENTE:
            // Verificar se existe entrada E se foi revertida posteriormente
            
            // 1. Buscar última entrada
            const { data: ultimaEntrada, error: errCheck } = await supabase
                .from('estoque_movimentacoes')
                .select('id, created_at')
                .eq('referencia_id', pedidoCompraId)
                .eq('referencia_tipo', 'PEDIDO_COMPRA')
                .eq('tipo_movimento', this.TIPOS.ENTRADA_COMPRA)
                .order('created_at', { ascending: false })
                .limit(1);

            console.log('🔍 [ESTOQUE] Verificação de duplicação:', { ultimaEntrada, errCheck });

            // 2. Buscar última reversão
            const { data: ultimaReversao } = await supabase
                .from('estoque_movimentacoes')
                .select('id, created_at')
                .eq('referencia_id', pedidoCompraId)
                .eq('referencia_tipo', 'PEDIDO_COMPRA_REVERSAO')
                .eq('tipo_movimento', this.TIPOS.SAIDA_AJUSTE)
                .order('created_at', { ascending: false })
                .limit(1);

            // Se existe entrada e NÃO existe reversão posterior, já foi processada
            if (ultimaEntrada && ultimaEntrada.length > 0) {
                const dataEntrada = new Date(ultimaEntrada[0].created_at);
                
                if (!ultimaReversao || ultimaReversao.length === 0) {
                    // Há entrada mas não há reversão - já processada
                    console.warn('⚠️ [ESTOQUE] Este pedido já teve entrada de estoque processada');
                    return { 
                        sucesso: true, 
                        itens_processados: 0,
                        mensagem: 'Entrada já processada anteriormente. Nenhuma ação necessária.',
                        ja_processado: true
                    };
                }
                
                const dataReversao = new Date(ultimaReversao[0].created_at);
                
                if (dataEntrada > dataReversao) {
                    // A entrada é mais recente que a reversão - já foi reprocessada
                    console.warn('⚠️ [ESTOQUE] Este pedido já foi reprocessado após reversão');
                    return { 
                        sucesso: true, 
                        itens_processados: 0,
                        mensagem: 'Entrada já processada após reversão. Nenhuma ação necessária.',
                        ja_processado: true
                    };
                }
                
                // Reversão é mais recente - pode processar nova entrada
                console.log('✅ [ESTOQUE] Pedido foi reaberto, processando nova entrada de estoque');
            }

            // 1. Buscar pedido com itens e produtos
            const { data: pedido, error: errPedido } = await supabase
                .from('pedidos_compra')
                .select('id, numero, status, usuario_id')
                .eq('id', pedidoCompraId)
                .single();

            console.log('🔍 [ESTOQUE] Pedido encontrado:', { pedido, errPedido });

            if (errPedido || !pedido) {
                console.error('❌ [ESTOQUE] Erro ao buscar pedido:', errPedido);
                throw new Error('Pedido de compra não encontrado');
            }

            // 2. Buscar itens do pedido (SEM JOIN porque não há FK para produto_id)
            const { data: itens, error: errItens } = await supabase
                .from('pedido_compra_itens')
                .select('id, produto_id, quantidade, preco_unitario')
                .eq('pedido_id', pedidoCompraId);

            console.log('🔍 [ESTOQUE] Itens encontrados:', { itens, errItens, count: itens?.length });

            if (errItens) {
                console.error('❌ [ESTOQUE] Erro ao buscar itens:', errItens);
                throw new Error(`Erro ao buscar itens: ${errItens.message}`);
            }

            if (!itens || itens.length === 0) {
                console.error('❌ [ESTOQUE] Nenhum item encontrado para pedido_id:', pedidoCompraId);
                throw new Error('Nenhum item encontrado no pedido. Verifique se o item foi salvo corretamente.');
            }

            console.log(`📊 [ESTOQUE] ${itens.length} itens para processar`);

            // 3. Buscar dados dos produtos (fazer query separada porque não há FK)
            const produtoIds = itens.map(item => item.produto_id);
            console.log('🔍 [ESTOQUE] IDs dos produtos:', produtoIds);
            
            const { data: produtos, error: errProdutos } = await supabase
                .from('produtos')
                .select('id, nome, codigo, estoque_atual, unidade')
                .in('id', produtoIds);

            console.log('🔍 [ESTOQUE] Produtos encontrados:', { produtos, errProdutos, count: produtos?.length });

            if (errProdutos) {
                console.error('❌ [ESTOQUE] Erro ao buscar produtos:', errProdutos);
                throw new Error(`Erro ao buscar produtos: ${errProdutos.message}`);
            }

            // Criar um mapa de produtos para fácil acesso
            const produtosMap = new Map();
            produtos?.forEach(p => produtosMap.set(p.id, p));

            console.log(`✅ [ESTOQUE] ${produtos?.length || 0} produtos carregados`);

            // 4. Processar cada item
            const movimentacoes = [];
            const atualizacoesProdutos = [];

            for (const item of itens) {
                const produto = produtosMap.get(item.produto_id);
                
                if (!produto) {
                    console.warn(`⚠️ [ESTOQUE] Item sem produto vinculado: ${item.id}`);
                    continue;
                }
                const quantidadeEntrada = parseFloat(item.quantidade) || 0;
                const precoUnitario = parseFloat(item.preco_unitario) || 0;

                if (quantidadeEntrada <= 0) {
                    console.warn(`⚠️ [ESTOQUE] Quantidade inválida para produto ${produto.nome}`);
                    continue;
                }

                // Calcular novo estoque
                const estoqueAtual = parseFloat(produto.estoque_atual) || 0;
                const novoEstoque = estoqueAtual + quantidadeEntrada;

                console.log(`  ✅ ${produto.nome}: ${estoqueAtual} + ${quantidadeEntrada} = ${novoEstoque}`);

                // Normalizar unidade de medida
                const unidadeNormalizada = this.normalizarUnidadeMedida(produto.unidade);

                // Preparar movimentação
                movimentacoes.push({
                    id: crypto.randomUUID(),
                    produto_id: produto.id,
                    tipo_movimento: this.TIPOS.ENTRADA_COMPRA,
                    quantidade: quantidadeEntrada,
                    unidade_medida: unidadeNormalizada,
                    preco_unitario: precoUnitario,
                    motivo: `Entrada por pedido de compra ${pedido.numero}`,
                    referencia_id: pedidoCompraId,
                    referencia_tipo: 'PEDIDO_COMPRA',
                    usuario_id: pedido.usuario_id,
                    created_at: new Date().toISOString()
                });

                // Preparar atualização do produto (estoque + preço de custo)
                atualizacoesProdutos.push({
                    id: produto.id,
                    estoque_atual: novoEstoque,
                    preco_custo: precoUnitario // ATUALIZAR PREÇO DE CUSTO
                });
            }

            // ⚠️ VALIDAÇÃO: Garantir que há itens para processar
            console.log('📊 [ESTOQUE] Movimentações preparadas:', movimentacoes.length);
            console.log('📊 [ESTOQUE] Atualizações preparadas:', atualizacoesProdutos.length);

            if (movimentacoes.length === 0) {
                console.error('❌ [ESTOQUE] Nenhum produto válido para processar!');
                console.error('   → Verifique se os produtos existem no cadastro');
                console.error('   → Verifique se as quantidades são válidas');
                throw new Error('Nenhum produto válido para processar. Verifique os itens do pedido.');
            }

            // 5. Executar inserções/atualizações
            console.log('💾 [ESTOQUE] Registrando', movimentacoes.length, 'movimentações...');

            // Inserir movimentações
            const { error: errMov } = await supabase
                .from('estoque_movimentacoes')
                .insert(movimentacoes);

            if (errMov) {
                console.error('❌ [ESTOQUE] Erro ao inserir movimentações:', errMov);
                throw new Error(`Erro ao registrar movimentações: ${errMov.message}`);
            }

            // Atualizar produtos (um por vez para garantir consistência)
            for (const update of atualizacoesProdutos) {
                const { error: errUpd } = await supabase
                    .from('produtos')
                    .update({
                        estoque_atual: update.estoque_atual,
                        preco_custo: update.preco_custo
                    })
                    .eq('id', update.id);

                if (errUpd) {
                    console.error(`❌ [ESTOQUE] Erro ao atualizar produto ${update.id}:`, errUpd);
                    throw new Error(`Erro ao atualizar estoque: ${errUpd.message}`);
                }
            }

            console.log('✅ [ESTOQUE] Entrada de compra registrada com sucesso!');

            return {
                sucesso: true,
                itens_processados: movimentacoes.length,
                mensagem: `${movimentacoes.length} produtos atualizados com sucesso`
            };

        } catch (error) {
            console.error('❌ [ESTOQUE] Erro na entrada por compra:', error);
            throw error;
        }
    }

    /**
     * =========================================
     * REVERTER ENTRADA - PEDIDO DE COMPRA
     * =========================================
     * Usado quando cancela ou reverte aprovação de pedido
     */
    static async reverterEntradaCompra(pedidoCompraId) {
        try {
            console.log('');
            console.log('═══════════════════════════════════════════════════════════════');
            console.log('🔄 [ESTOQUE] REVERSÃO DE ENTRADA DE COMPRA INICIADA');
            console.log('═══════════════════════════════════════════════════════════════');
            console.log('📋 Pedido ID:', pedidoCompraId);
            console.log('');

            // ⚠️ NÃO VERIFICAR STATUS DO PEDIDO!
            // O status pode ter sido alterado antes da reversão (ex: já CANCELADO)
            // A decisão de reverter é de quem chama este método
            // Aqui apenas verificamos se há movimentações para reverter

            // 1. Buscar movimentações relacionadas ao pedido (SEM JOIN)
            const { data: movimentacoes, error: errMov } = await supabase
                .from('estoque_movimentacoes')
                .select('id, produto_id, quantidade, unidade_medida, preco_unitario, usuario_id')
                .eq('referencia_id', pedidoCompraId)
                .eq('referencia_tipo', 'PEDIDO_COMPRA')
                .eq('tipo_movimento', this.TIPOS.ENTRADA_COMPRA);

            if (errMov || !movimentacoes || movimentacoes.length === 0) {
                console.warn('⚠️ [ESTOQUE] Nenhuma movimentação encontrada para reverter');
                return { 
                    sucesso: true, 
                    itens_processados: 0,
                    mensagem: 'Nenhuma movimentação de entrada encontrada para este pedido' 
                };
            }

            console.log(`📊 [ESTOQUE] ${movimentacoes.length} movimentações para reverter`);

            // 2. Buscar dados dos produtos
            const produtoIds = movimentacoes.map(m => m.produto_id);
            const { data: produtos, error: errProdutos } = await supabase
                .from('produtos')
                .select('id, nome, estoque_atual')
                .in('id', produtoIds);

            if (errProdutos) {
                console.error('❌ [ESTOQUE] Erro ao buscar produtos:', errProdutos);
                throw new Error(`Erro ao buscar produtos: ${errProdutos.message}`);
            }

            // Criar mapa de produtos
            const produtosMap = new Map();
            produtos?.forEach(p => produtosMap.set(p.id, p));

            // ⚠️ VALIDAÇÃO PRÉVIA: Verificar estoque de TODOS os produtos ANTES de processar
            // Isso garante atomicidade - se um produto não tiver estoque, nenhum é processado
            const problemas = [];
            for (const mov of movimentacoes) {
                const produto = produtosMap.get(mov.produto_id);
                if (!produto) continue;
                
                const quantidadeReverter = parseFloat(mov.quantidade) || 0;
                const estoqueAtual = parseFloat(produto.estoque_atual) || 0;
                const novoEstoque = estoqueAtual - quantidadeReverter;
                
                if (novoEstoque < 0) {
                    const faltam = Math.abs(novoEstoque);
                    problemas.push(
                        `• ${produto.nome}: estoque atual ${estoqueAtual}, necessário ${quantidadeReverter}, faltam ${faltam}`
                    );
                }
            }
            
            if (problemas.length > 0) {
                const mensagem = 
                    `❌ NÃO É POSSÍVEL REVERTER ESTE PEDIDO!\n\n` +
                    `Os produtos já foram vendidos e não há estoque suficiente:\n\n` +
                    problemas.join('\n') +
                    `\n\n💡 As vendas devem ser desfeitas primeiro ou aguardar nova entrada.`;
                console.error('❌ [ESTOQUE] Validação de estoque falhou:', problemas);
                throw new Error(mensagem);
            }

            // 3. Processar cada movimentação (já validado que todos têm estoque)
            for (const mov of movimentacoes) {
                const produto = produtosMap.get(mov.produto_id);
                
                if (!produto) {
                    console.warn(`⚠️ [ESTOQUE] Movimentação sem produto: ${mov.id}`);
                    continue;
                }
                const quantidadeReverter = parseFloat(mov.quantidade) || 0;
                const estoqueAtual = parseFloat(produto.estoque_atual) || 0;
                const novoEstoque = estoqueAtual - quantidadeReverter;

                console.log(`  ✅ ${produto.nome}: ${estoqueAtual} - ${quantidadeReverter} = ${novoEstoque}`);

                // Atualizar estoque do produto
                const { error: errUpd } = await supabase
                    .from('produtos')
                    .update({ estoque_atual: novoEstoque })
                    .eq('id', produto.id);

                if (errUpd) {
                    throw new Error(`Erro ao atualizar produto: ${errUpd.message}`);
                }

                // Criar movimentação de reversão (saída de ajuste)
                console.log(`🔄 [ESTOQUE] Criando movimentação SAIDA_AJUSTE para ${produto.nome}:`, {
                    produto_id: produto.id,
                    tipo_movimento: this.TIPOS.SAIDA_AJUSTE,
                    quantidade: quantidadeReverter,
                    referencia_id: pedidoCompraId
                });
                
                const { data: movCriada, error: errNewMov } = await supabase
                    .from('estoque_movimentacoes')
                    .insert({
                        id: crypto.randomUUID(),
                        produto_id: produto.id,
                        tipo_movimento: this.TIPOS.SAIDA_AJUSTE,
                        quantidade: quantidadeReverter,
                        unidade_medida: mov.unidade_medida,
                        preco_unitario: mov.preco_unitario,
                        motivo: `Reversão de entrada - Pedido ${pedidoCompraId}`,
                        referencia_id: pedidoCompraId,
                        referencia_tipo: 'PEDIDO_COMPRA_REVERSAO',
                        usuario_id: mov.usuario_id,
                        created_at: new Date().toISOString()
                    })
                    .select();

                if (errNewMov) {
                    console.error('❌ [ESTOQUE] Erro ao criar movimentação de reversão:', errNewMov);
                    throw new Error(`Erro ao criar movimentação de reversão: ${errNewMov.message}`);
                }
                
                console.log('✅ [ESTOQUE] Movimentação SAIDA_AJUSTE criada:', movCriada);
            }

            console.log('');
            console.log('═══════════════════════════════════════════════════════════════');
            console.log('✅ [ESTOQUE] REVERSÃO CONCLUÍDA COM SUCESSO!');
            console.log('═══════════════════════════════════════════════════════════════');
            console.log('📊 Itens processados:', movimentacoes.length);
            console.log('');

            return {
                sucesso: true,
                itens_processados: movimentacoes.length,
                mensagem: `${movimentacoes.length} produtos revertidos`
            };

        } catch (error) {
            console.log('');
            console.log('═══════════════════════════════════════════════════════════════');
            console.error('❌ [ESTOQUE] ERRO NA REVERSÃO!');
            console.log('═══════════════════════════════════════════════════════════════');
            console.error('Erro:', error);
            console.error('Stack:', error.stack);
            console.log('');
            throw error;
        }
    }

    /**
     * =========================================
     * REVERTER SAÍDA - VENDA CANCELADA
     * =========================================
     * Usado quando cancela uma venda (devolve produtos ao estoque)
     */
    static async reverterSaidaVenda(vendaId) {
        try {
            console.log('🔄 [ESTOQUE] Iniciando reversão de venda:', vendaId);

            // 1. VERIFICAR STATUS ATUAL DA VENDA (fonte de verdade)
            const { data: venda, error: errVenda } = await supabase
                .from('vendas')
                .select('id, status')
                .eq('id', vendaId)
                .single();
            
            if (errVenda || !venda) {
                console.error('❌ [ESTOQUE] Venda não encontrada:', errVenda);
                throw new Error('Venda não encontrada');
            }
            
            const statusAtual = venda.status?.toUpperCase() || '';
            console.log('🔍 [ESTOQUE] Status atual da venda:', statusAtual);
            
            // Se a venda NÃO está FINALIZADA, não há nada para reverter
            if (statusAtual !== 'FINALIZADA' && statusAtual !== 'FINALIZADO') {
                console.warn('⚠️ [ESTOQUE] Venda não está finalizada, status atual:', statusAtual);
                return { 
                    sucesso: true, 
                    itens_processados: 0,
                    mensagem: `Venda com status ${statusAtual} - nenhuma movimentação de estoque para reverter`
                };
            }

            // 2. Buscar movimentações relacionadas à venda (saídas)
            const { data: movimentacoes, error: errMov } = await supabase
                .from('estoque_movimentacoes')
                .select('id, produto_id, quantidade, unidade_medida, preco_unitario, usuario_id')
                .eq('referencia_id', vendaId)
                .eq('referencia_tipo', 'VENDA')
                .eq('tipo_movimento', this.TIPOS.SAIDA_VENDA);

            if (errMov || !movimentacoes || movimentacoes.length === 0) {
                console.warn('⚠️ [ESTOQUE] Nenhuma movimentação de venda encontrada para reverter');
                return { sucesso: true, mensagem: 'Nenhuma movimentação para reverter' };
            }

            console.log(`📊 [ESTOQUE] ${movimentacoes.length} movimentações para reverter`);

            // 3. Buscar dados dos produtos
            const produtoIds = movimentacoes.map(m => m.produto_id);
            const { data: produtos, error: errProdutos } = await supabase
                .from('produtos')
                .select('id, nome, estoque_atual')
                .in('id', produtoIds);

            if (errProdutos) {
                console.error('❌ [ESTOQUE] Erro ao buscar produtos:', errProdutos);
                throw new Error(`Erro ao buscar produtos: ${errProdutos.message}`);
            }

            // Criar mapa de produtos
            const produtosMap = new Map();
            produtos?.forEach(p => produtosMap.set(p.id, p));

            // 4. Processar cada movimentação (DEVOLVER ao estoque)
            for (const mov of movimentacoes) {
                const produto = produtosMap.get(mov.produto_id);
                
                if (!produto) {
                    console.warn(`⚠️ [ESTOQUE] Movimentação sem produto: ${mov.id}`);
                    continue;
                }

                const quantidadeDevolver = parseFloat(mov.quantidade) || 0;
                const estoqueAtual = parseFloat(produto.estoque_atual) || 0;
                const novoEstoque = estoqueAtual + quantidadeDevolver; // SOMA de volta

                console.log(`  ✅ ${produto.nome}: ${estoqueAtual} + ${quantidadeDevolver} = ${novoEstoque}`);

                // Atualizar estoque do produto
                const { error: errUpd } = await supabase
                    .from('produtos')
                    .update({ estoque_atual: novoEstoque })
                    .eq('id', produto.id);

                if (errUpd) {
                    throw new Error(`Erro ao atualizar produto: ${errUpd.message}`);
                }

                // Criar movimentação de devolução
                const { error: errNewMov } = await supabase
                    .from('estoque_movimentacoes')
                    .insert({
                        id: crypto.randomUUID(),
                        produto_id: produto.id,
                        tipo_movimento: this.TIPOS.ENTRADA_DEVOLUCAO,
                        quantidade: quantidadeDevolver,
                        unidade_medida: mov.unidade_medida || 'UN',
                        preco_unitario: mov.preco_unitario || 0,
                        motivo: `Devolução por cancelamento de venda ${vendaId}`,
                        referencia_id: vendaId,
                        referencia_tipo: 'VENDA_CANCELADA',
                        usuario_id: mov.usuario_id,
                        created_at: new Date().toISOString()
                    });

                if (errNewMov) {
                    console.error('❌ [ESTOQUE] Erro ao criar movimentação de devolução:', errNewMov);
                    throw new Error(`Erro ao registrar devolução: ${errNewMov.message}`);
                }
            }

            console.log('✅ [ESTOQUE] Devolução de venda concluída com sucesso!');

            return {
                sucesso: true,
                itens_processados: movimentacoes.length,
                mensagem: `${movimentacoes.length} produtos devolvidos ao estoque`
            };

        } catch (error) {
            console.error('❌ [ESTOQUE] Erro na reversão de venda:', error);
            throw error;
        }
    }

    /**
     * =========================================
     * SAÍDA DE ESTOQUE - VENDA
     * =========================================
     * Usado quando finaliza uma venda (PDV ou pedido)
     */
    static async saidaPorVenda(vendaId) {
        try {
            console.log('📤 [ESTOQUE] Iniciando saída por venda:', vendaId);

            // ⚠️ PROTEÇÃO CONTRA DUPLICAÇÃO INTELIGENTE:
            // Verificar se existe saída E se foi revertida posteriormente
            
            // 1. Buscar última saída
            const { data: ultimaSaida } = await supabase
                .from('estoque_movimentacoes')
                .select('id, created_at')
                .eq('referencia_id', vendaId)
                .eq('referencia_tipo', 'VENDA')
                .eq('tipo_movimento', this.TIPOS.SAIDA_VENDA)
                .order('created_at', { ascending: false })
                .limit(1);

            // 2. Buscar última devolução (reversão)
            const { data: ultimaDevolucao } = await supabase
                .from('estoque_movimentacoes')
                .select('id, created_at')
                .eq('referencia_id', vendaId)
                .eq('referencia_tipo', 'VENDA_CANCELADA')
                .eq('tipo_movimento', this.TIPOS.ENTRADA_DEVOLUCAO)
                .order('created_at', { ascending: false })
                .limit(1);

            // Se existe saída e NÃO existe devolução posterior, já foi processada
            if (ultimaSaida && ultimaSaida.length > 0) {
                const dataSaida = new Date(ultimaSaida[0].created_at);
                
                if (!ultimaDevolucao || ultimaDevolucao.length === 0) {
                    // Há saída mas não há devolução - já processada
                    console.warn('⚠️ [ESTOQUE] Esta venda já teve saída de estoque processada');
                    return { 
                        sucesso: true, 
                        itens_processados: 0,
                        mensagem: 'Saída já processada anteriormente. Nenhuma ação necessária.',
                        ja_processado: true
                    };
                }
                
                const dataDevolucao = new Date(ultimaDevolucao[0].created_at);
                
                if (dataSaida > dataDevolucao) {
                    // A saída é mais recente que a devolução - já foi reprocessada
                    console.warn('⚠️ [ESTOQUE] Esta venda já foi reprocessada após reversão');
                    return { 
                        sucesso: true, 
                        itens_processados: 0,
                        mensagem: 'Saída já processada após reversão. Nenhuma ação necessária.',
                        ja_processado: true
                    };
                }
                
                // Devolução é mais recente - pode processar nova saída
                console.log('✅ [ESTOQUE] Venda foi reaberta, processando nova saída de estoque');
            }

            // 1. Buscar venda
            const { data: venda, error: errVenda } = await supabase
                .from('vendas')
                .select('id, numero, operador_id')
                .eq('id', vendaId)
                .single();

            if (errVenda || !venda) {
                throw new Error('Venda não encontrada');
            }

            // 2. Buscar itens da venda
            const { data: itens, error: errItens } = await supabase
                .from('venda_itens')
                .select('id, produto_id, quantidade, preco_unitario, preco_custo')
                .eq('venda_id', vendaId);

            if (errItens || !itens || itens.length === 0) {
                throw new Error('Nenhum item encontrado na venda');
            }

            console.log(`📊 [ESTOQUE] ${itens.length} itens para processar`);

            // 3. Buscar dados dos produtos
            const produtoIds = itens.map(item => item.produto_id);
            const { data: produtos, error: errProdutos } = await supabase
                .from('produtos')
                .select('id, nome, estoque_atual, unidade')
                .in('id', produtoIds);

            if (errProdutos) {
                console.error('❌ [ESTOQUE] Erro ao buscar produtos:', errProdutos);
                throw new Error(`Erro ao buscar produtos: ${errProdutos.message}`);
            }

            // Criar mapa de produtos
            const produtosMap = new Map();
            produtos?.forEach(p => produtosMap.set(p.id, p));

            // 4. Validar estoque ANTES de processar
            const errosEstoque = [];
            for (const item of itens) {
                const produto = produtosMap.get(item.produto_id);
                
                if (!produto) {
                    errosEstoque.push(`Produto não encontrado para item ${item.id}`);
                    continue;
                }

                const quantidadeSaida = parseFloat(item.quantidade) || 0;
                const estoqueAtual = parseFloat(produto.estoque_atual) || 0;

                if (estoqueAtual < quantidadeSaida) {
                    errosEstoque.push(
                        `${produto.nome}: estoque insuficiente (disponível: ${estoqueAtual}, necessário: ${quantidadeSaida})`
                    );
                }
            }

            if (errosEstoque.length > 0) {
                throw new Error('Estoque insuficiente:\n' + errosEstoque.join('\n'));
            }

            // 5. Processar saídas
            const movimentacoes = [];
            const atualizacoesProdutos = [];

            for (const item of itens) {
                const produto = produtosMap.get(item.produto_id);
                
                if (!produto) continue;

                const quantidadeSaida = parseFloat(item.quantidade) || 0;
                const estoqueAtual = parseFloat(produto.estoque_atual) || 0;
                const novoEstoque = estoqueAtual - quantidadeSaida;

                console.log(`  ✅ ${produto.nome}: ${estoqueAtual} - ${quantidadeSaida} = ${novoEstoque}`);

                // Normalizar unidade de medida
                const unidadeNormalizada = this.normalizarUnidadeMedida(produto.unidade);

                // Preparar movimentação
                movimentacoes.push({
                    id: crypto.randomUUID(),
                    produto_id: produto.id,
                    tipo_movimento: this.TIPOS.SAIDA_VENDA,
                    quantidade: quantidadeSaida,
                    unidade_medida: unidadeNormalizada,
                    preco_unitario: parseFloat(item.preco_custo) || 0,
                    motivo: `Saída por venda ${venda.numero || vendaId}`,
                    referencia_id: vendaId,
                    referencia_tipo: 'VENDA',
                    usuario_id: venda.operador_id,
                    created_at: new Date().toISOString()
                });

                atualizacoesProdutos.push({
                    id: produto.id,
                    estoque_atual: novoEstoque
                });
            }

            // 5. Executar inserções/atualizações
            console.log('💾 [ESTOQUE] Registrando movimentações de saída...');

            const { error: errMov } = await supabase
                .from('estoque_movimentacoes')
                .insert(movimentacoes);

            if (errMov) {
                throw new Error(`Erro ao registrar movimentações: ${errMov.message}`);
            }

            for (const update of atualizacoesProdutos) {
                const { error: errUpd } = await supabase
                    .from('produtos')
                    .update({ estoque_atual: update.estoque_atual })
                    .eq('id', update.id);

                if (errUpd) {
                    throw new Error(`Erro ao atualizar estoque: ${errUpd.message}`);
                }
            }

            console.log('✅ [ESTOQUE] Saída por venda registrada com sucesso!');

            return {
                sucesso: true,
                itens_processados: movimentacoes.length,
                mensagem: `${movimentacoes.length} produtos atualizados`
            };

        } catch (error) {
            console.error('❌ [ESTOQUE] Erro na saída por venda:', error);
            throw error;
        }
    }

    /**
     * =========================================
     * AJUSTE MANUAL DE ESTOQUE
     * =========================================
     */
    static async ajusteManual(produtoId, quantidade, tipo, motivo, usuarioId) {
        try {
            // Validar tipo
            if (tipo !== 'ENTRADA' && tipo !== 'SAIDA') {
                throw new Error('Tipo de ajuste inválido. Deve ser ENTRADA ou SAIDA');
            }

            // Buscar produto
            const { data: produto, error: errProd } = await supabase
                .from('produtos')
                .select('id, nome, estoque_atual, unidade')
                .eq('id', produtoId)
                .single();

            if (errProd || !produto) {
                throw new Error('Produto não encontrado');
            }

            const qtd = Math.abs(parseFloat(quantidade));
            const estoqueAtual = parseFloat(produto.estoque_atual) || 0;

            let novoEstoque;
            let tipoMovimento;

            if (tipo === 'ENTRADA') {
                novoEstoque = estoqueAtual + qtd;
                tipoMovimento = this.TIPOS.ENTRADA_AJUSTE;
            } else {
                // Validar estoque negativo
                if (estoqueAtual < qtd) {
                    throw new Error(
                        `Estoque insuficiente para saída. Disponível: ${estoqueAtual}, Solicitado: ${qtd}`
                    );
                }
                novoEstoque = estoqueAtual - qtd;
                tipoMovimento = this.TIPOS.SAIDA_AJUSTE;
            }

            // Normalizar unidade de medida
            const unidadeNormalizada = this.normalizarUnidadeMedida(produto.unidade);

            // Registrar movimentação
            const { error: errMov } = await supabase
                .from('estoque_movimentacoes')
                .insert({
                    id: crypto.randomUUID(),
                    produto_id: produtoId,
                    tipo_movimento: tipoMovimento,
                    quantidade: qtd,
                    unidade_medida: unidadeNormalizada,
                    motivo: motivo || 'Ajuste manual',
                    referencia_tipo: 'AJUSTE_MANUAL',
                    usuario_id: usuarioId,
                    created_at: new Date().toISOString()
                });

            if (errMov) {
                throw new Error(`Erro ao registrar movimentação: ${errMov.message}`);
            }

            // Atualizar produto
            const { error: errUpd } = await supabase
                .from('produtos')
                .update({ estoque_atual: novoEstoque })
                .eq('id', produtoId);

            if (errUpd) {
                throw new Error(`Erro ao atualizar estoque: ${errUpd.message}`);
            }

            console.log(`✅ [ESTOQUE] Ajuste manual: ${produto.nome} - ${estoqueAtual} → ${novoEstoque}`);

            return {
                sucesso: true,
                estoque_anterior: estoqueAtual,
                estoque_novo: novoEstoque
            };

        } catch (error) {
            console.error('❌ [ESTOQUE] Erro no ajuste manual:', error);
            throw error;
        }
    }

    /**
     * =========================================
     * CONSULTAR HISTÓRICO DE MOVIMENTAÇÕES
     * =========================================
     */
    static async consultarHistorico(produtoId, limite = 100) {
        try {
            const { data, error } = await supabase
                .from('estoque_movimentacoes')
                .select(`
                    *,
                    usuario:usuario_id(nome_completo, email)
                `)
                .eq('produto_id', produtoId)
                .order('created_at', { ascending: false })
                .limit(limite);

            if (error) throw error;

            return data || [];

        } catch (error) {
            console.error('❌ [ESTOQUE] Erro ao consultar histórico:', error);
            return [];
        }
    }
}

// Expor globalmente
window.EstoqueService = EstoqueService;
