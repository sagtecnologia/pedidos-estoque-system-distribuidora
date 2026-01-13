/**
 * PRÉ-PEDIDOS SERVICE
 * Gerenciamento de pedidos públicos (sem autenticação)
 */

// =====================================================
// FUNÇÕES PÚBLICAS (SEM AUTENTICAÇÃO)
// =====================================================

/**
 * Listar produtos disponíveis publicamente
 */
async function listarProdutosPublicos(filtros = {}) {
    try {
        let query = supabase
            .from('vw_produtos_publicos')
            .select('*');
        
        // Aplicar filtros
        if (filtros.marca) {
            query = query.eq('marca', filtros.marca);
        }
        
        if (filtros.busca) {
            query = query.or(`nome.ilike.%${filtros.busca}%,descricao.ilike.%${filtros.busca}%`);
        }
        
        const { data, error } = await query.order('marca', { ascending: true })
                                            .order('nome', { ascending: true });
        
        if (error) throw error;
        return data || [];
    } catch (error) {
        console.error('Erro ao listar produtos públicos:', error);
        throw error;
    }
}

/**
 * Listar sabores disponíveis publicamente
 */
async function listarSaboresPublicos(produtoId = null) {
    try {
        let query = supabase
            .from('vw_sabores_publicos')
            .select('*');
        
        if (produtoId) {
            query = query.eq('produto_id', produtoId);
        }
        
        const { data, error } = await query.order('produto_nome', { ascending: true })
                                            .order('sabor', { ascending: true });
        
        if (error) throw error;
        return data || [];
    } catch (error) {
        console.error('Erro ao listar sabores públicos:', error);
        throw error;
    }
}

/**
 * Obter marcas disponíveis
 */
async function listarMarcasPublicas() {
    try {
        const { data, error } = await supabase
            .from('vw_produtos_publicos')
            .select('marca')
            .order('marca');
        
        if (error) throw error;
        
        // Remover duplicatas
        const marcas = [...new Set(data.map(p => p.marca))].filter(Boolean);
        return marcas;
    } catch (error) {
        console.error('Erro ao listar marcas:', error);
        throw error;
    }
}

/**
 * Criar um novo pré-pedido (público)
 */
async function criarPrePedido(dadosPedido) {
    try {
        // Validar dados obrigatórios
        if (!dadosPedido.nome || !dadosPedido.itens || dadosPedido.itens.length === 0) {
            throw new Error('Nome e itens são obrigatórios');
        }

        // Gerar token único
        const token = gerarTokenPublico();
        
        // Calcular data de expiração (24 horas)
        const dataExpiracao = new Date();
        dataExpiracao.setHours(dataExpiracao.getHours() + 24);

        // Calcular total
        const total = dadosPedido.itens.reduce((sum, item) => 
            sum + (item.quantidade * item.preco_unitario), 0
        );

        // Obter IP do usuário (melhor fazer no backend, aqui é aproximação)
        const ipOrigem = await obterIPPublico();

        // Inserir pré-pedido
        const { data: prePedido, error: errorPedido } = await supabase
            .from('pre_pedidos')
            .insert({
                nome_solicitante: dadosPedido.nome,
                email_contato: dadosPedido.email || null,
                telefone_contato: dadosPedido.telefone || null,
                observacoes: dadosPedido.observacoes || null,
                token_publico: token,
                ip_origem: ipOrigem,
                user_agent: navigator.userAgent,
                data_expiracao: dataExpiracao.toISOString(),
                total: total,
                status: 'PENDENTE'
            })
            .select()
            .single();
        
        if (errorPedido) throw errorPedido;

        // Inserir itens
        const itens = dadosPedido.itens.map(item => ({
            pre_pedido_id: prePedido.id,
            produto_id: item.produto_id,
            sabor_id: item.sabor_id || null,
            quantidade: item.quantidade,
            preco_unitario: item.preco_unitario,
            estoque_disponivel_momento: item.estoque_disponivel
        }));

        const { error: errorItens } = await supabase
            .from('pre_pedido_itens')
            .insert(itens);
        
        if (errorItens) throw errorItens;

        return {
            success: true,
            prePedido: prePedido,
            token: token
        };
    } catch (error) {
        console.error('Erro ao criar pré-pedido:', error);
        throw error;
    }
}

