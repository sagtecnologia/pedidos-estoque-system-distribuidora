// =====================================================
// SERVIÇO DE PRODUTOS
// =====================================================

// Listar produtos
async function listProdutos(filters = {}) {
    try {
        let query = supabase
            .from('produtos')
            .select('*')
            .eq('active', true)
            .order('nome');

        if (filters.categoria) {
            query = query.eq('categoria', filters.categoria);
        }

        if (filters.search) {
            query = query.or(`nome.ilike.%${filters.search}%,codigo.ilike.%${filters.search}%`);
        }

        const { data, error } = await query;

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao listar produtos');
        return [];
    }
}

// Buscar produto por ID
async function getProduto(id) {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('*')
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar produto');
        return null;
    }
}

// Criar produto
async function createProduto(produto) {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();
        
        const { data, error } = await supabase
            .from('produtos')
            .insert([{
                ...produto,
                created_by: user.id
            }])
            .select()
            .single();

        if (error) throw error;

        showToast('Produto criado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao criar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Atualizar produto
async function updateProduto(id, produto) {
    try {
        showLoading(true);

        const { data, error } = await supabase
            .from('produtos')
            .update(produto)
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        showToast('Produto atualizado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao atualizar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Deletar produto (soft delete)
async function deleteProduto(id) {
    try {
        if (!await confirmAction('Deseja realmente excluir este produto?')) {
            return false;
        }

        showLoading(true);

        const { error } = await supabase
            .from('produtos')
            .update({ active: false })
            .eq('id', id);

        if (error) throw error;

        showToast('Produto excluído com sucesso!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao excluir produto');
        return false;
    } finally {
        showLoading(false);
    }
}

// Listar produtos com estoque baixo
async function getProdutosEstoqueBaixo() {
    try {
        // Usar rpc ou filtrar no cliente, pois Supabase não permite comparar colunas diretamente
        const { data, error } = await supabase
            .from('produtos')
            .select('*')
            .eq('active', true)
            .order('estoque_atual');

        if (error) throw error;
        
        // Filtrar no cliente produtos onde estoque_atual <= estoque_minimo
        return data.filter(p => p.estoque_atual <= p.estoque_minimo);
        
    } catch (error) {
        handleError(error, 'Erro ao buscar produtos com estoque baixo');
        return [];
    }
}

// Listar categorias
async function getCategorias() {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('categoria')
            .eq('active', true)
            .not('categoria', 'is', null);

        if (error) throw error;

        // Remover duplicatas
        const categorias = [...new Set(data.map(p => p.categoria))];
        return categorias.sort();
        
    } catch (error) {
        handleError(error, 'Erro ao buscar categorias');
        return [];
    }
}

// =====================================================
// FUNÇÕES DE GERAÇÃO DE CÓDIGO
// =====================================================

// Gerar código automático do produto
async function generateProductCode(marca) {
    try {
        // Buscar último código da marca
        const prefixo = marca ? marca.substring(0, 3).toUpperCase() : 'PRD';
        
        const { data, error } = await supabase
            .from('produtos')
            .select('codigo')
            .like('codigo', `${prefixo}-%`)
            .order('codigo', { ascending: false })
            .limit(1);

        if (error) throw error;

        let nextNumber = 1;
        
        if (data && data.length > 0) {
            // Extrair número do último código (formato: XXX-0001)
            const lastCode = data[0].codigo;
            const match = lastCode.match(/-(\d+)$/);
            if (match) {
                nextNumber = parseInt(match[1]) + 1;
            }
        }

        // Formatar com 4 dígitos: IGN-0001, IGN-0002, etc.
        const codigo = `${prefixo}-${String(nextNumber).padStart(4, '0')}`;
        return codigo;
        
    } catch (error) {
        console.error('Erro ao gerar código:', error);
        // Fallback: usar timestamp
        return `PRD-${Date.now()}`;
    }
}

// =====================================================
// FUNÇÕES DE SABORES
// =====================================================

// Buscar sabores de um produto
async function getSaboresProduto(produtoId) {
    try {
        const { data, error } = await supabase
            .from('produto_sabores')
            .select('*')
            .eq('produto_id', produtoId)
            .eq('ativo', true)
            .order('sabor');

        if (error) throw error;
        return data || [];
        
    } catch (error) {
        handleError(error, 'Erro ao buscar sabores');
        return [];
    }
}

// Criar produto com sabores
async function createProdutoComSabores(produto, sabores) {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();
        
        // Gerar código automático baseado na marca
        const codigo = await generateProductCode(produto.marca);
        
        // 1. Criar produto
        const { data: produtoData, error: produtoError } = await supabase
            .from('produtos')
            .insert([{
                ...produto,
                codigo: codigo, // Código gerado automaticamente
                estoque_atual: 0, // Será calculado automaticamente pelo trigger
                created_by: user.id
            }])
            .select()
            .single();

        if (produtoError) throw produtoError;

        // 2. Criar sabores
        if (sabores && sabores.length > 0) {
            const saboresInsert = sabores.map(s => ({
                produto_id: produtoData.id,
                sabor: s.sabor,
                quantidade: s.quantidade || 0,
                ativo: true
            }));

            const { error: saboresError } = await supabase
                .from('produto_sabores')
                .insert(saboresInsert);

            if (saboresError) throw saboresError;
        }

        showToast('Produto criado com sucesso!', 'success');
        return produtoData;
        
    } catch (error) {
        handleError(error, 'Erro ao criar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Atualizar produto com sabores
async function updateProdutoComSabores(id, produto, sabores) {
    try {
        showLoading(true);

        // 1. Atualizar produto
        const { data: produtoData, error: produtoError } = await supabase
            .from('produtos')
            .update(produto)
            .eq('id', id)
            .select()
            .single();

        if (produtoError) throw produtoError;

        // 2. Buscar sabores existentes
        const saboresExistentes = await getSaboresProduto(id);
        const idsExistentes = saboresExistentes.map(s => s.id);
        const idsRecebidos = sabores.filter(s => s.id).map(s => s.id);

        // 3. Desativar sabores removidos
        const idsRemovidos = idsExistentes.filter(id => !idsRecebidos.includes(id));
        if (idsRemovidos.length > 0) {
            const { error: deleteError } = await supabase
                .from('produto_sabores')
                .update({ ativo: false })
                .in('id', idsRemovidos);

            if (deleteError) throw deleteError;
        }

        // 4. Atualizar e inserir sabores
        for (const sabor of sabores) {
            if (sabor.id) {
                // Atualizar existente
                const { error: updateError } = await supabase
                    .from('produto_sabores')
                    .update({
                        sabor: sabor.sabor,
                        quantidade: sabor.quantidade || 0
                    })
                    .eq('id', sabor.id);

                if (updateError) throw updateError;
            } else {
                // Inserir novo
                const { error: insertError } = await supabase
                    .from('produto_sabores')
                    .insert([{
                        produto_id: id,
                        sabor: sabor.sabor,
                        quantidade: sabor.quantidade || 0,
                        ativo: true
                    }]);

                if (insertError) throw insertError;
            }
        }

        showToast('Produto atualizado com sucesso!', 'success');
        return produtoData;
        
    } catch (error) {
        handleError(error, 'Erro ao atualizar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Listar marcas
async function getMarcas() {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('marca')
            .eq('active', true)
            .not('marca', 'is', null);

        if (error) throw error;

        // Remover duplicatas
        const marcas = [...new Set(data.map(p => p.marca))];
        return marcas.sort();
        
    } catch (error) {
        handleError(error, 'Erro ao buscar marcas');
        return [];
    }
}

// Listar produtos por marca
async function getProdutosPorMarca(marca) {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('*')
            .eq('marca', marca)
            .eq('active', true)
            .order('nome');

        if (error) throw error;
        return data || [];
        
    } catch (error) {
        handleError(error, 'Erro ao buscar produtos');
        return [];
    }
}
