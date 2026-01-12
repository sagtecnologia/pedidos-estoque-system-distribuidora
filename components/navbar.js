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
}