/**
 * Consultar pré-pedido por token
 */
async function consultarPrePedidoPorToken(token) {
    try {
        const { data, error } = await supabase
            .from('pre_pedidos')
            .select(`
                *,
                pre_pedido_itens (
                    *,
                    produto:produtos (id, nome, marca),
                    sabor:produto_sabores (id, sabor)
                )
            `)
            .eq('token_publico', token)
            .single();
        
        if (error) throw error;
        return data;
    } catch (error) {
        console.error('Erro ao consultar pré-pedido:', error);
        throw error;
    }
}

// =====================================================
// FUNÇÕES INTERNAS (COM AUTENTICAÇÃO)
// =====================================================

/**
 * Listar pré-pedidos (interno)
 */
async function listarPrePedidos(filtros = {}) {
    try {
        let query = supabase
            .from('pre_pedidos')
            .select(`
                *,
                analisado_por:users!pre_pedidos_analisado_por_fkey (full_name),
                cliente:clientes (nome),
                pre_pedido_itens (
                    id,
                    quantidade,
                    preco_unitario,
                    subtotal,
                    produto:produtos (nome, marca),
                    sabor:produto_sabores (sabor)
                )
            `);
        
        // Aplicar filtros
        if (filtros.status) {
            if (Array.isArray(filtros.status)) {
                query = query.in('status', filtros.status);
            } else {
                query = query.eq('status', filtros.status);
            }
        } else {
            // Por padrão, mostrar apenas pendentes e em análise
            query = query.in('status', ['PENDENTE', 'EM_ANALISE']);
        }
        
        if (filtros.dataInicio) {
            query = query.gte('created_at', filtros.dataInicio);
        }
        
        if (filtros.dataFim) {
            query = query.lte('created_at', filtros.dataFim);
        }
        
        const { data, error } = await query.order('created_at', { ascending: false });
        
        if (error) throw error;
        return data || [];
    } catch (error) {
        console.error('Erro ao listar pré-pedidos:', error);
        throw error;
    }
}

/**
 * Obter detalhes de um pré-pedido
 */
async function obterPrePedido(id) {
    try {
        const { data, error } = await supabase
            .from('pre_pedidos')
            .select(`
                *,
                analisado_por:users!pre_pedidos_analisado_por_fkey (full_name, email),
                cliente:clientes (id, nome, contato, whatsapp, email),
                pedido_gerado:pedidos (id, numero),
                pre_pedido_itens (
                    *,
                    produto:produtos (
                        id,
                        codigo,
                        nome,
                        marca,
                        estoque_atual,
                        preco_venda
                    ),
                    sabor:produto_sabores (
                        id,
                        sabor,
                        quantidade
                    )
                )
            `)
            .eq('id', id)
            .single();
        
        if (error) throw error;
        return data;
    } catch (error) {
        console.error('Erro ao obter pré-pedido:', error);
        throw error;
    }
}

/**
 * Atualizar status do pré-pedido
 */
async function atualizarStatusPrePedido(id, novoStatus, dadosAdicionais = {}) {
    try {
        const updateData = {
            status: novoStatus,
            ...dadosAdicionais
        };

        const { data, error } = await supabase
            .from('pre_pedidos')
            .update(updateData)
            .eq('id', id)
            .select()
            .single();
        
        if (error) throw error;
        return data;
    } catch (error) {
        console.error('Erro ao atualizar status:', error);
        throw error;
    }
}

/**
 * Marcar pré-pedido como em análise
 */
async function marcarEmAnalise(id) {
    const user = await getCurrentUser();
    return await atualizarStatusPrePedido(id, 'EM_ANALISE', {
        analisado_por: user.id,
        data_analise: new Date().toISOString()
    });
}

/**
 * Rejeitar pré-pedido
 */
