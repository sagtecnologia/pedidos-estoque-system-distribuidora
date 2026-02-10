/**
 * Serviço de Distribuição de NFC-e para Entradas
 * Permite emitir notas de saída para produtos que chegaram com NF-e
 * Sem gerar movimentação de estoque
 */

class DistribuicaoNFCeService {
    /**
     * Buscar entradas de um período que ainda não têm nota de saída
     * @param {Date} dataInicio - Data inicial (inclusive)
     * @param {Date} dataFim - Data final (inclusive)
     * @returns {Array} Lista de pedidos de compra com itens
     */
    static async buscarEntradasPeriodo(dataInicio, dataFim) {
        try {
            console.log('🔍 [DistribuicaoNFCe] Buscando entradas de compra:', { dataInicio, dataFim });

            // 1️⃣ Buscar pedidos de compra recebidos
            const { data: pedidos, error: erroPedidos } = await supabase
                .from('pedidos_compra')
                .select(`
                    id,
                    numero,
                    fornecedor_id,
                    data_recebimento,
                    nf_numero,
                    nf_serie,
                    nf_chave,
                    total
                `)
                .eq('status', 'RECEBIDO')
                .gte('data_recebimento', dataInicio.toISOString().split('T')[0])
                .lte('data_recebimento', dataFim.toISOString().split('T')[0])
                .not('nf_chave', 'is', null) // Apenas entradas com NF-e
                .order('data_recebimento', { ascending: false });

            if (erroPedidos) {
                console.error('❌ [DistribuicaoNFCe] Erro ao buscar pedidos:', erroPedidos.message);
                throw erroPedidos;
            }

            if (!pedidos || pedidos.length === 0) {
                console.log('ℹ️ [DistribuicaoNFCe] Nenhum pedido encontrado no período');
                return [];
            }

            // 2️⃣ Para cada pedido, buscar seus itens com dados disponível
            const entradasComItens = await Promise.all(
                pedidos.map(async (pedido) => {
                    const { data: itens, error: erroItens } = await supabase
                        .from('pedido_compra_itens')
                        .select(`
                            id,
                            pedido_id,
                            produto_id,
                            quantidade,
                            quantidade_recebida,
                            preco_unitario,
                            subtotal,
                            numero_lote,
                            data_validade,
                            nota_saida_emitida,
                            nota_saida_numero,
                            preco_venda_nfe,
                            produtos:produto_id (
                                id,
                                nome,
                                codigo_barras,
                                ncm,
                                cfop,
                                cfop_venda,
                                origem_produto,
                                descricao_nfe,
                                aliquota_icms,
                                aliquota_pis,
                                aliquota_cofins,
                                cst_icms,
                                cst_pis,
                                cst_cofins,
                                preco_venda,
                                unidade_medida_padrao,
                                controla_validade
                            )
                        `)
                        .eq('pedido_id', pedido.id)
                        .eq('nota_saida_emitida', false); // Apenas itens SEM nota de saída

                    if (erroItens) {
                        console.warn(`⚠️ [DistribuicaoNFCe] Erro ao buscar itens do pedido ${pedido.numero}:`, erroItens.message);
                        return null;
                    }

                    // 3️⃣ Buscar dados do fornecedor
                    const { data: fornecedor } = await supabase
                        .from('fornecedores')
                        .select('id, nome, cnpj, inscricao_estadual')
                        .eq('id', pedido.fornecedor_id)
                        .single();

                    return {
                        ...pedido,
                        fornecedores: fornecedor,
                        pedido_compra_itens: itens || []
                    };
                })
            );

            // Filtrar apenas pedidos que têm itens disponíveis
            const entradasFiltradas = entradasComItens.filter(p => p && p.pedido_compra_itens.length > 0);

            console.log(`✅ [DistribuicaoNFCe] ${entradasFiltradas.length} pedidos encontrados com itens sem nota de saída`);
            return entradasFiltradas;

        } catch (erro) {
            console.error('❌ [DistribuicaoNFCe] Erro ao buscar entradas:', erro.message);
            throw erro;
        }
    }

