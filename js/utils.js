// =====================================================
// FUNÇÕES UTILITÁRIAS
// =====================================================

// Mostrar mensagem toast
function showToast(message, type = 'info') {
    const toast = document.createElement('div');
    toast.className = `fixed top-4 right-4 px-6 py-3 rounded-lg shadow-lg text-white z-50 animate-fade-in ${
        type === 'success' ? 'bg-green-500' :
        type === 'error' ? 'bg-red-500' :
        type === 'warning' ? 'bg-yellow-500' :
        'bg-blue-500'
    }`;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.classList.add('animate-fade-out');
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// Mostrar loading
function showLoading(show = true) {
    const loadingEl = document.getElementById('loading');
    if (loadingEl) {
        loadingEl.classList.toggle('hidden', !show);
    }
}

// Formatar moeda
function formatCurrency(value) {
    return new Intl.NumberFormat('pt-BR', {
        style: 'currency',
        currency: 'BRL'
    }).format(value);
}

// Formatar data
function formatDate(date) {
    return new Intl.DateTimeFormat('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric'
    }).format(new Date(date));
}

// Formatar data e hora
function formatDateTime(date) {
    return new Intl.DateTimeFormat('pt-BR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    }).format(new Date(date));
}

// Formatar CNPJ
function formatCNPJ(cnpj) {
    return cnpj.replace(/^(\d{2})(\d{3})(\d{3})(\d{4})(\d{2})/, '$1.$2.$3/$4-$5');
}

// Validar email
function validateEmail(email) {
    const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return re.test(email);
}

// Validar CNPJ
function validateCNPJ(cnpj) {
    cnpj = cnpj.replace(/[^\d]/g, '');
    return cnpj.length === 14;
}

// Gerar número de pedido
function generateOrderNumber(tipo = 'COMPRA') {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
    const prefix = tipo === 'VENDA' ? 'VND' : 'PED';
    return `${prefix}${year}${month}${day}${random}`;
}

// Gerar link WhatsApp
function generateWhatsAppLink(phone, message) {
    const cleanPhone = phone.replace(/\D/g, '');
    const encodedMessage = encodeURIComponent(message);
    return `https://wa.me/${cleanPhone}?text=${encodedMessage}`;
}

// Confirmar ação
async function confirmAction(message) {
    return confirm(message);
}

// Obter parâmetro da URL
function getUrlParameter(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
}

// Redirecionar
function redirect(url) {
    window.location.href = url;
}

// Verificar se está autenticado
async function checkAuth() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) {
        redirect('/index.html');
        return null;
    }

    // Verificar se o usuário está ativo na tabela users
    const { data: userData, error } = await supabase
        .from('users')
        .select('active')
        .eq('id', session.user.id)
        .single();

    if (error) {
        console.error('Erro ao verificar status do usuário:', error);
        await supabase.auth.signOut();
        redirect('/index.html');
        return null;
    }

    // Se o usuário não estiver ativo, fazer logout e redirecionar
    if (!userData.active) {
        await supabase.auth.signOut();
        showToast('⏳ Sua conta está aguardando aprovação do administrador. Você será notificado quando for aprovada.', 'warning', 6000);
        setTimeout(() => {
            redirect('/index.html');
        }, 2000);
        return null;
    }

    return session;
}

// Obter usuário atual
async function getCurrentUser() {
    const { data: { session } } = await supabase.auth.getSession();
    if (!session) return null;

    const { data: user, error } = await supabase
        .from('users')
        .select('*')
        .eq('id', session.user.id)
        .single();

    if (error) {
        console.error('Erro ao buscar usuário:', error);
        return null;
    }

    return user;
}

// Verificar permissão
async function hasRole(roles) {
    const user = await getCurrentUser();
    if (!user) return false;
    
    if (Array.isArray(roles)) {
        return roles.includes(user.role);
    }
    return user.role === roles;
}

// Obter badge de status
function getStatusBadge(status) {
    const badges = {
        'RASCUNHO': '<span class="px-2 py-1 text-xs rounded-full bg-gray-200 text-gray-800">Rascunho</span>',
        'ENVIADO': '<span class="px-2 py-1 text-xs rounded-full bg-blue-200 text-blue-800">Enviado</span>',
        'APROVADO': '<span class="px-2 py-1 text-xs rounded-full bg-green-200 text-green-800">Aprovado</span>',
        'REJEITADO': '<span class="px-2 py-1 text-xs rounded-full bg-red-200 text-red-800">Rejeitado</span>',
        'FINALIZADO': '<span class="px-2 py-1 text-xs rounded-full bg-purple-200 text-purple-800">Finalizado</span>'
    };
    return badges[status] || status;
}

// Debounce para search
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// Download CSV
function downloadCSV(data, filename) {
    const csv = convertToCSV(data);
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
}

