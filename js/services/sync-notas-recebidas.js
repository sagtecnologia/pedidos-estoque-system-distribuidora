/**
 * Serviço de Sincronização de Notas Recebidas (NF-e e NFC-e)
 * Para distribuidoras importarem automaticamente notas de compra de fornecedores
 * 
 * Funcionalidades:
 * - Listar NF-e e NFC-e recebidas da Nuvem Fiscal
 * - Baixar XML automaticamente
 * - Importar como pedidos de compra
 * - Sincronização por período/data
 */

class SincronizacaoNotasRecebidas {
    constructor() {
        this.notasSincronizadas = [];
        this.notasErro = [];
        this.cnpj = null;
        this.ambiente = 'homologacao';
    }

    /**
     * Inicializar sincronização - carregar configurações
     */
    async inicializar() {
        try {
            const { data: config } = await supabase
                .from('empresa_config')
                .select('cnpj, focusnfe_ambiente')
                .single();

            if (!config) {
                throw new Error('Configuração da empresa não encontrada');
            }

            this.cnpj = config.cnpj;
            this.ambiente = config.focusnfe_ambiente === 1 ? 'producao' : 'homologacao';

            console.log('✅ [SincronizacaoNotasRecebidas] Inicializado:', {
                cnpj: this.cnpj,
                ambiente: this.ambiente
            });

            return true;
        } catch (erro) {
            console.error('Erro ao inicializar sincronização:', erro);
            throw erro;
        }
    }