    /**
     * Emitir NFC-e consolidada para itens de entrada selecionados
     * Não gera movimentação de estoque
     * @param {Object} params - Parâmetros da emissão
     * @returns {Object} Resultado da emissão
     */
    static async emitirNFCeDistribuicao(params) {
        try {
            const {
                itensCliente, // [{ pedido_item_id, quantidade, preco_venda }, ...]
                cliente = null, // CPF/CNPJ cliente (opcional)
                descricaoNota = 'Distribuição de Produtos', // Descrição opcional
                observacoes = null
            } = params;

            console.log('📮 [DistribuicaoNFCe] Iniciando emissão NFC-e de distribuição...');
            console.log('📊 [DistribuicaoNFCe] Itens selecionados:', itensCliente.length);

            // 1️⃣ Validar e buscar dados dos itens
            const itensComDados = await Promise.all(
                itensCliente.map(async (item) => {
                    const { data: pedidoItem, error } = await supabase
                        .from('pedido_compra_itens')
                        .select(`
                            *,
                            produtos:produto_id (
                                id,
                                nome,
                                codigo_barras,
                                ncm,
                                cfop_venda,
                                origem_produto,
                                descricao_nfe,
                                aliquota_icms,
                                aliquota_pis,
                                aliquota_cofins,
                                cst_icms,
                                cst_pis,
                                cst_cofins,
                                unidade_medida_padrao
                            ),
                            pedidos_compra:pedido_id (
                                nf_chave,
                                nf_numero,
                                nf_serie,
                                fornecedor_id,
                                fornecedores:fornecedor_id (
                                    nome,
                                    cnpj
                                )
                            )
                        `)
                        .eq('id', item.pedido_item_id)
                        .single();

                    if (error || !pedidoItem) {
                        throw new Error(`Item de pedido ${item.pedido_item_id} não encontrado`);
                    }

                    return {
                        ...pedidoItem,
                        preco_venda: item.preco_venda || pedidoItem.preco_venda_nfe || pedidoItem.produtos.preco_venda,
                        quantidade_emissao: item.quantidade
                    };
                })
            );

            console.log('✅ [DistribuicaoNFCe] Dados dos itens carregados');

            // 2️⃣ Buscar configuração da empresa e cliente (se fornecido)
            const { data: empresa, error: erroEmpresa } = await supabase
                .from('empresa_config')
                .select('*')
                .single();

            if (erroEmpresa || !empresa) {
                throw new Error('Configuração da empresa não encontrada');
            }

            let clientePessoa = null;
            if (cliente) {
                const { data: cli } = await supabase
                    .from('clientes')
                    .select('*')
                    .or(`cpf_cnpj.eq.${cliente},id.eq.${cliente}`)
                    .limit(1);

                if (cli && cli.length > 0) {
                    clientePessoa = cli[0];
                }
            }

            // 3️⃣ Montar dados da venda para emissão
            const agora = new Date();
            const vendaData = {
                data_emissao: agora.toISOString().split('T')[0],
                hora_emissao: agora.toTimeString().substring(0, 8),
                subtotal: itensComDados.reduce((sum, item) => sum + (item.preco_venda * item.quantidade_emissao), 0),
                desconto: 0,
                total: itensComDados.reduce((sum, item) => sum + (item.preco_venda * item.quantidade_emissao), 0),
                valor_total: itensComDados.reduce((sum, item) => sum + (item.preco_venda * item.quantidade_emissao), 0),
                troco: 0,
                cliente_id: clientePessoa?.id || null,
                forma_pagamento: 'DINHEIRO',
                observacoes: `DISTRIBUIÇÃO DE NFC-e - ${descricaoNota}\nChaves de origem: ${[...new Set(itensComDados.map(i => i.pedidos_compra?.nf_chave))].join(', ')}\n${observacoes || ''}`
            };

            // 4️⃣ Montar itens da venda
            const itensVenda = itensComDados.map((item, idx) => ({
                numero_item: idx + 1,
                codigo: item.produtos.codigo_barras || String(item.produto_id),
                nome_produto: item.produtos.nome,
                descricao: item.produtos.descricao_nfe || item.produtos.nome,
                quantidade: item.quantidade_emissao,
                valor_unitario: item.preco_venda,
                valor_total: item.preco_venda * item.quantidade_emissao,
                ncm: item.produtos.ncm || '22021000',
                cfop: item.produtos.cfop_venda || '5102',
                origem: item.produtos.origem_produto || 0,
                cst_icms: item.produtos.cst_icms || '102',
                cst_pis: item.produtos.cst_pis || '99',
                cst_cofins: item.produtos.cst_cofins || '99',
                unidade_medida: item.produtos.unidade_medida_padrao || 'UN',
                icms_aliquota: item.produtos.aliquota_icms || 0,
                icms_valor: (item.preco_venda * item.quantidade_emissao) * (item.produtos.aliquota_icms || 0) / 100,
                pis_aliquota: item.produtos.aliquota_pis || 0,
                pis_valor: (item.preco_venda * item.quantidade_emissao) * (item.produtos.aliquota_pis || 0) / 100,
                cofins_aliquota: item.produtos.aliquota_cofins || 0,
                cofins_valor: (item.preco_venda * item.quantidade_emissao) * (item.produtos.aliquota_cofins || 0) / 100,
                // Referência ao item original para marcar como emitido
                pedido_item_id: item.id
            }));

            console.log('✅ [DistribuicaoNFCe] Dados da venda montados');

            // 5️⃣ Emitir NFC-e via FiscalSystem
            console.log('📮 [DistribuicaoNFCe] Enviando para emissão fiscal...');

            const resultadoFiscal = await FiscalSystem.emitirNFCeDireto(
                vendaData,
                itensVenda,
                [{ forma_pagamento: 'DINHEIRO', valor: vendaData.total }],
                clientePessoa
            );

            if (!resultadoFiscal.success && resultadoFiscal.status !== 'autorizado') {
                throw new Error(`Emissão fiscal falhou: ${resultadoFiscal.mensagem || 'Erro desconhecido'}`);
            }

            console.log('✅ [DistribuicaoNFCe] NFC-e emitida com sucesso! Número:', resultadoFiscal.numero);

            // 6️⃣ Marcar itens como emitidos (SEM CRIAR MOVIMENTAÇÃO DE ESTOQUE)
            const atualizacoes = itensVenda.map(item =>
                supabase
                    .from('pedido_compra_itens')
                    .update({
                        nota_saida_emitida: true,
                        nota_saida_numero: String(resultadoFiscal.numero),
                        nota_saida_id: resultadoFiscal.nfce_id || resultadoFiscal.numero
                    })
                    .eq('id', item.pedido_item_id)
            );

            const resultadosAtualizacao = await Promise.all(atualizacoes);
            const errosAtualizacao = resultadosAtualizacao.filter(r => r.error);

            if (errosAtualizacao.length > 0) {
                console.warn('⚠️ [DistribuicaoNFCe] Alguns itens não foram marcados como emitidos');
            }

            console.log('✅ [DistribuicaoNFCe] Itens marcados como emitidos');

            // 7️⃣ Salvar documento fiscal no banco (para poder cancelar/baixar depois)
            const documentoFiscal = {
                tipo_documento: 'NFCE',
                numero_documento: String(resultadoFiscal.numero),
                serie: parseInt(resultadoFiscal.serie || '1'),
                chave_acesso: resultadoFiscal.chave_nfe,
                protocolo_autorizacao: resultadoFiscal.protocolo,
                status_sefaz: '100', // Autorizado
                mensagem_sefaz: 'Autorizado o uso da NFC-e',
                valor_total: vendaData.total,
                natureza_operacao: 'VENDA',
                data_emissao: vendaData.data_emissao,
                data_autorizacao: new Date().toISOString(),
                xml_nota: null,
                xml_retorno: JSON.stringify(resultadoFiscal),
                tentativas_emissao: 1,
                ultima_tentativa: new Date().toISOString(),
                api_provider: 'nuvem_fiscal',
                nfce_id: resultadoFiscal.nfce_id // ✅ IMPORTANTE: ID da nota na Nuvem Fiscal
            };

            const { error: erroDocumento, data: docInserido } = await supabase
                .from('documentos_fiscais')
                .insert([documentoFiscal])
                .select('id');

            if (erroDocumento) {
                console.warn('⚠️ [DistribuicaoNFCe] Não foi possível salvar documento fiscal:', erroDocumento.message);
                // Continuar mesmo com erro, pois a nota foi emitida
            } else if (docInserido && docInserido.length > 0) {
                console.log('✅ [DistribuicaoNFCe] Documento fiscal salvo no banco com ID:', docInserido[0].id);
            }

            // 📋 Retornar resultado completo
            return {
                success: true,
                status: 'emitida',
                numero_nfce: resultadoFiscal.numero,
                chave_nfe: resultadoFiscal.chave_nfe,
                protocolo: resultadoFiscal.protocolo,
                caminho_danfe: resultadoFiscal.caminho_danfe,
                caminho_xml: resultadoFiscal.caminho_xml_nota_fiscal,
                nfce_id: resultadoFiscal.nfce_id,
                total_itens: itensVenda.length,
                valor_total: vendaData.total,
                itens_marcados: resultadosAtualizacao.filter(r => !r.error).length,
                mensagem: `NFC-e #${resultadoFiscal.numero} emitida com sucesso para ${itensVenda.length} itens`
            };

        } catch (erro) {
            console.error('❌ [DistribuicaoNFCe] Erro ao emitir NFC-e:', erro.message);
            throw erro;
        }
    }

