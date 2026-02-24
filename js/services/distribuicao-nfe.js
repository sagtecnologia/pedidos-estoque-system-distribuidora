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
                            produto:produtos (
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
                itensCliente, // [{ pedido_item_id, quantidade, preco_venda, cst_icms, cst_pis, cst_cofins }, ...]
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
                            produto:produtos (
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
                            pedido_compra:pedidos_compra (
                                nf_chave,
                                nf_numero,
                                nf_serie,
                                fornecedor_id,
                                fornecedor:fornecedores (
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
                        preco_venda: item.preco_venda || pedidoItem.preco_venda_nfe || pedidoItem.produto.preco_venda,
                        quantidade_emissao: item.quantidade,
                        // CST personalizados vindo do frontend (se fornecidos)
                        cst_icms_customizado: item.cst_icms,
                        cst_pis_customizado: item.cst_pis,
                        cst_cofins_customizado: item.cst_cofins
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
                observacoes: `DISTRIBUIÇÃO DE NFC-e - ${descricaoNota}\nChaves de origem: ${[...new Set(itensComDados.map(i => i.pedido_compra?.nf_chave))].join(', ')}\n${observacoes || ''}`
            };

            // 4️⃣ Montar itens da venda
            const itensVenda = itensComDados.map((item, idx) => ({
                numero_item: idx + 1,
                codigo: item.produto.codigo_barras || String(item.produto_id),
                codigo_produto: item.produto.codigo_barras || String(item.produto_id), // ✅ Campo adicional para compatibilidade
                codigo_barras: item.produto.codigo_barras || null,
                produto_id: item.produto_id,
                nome_produto: item.produto.nome,
                descricao: item.produto.descricao_nfe || item.produto.nome,
                quantidade: item.quantidade_emissao,
                preco_unitario: item.preco_venda,
                valor_unitario: item.preco_venda,
                subtotal: item.preco_venda * item.quantidade_emissao,
                valor_total: item.preco_venda * item.quantidade_emissao,
                unidade: item.produto.unidade_medida_padrao || 'UN',
                ncm: item.produto.ncm || '22021000',
                cfop: item.produto.cfop_venda || '5102',
                origem: item.produto.origem_produto || 0,
                icms_origem: item.produto.origem_produto || 0,
                // ✅ Aplicar CST customizados se fornecidos, senão usar do produto
                cst_icms: item.cst_icms_customizado || item.produto.cst_icms || '102',
                cst_pis: item.cst_pis_customizado || item.produto.cst_pis || '99',
                cst_cofins: item.cst_cofins_customizado || item.produto.cst_cofins || '99',
                unidade_medida: item.produto.unidade_medida_padrao || 'UN',
                icms_aliquota: item.produto.aliquota_icms || 0,
                icms_valor: (item.preco_venda * item.quantidade_emissao) * (item.produto.aliquota_icms || 0) / 100,
                pis_aliquota: item.produto.aliquota_pis || 0,
                pis_valor: (item.preco_venda * item.quantidade_emissao) * (item.produto.aliquota_pis || 0) / 100,
                cofins_aliquota: item.produto.aliquota_cofins || 0,
                cofins_valor: (item.preco_venda * item.quantidade_emissao) * (item.produto.aliquota_cofins || 0) / 100,
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
            console.log('📋 [DistribuicaoNFCe] DADOS COMPLETOS DA EMISSÃO (GUARDAR PARA CANCELAMENTO):');
            console.log('   - Número:', resultadoFiscal.numero);
            console.log('   - Chave:', resultadoFiscal.chave_nfe || resultadoFiscal.chave_acesso);
            console.log('   - Protocolo:', resultadoFiscal.protocolo);
            console.log('   - NFC-e ID (API):', resultadoFiscal.nfce_id);
            console.log('   - Provider:', resultadoFiscal.provider);
            console.log('   - Objeto completo:', JSON.stringify(resultadoFiscal, null, 2));

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

            // 7️⃣ Salvar documento fiscal no banco - SEGUINDO PADRÃO DO PDV
            // ⚠️ CRITICAL: Salvar todos os dados necessários para cancelamento!
            // ⚠️ USAR DATA/HORA DA SEFAZ, NÃO DO NAVEGADOR (horário correto de Brasília)
            const dataEmissaoSefaz = resultadoFiscal.data_emissao || resultadoFiscal.documentoFiscalData?.data_emissao || new Date().toISOString();
            const dataAutorizacaoSefaz = resultadoFiscal.data_autorizacao || resultadoFiscal.documentoFiscalData?.data_autorizacao || new Date().toISOString();
            
            console.log('📅 [DistribuicaoNFCe] Datas SEFAZ para salvar:', { dataEmissaoSefaz, dataAutorizacaoSefaz });
            
            // Sempre construir o objeto explicitamente para garantir que nfce_id e demais campos estão corretos
            // Mesclar documentoFiscalData retornado pelo fiscal.js (se existir) com campos distribuição
            const chaveAcessoFinal = resultadoFiscal.chave_nfe || resultadoFiscal.chave_acesso || resultadoFiscal.documentoFiscalData?.chave_acesso;
            const nfceIdFinal = resultadoFiscal.nfce_id || resultadoFiscal.documentoFiscalData?.nfce_id || null;

            const documentoFiscalData = {
                venda_id: null, // ✅ NULL pois não há venda na distribuição
                tipo_documento: 'NFCE',
                numero_documento: String(resultadoFiscal.numero || resultadoFiscal.documentoFiscalData?.numero_documento || '0'),
                serie: parseInt(resultadoFiscal.serie || resultadoFiscal.documentoFiscalData?.serie || '1'),
                chave_acesso: chaveAcessoFinal,
                protocolo_autorizacao: resultadoFiscal.protocolo || resultadoFiscal.documentoFiscalData?.protocolo_autorizacao,
                status_sefaz: '100', // Autorizado
                mensagem_sefaz: resultadoFiscal.mensagem || 'Autorizado o uso da NFC-e',
                valor_total: vendaData.total,
                natureza_operacao: 'DISTRIBUICAO',
                data_emissao: dataEmissaoSefaz,
                data_autorizacao: dataAutorizacaoSefaz,
                xml_nota: resultadoFiscal.caminho_xml || resultadoFiscal.documentoFiscalData?.xml_nota || null,
                xml_retorno: JSON.stringify(resultadoFiscal),
                tentativas_emissao: 1,
                ultima_tentativa: new Date().toISOString(),
                api_provider: resultadoFiscal.provider || 'nuvem_fiscal',
                nfce_id: nfceIdFinal // ✅ CRITICAL: ID da nota na Nuvem Fiscal para impressão/consulta
            };

            let documentoFiscalId = null;
            const { error: erroDocumento, data: docInserido } = await supabase
                .from('documentos_fiscais')
                .insert([documentoFiscalData])
                .select('id')
                .single();

            if (erroDocumento) {
                console.error('❌ [DistribuicaoNFCe] ERRO CRÍTICO ao salvar documento fiscal:', erroDocumento.message);
                console.error('⚠️ [DistribuicaoNFCe] A nota foi emitida mas não foi salva no banco!');
                console.error('⚠️ [DistribuicaoNFCe] Dados da nota:', documentoFiscalData);
                // ⚠️ NÃO continuar silenciosamente - lançar aviso mas retornar resultado
                throw new Error(`Nota emitida mas ERRO ao salvar no banco: ${erroDocumento.message}. ANOTE: Chave ${resultadoFiscal.chave_nfe}, Número ${resultadoFiscal.numero}`);
            } else if (docInserido && docInserido.id) {
                documentoFiscalId = docInserido.id;
                console.log('✅ [DistribuicaoNFCe] Documento fiscal salvo no banco com ID:', documentoFiscalId);
            }

            // 📋 Retornar resultado completo
            return {
                success: true,
                status: 'emitida',
                numero_nfce: resultadoFiscal.numero,
                serie: resultadoFiscal.serie || resultadoFiscal.documentoFiscalData?.serie || 1,
                chave_nfe: resultadoFiscal.chave_nfe || resultadoFiscal.chave_acesso,
                protocolo: resultadoFiscal.protocolo,
                caminho_danfe: resultadoFiscal.caminho_danfe,
                caminho_xml: resultadoFiscal.caminho_xml_nota_fiscal,
                nfce_id: resultadoFiscal.nfce_id, // ✅ ID para download de XML/PDF
                documento_fiscal_id: documentoFiscalId, // ✅ ID do registro no banco
                provider: resultadoFiscal.provider || 'nuvem_fiscal',
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
