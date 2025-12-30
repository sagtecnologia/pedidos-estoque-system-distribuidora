// =====================================================
// COMPONENTE: SIDEBAR
// =====================================================

function createSidebar() {
    return `
        <aside id="sidebar" class="sidebar fixed top-16 left-0 h-full w-64 bg-gray-800 text-white z-30 overflow-y-auto">
            <nav class="mt-5 px-2">
                <a href="/pages/dashboard.html" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition mb-1">
                    <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"></path>
                    </svg>
                    Dashboard
                </a>

                <div class="mt-6">
                    <h3 class="px-4 text-xs font-semibold text-gray-400 uppercase tracking-wider">Cadastros</h3>
                    
                    <a href="/pages/produtos.html" id="menu-produtos" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition mt-1">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4"></path>
                        </svg>
                        Produtos
                    </a>

                    <a href="/pages/fornecedores.html" id="menu-fornecedores" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"></path>
                        </svg>
                        Fornecedores
                    </a>

                    <a href="/pages/clientes.html" id="menu-clientes" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z"></path>
                        </svg>
                        Clientes
                    </a>

                    <a href="/pages/usuarios.html" id="menu-usuarios" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.354a4 4 0 110 5.292M15 21H3v-1a6 6 0 0112 0v1zm0 0h6v-1a6 6 0 00-9-5.197M13 7a4 4 0 11-8 0 4 4 0 018 0z"></path>
                        </svg>
                        Usuários
                    </a>

                    <a href="/pages/aprovacao-usuarios.html" id="menu-aprovacao-usuarios" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"></path>
                        </svg>
                        Aprovações de Usuários
                    </a>

                    <a href="/pages/configuracoes-empresa.html" id="menu-config-empresa" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"></path>
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"></path>
                        </svg>
                        Configurações da Empresa
                    </a>
                </div>

                <div class="mt-6">
                    <h3 class="px-4 text-xs font-semibold text-gray-400 uppercase tracking-wider">Operações</h3>
                    
                    <a href="/pages/estoque.html" id="menu-estoque" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition mt-1">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4"></path>
                        </svg>
                        Estoque
                    </a>

                    <a href="/pages/pedidos.html" id="menu-compras" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 11V7a4 4 0 00-8 0v4M5 9h14l1 12H4L5 9z"></path>
                        </svg>
                        Pedidos de Compra
                    </a>

                    <a href="/pages/vendas.html" id="menu-vendas" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 11-4 0 2 2 0 014 0z"></path>
                        </svg>
                        Vendas
                    </a>

                    <a href="/pages/vendas-pendentes.html" id="menu-vendas-pendentes" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                        <span class="flex-1">Vendas Pendentes</span>
                        <span id="badge-pendentes" class="hidden ml-2 px-2 py-1 text-xs font-semibold rounded-full bg-orange-500 text-white"></span>
                    </a>

                    <a href="/pages/aprovacao.html" id="menu-aprovacao" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                        Aprovações
                    </a>
                    <a href="/pages/analise.html" id="menu-analise" class="sidebar-link group flex items-center px-4 py-3 text-sm font-medium rounded-md hover:bg-gray-700 transition">
                        <svg class="mr-3 h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"></path>
                        </svg>
                        Análise de Lucros
                    </a>                </div>
            </nav>
        </aside>
    `;
}

async function initSidebar() {
    // Marcar item ativo
    const currentPage = window.location.pathname;
    document.querySelectorAll('.sidebar-link').forEach(link => {
        if (link.getAttribute('href') && currentPage.includes(link.getAttribute('href'))) {
            link.classList.add('bg-gray-700');
        }
    });

    // Controle de visibilidade baseado em permissões por perfil
    const user = await getCurrentUser();
    if (user) {
        const role = user.role;

        // VENDEDOR: Só vê vendas e clientes
        if (role === 'VENDEDOR') {
            // Esconder: produtos, fornecedores, usuários, aprovações de usuários, config empresa, estoque, compras, aprovações, análise
            hideMenuItems(['menu-produtos', 'menu-fornecedores', 'menu-usuarios', 'menu-aprovacao-usuarios', 
                          'menu-config-empresa', 'menu-estoque', 'menu-compras', 'menu-aprovacao', 'menu-analise']);
        }

        // COMPRADOR: Só vê compras, estoque, produtos e fornecedores
        if (role === 'COMPRADOR') {
            // Esconder: vendas, clientes, usuários, aprovações de usuários, config empresa, aprovações, análise
            hideMenuItems(['menu-vendas', 'menu-clientes', 'menu-usuarios', 'menu-aprovacao-usuarios', 
                          'menu-config-empresa', 'menu-aprovacao', 'menu-analise']);
        }

        // APROVADOR: Só vê aprovações
        if (role === 'APROVADOR') {
            // Esconder: produtos, fornecedores, clientes, usuários, aprovações de usuários, config empresa, estoque, compras, vendas, análise
            hideMenuItems(['menu-produtos', 'menu-fornecedores', 'menu-clientes', 'menu-usuarios', 
                          'menu-aprovacao-usuarios', 'menu-config-empresa', 'menu-estoque', 
                          'menu-compras', 'menu-vendas', 'menu-analise']);
        }

        // ADMIN: Vê tudo (não esconde nada)
        // Análise de Lucros é exclusiva do ADMIN
        if (role !== 'ADMIN') {
            hideMenuItems(['menu-analise']);
        }
    }

    // Fechar sidebar ao clicar fora (mobile)
    document.addEventListener('click', (e) => {
        const sidebar = document.getElementById('sidebar');
        const sidebarToggle = document.getElementById('sidebar-toggle');
        
        if (sidebar && sidebarToggle && 
            !sidebar.contains(e.target) && 
            !sidebarToggle.contains(e.target) &&
            sidebar.classList.contains('active')) {
            sidebar.classList.remove('active');
        }
    });
}

// Função auxiliar para esconder múltiplos itens do menu
function hideMenuItems(menuIds) {
    menuIds.forEach(id => {
        const menuItem = document.getElementById(id);
        if (menuItem) {
            menuItem.style.display = 'none';
        }
    });
}
