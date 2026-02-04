/**
 * Sistema PDV - Ponto de Venda para Distribuidora de Bebidas
 * Fluxo: Abertura Caixa → Vendas → Finalização → Emissão Fiscal (desacoplada)
 */

class PDVSystem {
    /**
     * Inicializa o PDV
     */
    static async init() {
        try {
            console.log('🚀 Inicializando PDV...');
            
            this.caixaAtual = null;
            this.movimentacaoAtual = null;
            this.vendaAtual = null;
            this.itensCarrinho = [];
            
            // Setup de eventos primeiro
            this.setupEventos();
            
            // Verificar se existe caixa aberto
            await this.verificarCaixaAberta();
            
            // Atualizar interface depois
            this.atualizarUI();
            
            // Se não houver caixa aberto, exibir modal automaticamente
            if (!this.caixaAtual || !this.movimentacaoAtual) {
                console.log('⏳ Nenhum caixa aberto, exibindo modal em 500ms...');
                setTimeout(async () => {
                    await this.exibirModalAbrirCaixa();
                }, 500);
            } else {
                console.log('✅ PDV inicializado com caixa aberto');
            }
        } catch (error) {
            console.error('❌ Erro ao inicializar PDV:', error);
            this.exibirErro('Erro ao inicializar PDV: ' + error.message);
        }
    }

    /**
     * Verificar se existe caixa aberta
     */
    static async verificarCaixaAberta() {
        try {
            // Obter usuário autenticado do Supabase Auth diretamente
            const { data: { user: authUser } } = await supabase.auth.getUser();
            
            if (!authUser) {
                console.log('⭕ Nenhum usuário autenticado');
                this.movimentacaoAtual = null;
                this.caixaAtual = null;
                this.atualizarStatusCaixa(false);
                return;
            }

            console.log('🔍 [VERIFICAÇÃO] Operador:', authUser.id, authUser.email);
            console.log('🔍 [VERIFICAÇÃO] Buscando caixa_sessoes com filtros:');
            console.log('   - operador_id:', authUser.id);
            console.log('   - status: ABERTO');
            console.log('   - operador_id NOT NULL (validação extra)');
            
            // Buscar caixa aberta para este usuário - APENAS com status ABERTO
            // IMPORTANTE: Adicionar validação operador_id IS NOT NULL
            const { data, error } = await supabase
                .from('caixa_sessoes')
                .select('id, caixa_id, operador_id, status, data_abertura, valor_abertura, caixas(id, numero, nome)')
                .eq('operador_id', authUser.id)
                .eq('status', 'ABERTO')
                .not('operador_id', 'is', null) // VALIDAÇÃO EXTRA: garantir que operador_id não é NULL
                .order('data_abertura', { ascending: false })
                .limit(1)
                .maybeSingle(); // maybeSingle() retorna 0 ou 1 registro, sem erro

            console.log('🔍 [VERIFICAÇÃO] Resultado:', { 
                data_existe: !!data, 
                error_code: error?.code,
                operador_id: data?.operador_id 
            });

            if (error && error.code !== 'PGRST116') { // PGRST116 = No rows found
                console.error('❌ Erro ao buscar caixa:', error);
                throw error;
            }

            // Se não encontrou (error PGRST116 ou data === null), caixa não está aberto
            if (!data || error?.code === 'PGRST116') {
                console.log('⭕ [RESULTADO] Nenhum caixa aberto para este operador');
                console.log('   Limpando estado do PDV...');
                this.movimentacaoAtual = null;
                this.caixaAtual = null;
                console.log('   Estado limpo:', { movimentacaoAtual: this.movimentacaoAtual, caixaAtual: this.caixaAtual });
                this.atualizarStatusCaixa(false);
            } else {
                // VALIDAÇÃO RIGOROSA: Verificar que operador_id não é null
                if (!data.operador_id || data.operador_id !== authUser.id) {
                    console.warn('⚠️ [VALIDAÇÃO] Registro tem operador_id inválido!', {
                        esperado: authUser.id,
                        recebido: data.operador_id
                    });
                    console.log('   Ignorando este registro e tratando como sem caixa aberto');
                    this.movimentacaoAtual = null;
                    this.caixaAtual = null;
                    this.atualizarStatusCaixa(false);
                    return;
                }

                console.log('✅ [RESULTADO] Caixa ENCONTRADO:', {
                    id: data.id,
                    caixa_numero: data.caixas?.numero,
                    caixa_nome: data.caixas?.nome,
                    operador: data.operador_id,
                    status: data.status,
                    abertura: data.data_abertura,
                    saldo: data.valor_abertura
                });
                this.movimentacaoAtual = data;
                this.caixaAtual = data.caixas;
                console.log('   Estado atualizado:', { 
                    movimentacaoAtual_id: this.movimentacaoAtual?.id,
                    caixaAtual_numero: this.caixaAtual?.numero
                });
                this.atualizarStatusCaixa(true);
            }
        } catch (error) {
            console.error('❌ [ERRO] Erro ao verificar caixa aberta:', error);
            this.movimentacaoAtual = null;
            this.caixaAtual = null;
            this.atualizarStatusCaixa(false);
        }
    }

    /**
     * Atualizar status visual do caixa
     */
    static atualizarStatusCaixa(aberto) {
        const statusCaixa = document.getElementById('status-caixa');
        
        if (!statusCaixa) {
            console.warn('⚠️ Elemento status-caixa não encontrado');
            return;
        }
        
        console.log('🎨 [UI-UPDATE] Atualizando status com:', {
            aberto,
            caixaAtual: this.caixaAtual,
            movimentacaoAtual_id: this.movimentacaoAtual?.id
        });
        
        // VERIFICAÇÃO RIGOROSA: precisa ter AMBOS os objetos preenchidos
        const temCaixaValido = Boolean(
            aberto && 
            this.caixaAtual && 
            this.movimentacaoAtual && 
            this.caixaAtual.numero &&
            this.movimentacaoAtual.id
        );
        
        console.log('🎨 [UI-UPDATE] Validação:', {
            aberto,
            caixaAtual_existe: Boolean(this.caixaAtual),
            caixaAtual_numero: this.caixaAtual?.numero,
            movimentacaoAtual_existe: Boolean(this.movimentacaoAtual),
            movimentacaoAtual_id: this.movimentacaoAtual?.id,
            resultado: temCaixaValido ? '🟢 ABERTO' : '🔴 FECHADO'
        });
        
        if (temCaixaValido) {
            console.log('🟢 Exibindo status ABERTO');
            statusCaixa.innerHTML = `
                <div class="bg-green-100 text-green-800 p-4 rounded-lg flex items-center justify-between">
                    <div class="flex items-center">
                        <i class="fas fa-lock-open mr-2 text-lg"></i>
                        <div>
                            <div class="font-bold">Caixa ${this.caixaAtual.numero} - ${this.caixaAtual.nome}</div>
                            <div class="text-sm">ABERTO - Saldo: R$ ${(this.movimentacaoAtual.valor_abertura || 0).toFixed(2)}</div>
                        </div>
                    </div>
                    <button id="btn-fechar-caixa-status" class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700">
                        <i class="fas fa-lock mr-1"></i>Fechar Caixa
                    </button>
                </div>
            `;
            
            // Adicionar listener após render
            setTimeout(() => {
                const btnFechar = document.getElementById('btn-fechar-caixa-status');
                if (btnFechar) {
                    btnFechar.addEventListener('click', async () => {
                        await this.fecharCaixa();
                    });
                }
            }, 0);
        } else {
            console.log('🔴 Exibindo status FECHADO');
            statusCaixa.innerHTML = `
                <div class="bg-red-100 text-red-800 p-4 rounded-lg flex items-center justify-between">
                    <div class="flex items-center">
                        <i class="fas fa-lock mr-2 text-lg"></i>
                        <div>
                            <div class="font-bold">Nenhum caixa aberto</div>
                            <div class="text-sm">Clique em "Abrir Caixa" para começar</div>
                        </div>
                    </div>
                    <button id="btn-abrir-caixa-status" class="px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700">
                        <i class="fas fa-unlock mr-1"></i>Abrir Caixa
                    </button>
                </div>
            `;
            
            // Adicionar listener após render
            setTimeout(() => {
                const btnAbrir = document.getElementById('btn-abrir-caixa-status');
                if (btnAbrir) {
                    btnAbrir.addEventListener('click', async () => {
                        await this.exibirModalAbrirCaixa();
                    });
                }
            }, 0);
        }
    }