    /**
     * Sincronizar todas as notas recebidas (NF-e e NFC-e)
     * @param {Object} opcoes - Opções de sincronização
     *   - dataInicio: Data inicial (YYYY-MM-DD)
     *   - dataFim: Data final (YYYY-MM-DD)
     *   - tiposNota: ['nfe', 'nfce'] ou apenas um tipo
     *   - top: Limite de notas a sincronizar (padrão: 100)
     *   - callback: Função para reportar progresso
     * @returns {Object} Resultado da sincronização
     */
    async sincronizar(opcoes = {}) {
        try {
            await this.inicializar();

            const {
                dataInicio = null,
                dataFim = null,
                tiposNota = ['nfe', 'nfce'],
                top = 100,
                callback = null
            } = opcoes;

            console.log('🚀 [SincronizacaoNotasRecebidas] Iniciando sincronização:', opcoes);

            this.notasSincronizadas = [];
            this.notasErro = [];

            const tiposArray = Array.isArray(tiposNota) ? tiposNota : [tiposNota];
            let notasParaImportar = [];

            // 1. Listar NF-e recebidas (usando API de Distribuição do SEFAZ)
            if (tiposArray.includes('nfe')) {
                console.log('📋 [SincronizacaoNotasRecebidas] Buscando NF-e distribuídas (API de Distribuição)...');
                this._reportarProgresso(callback, 'Buscando NF-e distribuídas...', 0);

                try {
                    // Usar novo método que chama a API de Distribuição NF-e
                    const nfes = await NuvemFiscal.buscarDistribuicaoNFe(
                        this.cnpj,
                        this.ambiente,
                        top,
                        dataInicio,
                        dataFim
                    );

                    if (nfes?.data && nfes.data.length > 0) {
                        notasParaImportar.push(...nfes.data.map(n => ({
                            ...n,
                            tipo: 'nfe'
                        })));
                        console.log(`✅ [SincronizacaoNotasRecebidas] ${nfes.data.length} NF-e encontradas via distribuição`);
                    } else {
                        console.log('ℹ️ [SincronizacaoNotasRecebidas] Nenhuma NF-e encontrada no período especificado');
                    }
                } catch (erro) {
                    console.error('❌ [SincronizacaoNotasRecebidas] Erro ao listar NF-e via distribuição:', erro);
                    this._reportarProgresso(callback, `Erro ao buscar NF-e: ${erro.message}`, 0);
                    
                    this.notasErro.push({
                        chaveAcesso: 'N/A',
                        tipo: 'nfe',
                        emitente: 'Busca geral',
                        erro: `Erro ao conectar com API de distribuição: ${erro.message}`
                    });
                }
            }
            // 2. Listar NFC-e recebidas (⚠️ TEMPORARIAMENTE DESABILITADO - endpoint não disponível)
            // Se precisar sincronizar NFC-e, entre em contato com suporte Nuvem Fiscal
            if (tiposArray.includes('nfce')) {
                console.log('📋 [SincronizacaoNotasRecebidas] NFC-e temporariamente desabilitado...');
                this._reportarProgresso(callback, 'NFC-e ainda não suportado nesta API', 10);

                // NFC-e será suportado em breve
                const mensagem = 'Sincronização de NFC-e foi temporariamente desabilitada. Use apenas NF-e ou aguarde atualização.';
                console.warn('⚠️ [SincronizacaoNotasRecebidas] ' + mensagem);
                this._reportarProgresso(callback, mensagem, 10);

                this.notasErro.push({
                    chaveAcesso: 'N/A',
                    tipo: 'nfce',
                    emitente: 'Busca geral',
                    erro: mensagem
                });
            }

            if (notasParaImportar.length === 0) {
                console.log('ℹ️ [SincronizacaoNotasRecebidas] Nenhuma nota para importar');
                return {
                    sucesso: true,
                    totalEncontradas: 0,
                    totalImportadas: 0,
                    totalErros: this.notasErro.length,
                    detalhes: {
                        sincronizadas: [],
                        erros: this.notasErro
                    }
                };
            }

            console.log(`📦 [SincronizacaoNotasRecebidas] Total de notas para importar: ${notasParaImportar.length}`);

            // 3. Processar cada nota
            const incrementoProgresso = 80 / notasParaImportar.length;
            for (let i = 0; i < notasParaImportar.length; i++) {
                const nota = notasParaImportar[i];
                const percentual = Math.round(10 + (i * incrementoProgresso));

                try {
                    console.log(`\n📥 [SincronizacaoNotasRecebidas] Processando nota ${i + 1}/${notasParaImportar.length}`);
                    console.log(`   Tipo: ${nota.tipo.toUpperCase()}`);
                    console.log(`   ID: ${nota.id || '-'}`);
                    console.log(`   Chave: ${nota.chave_acesso || nota.chaveAcesso || '-'}`);
                    console.log(`   Emitente: ${nota.emitente?.CNPJ || nota.numero || '-'}`);

                    this._reportarProgresso(callback, `Processando ${nota.tipo.toUpperCase()} ${i + 1}/${notasParaImportar.length}...`, percentual);

                    // 4. Baixar XML
                    console.log('   📥 Baixando XML via API de Distribuição...');
                    
                    if (!nota.id) {
                        throw new Error('ID da nota não disponível para download');
                    }
                    
                    // Usar apenas o método de distribuição (único que funciona)
                    // O ID vem da resposta da API de distribuição
                    const xmlBlob = await NuvemFiscal.baixarXMLDistribuicao(nota.id);

                    // 5. Converter Blob para texto
                    const xmlText = await xmlBlob.text();
                    console.log('   ✅ XML baixado com sucesso');

                    // 6. Importar como pedido de compra
                    console.log('   📦 Importando como pedido de compra...');
                    const resultadoImportacao = await this._importarXML(xmlText, nota);

                    this.notasSincronizadas.push({
                        chaveAcesso: nota.chave_acesso || nota.chaveAcesso,
                        tipo: nota.tipo,
                        emitente: nota.emitente?.CNPJ || nota.numero || 'Desconhecido',
                        pedidoId: resultadoImportacao?.pedido_id,
                        status: 'SUCESSO'
                    });

                    console.log(`   ✅ Nota importada com sucesso! Pedido: ${resultadoImportacao?.pedido_id}`);
                } catch (erro) {
                    console.error(`   ❌ Erro ao processar nota:`, erro);

                    this.notasErro.push({
                        chaveAcesso: nota.chave_acesso || nota.chaveAcesso,
                        tipo: nota.tipo,
                        emitente: nota.emitente?.CNPJ || nota.numero || 'Desconhecido',
                        erro: erro.message
                    });
                }
            }

            this._reportarProgresso(callback, 'Sincronização concluída!', 100);

            // 7. Retornar resultado
            const resultado = {
                sucesso: true,
                totalEncontradas: notasParaImportar.length,
                totalImportadas: this.notasSincronizadas.length,
                totalErros: this.notasErro.length,
                detalhes: {
                    sincronizadas: this.notasSincronizadas,
                    erros: this.notasErro
                }
            };

            console.log('📊 [SincronizacaoNotasRecebidas] Resultado final:', resultado);
            return resultado;
        } catch (erro) {
            console.error('❌ [SincronizacaoNotasRecebidas] Erro geral na sincronização:', erro);
            throw erro;
        }
    }

    /**
     * Consulta uma NF-e destinada à empresa pela chave e cria o pedido de compra.
     */
    async importarPorChave(chaveAcesso) {
        const chave = String(chaveAcesso || '').replace(/\D/g, '');
        if (chave.length !== 44) {
            throw new Error('A chave de acesso deve conter 44 dígitos.');
        }
        if (chave.substring(20, 22) !== '55') {
            throw new Error('Informe uma chave de NF-e modelo 55.');
        }
        if (typeof SefazDireta === 'undefined') {
            throw new Error('Serviço de consulta direta à SEFAZ indisponível.');
        }

        const consulta = await SefazDireta.invoke('consultar_nfe_entrada', {
            chave_acesso: chave
        });
        if (!consulta?.success || !consulta?.xml) {
            throw new Error(consulta?.mensagem || 'A SEFAZ não disponibilizou o XML da nota.');
        }

        return await this._importarXML(consulta.xml, {
            tipo: 'nfe',
            chave_acesso: chave,
            origem: 'sefaz_direta'
        });
    }

