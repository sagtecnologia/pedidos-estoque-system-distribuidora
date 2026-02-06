/**
 * Serviço de Controle de Validade de Produtos
 * Gerencia alertas de vencimento usando a tabela produto_lotes
 */

class ServicoVencimento {
    constructor() {
        this.diasAlertaVencimento = 30; // Alertar produtos com 30 dias ou menos
        this.diasAlertaCritico = 7;     // Crítico: 7 dias ou menos
    }

    /**
     * Buscar produtos próximos do vencimento
     * @param {number} dias - Dias para considerar "próximo" (padrão: 30)
     * @returns {Array} Lotes próximos do vencimento
     */
    async buscarProdutosProximosVencimento(dias = null) {
        try {
            const diasBusca = dias || this.diasAlertaVencimento;
            const dataLimite = new Date();
            dataLimite.setDate(dataLimite.getDate() + diasBusca);

            const { data: lotes, error } = await supabase
                .from('produto_lotes')
                .select(`
                    *,
                    produtos (
                        id,
                        nome,
                        codigo_produto,
                        codigo_barras,
                        categoria_id,
                        categorias (
                            nome
                        )
                    )
                `)
                .gte('quantidade_atual', 0.01) // Apenas lotes com estoque
                .lte('data_vencimento', dataLimite.toISOString().split('T')[0])
                .order('data_vencimento', { ascending: true });

            if (error) throw error;

            // Calcular dias restantes e classificar por urgência
            const hoje = new Date();
            hoje.setHours(0, 0, 0, 0);

            const lotesProcessados = lotes.map(lote => {
                const dataVencimento = new Date(lote.data_vencimento);
                const diasRestantes = Math.ceil((dataVencimento - hoje) / (1000 * 60 * 60 * 24));
                
                let urgencia = 'normal';
                if (diasRestantes <= 0) {
                    urgencia = 'vencido';
                } else if (diasRestantes <= this.diasAlertaCritico) {
                    urgencia = 'critico';
                } else if (diasRestantes <= this.diasAlertaVencimento) {
                    urgencia = 'alerta';
                }

                return {
                    ...lote,
                    diasRestantes,
                    urgencia,
                    produto: lote.produtos
                };
            });

            return lotesProcessados;
        } catch (erro) {
            console.error('Erro ao buscar produtos próximos do vencimento:', erro);
            throw erro;
        }
    }

    /**
     * Buscar produtos VENCIDOS (data_vencimento < hoje)
     */
    async buscarProdutosVencidos() {
        try {
            const hoje = new Date().toISOString().split('T')[0];

            const { data: lotes, error } = await supabase
                .from('produto_lotes')
                .select(`
                    *,
                    produtos (
                        id,
                        nome,
                        codigo_produto,
                        codigo_barras,
                        categoria_id,
                        categorias (nome)
                    )
                `)
                .gte('quantidade_atual', 0.01)
                .lt('data_vencimento', hoje)
                .order('data_vencimento', { ascending: true });

            if (error) throw error;

            return lotes.map(lote => ({
                ...lote,
                produto: lote.produtos,
                diasRestantes: Math.floor((new Date(lote.data_vencimento) - new Date()) / (1000 * 60 * 60 * 24)),
                urgencia: 'vencido'
            }));
        } catch (erro) {
            console.error('Erro ao buscar produtos vencidos:', erro);
            throw erro;
        }
    }

    /**
     * Buscar lotes de um produto específico ordenados por vencimento (FIFO)
     * @param {number} produtoId - ID do produto
     */
    async buscarLotesProduto(produtoId) {
        try {
            const { data: lotes, error } = await supabase
                .from('produto_lotes')
                .select('*')
                .eq('produto_id', produtoId)
                .gte('quantidade_atual', 0.01)
                .order('data_vencimento', { ascending: true });

            if (error) throw error;

            const hoje = new Date();
            return lotes.map(lote => {
                const dataVencimento = new Date(lote.data_vencimento);
                const diasRestantes = Math.ceil((dataVencimento - hoje) / (1000 * 60 * 60 * 24));
                
                return {
                    ...lote,
                    diasRestantes,
                    urgencia: diasRestantes <= 0 ? 'vencido' : 
                             diasRestantes <= this.diasAlertaCritico ? 'critico' : 
                             diasRestantes <= this.diasAlertaVencimento ? 'alerta' : 'normal'
                };
            });
        } catch (erro) {
            console.error('Erro ao buscar lotes do produto:', erro);
            throw erro;
        }
    }