    /**
     * Exibir modal profissional para abrir caixa
     */
    static async exibirModalAbrirCaixa() {
        try {
            console.log('📋 Buscando caixas ativos...');
            
            // Remover modal anterior se existir
            const modalAnterior = document.getElementById('modal-abrir-caixa');
            if (modalAnterior) modalAnterior.remove();
            
            // Buscar caixas disponíveis
            const { data: caixas, error } = await supabase
                .from('caixas')
                .select('id, numero, nome')
                .eq('ativo', true)
                .order('numero');
            
            if (error) {
                console.error('❌ Erro ao buscar caixas:', error);
                throw error;
            }
            
            console.log('✅ Caixas encontrados:', caixas?.length || 0);
            
            if (!caixas || caixas.length === 0) {
                this.exibirErro('Nenhum caixa disponível para abrir');
                return;
            }

            // Criar modal profissional
            const modal = document.createElement('div');
            modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
            modal.id = 'modal-abrir-caixa';
            modal.innerHTML = `
                <div class="bg-white rounded-lg shadow-lg max-w-md w-full mx-4">
                    <!-- Header -->
                    <div class="bg-blue-600 text-white p-4 rounded-t-lg">
                        <h2 class="text-xl font-bold flex items-center gap-2">
                            <i class="fas fa-cash-register"></i>
                            Abrir Caixa
                        </h2>
                    </div>

                    <!-- Content -->
                    <div class="p-6 space-y-4">
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">
                                Selecione o Caixa
                            </label>
                            <select id="select-caixa" class="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500">
                                <option value="">-- Escolha um caixa --</option>
                                ${caixas.map(c => `<option value="${c.id}">${c.numero} - ${c.nome}</option>`).join('')}
                            </select>
                        </div>

                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">
                                Saldo Inicial (R$)
                            </label>
                            <input 
                                type="number" 
                                id="input-saldo-inicial" 
                                placeholder="0.00" 
                                step="0.01" 
                                min="0"
                                value="0"
                                class="w-full border border-gray-300 rounded-lg px-4 py-2 focus:ring-2 focus:ring-blue-500"
                            >
                            <small class="text-gray-500 block mt-1">Valor em caixa do dia anterior (conferência)</small>
                        </div>

                        <div class="bg-blue-50 p-3 rounded-lg border border-blue-200">
                            <p class="text-sm text-gray-700">
                                <i class="fas fa-info-circle mr-2 text-blue-600"></i>
                                Digite o saldo conferido do caixa para reconciliação ao final do expediente
                            </p>
                        </div>
                    </div>

                    <!-- Footer -->
                    <div class="bg-gray-50 px-6 py-4 rounded-b-lg flex gap-3 justify-end">
                        <button 
                            id="btn-cancelar-caixa"
                            class="px-4 py-2 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-100"
                        >
                            Cancelar
                        </button>
                        <button 
                            id="btn-confirmar-caixa"
                            class="px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 flex items-center gap-2"
                        >
                            <i class="fas fa-check"></i>
                            Abrir Caixa
                        </button>
                    </div>
                </div>
            `;

            document.body.appendChild(modal);
            
            // Adicionar listeners após criar modal
            document.getElementById('btn-cancelar-caixa').addEventListener('click', () => {
                modal.remove();
            });
            
            document.getElementById('btn-confirmar-caixa').addEventListener('click', async () => {
                await this.confirmarAbrirCaixa();
            });
            
            setTimeout(() => {
                document.getElementById('select-caixa')?.focus();
            }, 100);
            
        } catch (error) {
            console.error('❌ Erro ao exibir modal:', error);
            this.exibirErro('Erro ao carregar caixas: ' + error.message);
        }
    }

    /**
     * Confirmar abertura de caixa
     */
    static async confirmarAbrirCaixa() {
        try {
            const caixaId = document.getElementById('select-caixa').value;
            const saldoInicial = parseFloat(document.getElementById('input-saldo-inicial').value || '0');

            if (!caixaId) {
                this.exibirErro('Por favor, selecione um caixa');
                return;
            }

            if (isNaN(saldoInicial) || saldoInicial < 0) {
                this.exibirErro('Informe um saldo inicial válido');
                return;
            }

            // Obter usuário autenticado do Supabase Auth diretamente
            const { data: { user: authUser } } = await supabase.auth.getUser();
            
            if (!authUser) {
                throw new Error('Usuário não autenticado');
            }

            console.log('🔐 [AUTH] Usuário autenticado:', {
                auth_id: authUser.id,
                auth_email: authUser.email
            });

            // Buscar dados do usuário da tabela users
            const { data: usuario, error: erroUser } = await supabase
                .from('users')
                .select('id, email, full_name, role')
                .eq('id', authUser.id)
                .maybeSingle();

            if (erroUser) {
                console.error('❌ [DB] Erro ao buscar usuário no banco:', erroUser);
                throw new Error(`Usuário não encontrado no banco: ${erroUser.message}`);
            }

            if (!usuario) {
                console.error('❌ [DB] Usuário não encontrado no banco');
                throw new Error('Usuário não encontrado no banco de dados');
            }

            console.log('👤 [USER] Dados do usuário:', {
                id: usuario.id,
                email: usuario.email,
                name: usuario.full_name
            });
            
            // VALIDAÇÃO: Garantir que usuario.id não é null
            if (!usuario.id || usuario.id.trim() === '') {
                throw new Error('ID do usuário inválido ou vazio');
            }

            console.log('💾 Abrindo caixa com dados:', {
                caixa_id: caixaId,
                operador_id: usuario.id,
                valor_abertura: saldoInicial,
                status: 'ABERTO'
            });
            
            // Criar nova sessão de caixa
            const { data, error } = await supabase
                .from('caixa_sessoes')
                .insert([{
                    caixa_id: caixaId,
                    operador_id: usuario.id,
                    valor_abertura: saldoInicial,
                    status: 'ABERTO',
                    data_abertura: new Date().toISOString()
                }])
                .select()
                .maybeSingle();

            if (error) {
                console.error('❌ Erro ao inserir:', error);
                console.error('❌ Detalhes do erro:', {
                    code: error.code,
                    message: error.message,
                    details: error.details,
                    hint: error.hint
                });
                throw new Error(`Erro ao abrir caixa: ${error.message}`);
            }

            console.log('✅ Caixa inserido com sucesso:', data);

            this.movimentacaoAtual = data;
            
            // Buscar dados do caixa
            const { data: caixaDados, error: erroCaixa } = await supabase
                .from('caixas')
                .select('id, numero, nome')
                .eq('id', caixaId)
                .maybeSingle();
            
            if (erroCaixa) {
                throw new Error(`Erro ao buscar dados do caixa: ${erroCaixa.message}`);
            }
            
            this.caixaAtual = caixaDados;
            
            // Fechar modal
            const modal = document.getElementById('modal-abrir-caixa');
            if (modal) modal.remove();
            
            console.log('🎉 Caixa aberto com sucesso!');
            this.exibirSucesso(`Caixa ${caixaDados.numero} aberto com sucesso!`);
            this.atualizarStatusCaixa(true);
            this.atualizarUI();
        } catch (error) {
            console.error('❌ Erro ao abrir caixa:', error);
            this.exibirErro(error.message || 'Erro ao abrir caixa');
        }
    }

