// =====================================================
// COMPONENTE: NAVBAR
// =====================================================

function createNavbar() {
    return `
        <nav class="bg-white shadow-lg fixed top-0 left-0 right-0 z-40">
            <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                <div class="flex justify-between h-16">
                    <div class="flex items-center">
                        <button id="sidebar-toggle" class="lg:hidden mr-4 text-gray-600 hover:text-gray-900">
                            <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"></path>
                            </svg>
                        </button>
                        <div class="flex items-center space-x-3">
                            <div id="empresa-logo" class="w-10 h-10 bg-blue-600 rounded-lg flex items-center justify-center">
                                <span class="text-white font-bold text-xl">SC</span>
                            </div>
                            <div>
                                <h1 id="empresa-nome" class="text-xl font-bold text-gray-900">Sistema de Compras</h1>
                                <p class="text-xs text-gray-500">Controle de Estoque</p>
                            </div>
                        </div>
                    </div>
                    <div class="flex items-center space-x-4">
                        <!-- Indicador de Sessão -->
                        <div id="session-indicator" class="hidden sm:flex items-center space-x-2 px-3 py-1.5 bg-green-50 rounded-lg border border-green-200 cursor-pointer hover:bg-green-100 transition" title="Clique para ver detalhes da sessão">
                            <svg class="w-4 h-4 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                            </svg>
                            <span id="session-time" class="text-xs font-medium text-green-700">--:--</span>
                        </div>
                        
                        <div class="hidden sm:flex items-center space-x-2">
                            <svg class="w-5 h-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"></path>
                            </svg>
                            <span id="user-name" class="text-sm font-medium text-gray-700"></span>
                        </div>
                        <span id="user-role" class="hidden sm:block px-2 py-1 text-xs rounded-full bg-blue-100 text-blue-800"></span>
                        <button onclick="logout()" class="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-md hover:bg-red-700 transition">
                            Sair
                        </button>
                    </div>
                </div>
            </div>
        </nav>
    `;
}

async function initNavbar() {
    const user = await getCurrentUser();
    if (user) {
        const userNameEl = document.getElementById('user-name');
        const userRoleEl = document.getElementById('user-role');
        
        if (userNameEl) userNameEl.textContent = user.full_name;
        if (userRoleEl) {
            const roleLabels = {
                'ADMIN': 'Administrador',
                'COMPRADOR': 'Comprador',
                'VENDEDOR': 'Vendedor',
                'APROVADOR': 'Aprovador'
            };
            userRoleEl.textContent = roleLabels[user.role] || user.role;
        }
    }

    // Carregar logo e nome da empresa
    try {
        const empresaConfig = await getEmpresaConfig();
        if (empresaConfig) {
            // Atualizar logo se existir
            const logoEl = document.getElementById('empresa-logo');
            if (logoEl) {
                if (empresaConfig.logo_url) {
                    logoEl.innerHTML = `<img src="${empresaConfig.logo_url}" alt="Logo" class="w-full h-full object-contain rounded-lg">`;
                } else {
                    // Manter ícone padrão se não houver logo
                    logoEl.innerHTML = `<span class="text-white font-bold text-xl">SC</span>`;
                }
            }

            // Atualizar nome da empresa
            const nomeEl = document.getElementById('empresa-nome');
            if (nomeEl) {
                nomeEl.textContent = empresaConfig.nome_empresa || 'Sistema de Compras';
            }
        }
    } catch (error) {
        // Manter valores padrão em caso de erro
        console.log('Usando configurações padrão da empresa');
    }

    // Toggle sidebar em mobile
    const sidebarToggle = document.getElementById('sidebar-toggle');
    if (sidebarToggle) {
        sidebarToggle.addEventListener('click', () => {
            const sidebar = document.getElementById('sidebar');
            if (sidebar) {
                sidebar.classList.toggle('active');
            }
        });
    }

    // Inicializar indicador de sessão
    initSessionIndicator();
}