    /**
     * Cancelar emissão e reverter marcações
     * @param {String} notaSaidaNumero - Número da nota de saída
     * @param {String} justificativa - Motivo do cancelamento
     */
    static async cancelarDistribuicao(notaSaidaNumero, justificativa) {
        try {
            console.log('❌ [DistribuicaoNFCe] Cancelando distribuição:', notaSaidaNumero);

            // 1️⃣ Reverter marcações nos itens
            const { error: erroUpdate } = await supabase
                .from('pedido_compra_itens')
                .update({
                    nota_saida_emitida: false,
                    nota_saida_numero: null,
                    nota_saida_id: null
                })
                .eq('nota_saida_numero', String(notaSaidaNumero));

            if (erroUpdate) {
                console.error('❌ [DistribuicaoNFCe] Erro ao reverter marcações:', erroUpdate.message);
                throw erroUpdate;
            }

            console.log('✅ [DistribuicaoNFCe] Distribuição cancelada e itens revertidos');

            return {
                success: true,
                mensagem: `Distribuição #${notaSaidaNumero} cancelada. Itens revertidos para emissão posterior.`
            };

        } catch (erro) {
            console.error('❌ [DistribuicaoNFCe] Erro ao cancelar:', erro.message);
            throw erro;
        }
    }
}

// Alias para compatibilidade
const DistribuicaoNFCe = DistribuicaoNFCeService;
