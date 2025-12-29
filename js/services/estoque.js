// =====================================================
// SERVIÇO DE ESTOQUE
// =====================================================

// Listar movimentações
async function listMovimentacoes(filters = {}) {
    try {
        let query = supabase
            .from('estoque_movimentacoes')
            .select(`
                *,
                produto:produtos(codigo, nome, unidade),
                usuario:users(full_name),
                pedido:pedidos(numero)
            `)
            .order('created_at', { ascending: false })
            .limit(filters.limit || 100);

        if (filters.produto_id) {
            query = query.eq('produto_id', filters.produto_id);
        }

        if (filters.tipo) {
            query = query.eq('tipo', filters.tipo);
        }

        if (filters.pedido_id) {
            query = query.eq('pedido_id', filters.pedido_id);
        }

        const { data, error } = await query;

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao listar movimentações');
        return [];
    }
}

// Criar entrada de estoque
async function criarEntradaEstoque(produtoId, quantidade, observacao = '') {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();

        // Chamar função do banco
        const { data, error } = await supabase
            .rpc('processar_movimentacao_estoque', {
                p_produto_id: produtoId,
                p_tipo: 'ENTRADA',
                p_quantidade: quantidade,
                p_usuario_id: user.id,
                p_observacao: observacao
            });

        if (error) throw error;

        showToast('Entrada de estoque registrada com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao registrar entrada de estoque');
        return null;
    } finally {
        showLoading(false);
    }
}

// Criar saída manual de estoque
async function criarSaidaEstoque(produtoId, quantidade, observacao = '') {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();

        // Chamar função do banco
        const { data, error } = await supabase
            .rpc('processar_movimentacao_estoque', {
                p_produto_id: produtoId,
                p_tipo: 'SAIDA',
                p_quantidade: quantidade,
                p_usuario_id: user.id,
                p_observacao: observacao
            });

        if (error) throw error;

        showToast('Saída de estoque registrada com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao registrar saída de estoque');
        return null;
    } finally {
        showLoading(false);
    }
}

// Obter histórico de um produto
async function getHistoricoProduto(produtoId) {
    try {
        const { data, error } = await supabase
            .from('estoque_movimentacoes')
            .select(`
                *,
                usuario:users(full_name),
                pedido:pedidos(numero)
            `)
            .eq('produto_id', produtoId)
            .order('created_at', { ascending: false });

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar histórico do produto');
        return [];
    }
}

// Relatório de estoque
async function getRelatorioEstoque() {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('*')
            .eq('active', true)
            .order('nome');

        if (error) throw error;

        return data.map(p => ({
            ...p,
            status: p.estoque_atual <= p.estoque_minimo ? 'BAIXO' : 'NORMAL',
            deficit: p.estoque_minimo - p.estoque_atual
        }));
        
    } catch (error) {
        handleError(error, 'Erro ao gerar relatório de estoque');
        return [];
    }
}