// Inicializar e atualizar o indicador de sessão
function initSessionIndicator() {
    const sessionTimeEl = document.getElementById('session-time');
    const sessionIndicator = document.getElementById('session-indicator');
    
    if (!sessionTimeEl || !sessionIndicator) return;

    // Atualizar a cada segundo
    function updateSessionIndicator() {
        if (!window.sessionManager) {
            sessionTimeEl.textContent = '--:--';
            return;
        }

        const timeUntilLogout = window.sessionManager.getTimeUntilLogout();
        const minutes = Math.floor(timeUntilLogout / 1000 / 60);
        const seconds = Math.floor((timeUntilLogout / 1000) % 60);
        
        // Formatar tempo
        sessionTimeEl.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
        
        // Mudar cor baseado no tempo restante
        if (minutes < 3) {
            // Menos de 3 minutos - vermelho
            sessionIndicator.className = 'hidden sm:flex items-center space-x-2 px-3 py-1.5 bg-red-50 rounded-lg border border-red-200 cursor-pointer hover:bg-red-100 transition animate-pulse';
            sessionTimeEl.className = 'text-xs font-medium text-red-700';
            sessionIndicator.querySelector('svg').className = 'w-4 h-4 text-red-600';
        } else if (minutes < 5) {
            // Menos de 5 minutos - amarelo
            sessionIndicator.className = 'hidden sm:flex items-center space-x-2 px-3 py-1.5 bg-yellow-50 rounded-lg border border-yellow-200 cursor-pointer hover:bg-yellow-100 transition';
            sessionTimeEl.className = 'text-xs font-medium text-yellow-700';
            sessionIndicator.querySelector('svg').className = 'w-4 h-4 text-yellow-600';
        } else {
            // Mais de 5 minutos - verde
            sessionIndicator.className = 'hidden sm:flex items-center space-x-2 px-3 py-1.5 bg-green-50 rounded-lg border border-green-200 cursor-pointer hover:bg-green-100 transition';
            sessionTimeEl.className = 'text-xs font-medium text-green-700';
            sessionIndicator.querySelector('svg').className = 'w-4 h-4 text-green-600';
        }
    }

    // Atualizar imediatamente e a cada segundo
    updateSessionIndicator();
    setInterval(updateSessionIndicator, 1000);

    // Adicionar evento de clique para mostrar detalhes
    sessionIndicator.addEventListener('click', showSessionDetails);
}

// Mostrar detalhes da sessão em um modal
function showSessionDetails() {
    if (!window.sessionManager) return;

    const info = window.sessionManager.getSessionInfo();
    
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-[9999]';
    modal.innerHTML = `
        <div class="bg-white rounded-lg shadow-2xl max-w-md w-full mx-4 p-6">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-xl font-bold text-gray-900">📊 Informações da Sessão</h3>
                <button onclick="this.closest('.fixed').remove()" class="text-gray-400 hover:text-gray-600">
                    <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
                    </svg>
                </button>
            </div>
            
            <div class="space-y-3">
                <div class="bg-blue-50 p-3 rounded-lg">
                    <p class="text-xs text-blue-600 font-semibold mb-1">⏱️ TEMPO DE SESSÃO</p>
                    <p class="text-lg font-bold text-blue-900">${window.sessionManager.formatTime(info.sessionDuration)}</p>
                </div>
                
                <div class="bg-gray-50 p-3 rounded-lg">
                    <p class="text-xs text-gray-600 font-semibold mb-1">🖱️ ÚLTIMA ATIVIDADE</p>
                    <p class="text-lg font-bold text-gray-900">${window.sessionManager.formatTime(info.timeSinceLastActivity)} atrás</p>
                </div>
                
                <div class="bg-yellow-50 p-3 rounded-lg">
                    <p class="text-xs text-yellow-600 font-semibold mb-1">⚠️ AVISO EM</p>
                    <p class="text-lg font-bold text-yellow-900">${window.sessionManager.formatTime(info.timeUntilWarning)}</p>
                </div>
                
                <div class="bg-red-50 p-3 rounded-lg">
                    <p class="text-xs text-red-600 font-semibold mb-1">🚪 LOGOUT EM</p>
                    <p class="text-lg font-bold text-red-900">${window.sessionManager.formatTime(info.timeUntilLogout)}</p>
                </div>
                
                <div class="bg-green-50 p-3 rounded-lg border-l-4 border-green-500">
                    <p class="text-xs text-green-800">
                        <strong>💡 Dica:</strong> Qualquer atividade (clique, movimento do mouse, digitação) renova automaticamente sua sessão.
                    </p>
                </div>
            </div>
            
            <div class="mt-6 flex gap-3">
                <button onclick="if(window.sessionManager) window.sessionManager.logStatus()" class="flex-1 bg-blue-600 text-white py-2 px-4 rounded-lg font-semibold hover:bg-blue-700 transition text-sm">
                    📋 Ver Logs (Console)
                </button>
                <button onclick="this.closest('.fixed').remove()" class="flex-1 bg-gray-200 text-gray-700 py-2 px-4 rounded-lg font-semibold hover:bg-gray-300 transition text-sm">
                    Fechar
                </button>
            </div>
        </div>
    `;
    
    document.body.appendChild(modal);
    
    // Fechar ao clicar fora
    modal.addEventListener('click', (e) => {
        if (e.target === modal) {
            modal.remove();
        }
    });
}
