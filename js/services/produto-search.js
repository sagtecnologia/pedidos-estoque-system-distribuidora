// =====================================================
// SERVIÇO: BUSCA DE PRODUTOS COM AUTOCOMPLETE
// =====================================================
// Busca avançada para produtos com:
// - Autocomplete em tempo real
// - Busca por código de barras
// - Busca por nome do produto
// - Suporte a scanner físico
// =====================================================

const ProdutoSearch = {
    // Estado
    debounceTimer: null,
    ultimaBusca: '',
    resultados: [],
    indiceAtivo: -1,
    onSelect: null,

    /**
     * Criar componente de busca com autocomplete
     */
    criarComponente(options = {}) {
        const {
            inputId = 'input-busca-produto',
            placeholder = 'Código de barras ou nome do produto',
            showCameraButton = true,
            maxResultados = 10
        } = options;

        return `
            <div class="relative produto-search-container">
                <!-- Input principal -->
                <div class="relative flex">
                    <input type="text" 
                           id="${inputId}"
                           class="flex-1 px-4 py-3 pr-20 text-lg border border-gray-300 rounded-l-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 barcode-input"
                           placeholder="${placeholder}"
                           autocomplete="off">
                    
                    ${showCameraButton ? `
                    <button onclick="ProdutoSearch.abrirCamera('${inputId}')" 
                            class="px-4 py-3 bg-blue-600 text-white hover:bg-blue-700 rounded-r-lg border border-blue-600">
                        <i class="fas fa-camera"></i>
                    </button>
                    ` : ''}
                </div>

                <!-- Dropdown de resultados -->
                <div id="${inputId}-dropdown" 
                     class="absolute top-full left-0 right-0 bg-white border border-gray-300 rounded-lg shadow-lg z-50 hidden max-h-80 overflow-y-auto">
                    <!-- Resultados serão inseridos aqui -->
                </div>

                <!-- Loader -->
                <div id="${inputId}-loader" 
                     class="absolute top-full left-0 right-0 bg-white border border-gray-300 rounded-lg shadow-lg z-50 hidden p-4 text-center">
                    <i class="fas fa-spinner fa-spin mr-2"></i>
                    Buscando produtos...
                </div>
            </div>
        `;
    },

    /**
     * Inicializar componente
     */
    inicializarComponente(inputId, onSelectCallback) {
        const input = document.getElementById(inputId);
        if (!input) {
            console.error(`Input ${inputId} não encontrado`);
            return;
        }

        this.onSelect = onSelectCallback;
        
        // Configurar eventos
        input.addEventListener('input', (e) => this.handleInput(e, inputId));
        input.addEventListener('keydown', (e) => this.handleKeydown(e, inputId));
        input.addEventListener('focus', (e) => this.handleFocus(e, inputId));
        input.addEventListener('blur', (e) => this.handleBlur(e, inputId));

        // Configurar scanner físico
        BarcodeScanner.iniciarLeitorFisico(async (codigo) => {
            // Se o input estiver focado, usar o código
            if (document.activeElement === input) {
                input.value = codigo;
                await this.selecionarPrimeiroProduto(inputId);
            }
        });

        console.log('✅ Produto Search inicializado para', inputId);
    },

    /**
     * Handle input change
     */
    async handleInput(event, inputId) {
        const valor = event.target.value.trim();
        
        // Limpar timeout anterior
        if (this.debounceTimer) {
            clearTimeout(this.debounceTimer);
        }

        // Se vazio, esconder dropdown
        if (!valor) {
            this.esconderDropdown(inputId);
            return;
        }

        // Busca com debounce para não sobrecarregar
        this.debounceTimer = setTimeout(async () => {
            await this.buscarProdutos(valor, inputId);
        }, 300);
    },

    /**
     * Handle keydown events
     */
    async handleKeydown(event, inputId) {
        const dropdown = document.getElementById(`${inputId}-dropdown`);
        
        if (!dropdown.classList.contains('hidden')) {
            // Navegar pelos resultados
            if (event.key === 'ArrowDown') {
                event.preventDefault();
                this.navegarDropdown(inputId, 1);
            } else if (event.key === 'ArrowUp') {
                event.preventDefault();
                this.navegarDropdown(inputId, -1);
            } else if (event.key === 'Enter') {
                event.preventDefault();
                await this.selecionarItemAtivo(inputId);
            } else if (event.key === 'Escape') {
                this.esconderDropdown(inputId);
                event.target.blur();
            }
        } else if (event.key === 'Enter') {
            // Se não há dropdown aberto, buscar produto diretamente
            event.preventDefault();
            await this.selecionarPrimeiroProduto(inputId);
        }
    },

    /**
     * Handle focus
     */
    handleFocus(event, inputId) {
        const valor = event.target.value.trim();
        if (valor && this.ultimaBusca === valor && this.resultados.length > 0) {
            this.mostrarDropdown(inputId);
        }
    },

    /**
     * Handle blur (com delay para permitir cliques no dropdown)
     */
    handleBlur(event, inputId) {
        setTimeout(() => {
            if (!document.activeElement?.closest(`#${inputId}-dropdown`)) {
                this.esconderDropdown(inputId);
            }
        }, 150);
    },

    /**
     * Buscar produtos
     */
    async buscarProdutos(termo, inputId) {
        try {
            this.mostrarLoader(inputId);
            
            // Usar busca universal do PDV
            const resultados = await PDV.buscarProdutoUniversal(termo);
            
            this.resultados = resultados;
            this.ultimaBusca = termo;
            this.indiceAtivo = -1;
            
            this.esconderLoader(inputId);
            this.renderizarResultados(inputId);
            
        } catch (error) {
            console.error('Erro na busca:', error);
            this.esconderLoader(inputId);
            this.esconderDropdown(inputId);
        }
    },

    /**
     * Renderizar resultados no dropdown
     */
    renderizarResultados(inputId) {
        const dropdown = document.getElementById(`${inputId}-dropdown`);
        
        if (!this.resultados || this.resultados.length === 0) {
            dropdown.innerHTML = `
                <div class="p-4 text-center text-gray-500">
                    <i class="fas fa-search mr-2"></i>
                    Nenhum produto encontrado
                </div>
            `;
            this.mostrarDropdown(inputId);
            return;
        }

        dropdown.innerHTML = this.resultados.map((produto, index) => `
            <div class="produto-item p-3 hover:bg-gray-50 cursor-pointer border-b border-gray-100 ${index === this.indiceAtivo ? 'bg-blue-50' : ''}"
                 data-index="${index}"
                 onclick="ProdutoSearch.selecionarProduto(${index}, '${inputId}')">
                
                <div class="flex justify-between items-start">
                    <div class="flex-1">
                        <h4 class="font-medium text-gray-900">${produto.nome}</h4>
                        <div class="text-sm text-gray-500 space-y-1">
                            ${produto.codigo ? `<p>Código: ${produto.codigo}</p>` : ''}
                            ${produto.codigo_barras ? `<p>Código de Barras: ${produto.codigo_barras}</p>` : ''}
                            <p>Unidade: ${produto.unidade} | Estoque: ${produto.estoque_atual}</p>
                        </div>
                    </div>
                    <div class="text-right ml-4">
                        <p class="text-lg font-bold text-blue-600">${this.formatarMoeda(produto.preco_venda)}</p>
                        ${produto.tipo_match ? `<span class="text-xs px-2 py-1 rounded-full ${produto.tipo_match === 'codigo' ? 'bg-green-100 text-green-600' : 'bg-blue-100 text-blue-600'}">${produto.tipo_match === 'codigo' ? 'Código' : 'Nome'}</span>` : ''}
                    </div>
                </div>
            </div>
        `).join('');

        this.mostrarDropdown(inputId);
    },

    /**
     * Navegar pelo dropdown com teclado
     */
    navegarDropdown(inputId, direcao) {
        const novoIndice = this.indiceAtivo + direcao;
        
        if (novoIndice >= 0 && novoIndice < this.resultados.length) {
            this.indiceAtivo = novoIndice;
            this.atualizarSelecaoVisual(inputId);
        }
    },

    /**
     * Atualizar seleção visual
     */
    atualizarSelecaoVisual(inputId) {
        const dropdown = document.getElementById(`${inputId}-dropdown`);
        const itens = dropdown.querySelectorAll('.produto-item');
        
        itens.forEach((item, index) => {
            if (index === this.indiceAtivo) {
                item.classList.add('bg-blue-50');
                item.scrollIntoView({ block: 'nearest' });
            } else {
                item.classList.remove('bg-blue-50');
            }
        });
    },

    /**
     * Selecionar produto por índice
     */
    async selecionarProduto(index, inputId) {
        if (this.resultados[index]) {
            await this.executarSelecao(this.resultados[index], inputId);
        }
    },

    /**
     * Selecionar item ativo
     */
    async selecionarItemAtivo(inputId) {
        if (this.indiceAtivo >= 0 && this.resultados[this.indiceAtivo]) {
            await this.executarSelecao(this.resultados[this.indiceAtivo], inputId);
        } else if (this.resultados.length > 0) {
            await this.executarSelecao(this.resultados[0], inputId);
        }
    },

    /**
     * Selecionar primeiro produto (para enter direto)
     */
    async selecionarPrimeiroProduto(inputId) {
        const input = document.getElementById(inputId);
        const valor = input.value.trim();
        
        if (!valor) return;

        // Se já temos resultados para este valor, usar o primeiro
        if (this.ultimaBusca === valor && this.resultados.length > 0) {
            await this.executarSelecao(this.resultados[0], inputId);
            return;
        }

        // Buscar e selecionar
        await this.buscarProdutos(valor, inputId);
        if (this.resultados.length > 0) {
            await this.executarSelecao(this.resultados[0], inputId);
        }
    },

    /**
     * Executar seleção do produto
     */
    async executarSelecao(produto, inputId) {
        const input = document.getElementById(inputId);
        
        // Limpar campo
        input.value = '';
        this.esconderDropdown(inputId);
        this.resultados = [];
        this.indiceAtivo = -1;
        
        // Callback - passar o produto completo
        if (this.onSelect) {
            await this.onSelect(produto);
        }
        
        // Focar no input para próxima busca
        input.focus();
    },

    /**
     * Mostrar dropdown
     */
    mostrarDropdown(inputId) {
        const dropdown = document.getElementById(`${inputId}-dropdown`);
        dropdown.classList.remove('hidden');
    },

    /**
     * Esconder dropdown
     */
    esconderDropdown(inputId) {
        const dropdown = document.getElementById(`${inputId}-dropdown`);
        dropdown.classList.add('hidden');
        this.indiceAtivo = -1;
    },

    /**
     * Mostrar loader
     */
    mostrarLoader(inputId) {
        this.esconderDropdown(inputId);
        const loader = document.getElementById(`${inputId}-loader`);
        loader.classList.remove('hidden');
    },

    /**
     * Esconder loader
     */
    esconderLoader(inputId) {
        const loader = document.getElementById(`${inputId}-loader`);
        loader.classList.add('hidden');
    },

    /**
     * Abrir câmera para scan
     */
    async abrirCamera(inputId) {
        try {
            // Implementar abertura da câmera
            if (BarcodeScanner.verificarSuporteCamera()) {
                // Modal da câmera seria implementado aqui
                showToast('Câmera em desenvolvimento...', 'info');
            } else {
                showToast('Câmera não suportada neste dispositivo', 'error');
            }
        } catch (error) {
            console.error('Erro ao abrir câmera:', error);
            showToast('Erro ao abrir câmera', 'error');
        }
    },

    /**
     * Formatar moeda
     */
    formatarMoeda(valor) {
        return new Intl.NumberFormat('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        }).format(valor);
    },

    /**
     * Limpar busca
     */
    limpar(inputId) {
        const input = document.getElementById(inputId);
        input.value = '';
        this.esconderDropdown(inputId);
        this.resultados = [];
        this.ultimaBusca = '';
        this.indiceAtivo = -1;
    }
};

// Exportar para uso global
window.ProdutoSearch = ProdutoSearch;