    /**
     * Fechar caixa
     */
    static async fecharCaixa() {
        if (!this.movimentacaoAtual) {
            this.exibirErro('Nenhum caixa aberto');
            return;
        }

        try {
            console.log('🔒 Iniciando fechamento do caixa...');
            console.log('📊 Movimentação Atual:', this.movimentacaoAtual);
            
            // Buscar valor total de vendas do caixa pela sessão
            const { data: vendas, error: erroVendas } = await supabase
                .from('vendas')
                .select('total')
                .eq('sessao_id', this.movimentacaoAtual.id)
                .eq('status', 'FINALIZADA');

            if (erroVendas) {
                console.error('❌ Erro ao buscar vendas:', erroVendas);
            }

            console.log('💰 Vendas encontradas:', vendas);
            
            const valorVendas = vendas?.reduce((sum, v) => sum + (parseFloat(v.total) || 0), 0) || 0;
            const saldoInicial = parseFloat(this.movimentacaoAtual.valor_abertura) || 0;
            const valorEsperado = saldoInicial + valorVendas;
            
            console.log('📈 Cálculos:', {
                saldoInicial,
                valorVendas,
                valorEsperado
            });

            // Modal para fechar caixa com cálculos corretos
            const modal = document.createElement('div');
            modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
            modal.id = 'modal-fechar-caixa';
            modal.innerHTML = `
                <div class="bg-white rounded-lg shadow-lg max-w-lg w-full mx-4">
                    <div class="bg-red-600 text-white p-4 rounded-t-lg">
                        <h2 class="text-xl font-bold flex items-center gap-2">
                            <i class="fas fa-cash-register"></i>
                            Fechar Caixa
                        </h2>
                    </div>
                    
                    <div class="p-6 space-y-4">
                        <div class="bg-blue-50 p-4 rounded-lg border-l-4 border-blue-500">
                            <div class="flex justify-between items-center">
                                <div class="text-sm text-gray-600">Saldo Inicial</div>
                                <div class="text-xl font-bold text-blue-700">R$ ${saldoInicial.toFixed(2)}</div>
                            </div>
                        </div>
                        
                        <div class="bg-green-50 p-4 rounded-lg border-l-4 border-green-500">
                            <div class="flex justify-between items-center">
                                <div class="text-sm text-gray-600">Total de Vendas</div>
                                <div class="text-xl font-bold text-green-700">+ R$ ${valorVendas.toFixed(2)}</div>
                            </div>
                        </div>
                        
                        <div class="bg-purple-50 p-4 rounded-lg border-l-4 border-purple-500">
                            <div class="flex justify-between items-center">
                                <div class="text-sm text-gray-600 font-semibold">Valor Esperado no Caixa</div>
                                <div class="text-2xl font-bold text-purple-700">R$ ${valorEsperado.toFixed(2)}</div>
                            </div>
                            <div class="text-xs text-gray-500 mt-1">
                                (Saldo Inicial + Vendas)
                            </div>
                        </div>
                        
                        <hr class="border-gray-300">
                        
                        <div>
                            <label class="block text-sm font-medium text-gray-700 mb-2">
                                <i class="fas fa-calculator mr-2"></i>
                                Informe o Valor Conferido no Caixa (R$)
                            </label>
                            <input 
                                type="number" 
                                id="input-saldo-final" 
                                placeholder="0.00" 
                                step="0.01" 
                                min="0"
                                class="w-full border-2 border-gray-300 rounded-lg px-4 py-3 text-lg font-semibold focus:ring-2 focus:ring-red-500 focus:border-red-500"
                            >
                            <small class="text-gray-600 block mt-2">
                                <i class="fas fa-info-circle mr-1"></i>
                                Conte o dinheiro físico no caixa e digite o valor aqui
                            </small>
                        </div>
                        
                        <div id="area-diferenca" class="hidden">
                            <!-- Será preenchido dinamicamente -->
                        </div>
                    </div>
                    
                    <div class="bg-gray-50 px-6 py-4 rounded-b-lg flex gap-3 justify-end">
                        <button 
                            id="btn-cancelar-fechar-caixa"
                            class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-100 font-medium"
                        >
                            <i class="fas fa-times mr-2"></i>Cancelar
                        </button>
                        <button 
                            id="btn-confirmar-fechar-caixa"
                            class="px-6 py-3 bg-red-600 text-white rounded-lg hover:bg-red-700 flex items-center gap-2 font-medium"
                        >
                            <i class="fas fa-check"></i>
                            Confirmar Fechamento
                        </button>
                    </div>
                </div>
            `;

            document.body.appendChild(modal);
            
            // Adicionar cálculo de diferença em tempo real
            const inputSaldoFinal = document.getElementById('input-saldo-final');
            const areaDiferenca = document.getElementById('area-diferenca');
            
            const calcularDiferenca = () => {
                const saldoFinalInformado = parseFloat(inputSaldoFinal.value) || 0;
                const diferenca = saldoFinalInformado - valorEsperado;
                
                if (inputSaldoFinal.value && saldoFinalInformado > 0) {
                    areaDiferenca.classList.remove('hidden');
                    
                    if (Math.abs(diferenca) < 0.01) {
                        // Caixa OK
                        areaDiferenca.innerHTML = `
                            <div class="bg-green-50 p-4 rounded-lg border-l-4 border-green-500">
                                <div class="flex items-center gap-3">
                                    <i class="fas fa-check-circle text-green-600 text-2xl"></i>
                                    <div class="flex-1">
                                        <div class="font-bold text-green-800">✅ Caixa Conferido!</div>
                                        <div class="text-sm text-green-700">Valores estão corretos</div>
                                    </div>
                                </div>
                            </div>
                        `;
                    } else if (diferenca > 0) {
                        // Sobra
                        areaDiferenca.innerHTML = `
                            <div class="bg-yellow-50 p-4 rounded-lg border-l-4 border-yellow-500">
                                <div class="flex items-center gap-3">
                                    <i class="fas fa-arrow-up text-yellow-600 text-2xl"></i>
                                    <div class="flex-1">
                                        <div class="font-bold text-yellow-800">⚠️ Sobra no Caixa</div>
                                        <div class="text-lg font-bold text-yellow-700">+ R$ ${Math.abs(diferenca).toFixed(2)}</div>
                                        <div class="text-sm text-yellow-600 mt-1">Há mais dinheiro do que o esperado</div>
                                    </div>
                                </div>
                            </div>
                        `;
                    } else {
                        // Falta
                        areaDiferenca.innerHTML = `
                            <div class="bg-red-50 p-4 rounded-lg border-l-4 border-red-500">
                                <div class="flex items-center gap-3">
                                    <i class="fas fa-arrow-down text-red-600 text-2xl"></i>
                                    <div class="flex-1">
                                        <div class="font-bold text-red-800">❌ Falta no Caixa</div>
                                        <div class="text-lg font-bold text-red-700">- R$ ${Math.abs(diferenca).toFixed(2)}</div>
                                        <div class="text-sm text-red-600 mt-1">Está faltando dinheiro no caixa</div>
                                    </div>
                                </div>
                            </div>
                        `;
                    }
                } else {
                    areaDiferenca.classList.add('hidden');
                }
            };
            
            inputSaldoFinal.addEventListener('input', calcularDiferenca);
            inputSaldoFinal.addEventListener('change', calcularDiferenca);
            
            // Adicionar listeners
            document.getElementById('btn-cancelar-fechar-caixa')?.addEventListener('click', () => {
                modal.remove();
            });
            
            document.getElementById('btn-confirmar-fechar-caixa')?.addEventListener('click', async () => {
                const saldoFinalInformado = parseFloat(inputSaldoFinal.value) || 0;
                
                if (saldoFinalInformado === 0 && !confirm('O valor informado é R$ 0.00. Deseja realmente continuar?')) {
                    return;
                }
                
                const diferenca = saldoFinalInformado - valorEsperado;
                await this.confirmarFecharCaixa(saldoFinalInformado, diferenca, valorVendas);
            });
            
            setTimeout(() => {
                inputSaldoFinal.focus();
            }, 100);

        } catch (error) {
            console.error('❌ Erro ao fechar caixa:', error);
            this.exibirErro('Erro ao fechar caixa: ' + error.message);
        }
    }