    /**
     * Importar XML como pedido de compra
     * Reutiliza a lógica de importação que já existe em pedidos.html
     */
    async _importarXML(xmlText, notaMetadata) {
        try {
            const parser = new DOMParser();
            const xmlDoc = parser.parseFromString(xmlText, 'text/xml');

            // Validar XML
            const nfeProc = xmlDoc.querySelector('nfeProc') || xmlDoc.querySelector('NFe');
            if (!nfeProc) {
                throw new Error('Arquivo XML não é uma NFe/NFCe válida');
            }

            const infNFe = xmlDoc.querySelector('infNFe');
            const ide = xmlDoc.querySelector('ide');
            const emit = xmlDoc.querySelector('emit');
            const total = xmlDoc.querySelector('total');
            const det = xmlDoc.querySelectorAll('det');

            // Extrair dados
            const dadosXML = {
                chave: infNFe?.getAttribute('Id')?.replace('NFe', '') || '',
                numero_nf: ide?.querySelector('nNF')?.textContent || '',
                serie: ide?.querySelector('serie')?.textContent || '',
                data_emissao: ide?.querySelector('dhEmi')?.textContent?.split('T')[0] || '',
                fornecedor: {
                    cnpj: emit?.querySelector('CNPJ')?.textContent || '',
                    razao_social: emit?.querySelector('xNome')?.textContent || '',
                    nome_fantasia: emit?.querySelector('xFant')?.textContent || '',
                    ie: emit?.querySelector('IE')?.textContent || '',
                    endereco: {
                        logradouro: emit?.querySelector('xLgr')?.textContent || '',
                        numero: emit?.querySelector('nro')?.textContent || '',
                        bairro: emit?.querySelector('xBairro')?.textContent || '',
                        cidade: emit?.querySelector('xMun')?.textContent || '',
                        uf: emit?.querySelector('UF')?.textContent || '',
                        cep: emit?.querySelector('CEP')?.textContent || ''
                    }
                },
                total_produtos: parseFloat(total?.querySelector('vProd')?.textContent || 0),
                total_frete: parseFloat(total?.querySelector('vFrete')?.textContent || 0),
                total_desconto: parseFloat(total?.querySelector('vDesc')?.textContent || 0),
                total_nf: parseFloat(total?.querySelector('vNF')?.textContent || 0),
                itens: []
            };

            // Extrair itens
            det.forEach(item => {
                const prod = item.querySelector('prod');
                if (prod) {
                    const unidadeXML = prod?.querySelector('uCom')?.textContent || '';
                    dadosXML.itens.push({
                        codigo: prod?.querySelector('cProd')?.textContent || '',
                        codigo_barras: prod?.querySelector('cEAN')?.textContent || '',
                        ncm: prod?.querySelector('NCM')?.textContent || '',
                        nome: prod?.querySelector('xProd')?.textContent || '',
                        unidade: this._normalizarUnidade(unidadeXML),
                        quantidade: parseFloat(prod?.querySelector('qCom')?.textContent || 0),
                        valor_unitario: parseFloat(prod?.querySelector('vUnCom')?.textContent || 0),
                        valor_total: parseFloat(prod?.querySelector('vProd')?.textContent || 0),
                        cfop: prod?.querySelector('CFOP')?.textContent || ''
                    });
                }
            });

            // 1. Verificar se já foi importada
            const { data: pedidoExistente } = await supabase
                .from('pedidos_compra')
                .select('id, numero, status')
                .eq('nf_chave', dadosXML.chave)
                .maybeSingle();

            if (pedidoExistente && pedidoExistente.status !== 'CANCELADO') {
                throw new Error(`Nota já importada (Pedido: ${pedidoExistente.numero})`);
            }

            // 2. Buscar ou criar fornecedor
            const { data: fornecedorExistente } = await supabase
                .from('fornecedores')
                .select('id')
                .eq('cnpj', dadosXML.fornecedor.cnpj)
                .maybeSingle();

            let fornecedorId = fornecedorExistente?.id;
            if (!fornecedorId && dadosXML.fornecedor.cnpj) {
                const { data: novoFornecedor } = await supabase
                    .from('fornecedores')
                    .insert([{
                        nome: dadosXML.fornecedor.nome_fantasia || dadosXML.fornecedor.razao_social,
                        razao_social: dadosXML.fornecedor.razao_social,
                        nome_fantasia: dadosXML.fornecedor.nome_fantasia,
                        cnpj: dadosXML.fornecedor.cnpj,
                        inscricao_estadual: dadosXML.fornecedor.ie,
                        endereco: dadosXML.fornecedor.endereco.logradouro,
                        numero: dadosXML.fornecedor.endereco.numero,
                        bairro: dadosXML.fornecedor.endereco.bairro,
                        cidade: dadosXML.fornecedor.endereco.cidade,
                        estado: dadosXML.fornecedor.endereco.uf,
                        cep: dadosXML.fornecedor.endereco.cep,
                        ativo: true
                    }])
                    .select('id')
                    .single();

                fornecedorId = novoFornecedor?.id;
            }

            if (!fornecedorId) {
                throw new Error('Fornecedor não encontrado e não foi possível criar');
            }

            // 3. Processar produtos
            const itensParaPedido = [];
            for (const item of dadosXML.itens) {
                if (!item.quantidade || !item.valor_unitario) continue;

                let produtoId = null;

                // Buscar por código de barras ou código
                if (item.codigo_barras) {
                    const { data: prod } = await supabase
                        .from('produtos')
                        .select('id')
                        .eq('codigo_barras', item.codigo_barras)
                        .maybeSingle();
                    produtoId = prod?.id;
                }

                if (!produtoId && item.codigo) {
                    const { data: prod } = await supabase
                        .from('produtos')
                        .select('id')
                        .eq('codigo', item.codigo)
                        .maybeSingle();
                    produtoId = prod?.id;
                }

                // Se encontrou produto, adicionar ao pedido
                if (produtoId) {
                    itensParaPedido.push({
                        produto_id: produtoId,
                        quantidade: item.quantidade,
                        preco_unitario: item.valor_unitario,
                        preco_total: item.valor_total
                    });
                }
            }

            if (itensParaPedido.length === 0) {
                throw new Error('Nenhum produto encontrado no XML');
            }

            // 4. Criar pedido de compra
            const usuario = await this._getCurrentUser();
            const pedidoId = crypto.randomUUID ? crypto.randomUUID() : 
                'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
                    const r = Math.random() * 16 | 0;
                    return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
                });

