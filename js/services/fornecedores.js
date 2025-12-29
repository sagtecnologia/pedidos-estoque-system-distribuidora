// =====================================================
// SERVIÇO DE FORNECEDORES
// =====================================================

// Listar fornecedores
async function listFornecedores(filters = {}) {
    try {
        let query = supabase
            .from('fornecedores')
            .select('*')
            .eq('active', true)
            .order('nome');

        if (filters.search) {
            query = query.or(`nome.ilike.%${filters.search}%,cnpj.ilike.%${filters.search}%`);
        }

        const { data, error } = await query;

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao listar fornecedores');
        return [];
    }
}

// Buscar fornecedor por ID
async function getFornecedor(id) {
    try {
        const { data, error } = await supabase
            .from('fornecedores')
            .select('*')
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar fornecedor');
        return null;
    }
}

// Criar fornecedor
async function createFornecedor(fornecedor) {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();
        
        const { data, error } = await supabase
            .from('fornecedores')
            .insert([{
                ...fornecedor,
                created_by: user.id
            }])
            .select()
            .single();

        if (error) throw error;

        showToast('Fornecedor criado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao criar fornecedor');
        return null;
    } finally {
        showLoading(false);
    }
}

// Atualizar fornecedor
async function updateFornecedor(id, fornecedor) {
    try {
        showLoading(true);

        const { data, error } = await supabase
            .from('fornecedores')
            .update(fornecedor)
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        showToast('Fornecedor atualizado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao atualizar fornecedor');
        return null;
    } finally {
        showLoading(false);
    }
}

// Deletar fornecedor (soft delete)
async function deleteFornecedor(id) {
    try {
        if (!await confirmAction('Deseja realmente excluir este fornecedor?')) {
            return false;
        }

        showLoading(true);

        const { error } = await supabase
            .from('fornecedores')
            .update({ active: false })
            .eq('id', id);

        if (error) throw error;

        showToast('Fornecedor excluído com sucesso!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao excluir fornecedor');
        return false;
    } finally {
        showLoading(false);
    }
}