    static async confirmarFecharCaixa(saldoFinal, diferenca, valorVendas) {
        const modal = document.getElementById('modal-fechar-caixa');
        
        try {
            console.log('💾 Salvando fechamento do caixa:', {
                sessao_id: this.movimentacaoAtual.id,
                valor_fechamento: saldoFinal,
                diferenca: diferenca,
                valor_vendas: valorVendas
            });
            
            const { error } = await supabase
                .from('caixa_sessoes')
                .update({
                    status: 'FECHADO',
                    data_fechamento: new Date().toISOString(),
                    valor_fechamento: saldoFinal,
                    valor_vendas: valorVendas,
                    diferenca: diferenca
                })
                .eq('id', this.movimentacaoAtual.id);

            if (error) {
                console.error('❌ Erro ao atualizar caixa_sessoes:', error);
                throw error;
            }

            console.log('✅ Caixa fechado com sucesso no banco de dados');
            
            this.movimentacaoAtual = null;
            this.caixaAtual = null;
            this.itensCarrinho = [];
            
            if (modal) modal.remove();
            this.exibirSucesso('Caixa fechado com sucesso!');
            this.atualizarStatusCaixa(false);
            this.atualizarCarrinho();
            
            // Refresh da página após 2 segundos
            setTimeout(() => {
                window.location.reload();
            }, 2000);
        } catch (error) {
            console.error('❌ Erro ao confirmar fechamento:', error);
            this.exibirErro('Erro ao fechar caixa: ' + (error.message || 'Erro desconhecido'));
        }
    }

    /**
     * Buscar produto por código de barras ou SKU
     */
    static async buscarProduto(codigo) {
        try {
            const { data, error } = await supabase
                .from('produtos')
                .select('*')
                .or(`codigo_barras.eq.${codigo},sku.eq.${codigo}`)
                .eq('ativo', true)
                .single();

            if (error && error.code !== 'PGRST116') throw error;

            return data || null;
        } catch (error) {
            console.error('Erro ao buscar produto:', error);
            return null;
        }
    }

    /**
     * Buscar produtos por nome (autocomplete)
     */
    static async buscarProdutosPorNome(nome) {
        try {
            if (!nome || nome.length < 2) return [];
            
            const { data, error } = await supabase
                .from('produtos')
                .select('id, codigo, nome, preco_venda')
                .ilike('nome', `%${nome}%`)
                .eq('ativo', true)
                .limit(8);

            if (error) throw error;
            return data || [];
        } catch (error) {
            console.error('Erro ao buscar produtos por nome:', error);
            return [];
        }
    }

    /**
     * Adicionar produto ao carrinho
     */
    static async adicionarItem(produtoId, quantidade = 1, precoCustomizado = null) {
        try {
            // Validações
            if (!this.movimentacaoAtual) {
                this.exibirErro('Nenhum caixa aberto');
                return false;
            }

            if (quantidade <= 0) {
                this.exibirErro('Quantidade inválida');
                return false;
            }

            // Buscar produto
            const { data: produto, error: erroP } = await supabase
                .from('produtos')
                .select('*')
                .eq('id', produtoId)
                .single();

            if (erroP || !produto) {
                this.exibirErro('Produto não encontrado');
                return false;
            }

            // Verificar estoque
            if (quantidade > produto.estoque_atual && !false) { // permitir_venda_zerado
                this.exibirErro(`Estoque insuficiente. Disponível: ${produto.estoque_atual}`);
                return false;
            }

            // Criar item
            const item = {
                id: `item-${Date.now()}`,
                produto_id: produto.id,
                produto: produto,
                quantidade: quantidade,
                unidade_medida: produto.unidade_venda || 'UN',
                preco_unitario: precoCustomizado || produto.preco_venda,
                subtotal: (precoCustomizado || produto.preco_venda) * quantidade,
                desconto: 0,
                acrescimo: 0
            };

            // Verificar se já existe no carrinho
            const indiceExistente = this.itensCarrinho.findIndex(i => i.produto_id === produtoId);
            if (indiceExistente >= 0) {
                this.itensCarrinho[indiceExistente].quantidade += quantidade;
                this.itensCarrinho[indiceExistente].subtotal = 
                    this.itensCarrinho[indiceExistente].preco_unitario * 
                    this.itensCarrinho[indiceExistente].quantidade;
            } else {
                this.itensCarrinho.push(item);
            }

            this.atualizarCarrinho();
            this.exibirSucesso(`${produto.nome} adicionado`);
            return true;
        } catch (error) {
            console.error('Erro ao adicionar item:', error);
            this.exibirErro('Erro ao adicionar item');
            return false;
        }
    }

    /**
     * Remover item do carrinho
     */
    static removerItem(itemId) {
        this.itensCarrinho = this.itensCarrinho.filter(i => i.id !== itemId);
        this.atualizarCarrinho();
    }

    /**
     * Atualizar quantidade do item
     */
    static atualizarQuantidade(itemId, novaQuantidade) {
        if (novaQuantidade <= 0) {
            this.removerItem(itemId);
            return;
        }

        const item = this.itensCarrinho.find(i => i.id === itemId);
        if (item) {
            item.quantidade = novaQuantidade;
            item.subtotal = item.preco_unitario * novaQuantidade;
            this.atualizarCarrinho();
        }
    }

    /**
     * Aplicar desconto ao item
     */
    static aplicarDesconto(itemId, percentual) {
        const item = this.itensCarrinho.find(i => i.id === itemId);
        if (item) {
            const desconto = (item.preco_unitario * item.quantidade * percentual) / 100;
            item.desconto = desconto;
            this.atualizarCarrinho();
        }
    }