function convertToCSV(data) {
    if (data.length === 0) return '';
    
    const headers = Object.keys(data[0]);
    const csvRows = [];
    
    csvRows.push(headers.join(','));
    
    for (const row of data) {
        const values = headers.map(header => {
            const escaped = ('' + row[header]).replace(/"/g, '\\"');
            return `"${escaped}"`;
        });
        csvRows.push(values.join(','));
    }
    
    return csvRows.join('\n');
}

// Handle de erros
function handleError(error, customMessage = 'Ocorreu um erro') {
    console.error('Error:', error);
    
    // Traduzir erros comuns para português
    let errorMessage = error.message || error;
    
    // Email duplicado
    if (errorMessage.includes('duplicate key value violates unique constraint "users_email_key"') ||
        errorMessage.includes('users_email_key') ||
        errorMessage.includes('duplicate key')) {
        showToast('Este email já está cadastrado no sistema. Use outro email ou faça login.', 'error');
        return;
    }
    
    // Email já registrado (Supabase auth)
    if (errorMessage.includes('User already registered') || 
        errorMessage.includes('already registered')) {
        showToast('Este email já está cadastrado. Faça login ou use a opção "Esqueci minha senha".', 'error');
        return;
    }
    
    // Email inválido
    if (errorMessage.includes('Invalid email') || 
        errorMessage.includes('invalid email')) {
        showToast('Email inválido. Verifique o formato do email.', 'error');
        return;
    }
    
    // Senha fraca
    if (errorMessage.includes('Password should be at least') ||
        errorMessage.includes('password')) {
        showToast('Senha muito fraca. Use no mínimo 6 caracteres.', 'error');
        return;
    }
    
    // Credenciais inválidas
    if (errorMessage.includes('Invalid login credentials') ||
        errorMessage.includes('invalid credentials')) {
        showToast('Email ou senha incorretos. Verifique suas credenciais.', 'error');
        return;
    }
    
    // Email não confirmado
    if (errorMessage.includes('Email not confirmed') ||
        errorMessage.includes('not confirmed')) {
        showToast('Email não confirmado. Verifique sua caixa de entrada e clique no link de confirmação.', 'error');
        return;
    }
    
    // Usuário não encontrado
    if (errorMessage.includes('User not found')) {
        showToast('Usuário não encontrado. Verifique o email digitado.', 'error');
        return;
    }
    
    // RLS policy violation
    if (errorMessage.includes('new row violates row-level security policy') ||
        errorMessage.includes('row-level security')) {
        showToast('Você não tem permissão para realizar esta ação.', 'error');
        return;
    }
    
    // Foreign key violation
    if (errorMessage.includes('violates foreign key constraint')) {
        showToast('Não é possível excluir este registro pois está sendo usado em outro lugar.', 'error');
        return;
    }
    
    // Network error
    if (errorMessage.includes('Failed to fetch') ||
        errorMessage.includes('NetworkError')) {
        showToast('Erro de conexão. Verifique sua internet e tente novamente.', 'error');
        return;
    }
    
    // Mensagem padrão com tradução
    showToast(customMessage + ': ' + errorMessage, 'error');
}

// =====================================================
// CONFIGURAÇÕES DA EMPRESA (para uso global)
// =====================================================

/**
 * Buscar configurações da empresa (função global)
 */
async function getEmpresaConfig() {
    try {
        const { data, error } = await supabase
            .from('empresa_config')
            .select('*')
            .limit(1);

        if (error) throw error;
        return data && data.length > 0 ? data[0] : null;
    } catch (error) {
        console.error('Erro ao buscar configurações da empresa:', error);
        return null;
    }
}

// =====================================================
// MÁSCARAS DE FORMATAÇÃO
// =====================================================

// Aplicar máscara de CPF: 000.000.000-00
function maskCPF(value) {
    value = value.replace(/\D/g, '');
    value = value.replace(/(\d{3})(\d)/, '$1.$2');
    value = value.replace(/(\d{3})(\d)/, '$1.$2');
    value = value.replace(/(\d{3})(\d{1,2})$/, '$1-$2');
    return value.substring(0, 14);
}

// Aplicar máscara de CNPJ: 00.000.000/0000-00
function maskCNPJ(value) {
    value = value.replace(/\D/g, '');
    value = value.replace(/^(\d{2})(\d)/, '$1.$2');
    value = value.replace(/^(\d{2})\.(\d{3})(\d)/, '$1.$2.$3');
    value = value.replace(/\.(\d{3})(\d)/, '.$1/$2');
    value = value.replace(/(\d{4})(\d)/, '$1-$2');
    return value.substring(0, 18);
}

// Aplicar máscara de CPF ou CNPJ automaticamente
function maskCPFCNPJ(value) {
    value = value.replace(/\D/g, '');
    if (value.length <= 11) {
        return maskCPF(value);
    } else {
        return maskCNPJ(value);
    }
}

// Aplicar máscara de WhatsApp: +55 (00) 00000-0000
function maskWhatsApp(value) {
    // Remove tudo que não é dígito
    value = value.replace(/\D/g, '');
    
    // Se não começar com 55, adiciona
    if (!value.startsWith('55') && value.length > 0) {
        value = '55' + value;
    }
    
    // Limita a 13 dígitos (55 + DDD + número)
    value = value.substring(0, 13);
    
    // Aplica a máscara
    if (value.length > 2) {
        value = value.replace(/^(\d{2})(\d)/g, '+$1 ($2');
    }
    if (value.length > 6) {
        value = value.replace(/(\d{2})\)(\d)/g, '$1) $2');
    }
    if (value.length > 11) {
        value = value.replace(/(\d{5})(\d)/g, '$1-$2');
    }
    
    return value;
}

// Remover máscara e retornar apenas números
function unmask(value) {
    return value ? value.replace(/\D/g, '') : '';
}

// Inicializar máscaras em um input
function applyMask(inputId, maskType) {
    const input = document.getElementById(inputId);
    if (!input) return;

    input.addEventListener('input', (e) => {
        let value = e.target.value;
        
        switch(maskType) {
            case 'cpf':
                e.target.value = maskCPF(value);
                break;
            case 'cnpj':
                e.target.value = maskCNPJ(value);
                break;
            case 'cpf-cnpj':
                e.target.value = maskCPFCNPJ(value);
                break;
            case 'whatsapp':
                e.target.value = maskWhatsApp(value);
                break;
        }
    });

    // Aplicar máscara ao carregar se já houver valor
    if (input.value) {
        const event = new Event('input', { bubbles: true });
        input.dispatchEvent(event);
    }
}
