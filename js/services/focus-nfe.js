// =====================================================
// SERVIÇO: FOCUS NFe - INTEGRAÇÃO FISCAL
// =====================================================
// Documentação: https://focusnfe.com.br/doc/
// =====================================================

const FocusNFe = {
    // URLs base por ambiente
    URLS: {
        PRODUCAO: 'https://api.focusnfe.com.br',
        HOMOLOGACAO: 'https://homologacao.focusnfe.com.br'
    },

    // Flag para usar Edge Functions (sem CORS) ou chamada direta (com CORS)
    USE_EDGE_FUNCTIONS: true, // Usar Edge Function proxy-focus-nfe (sem CORS)

    // Obter configuração da empresa
    async getConfig() {
        const config = await getEmpresaConfig();
        if (!config) {
            throw new Error('Configurações da empresa não encontradas');
        }
        if (!config.focusnfe_token) {
            throw new Error('Token Focus NFe não configurado');
        }
        return config;
    },

    // Obter URL base conforme ambiente
    getBaseUrl(ambiente) {
        return ambiente === 1 ? this.URLS.PRODUCAO : this.URLS.HOMOLOGACAO;
    },

    // Headers padrão
    getHeaders(token) {
        return {
            'Authorization': 'Basic ' + btoa(token + ':'),
            'Content-Type': 'application/json'
        };
    },

    /**
     * Fazer requisição HTTP RAW (retorna Response para blob/text)
     */
    async makeRequestRaw(endpoint, method = 'GET') {
        const config = await this.getConfig();
        const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
        const token = config.focusnfe_token;

        const options = {
            method,
            headers: this.getHeaders(token)
        };

        const url = `${baseUrl}${endpoint}`;
        console.log(`🌐 ${method} ${url}`);

        return await fetch(url, options);
    },

    /**
     * Fazer requisição via Edge Function (sem CORS) ou direta (com CORS)
     */
    async makeRequest(endpoint, method = 'GET', body = null) {
        const config = await this.getConfig();

        if (this.USE_EDGE_FUNCTIONS) {
            // Usar Edge Function do Supabase (SEM CORS)
            console.log('🔄 Usando Edge Function (sem CORS)');
            console.log('📍 Endpoint:', endpoint);
            console.log('📍 Method:', method);
            
            // Fazer requisição direta com fetch para ter controle total da resposta
            const functionUrl = `${SUPABASE_URL}/functions/v1/proxy-focus-nfe`;
            
            const response = await fetch(functionUrl, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
                    'apikey': SUPABASE_ANON_KEY
                },
                body: JSON.stringify({
                    endpoint,
                    method,
                    data: body,
                    token: config.focusnfe_token,
                    ambiente: config.focusnfe_ambiente
                })
            });

            const result = await response.json();
            console.log('📦 Resposta da Edge Function:', result);
            console.log('📊 Status:', response.status);

            // Status 400/404 com resposta da API Focus NFe = erro de validação mas conexão OK
            if (!response.ok && result) {
                // Verificar se é erro de emitente não autorizado (CNPJ teste ou não configurado na Focus)
                if (result.codigo === 'requisicao_invalida' && result.mensagem?.includes('não autorizado')) {
                    console.log('✅ API Focus NFe respondeu corretamente');
                    return { 
                        sucesso_conexao: true, 
                        mensagem: 'Emitente não autorizado neste ambiente. Configure o CNPJ real na Focus NFe ou use ambiente de homologação com CNPJ autorizado.',
                        resposta_api: result 
                    };
                }
                
                // Outros erros da API
                if (result.codigo || result.mensagem || result.erro) {
                    const errorMsg = result.mensagem || result.erro || 'Erro da API Focus NFe';
                    throw new Error(errorMsg);
                }
            }

            // Status 2xx = sucesso normal
            if (response.ok) {
                return result;
            }

            // Erro desconhecido
            throw new Error('Erro ao chamar Edge Function');
        } else {
            // Chamada direta (requer extensão CORS)
            console.log('⚠️ Usando chamada direta (requer CORS)');
            
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            const response = await fetch(`${baseUrl}${endpoint}`, {
                method,
                headers: this.getHeaders(config.focusnfe_token),
                body: body ? JSON.stringify(body) : null
            });

            if (!response.ok) {
                const error = await response.json();
                throw new Error(error.mensagem || error.erro || 'Erro na requisição');
            }

            return await response.json();
        }
    },

    // =====================================================
    // NFC-e (Cupom Fiscal Eletrônico)
    // =====================================================

    /**
     * Emitir NFC-e
     * @param {Object} venda - Dados da venda
     * @param {Array} itens - Itens da venda
     * @param {Array} pagamentos - Formas de pagamento
     * @param {Object} cliente - Dados do cliente (opcional)
     */
    async emitirNFCe(venda, itens, pagamentos, cliente = null) {
        try {
            // Gerar referência única
            const ref = `NFCE-${Date.now()}-${venda.numero_venda}`;
            
            // Montar payload
            const config = await this.getConfig();
            const payload = this.montarPayloadNFCe(config, venda, itens, pagamentos, cliente);
            
            console.log('📤 Enviando NFC-e para Focus NFe:', ref);
            console.log('📦 Payload:', JSON.stringify(payload, null, 2));
            
            // Usar makeRequest para aproveitar o sistema de Edge Functions
            // Conforme doc: POST /v2/nfce?ref=REFERENCIA
            const result = await this.makeRequest(`/v2/nfce?ref=${ref}`, 'POST', payload);
            
            // Salvar documento fiscal no banco
            await this.salvarDocumentoFiscal({
                venda_id: venda.id,
                tipo_documento: 'NFCE',
                numero_documento: result.numero || '0',
                serie: parseInt(result.serie || '1'),
                chave_acesso: result.nf_chave,
                protocolo_autorizacao: result.protocolo || result.numero_protocolo,
                status_sefaz: result.status_sefaz || (result.status === 'autorizado' ? '100' : '999'),
                mensagem_sefaz: result.mensagem_sefaz,
                valor_total: venda.total,
                natureza_operacao: payload.natureza_operacao,
                data_emissao: payload.data_emissao,
                data_autorizacao: result.status === 'autorizado' ? new Date().toISOString() : null,
                xml_nota: JSON.stringify(payload),
                xml_retorno: JSON.stringify(result),
                tentativas_emissao: 1,
                ultima_tentativa: new Date().toISOString()
            });

            // Preparar resposta com métodos de download
            const response = {
                success: result.status !== 'erro_autorizacao',
                ref,
                ...result,
                // Métodos helper para download
                baixarDANFE: () => this.baixarDANFE(ref, 'nfce'),
                baixarXML: () => this.baixarXML(ref, 'nfce'),
                visualizarDANFE: async () => {
                    const url = await this.baixarDANFE(ref, 'nfce');
                    window.open(url, '_blank');
                }
            };

            return response;

        } catch (error) {
            console.error('❌ Erro ao emitir NFC-e:', error);
            throw error;
        }
    },

    /**
     * Obter data/hora atual no formato ISO com fuso horário de Brasília
     */
    getDataEmissaoBrasilia() {
        // Criar data atual
        const agora = new Date();
        
        // Converter para horário de Brasília (UTC-3)
        // Usar toLocaleString para garantir o fuso correto
        const brasiliaDate = new Date(agora.toLocaleString('en-US', { timeZone: 'America/Sao_Paulo' }));
        
        // Formatar no padrão ISO com timezone -03:00
        const year = brasiliaDate.getFullYear();
        const month = String(brasiliaDate.getMonth() + 1).padStart(2, '0');
        const day = String(brasiliaDate.getDate()).padStart(2, '0');
        const hours = String(brasiliaDate.getHours()).padStart(2, '0');
        const minutes = String(brasiliaDate.getMinutes()).padStart(2, '0');
        const seconds = String(brasiliaDate.getSeconds()).padStart(2, '0');
        
        return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}-03:00`;
    },

    /**
     * Montar payload da NFC-e conforme especificação Focus NFe
     */
    montarPayloadNFCe(config, venda, itens, pagamentos, cliente) {
        const naturezaOperacao = 'VENDA AO CONSUMIDOR';
        
        const payload = {
            // Identificação
            natureza_operacao: naturezaOperacao,
            data_emissao: this.getDataEmissaoBrasilia(), // Data/hora atual em horário de Brasília
            forma_pagamento: 0, // 0=À vista, 1=À prazo
            tipo_documento: 1, // 1=Saída
            finalidade_emissao: 1, // 1=Normal
            consumidor_final: 1, // 1=Consumidor final
            presenca_comprador: 1, // 1=Presencial
            
            // Dados do emitente (pego da config)
            cnpj_emitente: config.cnpj?.replace(/\D/g, ''),
            
            // Totais
            valor_produtos: venda.subtotal,
            valor_desconto: venda.desconto_valor || 0,
            valor_total: venda.total,
            
            // Transporte (OBRIGATÓRIO)
            modalidade_frete: "9", // 9=Sem frete
            
            // Itens
            items: itens.map((item, index) => ({
                numero_item: String(index + 1),
                codigo_produto: item.codigo_barras || item.produto_id?.substring(0, 14) || '999',
                codigo_barras_comercial: item.codigo_barras || '',
                descricao: item.descricao?.substring(0, 120) || 'Produto sem descrição',
                codigo_ncm: item.ncm || '84713012', // NCM genérico
                cfop: item.cfop || '5102',
                unidade_comercial: item.unidade || 'UN',
                unidade_tributavel: item.unidade || 'UN',
                quantidade_comercial: parseFloat(item.quantidade),
                quantidade_tributavel: parseFloat(item.quantidade),
                valor_unitario_comercial: parseFloat(item.preco_unitario),
                valor_unitario_tributavel: parseFloat(item.preco_unitario),
                valor_bruto: parseFloat(item.subtotal),
                
                // Tributação ICMS
                icms_origem: "0", // 0=Nacional
                icms_situacao_tributaria: item.cst_icms || "102", // 102=Tributada pelo Simples Nacional sem permissão de crédito
                icms_modalidade_base_calculo: "3", // 3=Valor da operação
                icms_base_calculo: "0.00",
                icms_aliquota: "0.00",
                icms_valor_total: "0.00",
                
                // PIS/COFINS
                pis_situacao_tributaria: "49", // Outras operações de saída
                cofins_situacao_tributaria: "49"
            })),
            
            // Formas de pagamento
            formas_pagamento: pagamentos.map(pag => {
                const formaPag = this.mapearFormaPagamento(pag.tipo);
                const isCartao = pag.tipo === 'CREDITO' || pag.tipo === 'DEBITO';
                
                const pagamento = {
                    forma_pagamento: formaPag,
                    valor_pagamento: parseFloat(pag.valor)
                };
                
                // Só adiciona grupo de cartão/boleto se for realmente cartão
                if (isCartao) {
                    pagamento.tipo_integracao = pag.tipo_integracao || 2; // 1=TEF integrado, 2=Não integrado
                    
                    // Campos obrigatórios para cartão
                    if (pag.cnpj_credenciadora) {
                        pagamento.cnpj_credenciadora = pag.cnpj_credenciadora.replace(/\D/g, '');
                    }
                    if (pag.bandeira) {
                        pagamento.bandeira_operadora = this.mapearBandeira(pag.bandeira);
                    }
                    if (pag.nsu) {
                        pagamento.numero_autorizacao = pag.nsu;
                    }
                }
                
                return pagamento;
            })
        };

        // Adicionar dados do cliente se informado
        if (cliente && cliente.cpf_cnpj) {
            const doc = cliente.cpf_cnpj.replace(/\D/g, '');
            if (doc.length === 11) {
                payload.cpf_destinatario = doc;
            } else if (doc.length === 14) {
                payload.cnpj_destinatario = doc;
            }
            payload.nome_destinatario = cliente.nome;
        }

        return payload;
    },

    /**
     * Mapear forma de pagamento para código SEFAZ
     */
    mapearFormaPagamento(tipo) {
        const mapa = {
            'DINHEIRO': '01',
            'CHEQUE': '02',
            'CREDITO': '03',
            'DEBITO': '04',
            'CREDIARIO': '05',
            'VALE_ALIMENTACAO': '10',
            'VALE_REFEICAO': '11',
            'VALE_PRESENTE': '12',
            'VALE_COMBUSTIVEL': '13',
            'BOLETO': '15',
            'DEPOSITO': '16',
            'PIX': '17',
            'TRANSFERENCIA': '18',
            'CASHBACK': '19',
            'SEM_PAGAMENTO': '90',
            'OUTROS': '99'
        };
        return mapa[tipo] || '99';
    },

    /**
     * Mapear bandeira do cartão
     */
    mapearBandeira(bandeira) {
        const mapa = {
            'VISA': '01',
            'MASTERCARD': '02',
            'AMERICAN_EXPRESS': '03',
            'SOROCRED': '04',
            'DINERS': '05',
            'ELO': '06',
            'HIPERCARD': '07',
            'AURA': '08',
            'CABAL': '09'
        };
        return mapa[bandeira?.toUpperCase()] || '99';
    },

    // =====================================================
    // NF-e (Nota Fiscal Eletrônica)
    // =====================================================

    /**
     * Emitir NF-e
     */
    async emitirNFe(venda, itens, cliente, transportadora = null) {
        try {
            const config = await this.getConfig();
            
            const ref = `NFE-${Date.now()}-${venda.numero_venda}`;
            const payload = this.montarPayloadNFe(config, venda, itens, cliente, transportadora);
            
            console.log('📤 Enviando NF-e para Focus NFe:', ref);
            
            const result = await this.makeRequest(`/v2/nfe?ref=${ref}`, 'POST', payload);
            
            await this.salvarDocumentoFiscal({
                venda_id: venda.id,
                tipo_documento: 'NFE',
                numero_documento: result.numero || '0',
                serie: parseInt(result.serie || '1'),
                chave_acesso: result.nf_chave,
                protocolo_autorizacao: result.protocolo || result.numero_protocolo,
                status_sefaz: result.status_sefaz || (result.status === 'autorizado' ? '100' : '999'),
                mensagem_sefaz: result.mensagem_sefaz,
                valor_total: venda.total,
                natureza_operacao: payload.natureza_operacao,
                data_emissao: payload.data_emissao,
                data_autorizacao: result.status === 'autorizado' ? new Date().toISOString() : null,
                xml_nota: JSON.stringify(payload),
                xml_retorno: JSON.stringify(result),
                tentativas_emissao: 1,
                ultima_tentativa: new Date().toISOString()
            });

            return { success: result.status !== 'erro_autorizacao', ref, ...result };

        } catch (error) {
            console.error('❌ Erro ao emitir NF-e:', error);
            throw error;
        }
    },

    /**
     * Montar payload da NF-e
     */
    montarPayloadNFe(config, venda, itens, cliente, transportadora) {
        return {
            natureza_operacao: 'VENDA DE MERCADORIA',
            forma_pagamento: 0,
            tipo_documento: 1,
            finalidade_emissao: 1,
            consumidor_final: cliente?.tipo === 'JURIDICA' ? 0 : 1,
            presenca_comprador: 1,
            
            cnpj_emitente: config.cnpj?.replace(/\D/g, ''),
            
            // Destinatário
            nome_destinatario: cliente.nome,
            cpf_destinatario: cliente.cpf_cnpj?.length === 14 ? cliente.cpf_cnpj.replace(/\D/g, '') : undefined,
            cnpj_destinatario: cliente.cpf_cnpj?.length > 14 ? cliente.cpf_cnpj.replace(/\D/g, '') : undefined,
            inscricao_estadual_destinatario: cliente.inscricao_estadual,
            endereco_destinatario: cliente.endereco,
            bairro_destinatario: cliente.bairro,
            municipio_destinatario: cliente.cidade,
            uf_destinatario: cliente.estado,
            cep_destinatario: cliente.cep?.replace(/\D/g, ''),
            telefone_destinatario: cliente.telefone?.replace(/\D/g, ''),
            email_destinatario: cliente.email,
            
            // Totais
            valor_produtos: venda.subtotal,
            valor_desconto: venda.desconto_valor || 0,
            valor_total: venda.total,
            
            // Itens
            items: itens.map((item, index) => ({
                numero_item: index + 1,
                codigo_produto: item.codigo_barras || item.produto_id.substring(0, 14),
                descricao: item.descricao,
                codigo_ncm: item.ncm || '22021000',
                cfop: item.cfop || '5102',
                unidade_comercial: item.unidade,
                quantidade_comercial: item.quantidade,
                valor_unitario_comercial: item.preco_unitario,
                valor_bruto: item.subtotal + (item.desconto_valor || 0),
                valor_desconto: item.desconto_valor || 0,
                
                icms_origem: 0,
                icms_situacao_tributaria: item.cst_icms || '102',
                pis_situacao_tributaria: '49',
                cofins_situacao_tributaria: '49'
            })),
            
            // Transporte
            modalidade_frete: transportadora ? 1 : 9 // 1=Por conta emitente, 9=Sem frete
        };
    },

    // =====================================================
    // OPERAÇÕES DE CONSULTA
    // =====================================================

    /**
     * Consultar status de documento
     */
    async consultarDocumento(ref, tipo = 'nfce') {
        try {
            // Conforme doc: GET /v2/nfce/REFERENCIA?completa=1
            return await this.makeRequest(`/v2/${tipo}/${ref}?completa=1`, 'GET');
        } catch (error) {
            console.error('❌ Erro ao consultar documento:', error);
            throw error;
        }
    },

    /**
     * Cancelar documento fiscal
     */
    async cancelarDocumento(ref, justificativa, tipo = 'nfce') {
        try {
            if (!justificativa || justificativa.length < 15) {
                throw new Error('Justificativa deve ter no mínimo 15 caracteres');
            }

            const result = await this.makeRequest(`/v2/${tipo}/${ref}`, 'DELETE', { justificativa });
            
            // Atualizar status no banco
            if (result.status === 'cancelado') {
                await supabase
                    .from('documentos_fiscais')
                    .update({
                        status_sefaz: result.status_sefaz || '135',
                        mensagem_sefaz: `CANCELADO: ${justificativa}`,
                        updated_at: new Date().toISOString()
                    })
                    .eq('chave_acesso', ref.replace(/^(NFCE|NFE)-\d+-/, ''));
            }

            return result;
        } catch (error) {
            console.error('❌ Erro ao cancelar documento:', error);
            throw error;
        }
    },

    /**
     * Baixar DANFE (PDF) e criar link de download
     */
    async baixarDANFE(ref, tipo = 'nfce') {
        try {
            console.log('📥 Baixando DANFE:', ref);
            // Usar Edge Function para evitar CORS
            const response = await this.makeRequest(`/v2/${tipo}/${ref}.pdf`, 'GET');
            if (!response || !response.pdf) {
                throw new Error('Erro ao baixar DANFE');
            }
            // Criar blob e link de download
            const blob = new Blob([new Uint8Array(response.pdf.data)], { type: 'application/pdf' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `DANFE-${ref}.pdf`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            return url;
        } catch (error) {
            console.error('❌ Erro ao baixar DANFE:', error);
            throw error;
        }
    },

    /**
     * Baixar XML e criar arquivo para download
     */
    async baixarXML(ref, tipo = 'nfce') {
        try {
            console.log('📥 Baixando XML:', ref);
            // Usar Edge Function para evitar CORS
            const response = await this.makeRequest(`/v2/${tipo}/${ref}.xml`, 'GET');
            if (!response || !response.xml) {
                throw new Error('Erro ao baixar XML');
            }
            // Criar blob e link de download
            const blob = new Blob([response.xml], { type: 'application/xml' });
            const url = URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `NFCe-${ref}.xml`;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            return response.xml;
        } catch (error) {
            console.error('❌ Erro ao baixar XML:', error);
            throw error;
        }
    },

    // =====================================================
    // INUTILIZAÇÃO
    // =====================================================

    /**
     * Inutilizar numeração
     */
    async inutilizarNumeracao(serie, numeroInicial, numeroFinal, justificativa, tipo = 'nfce') {
        try {
            const config = await this.getConfig();
            
            if (!config.cnpj) {
                throw new Error('CNPJ não configurado');
            }
            
            const ref = `INUT-${tipo.toUpperCase()}-${Date.now()}`;
            
            // Conforme doc: POST /v2/nfce/inutilizacao (sem ref na URL)
            return await this.makeRequest(`/v2/${tipo}/inutilizacao`, 'POST', {
                cnpj: config.cnpj.replace(/\D/g, ''),
                serie,
                numero_inicial: numeroInicial,
                numero_final: numeroFinal,
                justificativa
            });
        } catch (error) {
            console.error('❌ Erro ao inutilizar numeração:', error);
            throw error;
        }
    },

    // =====================================================
    // UTILITÁRIOS
    // =====================================================

    /**
     * Salvar documento fiscal no banco
     */
    async salvarDocumentoFiscal(dados) {
        try {
            const { data, error } = await supabase
                .from('documentos_fiscais')
                .insert([dados])
                .select()
                .single();

            if (error) throw error;
            return data;
        } catch (error) {
            console.error('Erro ao salvar documento fiscal:', error);
            throw error;
        }
    },

    /**
     * Verificar status do certificado digital
     */
    async verificarCertificado() {
        try {
            const config = await this.getConfig();
            
            if (!config.certificado_validade) {
                return { valido: false, mensagem: 'Certificado não configurado' };
            }
            
            const validade = new Date(config.certificado_validade);
            const hoje = new Date();
            const diasRestantes = Math.ceil((validade - hoje) / (1000 * 60 * 60 * 24));
            
            return {
                valido: diasRestantes > 0,
                validade: config.certificado_validade,
                diasRestantes,
                mensagem: diasRestantes > 30 ? 'Certificado válido' :
                         diasRestantes > 0 ? `Certificado expira em ${diasRestantes} dias` :
                         'Certificado expirado!'
            };
        } catch (error) {
            console.error('Erro ao verificar certificado:', error);
            return { valido: false, mensagem: 'Erro ao verificar certificado' };
        }
    },

    /**
     * Teste de conexão com Focus NFe
     */
    async testarConexao() {
        try {
            const config = await this.getConfig();
            
            // Verificar se tem CNPJ configurado
            if (!config.cnpj) {
                return {
                    success: false,
                    mensagem: 'CNPJ da empresa não configurado. Configure em: Configurações da Empresa → Dados Fiscais'
                };
            }
            
            // Remover formatação do CNPJ (apenas números)
            const cnpj = config.cnpj.replace(/\D/g, '');
            
            // Testar endpoint de inutilizações com o CNPJ
            const result = await this.makeRequest(`/v2/nfce/inutilizacoes?cnpj=${cnpj}`, 'GET');
            
            console.log('🎯 Resultado do teste:', result);
            
            // Se chegou aqui com sucesso_conexao, significa que a API respondeu
            if (result.sucesso_conexao) {
                return { 
                    success: true, 
                    ambiente: config.focusnfe_ambiente === 1 ? 'Produção' : 'Homologação',
                    mensagem: 'Conexão estabelecida com sucesso! Token válido e Edge Function operacional.',
                    metodo: 'Edge Function (sem CORS)',
                    detalhes: 'API Focus NFe respondeu corretamente'
                };
            }
            
            // Resposta normal (lista vazia ou dados)
            return { 
                success: true, 
                ambiente: config.focusnfe_ambiente === 1 ? 'Produção' : 'Homologação',
                mensagem: 'Conexão estabelecida com sucesso! Token válido, CNPJ aceito.',
                metodo: 'Edge Function (sem CORS)',
                dados: result
            };
        } catch (error) {
            console.error('❌ Erro no teste:', error);
            
            return { 
                success: false, 
                mensagem: error.message || 'Erro de conexão'
            };
        }
    },

    // =====================================================
    // CONSULTA NFE DE TERCEIROS (FORNECEDORES)
    // =====================================================

    /**
     * Consultar NFe de terceiro pela chave de acesso
     * Usado para importar notas de fornecedores
     */
    async consultarNFeTerceiro(chaveAcesso) {
        try {
            // Validar chave (44 dígitos)
            const chave = chaveAcesso.replace(/\D/g, '');
            if (chave.length !== 44) {
                throw new Error('Chave de acesso inválida. Deve ter 44 dígitos.');
            }

            console.log('🔍 Consultando NFe de terceiro:', chave);

            // Consultar NFe via Focus NFe
            // Endpoint: GET /v2/nfe_terceiros/{chave}
            const result = await this.makeRequest(`/v2/nfe_terceiros/${chave}`, 'GET');

            console.log('📦 Dados da NFe:', result);

            // Estruturar resposta
            return {
                success: true,
                chave: chave,
                ...result
            };

        } catch (error) {
            console.error('❌ Erro ao consultar NFe de terceiro:', error);
            throw error;
        }
    },

    /**
     * Baixar XML da NFe de terceiro
     */
    async baixarXMLTerceiro(chaveAcesso) {
        try {
            const chave = chaveAcesso.replace(/\D/g, '');
            if (chave.length !== 44) {
                throw new Error('Chave de acesso inválida.');
            }

            const config = await this.getConfig();
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            // Endpoint: GET /v2/nfe_terceiros/{chave}.xml
            const response = await fetch(`${baseUrl}/v2/nfe_terceiros/${chave}.xml`, {
                method: 'GET',
                headers: this.getHeaders(config.focusnfe_token)
            });

            if (!response.ok) {
                throw new Error('Erro ao baixar XML');
            }

            return await response.text();

        } catch (error) {
            console.error('❌ Erro ao baixar XML de terceiro:', error);
            throw error;
        }
    },

    /**
     * Manifestar destinatário (ciência, confirmação, desconhecimento, não realizada)
     */
    async manifestarDestinatario(chaveAcesso, tipoEvento, justificativa = null) {
        try {
            const chave = chaveAcesso.replace(/\D/g, '');
            
            const eventos = {
                'ciencia': '210210',        // Ciência da Operação
                'confirmacao': '210200',    // Confirmação da Operação
                'desconhecimento': '210220', // Desconhecimento da Operação
                'nao_realizada': '210240'   // Operação Não Realizada
            };

            const codigoEvento = eventos[tipoEvento];
            if (!codigoEvento) {
                throw new Error('Tipo de evento inválido');
            }

            const payload = {
                tipo_evento: codigoEvento
            };

            // Justificativa obrigatória para "nao_realizada"
            if (tipoEvento === 'nao_realizada') {
                if (!justificativa || justificativa.length < 15) {
                    throw new Error('Justificativa obrigatória (mínimo 15 caracteres)');
                }
                payload.justificativa = justificativa;
            }

            // Endpoint: POST /v2/nfe/{chave}/manifesto
            const result = await this.makeRequest(`/v2/nfe/${chave}/manifesto`, 'POST', payload);

            return {
                success: result.status === 'sucesso',
                ...result
            };

        } catch (error) {
            console.error('❌ Erro ao manifestar destinatário:', error);
            throw error;
        }
    }
};

// Exportar para uso global
window.FocusNFe = FocusNFe;