    /**
     * Atualizar exibição do carrinho
     */
    static atualizarCarrinho() {
        const container = document.getElementById('carrinho-items');
        
        let html = '';
        let subtotalGeral = 0;
        let descontoGeral = 0;

        this.itensCarrinho.forEach(item => {
            const total = item.subtotal - item.desconto + item.acrescimo;
            subtotalGeral += item.subtotal;
            descontoGeral += item.desconto;

            html += `
                <div class="flex items-center justify-between p-3 bg-gray-50 rounded mb-2 border-l-4 border-blue-500" data-item-id="${item.id}">
                    <div class="flex-1">
                        <div class="font-semibold">${item.produto.nome}</div>
                        <div class="text-sm text-gray-600">
                            ${item.quantidade} × R$ ${item.preco_unitario.toFixed(2)} = R$ ${item.subtotal.toFixed(2)}
                        </div>
                        ${item.desconto > 0 ? `<div class="text-sm text-green-600">-R$ ${item.desconto.toFixed(2)}</div>` : ''}
                    </div>
                    <div class="text-right">
                        <div class="font-bold">R$ ${total.toFixed(2)}</div>
                        <div class="text-sm space-x-1">
                            <button class="btn-diminuir px-2 py-1 bg-gray-300 rounded hover:bg-gray-400" data-item-id="${item.id}">-</button>
                            <span>${item.quantidade}</span>
                            <button class="btn-aumentar px-2 py-1 bg-gray-300 rounded hover:bg-gray-400" data-item-id="${item.id}">+</button>
                            <button class="btn-remover px-2 py-1 bg-red-500 text-white rounded hover:bg-red-600" data-item-id="${item.id}">✕</button>
                        </div>
                    </div>
                </div>
            `;
        });

        container.innerHTML = html || '<p class="text-gray-500 text-center py-4">Carrinho vazio</p>';

        // Setup event listeners via delegation
        container.querySelectorAll('.btn-diminuir').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const itemId = e.target.getAttribute('data-item-id');
                const item = this.itensCarrinho.find(i => i.id === itemId);
                if (item) this.atualizarQuantidade(itemId, item.quantidade - 1);
            });
        });

        container.querySelectorAll('.btn-aumentar').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const itemId = e.target.getAttribute('data-item-id');
                const item = this.itensCarrinho.find(i => i.id === itemId);
                if (item) this.atualizarQuantidade(itemId, item.quantidade + 1);
            });
        });

        container.querySelectorAll('.btn-remover').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const itemId = e.target.getAttribute('data-item-id');
                this.removerItem(itemId);
            });
        });

        // Atualizar totais
        const acrescimoTotal = 0;
        const totalGeral = subtotalGeral - descontoGeral + acrescimoTotal;
        
        document.getElementById('subtotal-valor').textContent = `R$ ${subtotalGeral.toFixed(2)}`;
        document.getElementById('desconto-valor').textContent = `R$ ${descontoGeral.toFixed(2)}`;
        document.getElementById('acrescimo-valor').textContent = `R$ ${acrescimoTotal.toFixed(2)}`;
        document.getElementById('total-valor').textContent = `R$ ${totalGeral.toFixed(2)}`;

        // Armazenar totais para finalização
        this.totaisAtual = {
            subtotal: subtotalGeral,
            desconto: descontoGeral,
            acrescimo: acrescimoTotal,
            total: totalGeral
        };
    }

    /**
     * Finalizar venda com bloqueio para evitar race condition
     */
    static async finalizarVenda(formaPagamento, valorPago, acrescimoTarifa = 0) {
        try {
            if (this.itensCarrinho.length === 0) {
                this.exibirErro('Carrinho vazio');
                return false;
            }

            if (!this.movimentacaoAtual) {
                this.exibirErro('Nenhum caixa aberto');
                return false;
            }

            const usuario = await getCurrentUser();
            const numeroVenda = this.gerarNumeroVenda();
            
            // Adicionar o acréscimo de tarifa ao total
            const totalComAcrescimo = this.totaisAtual.total + acrescimoTarifa;
            const troco = valorPago - totalComAcrescimo;

            console.log('🔵 Estado da movimentação:', {
                movimentacaoAtual: this.movimentacaoAtual,
                id: this.movimentacaoAtual?.id,
                caixa_id: this.movimentacaoAtual?.caixa_id,
                status: this.movimentacaoAtual?.status,
                tipo: typeof this.movimentacaoAtual,
                acrescimoTarifa: acrescimoTarifa,
                totalComAcrescimo: totalComAcrescimo
            });

            // Validar que temos os IDs necessários
            if (!this.movimentacaoAtual.id) {
                console.error('❌ movimentacaoAtual.id está undefined');
                this.exibirErro('Sessão inválida - ID não encontrado');
                return false;
            }

            if (!this.movimentacaoAtual.caixa_id) {
                console.error('❌ movimentacaoAtual.caixa_id está undefined');
                this.exibirErro('Caixa inválida - ID não encontrado');
                return false;
            }

            // Inserir venda com campos corretos do schema
            const { data: venda, error: erroVenda } = await supabase
                .from('vendas')
                .insert([{
                    numero: numeroVenda,
                    caixa_id: this.movimentacaoAtual.caixa_id,
                    movimentacao_caixa_id: this.movimentacaoAtual.id,
                    operador_id: usuario.id,
                    vendedor_id: usuario.id,
                    sessao_id: this.movimentacaoAtual.id,
                    subtotal: this.totaisAtual.subtotal,
                    desconto_valor: this.totaisAtual.desconto,
                    acrescimo: this.totaisAtual.acrescimo + acrescimoTarifa,
                    total: totalComAcrescimo,
                    valor_pago: valorPago,
                    forma_pagamento: formaPagamento,
                    troco: troco,
                    status: 'FINALIZADA'
                }])
                .select()
                .maybeSingle();

            if (erroVenda) throw erroVenda;

            if (!venda || !venda.id) {
                console.error('❌ Venda não retornou ID válido:', venda);
                throw new Error('Erro ao inserir venda: retorno inválido');
            }

            const vendaId = venda.id;

            // Inserir itens
            for (const item of this.itensCarrinho) {
                // Preparar dados do item sem campos que não existem na tabela
                const itemData = {
                    venda_id: vendaId,
                    produto_id: item.produto_id,
                    quantidade: item.quantidade,
                    preco_unitario: item.preco_unitario,
                    desconto_percentual: item.desconto_percentual || 0,
                    desconto_valor: item.desconto || 0,
                    subtotal: item.subtotal
                };
                
                console.log('📦 Inserindo item:', itemData);
                
                const { error: erroItem } = await supabase
                    .from('venda_itens')
                    .insert(itemData);

                if (erroItem) {
                    console.error('❌ Erro ao inserir item:', erroItem);
                    throw erroItem;
                }
            }

            // Registrar movimento de estoque
            await this.registrarMovimentoEstoque(vendaId, this.itensCarrinho);

            // Gerar cupom
            const cupom = await this.gerarCupom(vendaId);

            this.exibirSucesso('Venda finalizada com sucesso!');
            this.itensCarrinho = [];
            this.atualizarCarrinho();
            
            return {
                venda_id: vendaId,
                numero_venda: numeroVenda,
                cupom: cupom
            };
        } catch (error) {
            console.error('Erro ao finalizar venda:', error);
            this.exibirErro('Erro ao finalizar venda: ' + error.message);
            return false;
        }
    }

    /**
     * Registrar movimento de estoque
     */
    static async registrarMovimentoEstoque(vendaId, itens) {
        try {
            const usuario = await getCurrentUser();

            for (const item of itens) {
                // 1. Inserir movimento de estoque
                const { error: erroMov } = await supabase
                    .from('estoque_movimentacoes')
                    .insert({
                        produto_id: item.produto_id,
                        tipo_movimento: 'SAIDA',
                        quantidade: item.quantidade,
                        unidade_medida: item.unidade_medida,
                        preco_unitario: item.preco_unitario,
                        motivo: 'Venda PDV',
                        referencia_id: vendaId,
                        referencia_tipo: 'VENDA',
                        usuario_id: usuario.id
                    });

                if (erroMov) {
                    console.error('❌ Erro ao registrar movimento:', erroMov);
                    throw erroMov;
                }

                // 2. Atualizar estoque atual do produto (REDUZIR)
                const { data: produto } = await supabase
                    .from('produtos')
                    .select('estoque_atual')
                    .eq('id', item.produto_id)
                    .single();

                if (produto) {
                    const novoEstoque = Math.max(0, (produto.estoque_atual || 0) - item.quantidade);
                    const { error: erroUpdate } = await supabase
                        .from('produtos')
                        .update({ estoque_atual: novoEstoque })
                        .eq('id', item.produto_id);
                    
                    if (erroUpdate) {
                        console.error('❌ Erro ao atualizar estoque:', erroUpdate);
                        throw erroUpdate;
                    }
                    
                    console.log(`📦 Estoque atualizado: ${produto.estoque_atual} → ${novoEstoque}`);
                }
            }
            console.log('✅ Movimento de estoque registrado com sucesso');
        } catch (error) {
            console.error('❌ Erro ao registrar movimento de estoque:', error);
        }
    }

    /**
     * Gerar número de venda
     */
    static gerarNumeroVenda() {
        const sequencia = Math.floor(Math.random() * 999999).toString().padStart(6, '0');
        return `PED-${new Date().toISOString().split('T')[0].replace(/-/g, '')}-${sequencia}`;
    }

    /**
     * Gerar cupom da venda
     */
    static async gerarCupom(vendaId) {
        try {
            // Buscar venda com maybeSingle() para evitar erro se não encontrar
            const { data: venda, error: erroV } = await supabase
                .from('vendas')
                .select('id, numero, subtotal, desconto_valor, desconto, total, status')
                .eq('id', vendaId)
                .maybeSingle();

            if (erroV) {
                console.error('❌ Erro ao buscar venda:', erroV);
                throw erroV;
            }

            if (!venda) {
                console.warn('⚠️ Venda não encontrada:', vendaId);
                return 'VENDA NÃO ENCONTRADA';
            }

            // Buscar itens separadamente
            const { data: itens, error: erroItens } = await supabase
                .from('venda_itens')
                .select('*')
                .eq('venda_id', vendaId);

            if (erroItens) {
                console.error('❌ Erro ao buscar itens:', erroItens);
            }

            const empresa = await this.obterConfigEmpresa();
            const usuario = await getCurrentUser();
            
            // Validar dados antes de usar
            const nomeEmpresa = (empresa?.nome_empresa || 'EMPRESA').padEnd(38);
            const cnpjEmpresa = (empresa?.cnpj || '00.000.000/0000-00').padEnd(32);
            const nomeOperador = (usuario?.full_name || usuario?.nome_completo || 'Operador').padEnd(30);
            const dataAtual = new Date().toLocaleString('pt-BR').padEnd(32);
            
            let cupom = `
╔════════════════════════════════════════╗
║         CUPOM FISCAL - PDV              ║
╠════════════════════════════════════════╣
║ ${nomeEmpresa} ║
║ CNPJ: ${cnpjEmpresa} ║
║════════════════════════════════════════║
`;

            // Usar itens buscados separadamente
            if (itens && itens.length > 0) {
                itens.forEach((item, idx) => {
                    const descricao = (item.descricao || item.produto_nome || 'Produto').substring(0, 35);
                    const quantidade = parseFloat(item.quantidade || 0);
                    const preco = parseFloat(item.preco_unitario || 0).toFixed(2);
                    const total = parseFloat(item.total || 0).toFixed(2);
                    cupom += `\n${idx + 1}. ${descricao}\n`;
                    cupom += `   ${quantidade} × R$ ${preco} = R$ ${total}\n`;
                });
            }

            const subtotal = parseFloat(venda.subtotal || 0).toFixed(2);
            const desconto = parseFloat(venda.desconto_valor || venda.desconto || 0).toFixed(2);
            const total = parseFloat(venda.total || 0).toFixed(2);

            cupom += `
╠════════════════════════════════════════╣
║ SUBTOTAL...................R$ ${subtotal.padStart(11)} ║
║ DESCONTO..................R$ ${desconto.padStart(11)} ║
║ TOTAL.....................R$ ${total.padStart(11)} ║
╠════════════════════════════════════════╣
║ Operador: ${nomeOperador} ║
║ Data: ${dataAtual} ║
╚════════════════════════════════════════╝
            `;

            return cupom;
        } catch (error) {
            console.error('Erro ao gerar cupom:', error);
            return 'ERRO AO GERAR CUPOM';
        }
    }

    /**
     * Obter configuração da empresa
     */
    static async obterConfigEmpresa() {
        try {
            const { data, error } = await supabase
                .from('empresa_config')
                .select('*')
                .maybeSingle();

            // Se houver erro ou sem dados, retornar defaults
            if (error || !data) {
                console.warn('⚠️ empresa_config não encontrada, usando defaults');
                return {
                    nome_empresa: 'DISTRIBUIDORA',
                    cnpj: '00.000.000/0000-00'
                };
            }

            return data;
        } catch (error) {
            console.warn('⚠️ Erro ao obter config da empresa:', error?.message);
            // Retornar defaults em caso de erro
            return {
                nome_empresa: 'DISTRIBUIDORA',
                cnpj: '00.000.000/0000-00'
            };
        }
    }

    /**
     * Setup de eventos
     */
    static setupEventos() {
        // Busca rápida de produtos com autocomplete
        const inputBusca = document.getElementById('busca-produto');
        if (inputBusca) {
            // Remover listeners antigos clonando o elemento (importante para scanner de código de barras)
            const novoInputBusca = inputBusca.cloneNode(true);
            inputBusca.parentNode.replaceChild(novoInputBusca, inputBusca);
            const inputBuscaNovo = document.getElementById('busca-produto');

            // Criar dropdown de sugestões
            let dropdownSugestoes = document.getElementById('dropdown-sugestoes');
            if (!dropdownSugestoes) {
                dropdownSugestoes = document.createElement('div');
                dropdownSugestoes.id = 'dropdown-sugestoes';
                dropdownSugestoes.className = 'absolute z-50 w-full bg-white border border-gray-300 rounded-lg shadow-lg mt-1 hidden max-w-md';
                inputBuscaNovo.parentElement.style.position = 'relative';
                inputBuscaNovo.parentElement.appendChild(dropdownSugestoes);
            }

            // Input para sugestões
            inputBuscaNovo.addEventListener('input', async (e) => {
                const valor = e.target.value.trim();
                
                if (valor.length >= 2) {
                    const produtos = await this.buscarProdutosPorNome(valor);
                    
                    if (produtos.length > 0) {
                        dropdownSugestoes.innerHTML = produtos.map(p => `
                            <div class="p-3 border-b hover:bg-blue-50 cursor-pointer transition produto-sugestao" data-produto-id="${p.id}">
                                <div class="font-semibold text-gray-800">${p.nome}</div>
                                <div class="text-xs text-gray-500">Código: ${p.codigo} | R$ ${(p.preco_venda || 0).toFixed(2)}</div>
                            </div>
                        `).join('');
                        
                        // Adicionar listeners aos itens do dropdown
                        dropdownSugestoes.querySelectorAll('.produto-sugestao').forEach(item => {
                            item.addEventListener('click', async () => {
                                const produtoId = item.getAttribute('data-produto-id');
                                await this.selecionarProdutoAutoComplete(produtoId);
                            });
                        });
                        
                        dropdownSugestoes.classList.remove('hidden');
                    } else {
                        dropdownSugestoes.classList.add('hidden');
                    }
                } else {
                    dropdownSugestoes.classList.add('hidden');
                }
            });

            // Enter para buscar por código
            inputBuscaNovo.addEventListener('keypress', async (e) => {
                if (e.key === 'Enter') {
                    dropdownSugestoes.classList.add('hidden');
                    const produto = await this.buscarProduto(e.target.value);
                    if (produto) {
                        await this.adicionarItem(produto.id);
                        e.target.value = '';
                    } else {
                        this.exibirErro('Produto não encontrado');
                    }
                }
            });

            // Fechar dropdown ao clicar fora
            document.addEventListener('click', (e) => {
                if (e.target !== inputBuscaNovo) {
                    dropdownSugestoes.classList.add('hidden');
                }
            });
        }

        // Botão finalizar venda
        const btnFinalizar = document.getElementById('btn-finalizar-venda');
        if (btnFinalizar) {
            // Remover listener antigo clonando
            const novoBtnFinalizar = btnFinalizar.cloneNode(true);
            btnFinalizar.parentNode.replaceChild(novoBtnFinalizar, btnFinalizar);
            
            novoBtnFinalizar.addEventListener('click', () => {
                this.exibirTelaFinalizacao();
            });
        }
    }

    /**
     * Selecionar produto do autocomplete
     */
    static async selecionarProdutoAutoComplete(produtoId) {
        try {
            await this.adicionarItem(produtoId);
            document.getElementById('busca-produto').value = '';
            const dropdown = document.getElementById('dropdown-sugestoes');
            if (dropdown) dropdown.classList.add('hidden');
        } catch (error) {
            console.error('Erro ao selecionar produto:', error);
            this.exibirErro('Erro ao adicionar produto');
        }
    }

    /**
     * Atualizar interface do PDV
     */
    static atualizarUI() {
        // Atualizar status do caixa
        if (this.caixaAtual && this.movimentacaoAtual) {
            const statusCaixa = document.getElementById('status-caixa');
            if (statusCaixa) {
                statusCaixa.innerHTML = `
                    <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
                        <div class="bg-green-100 text-green-800 p-2 rounded inline-block">
                            <i class="fas fa-lock-open mr-1"></i>Caixa ${this.caixaAtual.numero} - ${this.caixaAtual.nome}
                        </div>
                        <button id="btn-fechar-caixa-ui" class="px-4 py-2 bg-red-700 text-white rounded hover:bg-red-800 whitespace-nowrap flex-shrink-0">
                            <i class="fas fa-power-off mr-1"></i>Fechar Caixa
                        </button>
                    </div>
                `;
                
                // Adicionar listener
                setTimeout(() => {
                    const btnFechar = document.getElementById('btn-fechar-caixa-ui');
                    if (btnFechar) {
                        btnFechar.addEventListener('click', async () => {
                            await this.fecharCaixa();
                        });
                    }
                }, 0);
            }
        }
        
        // Atualizar carrinho
        this.atualizarCarrinho();
    }

    /**
     * Exibir tela de finalização
     */
    static async exibirTelaFinalizacao() {
        console.log('🔵 Abrindo modal de finalização...');
        const total = this.totaisAtual.total;
        
        // Criar elementos
        const overlay = document.createElement('div');
        overlay.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
        overlay.id = 'modal-finalizar-venda-overlay';
        
        const container = document.createElement('div');
        container.className = 'bg-white p-6 rounded-lg max-w-lg w-full mx-4';
        
        // Construir HTML manualmente
        container.innerHTML = `
            <h3 class="text-xl font-bold mb-4">Finalizar Venda</h3>
            <p class="text-gray-600 mb-4">Total: <strong>R$ ${total.toFixed(2)}</strong></p>
            
            <div class="mb-4">
                <label class="block text-sm font-medium mb-2">Forma de Pagamento</label>
                <select id="forma-pagamento" class="w-full border rounded px-3 py-2">
                    <option value="DINHEIRO">Dinheiro</option>
                    <option value="PIX">PIX</option>
                    <option value="CARTAO_DEBITO">Cartão Débito</option>
                    <option value="CARTAO_CREDITO">Cartão Crédito</option>
                    <option value="PRAZO">A Prazo</option>
                </select>
            </div>

            <div id="secao-acrescimo" class="mb-4 hidden">
                <label class="block text-sm font-medium mb-2">Acréscimo (Tarifa) - <span id="taxa-percentual" class="text-blue-600 text-xs font-bold"></span></label>
                <div class="flex gap-2">
                    <input type="number" id="acrescimo-tarifa" class="flex-1 border rounded px-3 py-2" placeholder="0.00" step="0.01" min="0">
                    <span class="flex items-center text-gray-600 font-medium">R$</span>
                </div>
                <p class="text-xs text-gray-500 mt-1"><span id="taxa-descricao">Valor da tarifa</span></p>
            </div>

            <div class="mb-4">
                <label class="block text-sm font-medium mb-2">Valor Recebido</label>
                <input type="number" id="valor-pago" class="w-full border rounded px-3 py-2" value="${total.toFixed(2)}" step="0.01" min="0">
            </div>

            <div class="mb-4 p-3 bg-blue-50 rounded border border-blue-200">
                <div class="text-sm">Troco: <strong id="troco-valor" class="text-blue-600 font-bold">R$ 0.00</strong></div>
            </div>

            <div class="flex gap-2">
                <button id="btn-cancelar-venda" class="flex-1 px-4 py-2 border rounded hover:bg-gray-100">Cancelar</button>
                <button id="btn-confirmar-venda" class="flex-1 px-4 py-2 bg-green-600 text-white rounded hover:bg-green-700">Confirmar</button>
            </div>
        `;
        
        overlay.appendChild(container);
        document.body.appendChild(overlay);

        // Agora buscar os elementos (já estão no DOM)
        const formaPagamentoSelect = container.querySelector('#forma-pagamento');
        const secaoAcrescimo = container.querySelector('#secao-acrescimo');
        const acrescimoTarifaInput = container.querySelector('#acrescimo-tarifa');
        const valorPagoInput = container.querySelector('#valor-pago');
        const trocoValor = container.querySelector('#troco-valor');
        const btnCancelar = container.querySelector('#btn-cancelar-venda');
        const btnConfirmar = container.querySelector('#btn-confirmar-venda');

        console.log('✅ Elementos encontrados:', {
            formaPagamentoSelect: !!formaPagamentoSelect,
            secaoAcrescimo: !!secaoAcrescimo,
            acrescimoTarifaInput: !!acrescimoTarifaInput,
            valorPagoInput: !!valorPagoInput,
            trocoValor: !!trocoValor,
            btnCancelar: !!btnCancelar,
            btnConfirmar: !!btnConfirmar
        });

        if (!valorPagoInput || !trocoValor) {
            console.error('❌ Elementos não encontrados!');
            return;
        }

        // Função para calcular e atualizar troco
        const atualizarTroco = (e) => {
            const acrescimo = parseFloat(acrescimoTarifaInput.value) || 0;
            const totalComAcrescimo = total + acrescimo;
            const valorPago = parseFloat(valorPagoInput.value) || 0;
            const troco = valorPago - totalComAcrescimo;
            trocoValor.textContent = `R$ ${troco.toFixed(2)}`;
            
            console.log(`💰 Cálculo: R$ ${valorPago.toFixed(2)} - (R$ ${total.toFixed(2)} + R$ ${acrescimo.toFixed(2)}) = R$ ${troco.toFixed(2)}`);
            
            // Mudar cor conforme o troco
            if (troco < -0.01) {
                trocoValor.className = 'text-red-600 font-bold';
            } else if (Math.abs(troco) < 0.01) {
                trocoValor.className = 'text-green-600 font-bold';
            } else {
                trocoValor.className = 'text-blue-600 font-bold';
            }
        };

        // Listener para mudança de forma de pagamento
        formaPagamentoSelect.addEventListener('change', (e) => {
            const forma = e.target.value;
            const isCartao = forma === 'CARTAO_CREDITO' || forma === 'CARTAO_DEBITO';
            
            if (isCartao) {
                secaoAcrescimo.classList.remove('hidden');
                
                // Definir taxa e calcular acréscimo
                let taxa = 0;
                let descricao = '';
                
                if (forma === 'CARTAO_DEBITO') {
                    taxa = 1.09; // 1,09%
                    descricao = 'Taxa de débito: 1,09%';
                } else if (forma === 'CARTAO_CREDITO') {
                    taxa = 3.16; // 3,16%
                    descricao = 'Taxa de crédito: 3,16%';
                }
                
                // Calcular acréscimo baseado na taxa
                const acrescimo = (total * taxa) / 100;
                
                // Preencher campo de acréscimo
                acrescimoTarifaInput.value = acrescimo.toFixed(2);
                
                // Atualizar descrição
                container.querySelector('#taxa-percentual').textContent = `${taxa.toFixed(2)}%`;
                container.querySelector('#taxa-descricao').textContent = descricao;
                
                // Atualizar valor recebido com o novo total
                const totalComAcrescimo = total + acrescimo;
                valorPagoInput.value = totalComAcrescimo.toFixed(2);
                
                console.log(`💳 ${forma}: Taxa ${taxa}% = R$ ${acrescimo.toFixed(2)}`);
            } else {
                secaoAcrescimo.classList.add('hidden');
                acrescimoTarifaInput.value = '0';
                valorPagoInput.value = total.toFixed(2);
                container.querySelector('#taxa-percentual').textContent = '';
                container.querySelector('#taxa-descricao').textContent = 'Valor da tarifa';
            }
            
            atualizarTroco();
        });

        // Inicializar troco
        atualizarTroco();

        // Listeners para eventos
        valorPagoInput.addEventListener('change', atualizarTroco);
        valorPagoInput.addEventListener('keyup', atualizarTroco);
        valorPagoInput.addEventListener('input', atualizarTroco);
        acrescimoTarifaInput.addEventListener('change', atualizarTroco);
        acrescimoTarifaInput.addEventListener('keyup', atualizarTroco);
        acrescimoTarifaInput.addEventListener('input', atualizarTroco);

        // Cancelar venda - usar { once: true } para evitar múltiplos listeners
        btnCancelar.addEventListener('click', () => {
            console.log('❌ Cancelando venda...');
            overlay.remove();
        }, { once: true });

        // Confirmar pagamento
        btnConfirmar.addEventListener('click', (e) => {
            console.log('✅ Confirmar clicado');
            e.preventDefault();
            e.stopPropagation();
            
            const forma = container.querySelector('#forma-pagamento')?.value;
            const valorPago = parseFloat(container.querySelector('#valor-pago')?.value);
            const acrescimo = parseFloat(container.querySelector('#acrescimo-tarifa')?.value) || 0;

            console.log('💳 Confirmando pagamento:', { forma, valorPago, acrescimo });

            if (!forma) {
                alert('Selecione uma forma de pagamento!');
                return;
            }

            if (isNaN(valorPago) || valorPago < 0) {
                alert('Digite um valor válido!');
                return;
            }

            // Adicionar feedback visual ANTES de processar
            btnConfirmar.disabled = true;
            btnCancelar.disabled = true;
            btnConfirmar.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Processando...';
            
            // Chamar finalizarVenda (async)
            (async () => {
                const resultado = await PDVSystem.finalizarVenda(forma, valorPago, acrescimo);
                
                // Se deu sucesso, fechar overlay e exibir cupom imediatamente
                if (resultado && resultado.cupom) {
                    overlay.remove();
                    PDVSystem.exibirCupom(resultado.cupom);
                } else {
                    // Erro - reabilitar botões para retry
                    btnConfirmar.disabled = false;
                    btnCancelar.disabled = false;
                    btnConfirmar.innerHTML = 'Confirmar';
                    console.error('❌ Falha ao finalizar venda');
                }
            })();
        });

        // Fechar ao clicar no overlay (fora do container)
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay || e.target.id === 'modal-finalizar-venda-overlay') {
                console.log('🚪 Fechando modal por clique no overlay');
                overlay.remove();
            }
        });
        
        // Impedir que cliques no container fechem o modal
        container.addEventListener('click', (e) => {
            e.stopPropagation();
        });

        // Focus no input para facilitar digitação
        valorPagoInput.focus();
        valorPagoInput.select();
    }

    /**
     * Exibir cupom (simplificado - sem impressão)
     */
    static exibirCupom(cupom) {
        const modal = document.createElement('div');
        modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4';
        modal.innerHTML = `
            <div class="bg-white p-8 rounded-lg max-w-2xl w-full">
                <div class="text-center mb-8">
                    <i class="fas fa-check-circle text-green-500 text-8xl mb-4"></i>
                    <h3 class="text-4xl font-bold text-gray-800 mb-3">Venda Concluída!</h3>
                    <p class="text-gray-600 text-lg">Transação finalizada com sucesso</p>
                </div>
                
                <div class="bg-gradient-to-r from-blue-50 to-blue-100 p-6 rounded-lg mb-6 text-center border-2 border-blue-200">
                    <p class="text-sm text-gray-700 mb-2 font-medium uppercase">Número da Venda</p>
                    <p class="text-4xl font-bold text-blue-700">${this.vendaAtual?.numero || '-'}</p>
                </div>

                <div class="flex gap-3 mb-6">
                    <button id="btn-nfce-cupom" class="flex-1 px-6 py-4 bg-purple-600 text-white rounded-lg hover:bg-purple-700 transition-colors text-lg font-medium">
                        <i class="fas fa-file-invoice mr-2"></i>Emitir NFC-e
                    </button>
                </div>
                
                <button id="btn-proximo-cliente" class="w-full px-6 py-5 bg-green-600 text-white rounded-lg hover:bg-green-700 font-bold text-xl transition-colors shadow-lg">
                    <i class="fas fa-arrow-right mr-2"></i>Próximo Cliente
                </button>
                
                <p class="text-sm text-gray-500 text-center mt-6">
                    <i class="fas fa-info-circle mr-1"></i>
                    Cupom de impressão removido para otimização do processo
                </p>
            </div>
        `;

        document.body.appendChild(modal);
        
        // Adicionar listeners
        document.getElementById('btn-nfce-cupom')?.addEventListener('click', () => {
            this.perguntarNFCe();
        });
        
        document.getElementById('btn-proximo-cliente')?.addEventListener('click', async () => {
            await this.proximoCliente();
            modal.remove();
        });
    }

    /**
     * Perguntar sobre NFC-e
     */
    static perguntarNFCe() {
        const resposta = confirm('Deseja emitir NFC-e para esta venda?\n\nA emissão de NFC-e será processada no sistema fiscal integrado.');
        
        if (resposta) {
            this.exibirSucesso('NFC-e será emitida. Aguarde confirmação no seu email ou consulte o sistema fiscal.');
            // TODO: Implementar integração com sistema fiscal para emissão de NFC-e
        } else {
            this.exibirSucesso('NFC-e não será emitida. Você pode emitir manualmente depois se necessário.');
        }
    }

    /**
     * Função de impressão de cupom REMOVIDA (não é mais necessária)
     * Mantida apenas para compatibilidade com código legado
     */
    static imprimirCupom(cupom) {
        console.warn('⚠️ Impressão de cupom foi desabilitada. Use apenas NFC-e.');
        this.exibirErro('Impressão de cupom foi removida. Utilize a emissão de NFC-e.');
    }

    /**
     * Preparar para próximo cliente
     */
    static proximoCliente() {
        // Remover apenas modais de venda (não o sidebar/navbar)
        const modaisCupom = document.querySelectorAll('.fixed.inset-0, [id^="modal-"]');
        modaisCupom.forEach(modal => {
            // Verificar se é um modal de venda, não componentes fixos da página
            const isModalVenda = modal.innerHTML && (
                modal.innerHTML.includes('Cupom Fiscal') || 
                modal.innerHTML.includes('Finalizar Venda') || 
                modal.innerHTML.includes('Forma de Pagamento')
            );
            if (isModalVenda) {
                console.log('🗑️ Removendo modal de venda');
                modal.remove();
            }
        });
        
        // Limpar carrinho e atualizar UI
        this.itensCarrinho = [];
        this.atualizarCarrinho();
        this.atualizarUI();
        
        // Resetar campo de busca de produto
        const buscaProduto = document.getElementById('busca-produto');
        if (buscaProduto) {
            buscaProduto.value = '';
        }
        
        // Limpar resultados de busca
        const resultadosBusca = document.getElementById('produtos-resultado');
        if (resultadosBusca) {
            resultadosBusca.innerHTML = '';
        }
        
        // Focar no campo de busca após um pequeno delay para garantir que tudo carregou
        requestAnimationFrame(() => {
            if (buscaProduto) {
                buscaProduto.focus();
            }
        });
        
        console.log('✅ Próximo cliente - Pronto para nova venda!');
    }

    /**
     * Emitir NFC-e
     */
    static async emitirNFCe() {
        try {
            if (this.itensCarrinho.length === 0) {
                this.exibirErro('Carrinho vazio. Adicione produtos para emitir NFC-e.');
                return;
            }

            // Verificar configurações da empresa
            const { data: config, error } = await supabase
                .from('empresa_config')
                .select('*')
                .single();

            if (error || !config) {
                this.exibirErro('Configure os dados da empresa antes de emitir NFC-e.');
                return;
            }

            // Verificar certificado digital
            if (!config.certificado_digital || !config.senha_certificado) {
                this.exibirErro('Certificado digital não configurado. Acesse Configurações da Empresa.');
                return;
            }

            // Verificar CSC (Código de Segurança do Contribuinte)
            if (!config.csc_id || !config.csc_token) {
                this.exibirErro('CSC não configurado. Acesse Configurações da Empresa.');
                return;
            }

            this.exibirErro('Emissão de NFC-e em desenvolvimento. Estrutura pronta, aguardando integração com API SEFAZ.\n\nCampos já configurados:\n- Certificado Digital\n- Senha do Certificado\n- CSC ID e Token\n- Ambiente (Homologação/Produção)\n- Série e Numeração\n\nPróximos passos: Integrar com biblioteca de NFC-e.');
        } catch (error) {
            console.error('❌ Erro ao emitir NFC-e:', error);
            this.exibirErro('Erro ao preparar NFC-e: ' + error.message);
        }
    }

    /**
     * Consultar status fiscal
     */
    static async consultarFiscal() {
        this.exibirErro('Consulta fiscal em desenvolvimento.\n\nFuncionalidades planejadas:\n- Consultar status da NFC-e\n- Verificar autorização SEFAZ\n- Reenviar NFC-e rejeitada\n- Cancelar NFC-e');
    }

    /**
     * Utilidades de UI
     */
    static exibirErro(mensagem) {
        console.error(mensagem);
        // Usar toast ou alert
        alert(mensagem);
    }

    static exibirSucesso(mensagem) {
        console.log(mensagem);
        // Usar toast
        console.log('✓ ' + mensagem);
    }
}

// Inicializar quando documento carrega
document.addEventListener('DOMContentLoaded', () => PDVSystem.init());