async function rejeitarPrePedido(id, motivo) {
    const user = await getCurrentUser();
    return await atualizarStatusPrePedido(id, 'REJEITADO', {
        analisado_por: user.id,
        data_analise: new Date().toISOString(),
        motivo_rejeicao: motivo
    });
}

/**
 * Validar estoque dos itens do pré-pedido
 */
async function validarEstoquePrePedido(prePedidoId) {
    try {
        const prePedido = await obterPrePedido(prePedidoId);
        const validacoes = [];

        for (const item of prePedido.pre_pedido_itens) {
            let estoqueAtual = 0;
            let estoqueDisponivel = item.estoque_disponivel_momento || 0;
            let statusValidacao = 'OK';
            let mensagem = '';

            if (item.sabor_id) {
                // Produto com sabor
                const { data: sabor } = await supabase
                    .from('produto_sabores')
                    .select('quantidade')
                    .eq('id', item.sabor_id)
                    .single();
                
                estoqueAtual = sabor?.quantidade || 0;
            } else {
                // Produto sem sabor
                estoqueAtual = item.produto.estoque_atual;
            }

            if (estoqueAtual < item.quantidade) {
                statusValidacao = 'INSUFICIENTE';
                mensagem = `Estoque insuficiente. Disponível: ${estoqueAtual}, Solicitado: ${item.quantidade}`;
            } else if (estoqueAtual < estoqueDisponivel) {
                statusValidacao = 'ALERTA';
                mensagem = `Estoque diminuiu de ${estoqueDisponivel} para ${estoqueAtual}`;
            } else {
                mensagem = `Estoque OK: ${estoqueAtual} unidades disponíveis`;
            }

            validacoes.push({
                item_id: item.id,
                produto_nome: item.produto.nome,
                sabor_nome: item.sabor?.sabor || null,
                quantidade_solicitada: item.quantidade,
                estoque_momento: estoqueDisponivel,
                estoque_atual: estoqueAtual,
                status: statusValidacao,
                mensagem: mensagem
            });
        }

        const todosOk = validacoes.every(v => v.status === 'OK' || v.status === 'ALERTA');

        return {
            valido: todosOk,
            validacoes: validacoes
        };
    } catch (error) {
        console.error('Erro ao validar estoque:', error);
        throw error;
    }
}

/**
 * Gerar pedido de venda a partir do pré-pedido
 */
async function gerarPedidoVenda(prePedidoId, clienteId) {
    try {
        const user = await getCurrentUser();
        
        // 1. Buscar pré-pedido com itens
        const prePedido = await obterPrePedido(prePedidoId);
        
        if (prePedido.status !== 'PENDENTE' && prePedido.status !== 'EM_ANALISE') {
            throw new Error('Pré-pedido já foi processado');
        }

        // 2. Validar estoque
        const validacao = await validarEstoquePrePedido(prePedidoId);
        if (!validacao.valido) {
            throw new Error('Estoque insuficiente para um ou mais itens');
        }

        // 3. Gerar número do pedido (formato: VENDA-YYYYMMDD-XXXXX)
        const hoje = new Date();
        const ano = hoje.getFullYear();
        const mes = String(hoje.getMonth() + 1).padStart(2, '0');
        const dia = String(hoje.getDate()).padStart(2, '0');
        
        // Buscar último número do dia
        const { data: ultimoPedido } = await supabase
            .from('pedidos')
            .select('numero')
            .like('numero', `VENDA-${ano}${mes}${dia}-%`)
            .order('numero', { ascending: false })
            .limit(1)
            .single();
        
        let sequencial = 1;
        if (ultimoPedido && ultimoPedido.numero) {
            const partes = ultimoPedido.numero.split('-');
            sequencial = parseInt(partes[partes.length - 1]) + 1;
        }
        
        const numeroPedido = `VENDA-${ano}${mes}${dia}-${String(sequencial).padStart(5, '0')}`;

        // 4. Criar pedido de venda
        const observacoes = `Gerado a partir do pré-pedido ${prePedido.numero}\n` +
                          `Solicitante: ${prePedido.nome_solicitante}` +
                          (prePedido.email_contato ? `\nEmail: ${prePedido.email_contato}` : '') +
                          (prePedido.telefone_contato ? `\nTelefone: ${prePedido.telefone_contato}` : '') +
                          (prePedido.observacoes ? `\n\nObservações: ${prePedido.observacoes}` : '');

        const { data: pedido, error: errorPedido } = await supabase
            .from('pedidos')
            .insert({
                numero: numeroPedido,
                tipo_pedido: 'VENDA',
                solicitante_id: user.id,
                cliente_id: clienteId,
                status: 'RASCUNHO',
                observacoes: observacoes
            })
            .select()
            .single();
        
        if (errorPedido) throw errorPedido;

        // 5. Copiar itens para o pedido (incluindo sabor_id se houver)
        const itensPedido = prePedido.pre_pedido_itens.map(item => ({
            pedido_id: pedido.id,
            produto_id: item.produto_id,
            sabor_id: item.sabor_id || null,
            quantidade: item.quantidade,
            preco_unitario: item.preco_unitario
        }));

        const { error: errorItens } = await supabase
            .from('pedido_itens')
            .insert(itensPedido);
        
        if (errorItens) throw errorItens;

        // 6. Atualizar pré-pedido
        await supabase
            .from('pre_pedidos')
            .update({
                status: 'APROVADO',
                analisado_por: user.id,
                data_analise: new Date().toISOString(),
                cliente_vinculado_id: clienteId,
                pedido_gerado_id: pedido.id
            })
            .eq('id', prePedidoId);

        return {
            success: true,
            pedido: pedido,
            prePedido: prePedido
        };
    } catch (error) {
        console.error('Erro ao gerar pedido de venda:', error);
        throw error;
    }
}