    /**
     * Contar produtos por status de vencimento
     * Retorna: { vencidos: N, criticos: N, alertas: N }
     */
    async contarPorUrgencia() {
        try {
            const lotes = await this.buscarProdutosProximosVencimento(this.diasAlertaVencimento);
            
            const contagem = {
                vencidos: 0,
                criticos: 0,
                alertas: 0
            };

            lotes.forEach(lote => {
                if (lote.urgencia === 'vencido') contagem.vencidos++;
                else if (lote.urgencia === 'critico') contagem.criticos++;
                else if (lote.urgencia === 'alerta') contagem.alertas++;
            });

            return contagem;
        } catch (erro) {
            console.error('Erro ao contar produtos por urgência:', erro);
            return { vencidos: 0, criticos: 0, alertas: 0 };
        }
    }

    /**
     * Registrar baixa de lote (ao vender produto)
     * Usa lógica FIFO (primeiro que vence, primeiro que sai)
     * @param {number} produtoId - ID do produto
     * @param {number} quantidade - Quantidade vendida
     */
    async darBaixaLote(produtoId, quantidade) {
        try {
            // Buscar lotes ordenados por vencimento (FIFO)
            const lotes = await this.buscarLotesProduto(produtoId);
            
            if (lotes.length === 0) {
                console.warn(`⚠️ Nenhum lote encontrado para produto ${produtoId}`);
                return { sucesso: false, mensagem: 'Produto sem lote cadastrado' };
            }

            let quantidadeRestante = quantidade;
            const lotesAtualizados = [];

            for (const lote of lotes) {
                if (quantidadeRestante <= 0) break;

                const quantidadeDisponivel = lote.quantidade_atual;
                const quantidadeBaixar = Math.min(quantidadeRestante, quantidadeDisponivel);

                // Atualizar quantidade do lote
                const { error } = await supabase
                    .from('produto_lotes')
                    .update({ 
                        quantidade_atual: quantidadeDisponivel - quantidadeBaixar,
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', lote.id);

                if (error) throw error;

                lotesAtualizados.push({
                    lote_id: lote.id,
                    numero_lote: lote.numero_lote,
                    quantidade_baixada: quantidadeBaixar
                });

                quantidadeRestante -= quantidadeBaixar;

                console.log(`✅ Baixa lote ${lote.numero_lote}: ${quantidadeBaixar} un`);
            }

            if (quantidadeRestante > 0) {
                console.warn(`⚠️ Baixa parcial: faltou ${quantidadeRestante} un`);
            }

            return {
                sucesso: true,
                lotesAtualizados,
                quantidadeNaoBaixada: quantidadeRestante
            };
        } catch (erro) {
            console.error('Erro ao dar baixa no lote:', erro);
            throw erro;
        }
    }

    /**
     * Adicionar novo lote de produto
     * @param {Object} dadosLote - { produto_id, numero_lote, quantidade_inicial, data_fabricacao, data_vencimento }
     */
    async adicionarLote(dadosLote) {
        try {
            const { data: lote, error } = await supabase
                .from('produto_lotes')
                .insert({
                    produto_id: dadosLote.produto_id,
                    numero_lote: dadosLote.numero_lote,
                    quantidade_inicial: dadosLote.quantidade_inicial,
                    quantidade_atual: dadosLote.quantidade_inicial,
                    data_fabricacao: dadosLote.data_fabricacao,
                    data_vencimento: dadosLote.data_vencimento,
                    created_at: new Date().toISOString()
                })
                .select()
                .single();

            if (error) throw error;

            console.log('✅ Lote adicionado:', lote);
            return lote;
        } catch (erro) {
            console.error('Erro ao adicionar lote:', erro);
            throw erro;
        }
    }

    /**
     * Formatar cor do badge de urgência
     */
    obterCorUrgencia(urgencia) {
        const cores = {
            vencido: '#dc3545',   // Vermelho
            critico: '#fd7e14',   // Laranja
            alerta: '#ffc107',    // Amarelo
            normal: '#28a745'     // Verde
        };
        return cores[urgencia] || '#6c757d';
    }

    /**
     * Formatar texto do badge de urgência
     */
    obterTextoUrgencia(urgencia, diasRestantes) {
        if (urgencia === 'vencido') {
            return `VENCIDO (${Math.abs(diasRestantes)} dias)`;
        } else if (urgencia === 'critico') {
            return `CRÍTICO (${diasRestantes} dias)`;
        } else if (urgencia === 'alerta') {
            return `${diasRestantes} dias`;
        } else {
            return `${diasRestantes} dias`;
        }
    }
}

// Exportar instância única
const ServicoVencimentoService = new ServicoVencimento();

// Para ambientes que não suportam ES6 modules
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { ServicoVencimentoService };
}