            const { data: pedido } = await supabase
                .from('pedidos_compra')
                .insert([{
                    id: pedidoId,
                    numero: `PC-${new Date().getFullYear()}-${String(Date.now()).slice(-6)}`,
                    fornecedor_id: fornecedorId,
                    usuario_id: usuario.id,
                    status: 'PENDENTE',
                    total: dadosXML.total_nf,
                    nf_chave: dadosXML.chave,
                    nf_numero: dadosXML.numero_nf,
                    observacoes: `Importado de ${notaMetadata.tipo.toUpperCase()} via ${notaMetadata.origem === 'sefaz_direta' ? 'SEFAZ' : 'Nuvem Fiscal'} - Chave: ${dadosXML.chave}`
                }])
                .select('id')
                .single();

            // 5. Adicionar itens
            const itensInsercao = itensParaPedido.map(item => ({
                id: crypto.randomUUID ? crypto.randomUUID() : 
                    'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, c => {
                        const r = Math.random() * 16 | 0;
                        return (c === 'x' ? r : (r & 0x3 | 0x8)).toString(16);
                    }),
                pedido_id: pedido.id,
                produto_id: item.produto_id,
                quantidade: item.quantidade,
                preco_unitario: item.preco_unitario,
                subtotal: item.quantidade * item.preco_unitario
            }));

            await supabase.from('pedido_compra_itens').insert(itensInsercao);

            return {
                pedido_id: pedido.id,
                itens_importados: itensParaPedido.length
            };
        } catch (erro) {
            console.error('❌ [SincronizacaoNotasRecebidas] Erro ao importar XML:', erro);
            throw erro;
        }
    }

    /**
     * Normalizar unidade de medida
     */
    _normalizarUnidade(unidade) {
        const mapa = {
            'UN': 'UN', 'KG': 'KG', 'L': 'L', 'M': 'M', 'M2': 'M2', 'M3': 'M3',
            'H': 'H', 'TON': 'TON', 'PC': 'PC', 'CX': 'CX', 'UNID': 'UN'
        };
        return mapa[unidade?.toUpperCase()] || 'UN';
    }

    /**
     * Obter usuário atual
     */
    async _getCurrentUser() {
        const { data: { user } } = await supabase.auth.getUser();
        return user;
    }

    /**
     * Reportar progresso
     */
    _reportarProgresso(callback, mensagem, percentual) {
        if (callback && typeof callback === 'function') {
            callback({
                mensagem,
                percentual,
                timestamp: new Date()
            });
        }
    }
}

// Exportar instância única
const SincronizacaoNotas = new SincronizacaoNotasRecebidas();