/**
 * Expirar pré-pedidos antigos (24h)
 */
async function expirarPrePedidosAntigos() {
    try {
        const { data, error } = await supabase.rpc('expirar_pre_pedidos');
        
        if (error) throw error;
        return data;
    } catch (error) {
        console.error('Erro ao expirar pré-pedidos:', error);
        return 0;
    }
}

/**
 * Contar pré-pedidos pendentes
 */
async function contarPrePedidosPendentes() {
    try {
        const { count, error } = await supabase
            .from('pre_pedidos')
            .select('*', { count: 'exact', head: true })
            .in('status', ['PENDENTE', 'EM_ANALISE']);
        
        if (error) throw error;
        return count || 0;
    } catch (error) {
        console.error('Erro ao contar pendentes:', error);
        return 0;
    }
}

// =====================================================
// FUNÇÕES AUXILIARES
// =====================================================

/**
 * Gerar token público único
 */
function gerarTokenPublico() {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 15);
    const random2 = Math.random().toString(36).substring(2, 15);
    return `PRE_${timestamp}_${random}${random2}`;
}

/**
 * Obter IP público do usuário
 */
async function obterIPPublico() {
    try {
        const response = await fetch('https://api.ipify.org?format=json');
        const data = await response.json();
        return data.ip;
    } catch (error) {
        console.log('Não foi possível obter IP:', error);
        return 'desconhecido';
    }
}

/**
 * Calcular tempo restante até expiração
 */
function calcularTempoRestante(dataExpiracao) {
    const agora = new Date();
    const expiracao = new Date(dataExpiracao);
    const diferencaMs = expiracao - agora;
    
    if (diferencaMs <= 0) {
        return { expirado: true, texto: 'Expirado' };
    }
    
    const horas = Math.floor(diferencaMs / (1000 * 60 * 60));
    const minutos = Math.floor((diferencaMs % (1000 * 60 * 60)) / (1000 * 60));
    
    return {
        expirado: false,
        horas: horas,
        minutos: minutos,
        texto: `${horas}h ${minutos}min`
    };
}

/**
 * Formatar dados do pré-pedido para exibição
 */
function formatarPrePedido(prePedido) {
    return {
        ...prePedido,
        total_formatado: formatCurrency(prePedido.total),
        data_criacao_formatada: formatDateTime(prePedido.created_at),
        tempo_restante: calcularTempoRestante(prePedido.data_expiracao),
        quantidade_itens: prePedido.pre_pedido_itens?.length || 0
    };
}
