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
            const config = await this.getConfig();
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            // Gerar referência única
            const ref = `NFCE-${Date.now()}-${venda.numero_venda}`;
            
            // Montar payload
            const payload = this.montarPayloadNFCe(config, venda, itens, pagamentos, cliente);
            
            console.log('📤 Enviando NFC-e para Focus NFe:', ref);
            
            const response = await fetch(`${baseUrl}/v2/nfce?ref=${ref}`, {
                method: 'POST',
                headers: this.getHeaders(config.focusnfe_token),
                body: JSON.stringify(payload)
            });

            const result = await response.json();
            
            // Salvar documento fiscal no banco
            await this.salvarDocumentoFiscal({
                tipo: 'NFCE',
                venda_id: venda.id,
                cliente_id: cliente?.id,
                focusnfe_ref: ref,
                valor_total: venda.total,
                status: result.status === 'autorizado' ? 'AUTORIZADA' : 
                       result.status === 'processando_autorizacao' ? 'PROCESSANDO' : 'REJEITADA',
                status_sefaz: result.status_sefaz,
                motivo_sefaz: result.mensagem_sefaz,
                chave: result.chave_nfe,
                protocolo: result.protocolo,
                focusnfe_url_danfe: result.caminho_danfe,
                focusnfe_url_xml: result.caminho_xml_nota_fiscal
            });

            return {
                success: result.status !== 'erro_autorizacao',
                ref,
                ...result
            };

        } catch (error) {
            console.error('❌ Erro ao emitir NFC-e:', error);
            throw error;
        }
    },

    /**
     * Montar payload da NFC-e conforme especificação Focus NFe
     */
    montarPayloadNFCe(config, venda, itens, pagamentos, cliente) {
        const naturezaOperacao = 'VENDA AO CONSUMIDOR';
        
        const payload = {
            // Identificação
            natureza_operacao: naturezaOperacao,
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
            
            // Itens
            items: itens.map((item, index) => ({
                numero_item: index + 1,
                codigo_produto: item.codigo_barras || item.produto_id.substring(0, 14),
                codigo_barras_comercial: item.codigo_barras || '',
                descricao: item.descricao.substring(0, 120),
                codigo_ncm: item.ncm || '22021000', // NCM padrão bebidas
                cfop: item.cfop || '5102',
                unidade_comercial: item.unidade || 'UN',
                quantidade_comercial: item.quantidade,
                valor_unitario_comercial: item.preco_unitario,
                valor_bruto: item.subtotal + (item.desconto_valor || 0),
                valor_desconto: item.desconto_valor || 0,
                
                // Tributação
                icms_origem: 0, // Nacional
                icms_situacao_tributaria: item.cst_icms || '102', // Simples Nacional
                icms_aliquota: item.aliquota_icms || 0,
                
                // PIS/COFINS
                pis_situacao_tributaria: '49', // Outras operações de saída
                cofins_situacao_tributaria: '49'
            })),
            
            // Formas de pagamento
            formas_pagamento: pagamentos.map(pag => ({
                forma_pagamento: this.mapearFormaPagamento(pag.tipo),
                valor_pagamento: pag.valor,
                tipo_integracao: pag.tipo === 'CREDITO' || pag.tipo === 'DEBITO' ? 1 : 2,
                cnpj_credenciadora: pag.cnpj_credenciadora,
                bandeira_operadora: this.mapearBandeira(pag.bandeira),
                numero_autorizacao: pag.nsu
            }))
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
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            const ref = `NFE-${Date.now()}-${venda.numero_venda}`;
            const payload = this.montarPayloadNFe(config, venda, itens, cliente, transportadora);
            
            console.log('📤 Enviando NF-e para Focus NFe:', ref);
            
            const response = await fetch(`${baseUrl}/v2/nfe?ref=${ref}`, {
                method: 'POST',
                headers: this.getHeaders(config.focusnfe_token),
                body: JSON.stringify(payload)
            });

            const result = await response.json();
            
            await this.salvarDocumentoFiscal({
                tipo: 'NFE',
                venda_id: venda.id,
                cliente_id: cliente?.id,
                focusnfe_ref: ref,
                valor_total: venda.total,
                status: result.status === 'autorizado' ? 'AUTORIZADA' : 
                       result.status === 'processando_autorizacao' ? 'PROCESSANDO' : 'REJEITADA',
                status_sefaz: result.status_sefaz,
                motivo_sefaz: result.mensagem_sefaz,
                chave: result.chave_nfe,
                protocolo: result.protocolo,
                focusnfe_url_danfe: result.caminho_danfe,
                focusnfe_url_xml: result.caminho_xml_nota_fiscal
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
            const config = await this.getConfig();
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            const response = await fetch(`${baseUrl}/v2/${tipo}/${ref}`, {
                method: 'GET',
                headers: this.getHeaders(config.focusnfe_token)
            });

            return await response.json();
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

            const config = await this.getConfig();
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            const response = await fetch(`${baseUrl}/v2/${tipo}/${ref}`, {
                method: 'DELETE',
                headers: this.getHeaders(config.focusnfe_token),
                body: JSON.stringify({ justificativa })
            });

            const result = await response.json();
            
            // Atualizar status no banco
            if (result.status === 'cancelado') {
                await supabase
                    .from('documentos_fiscais')
                    .update({
                        status: 'CANCELADA',
                        cancelado: true,
                        justificativa_cancelamento: justificativa,
                        data_cancelamento: new Date().toISOString(),
                        protocolo_cancelamento: result.protocolo
                    })
                    .eq('focusnfe_ref', ref);
            }

            return result;
        } catch (error) {
            console.error('❌ Erro ao cancelar documento:', error);
            throw error;
        }
    },

    /**
     * Baixar DANFE (PDF)
     */
    async baixarDANFE(ref, tipo = 'nfce') {
        try {
            const config = await this.getConfig();
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            const response = await fetch(`${baseUrl}/v2/${tipo}/${ref}.pdf`, {
                method: 'GET',
                headers: this.getHeaders(config.focusnfe_token)
            });

            if (!response.ok) {
                throw new Error('Erro ao baixar DANFE');
            }

            const blob = await response.blob();
            return URL.createObjectURL(blob);
        } catch (error) {
            console.error('❌ Erro ao baixar DANFE:', error);
            throw error;
        }
    },

    /**
     * Baixar XML
     */
    async baixarXML(ref, tipo = 'nfce') {
        try {
            const config = await this.getConfig();
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            const response = await fetch(`${baseUrl}/v2/${tipo}/${ref}.xml`, {
                method: 'GET',
                headers: this.getHeaders(config.focusnfe_token)
            });

            return await response.text();
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
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            const ref = `INUT-${tipo.toUpperCase()}-${Date.now()}`;
            
            const response = await fetch(`${baseUrl}/v2/${tipo}_inutilizacao?ref=${ref}`, {
                method: 'POST',
                headers: this.getHeaders(config.focusnfe_token),
                body: JSON.stringify({
                    cnpj: config.cnpj?.replace(/\D/g, ''),
                    serie,
                    numero_inicial: numeroInicial,
                    numero_final: numeroFinal,
                    justificativa
                })
            });

            return await response.json();
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
            const baseUrl = this.getBaseUrl(config.focusnfe_ambiente);
            
            const response = await fetch(`${baseUrl}/v2/nfce?completa=0`, {
                method: 'GET',
                headers: this.getHeaders(config.focusnfe_token)
            });

            if (response.ok) {
                return { 
                    success: true, 
                    ambiente: config.focusnfe_ambiente === 1 ? 'Produção' : 'Homologação',
                    mensagem: 'Conexão estabelecida com sucesso!'
                };
            } else {
                const error = await response.json();
                return { success: false, mensagem: error.mensagem || 'Erro de autenticação' };
            }
        } catch (error) {
            return { success: false, mensagem: 'Erro de conexão: ' + error.message };
        }
    }
};

// Exportar para uso global
window.FocusNFe = FocusNFe;
