// =====================================================
// SERVIÇO DE CLIENTES
// =====================================================

// Listar todos os clientes ativos
async function getClientes() {
    try {
        const { data, error } = await supabase
            .from('clientes')
            .select('*')
            .eq('active', true)
            .order('nome');

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar clientes');
        return [];
    }
}

// Buscar cliente por ID
async function getClienteById(id) {
    try {
        const { data, error } = await supabase
            .from('clientes')
            .select('*')
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar cliente');
        return null;
    }
}

// Criar novo cliente
async function createCliente(clienteData) {
    try {
        const user = await getCurrentUser();
        
        const { data, error } = await supabase
            .from('clientes')
            .insert([{
                ...clienteData,
                created_by: user.id
            }])
            .select()
            .single();

        if (error) throw error;
        
        showToast('Cliente cadastrado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao cadastrar cliente');
        return null;
    }
}

// Atualizar cliente
async function updateCliente(id, clienteData) {
    try {
        const { data, error } = await supabase
            .from('clientes')
            .update(clienteData)
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;
        
        showToast('Cliente atualizado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao atualizar cliente');
        return null;
    }
}

// Desativar cliente (soft delete)
async function deleteCliente(id) {
    try {
        const { error } = await supabase
            .from('clientes')
            .update({ active: false })
            .eq('id', id);

        if (error) throw error;
        
        showToast('Cliente removido com sucesso!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao remover cliente');
        return false;
    }
}

// Buscar clientes por nome (para autocomplete)
async function searchClientes(termo) {
    try {
        const { data, error } = await supabase
            .from('clientes')
            .select('*')
            .eq('active', true)
            .or(`nome.ilike.%${termo}%,cpf_cnpj.ilike.%${termo}%`)
            .order('nome')
            .limit(10);

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar clientes');
        return [];
    }
}

// Validar CPF
function validarCPF(cpf) {
    cpf = cpf.replace(/[^\d]/g, '');
    
    if (cpf.length !== 11) return false;
    if (/^(\d)\1{10}$/.test(cpf)) return false;
    
    let soma = 0;
    let resto;
    
    for (let i = 1; i <= 9; i++) {
        soma += parseInt(cpf.substring(i-1, i)) * (11 - i);
    }
    
    resto = (soma * 10) % 11;
    if (resto === 10 || resto === 11) resto = 0;
    if (resto !== parseInt(cpf.substring(9, 10))) return false;
    
    soma = 0;
    for (let i = 1; i <= 10; i++) {
        soma += parseInt(cpf.substring(i-1, i)) * (12 - i);
    }
    
    resto = (soma * 10) % 11;
    if (resto === 10 || resto === 11) resto = 0;
    if (resto !== parseInt(cpf.substring(10, 11))) return false;
    
    return true;
}

// Validar CNPJ
function validarCNPJ(cnpj) {
    cnpj = cnpj.replace(/[^\d]/g, '');
    
    if (cnpj.length !== 14) return false;
    if (/^(\d)\1{13}$/.test(cnpj)) return false;
    
    let tamanho = cnpj.length - 2;
    let numeros = cnpj.substring(0, tamanho);
    let digitos = cnpj.substring(tamanho);
    let soma = 0;
    let pos = tamanho - 7;
    
    for (let i = tamanho; i >= 1; i--) {
        soma += numeros.charAt(tamanho - i) * pos--;
        if (pos < 2) pos = 9;
    }
    
    let resultado = soma % 11 < 2 ? 0 : 11 - soma % 11;
    if (resultado != digitos.charAt(0)) return false;
    
    tamanho = tamanho + 1;
    numeros = cnpj.substring(0, tamanho);
    soma = 0;
    pos = tamanho - 7;
    
    for (let i = tamanho; i >= 1; i--) {
        soma += numeros.charAt(tamanho - i) * pos--;
        if (pos < 2) pos = 9;
    }
    
    resultado = soma % 11 < 2 ? 0 : 11 - soma % 11;
    if (resultado != digitos.charAt(1)) return false;
    
    return true;
}

// Formatar CPF
function formatarCPF(cpf) {
    cpf = cpf.replace(/[^\d]/g, '');
    return cpf.replace(/(\d{3})(\d{3})(\d{3})(\d{2})/, '$1.$2.$3-$4');
}

// Formatar CNPJ
function formatarCNPJ(cnpj) {
    cnpj = cnpj.replace(/[^\d]/g, '');
    return cnpj.replace(/(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5');
}
