/**
 * Serviço de Integração com API Nuvem Fiscal
 * Documentação: https://dev.nuvemfiscal.com.br/docs/api/
 * 
 * Funcionalidades:
 * - Emissão, consulta e cancelamento de NFC-e
 * - Download de PDF (DANFCE) e XML
 * - Consulta de CEP (endereços)
 * - Consulta de CNPJ (dados cadastrais de empresas)
 * - Consulta de status SEFAZ
 */

class NuvemFiscalService {
    constructor() {
        this.baseURL = 'https://api.nuvemfiscal.com.br';
        this.authURL = 'https://auth.nuvemfiscal.com.br';
        this.clientId = null;
        this.clientSecret = null;
        this.accessToken = null;
        this.tokenExpiry = null;
        this.ambiente = 'homologacao'; // 'homologacao' ou 'producao'
    }

    /**
     * Carregar configuração da empresa do banco de dados
     * ⚠️ IMPORTANTE: Se o token foi gerado ANTES de adicionar 'distribuicao-nfe' ao escopo,
     *               ele precisa ser regenerado para ter as novas permissões!
     */
    async carregarConfig() {
        try {
            const { data: config, error } = await supabase
                .from('empresa_config')
                .select('nuvemfiscal_client_id, nuvemfiscal_client_secret, nuvemfiscal_access_token, nuvemfiscal_token_expiry, nuvemfiscal_ambiente, focusnfe_ambiente, cnpj')
                .single();

            if (error) throw error;

            this.clientId = config.nuvemfiscal_client_id;
            this.clientSecret = config.nuvemfiscal_client_secret;
            this.accessToken = config.nuvemfiscal_access_token;
            this.tokenExpiry = config.nuvemfiscal_token_expiry ? new Date(config.nuvemfiscal_token_expiry) : null;
            
            // 🔧 Determinar ambiente - PRIORIDADE:
            // 1. nuvemfiscal_ambiente (específico Nuvem Fiscal)
            // 2. focusnfe_ambiente (fallback)
            let ambienteConfig = config.nuvemfiscal_ambiente || config.focusnfe_ambiente || 2;
            
            // Normalizar: 1=produção, 2=homologação
            ambienteConfig = parseInt(ambienteConfig) || 2;
            this.ambiente = ambienteConfig === 1 ? 'producao' : 'homologacao';
            
            console.log('⚙️ [NuvemFiscal] Ambiente carregado:', {
                nuvemfiscal_ambiente: config.nuvemfiscal_ambiente,
                focusnfe_ambiente: config.focusnfe_ambiente,
                ambienteResolvido: this.ambiente
            });

            if (!this.clientId || !this.clientSecret) {
                throw new Error('Credenciais da Nuvem Fiscal não configuradas. Acesse Configurações da Empresa.');
            }

            return config;
        } catch (erro) {
            console.error('Erro ao carregar configuração:', erro);
            throw erro;
        }
    }

    /**
     * Obter access token OAuth2
     * Usa token em cache se válido, caso contrário requisita novo
     */
    async getAccessToken() {
        try {
            // Verificar se há token em cache válido
            if (this.accessToken && this.tokenExpiry && new Date() < this.tokenExpiry) {
                return this.accessToken;
            }

            // Carregar credenciais se não estiverem carregadas
            if (!this.clientId || !this.clientSecret) {
                await this.carregarConfig();
            }

            // Requisitar novo token OAuth2
            // Documentação: https://dev.nuvemfiscal.com.br/docs/autenticacao/
            // Escopos necessários para funcionalidades completas
            const scopes = 'empresa cep cnpj nfe nfce nfse cte mdfe distribuicao-nfe';
            const params = new URLSearchParams({
                grant_type: 'client_credentials',
                client_id: this.clientId,
                client_secret: this.clientSecret,
                scope: scopes
            });

            const response = await fetch(`${this.authURL}/oauth/token`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/x-www-form-urlencoded'
                },
                body: params.toString()
            });

            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(`Erro ao obter token OAuth2: ${response.status} - ${errorText}`);
            }

            const tokenData = await response.json();
            
            // Armazenar token e expiry
            this.accessToken = tokenData.access_token;
            
            // Calcular data de expiração (expires_in vem em segundos)
            const expiresInMs = tokenData.expires_in * 1000;
            this.tokenExpiry = new Date(Date.now() + expiresInMs);

            // Salvar token em cache no banco de dados
            await this.salvarTokenCache();

            return this.accessToken;

        } catch (erro) {
            console.error('Erro ao obter access token OAuth2:', erro);
            throw erro;
        }
    }

    /**
     * Forçar geração de novo token OAuth2 (útil quando escopos mudam)
     * Limpa o token em cache e solicita um novo
     */
    async forceNewToken() {
        try {
            console.log('🔄 [NuvemFiscal] Limpando token em cache e gerando novo...');
            
            // Limpar token em cache
            this.accessToken = null;
            this.tokenExpiry = null;
            
            // Limpar do banco de dados
            const { data: config } = await supabase
                .from('empresa_config')
                .select('id')
                .single();

            if (config) {
                await supabase
                    .from('empresa_config')
                    .update({
                        nuvemfiscal_access_token: null,
                        nuvemfiscal_token_expiry: null
                    })
                    .eq('id', config.id);
            }

            // Solicitar novo token
            const novoToken = await this.getAccessToken();
            console.log('✅ [NuvemFiscal] Novo token gerado com sucesso');
            return novoToken;
        } catch (erro) {
            console.error('Erro ao regenerar token:', erro);
            throw erro;
        }
    }

    /**
     * Salvar token em cache no banco de dados
     */
    async salvarTokenCache() {
        try {
            // Buscar o ID da empresa_config
            const { data: config } = await supabase
                .from('empresa_config')
                .select('id')
                .single();

            if (!config) return;

            const { error } = await supabase
                .from('empresa_config')
                .update({
                    nuvemfiscal_access_token: this.accessToken,
                    nuvemfiscal_token_expiry: this.tokenExpiry.toISOString()
                })
                .eq('id', config.id);

            if (error) {
                console.error('Erro ao salvar token em cache:', error);
            }
        } catch (erro) {
            console.error('Erro ao salvar token em cache:', erro);
        }
    }

    /**
     * Fazer requisição HTTP para a API
     */
    async request(endpoint, method = 'GET', body = null, headers = {}) {
        try {
            // Obter access token válido (usa cache ou requisita novo)
            const token = await this.getAccessToken();

            const url = `${this.baseURL}${endpoint}`;
            const options = {
                method,
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                    'Accept': 'application/json',
                    ...headers
                }
            };

            if (body && method !== 'GET') {
                options.body = JSON.stringify(body);
                console.log('📤 [NuvemFiscal] Request:', { url, method, body });
            }

            const response = await fetch(url, options);
            
            // Para downloads de arquivos (PDF, XML)
            if (headers.Accept && headers.Accept !== 'application/json') {
                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error(`Erro ${response.status}: ${errorText}`);
                }
                return await response.blob();
            }

            const data = await response.json();
            
            console.log('📥 [NuvemFiscal] Response:', { status: response.status, data });

            if (!response.ok) {
                // Tentar extrair mensagens de erro detalhadas
                let mensagemErro = `Erro HTTP ${response.status}`;
                let codigoErro = null;
                
                // Estrutura de erro com "{error: {code, message}}"
                if (data.error && data.error.code && data.error.message) {
                    codigoErro = data.error.code;
                    mensagemErro = `[${data.error.code}] ${data.error.message}`;
                } else if (data.mensagens && Array.isArray(data.mensagens)) {
                    mensagemErro = data.mensagens.map(m => `[${m.codigo}] ${m.mensagem}`).join('; ');
                } else if (data.mensagem) {
                    mensagemErro = data.mensagem;
                } else if (data.erro) {
                    mensagemErro = data.erro;
                } else if (data.erros) {
                    mensagemErro = JSON.stringify(data.erros);
                }
                
                console.error('❌ [NuvemFiscal] Erro detalhado:', data);
                
                const erro = new Error(mensagemErro);
                erro.code = codigoErro;
                erro.status = response.status;
                erro.details = data;
                throw erro;
            }

            return data;
        } catch (erro) {
            console.error('❌ [NuvemFiscal] Erro na requisição:', erro);
            throw erro;
        }
    }

    // ===================================
    // MÉTODOS NFC-E
    // ===================================

    /**
     * Emitir NFC-e
     * POST /nfce
     * @param {Object} dadosNFCe - Dados completos da NFCe no formato da API
     * @returns {Object} Resposta da API com id, status, chave, etc
     */
    async emitirNFCe(dadosNFCe) {
        try {
            // ✅ CORREÇÃO: Extrair chave da NFC-e corretamente
            // A chave pode estar em:
            // 1. dadosNFCe.chave_acesso (se já foi calculada)
            // 2. dadosNFCe.infNFe.Id (no formato "NFe" + chave de 44 dígitos)
            // 3. Precisar ser calculada a partir dos campos (último caso)
            
            let chaveNFCe = null;
            
            // Tentar extrair da chave pré-calculada
            if (dadosNFCe?.chave_acesso) {
                chaveNFCe = dadosNFCe.chave_acesso;
            } 
            // Tentar extrair do atributo Id da infNFe (formato: "NFe" + 44 dígitos)
            else if (dadosNFCe?.infNFe?.Id) {
                const id = dadosNFCe.infNFe.Id;
                // Remove "NFe" do início se existir
                chaveNFCe = id.replace(/^NFe/i, '');
            }
            // Tentar montar a partir dos componentes (UF, AAMM, CNPJ, modelo, série, número, etc)
            else if (dadosNFCe?.infNFe?.ide) {
                const ide = dadosNFCe.infNFe.ide;
                const emit = dadosNFCe?.infNFe?.emit;
                
                // Validar se temos os campos mínimos
                if (ide.cUF && ide.dhEmi && emit?.CNPJ && ide.mod && ide.serie && ide.nNF && ide.cNF && ide.cDV) {
                    // Montar chave (44 dígitos): UF(2) + AAMM(4) + CNPJ(14) + mod(2) + serie(3) + nNF(9) + tpEmis(1) + cNF(8) + DV(1)
                    const aamm = ide.dhEmi.substring(2, 4) + ide.dhEmi.substring(5, 7); // AAMM do dhEmi
                    const cnpj = emit.CNPJ.padStart(14, '0');
                    const modelo = String(ide.mod).padStart(2, '0');
                    const serie = String(ide.serie).padStart(3, '0');
                    const numero = String(ide.nNF).padStart(9, '0');
                    const tpEmis = String(ide.tpEmis || '1').padStart(1, '0');
                    const codNumerico = String(ide.cNF).padStart(8, '0');
                    const dv = String(ide.cDV).padStart(1, '0');
                    
                    chaveNFCe = `${ide.cUF}${aamm}${cnpj}${modelo}${serie}${numero}${tpEmis}${codNumerico}${dv}`;
                } else {
                    console.warn('⚠️ [NuvemFiscal] Campos insuficientes para montar chave da NFC-e');
                }
            }
            
            // Se não conseguiu extrair a chave, apenas avisa mas permite continuar
            // (a API pode gerar/validar a chave internamente)
            if (!chaveNFCe || chaveNFCe.length !== 44) {
                console.warn('⚠️ [NuvemFiscal] Chave da NFC-e não encontrada ou inválida:', chaveNFCe);
                console.warn('⚠️ [NuvemFiscal] Continuando sem validação prévia (a API fará a validação)');
                // NÃO lançar erro aqui, permitir que a API processe
            } else {
                console.log('🔍 [NuvemFiscal] Chave da NFC-e extraída:', chaveNFCe);
                
                // Tentar consultar documento anterior
                try {
                    const docAnterior = await this.consultarNFCe(chaveNFCe);
                    if (docAnterior && docAnterior.status === 'autorizado') {
                        throw new Error(`❌ NFC-e com chave ${chaveNFCe} já foi AUTORIZADA anteriormente (Status: ${docAnterior.status}). Não é possível emitir novamente. Verifique o número sequencial da NFC-e.`);
                    }
                    if (docAnterior && docAnterior.status === 'cancelado') {
                        throw new Error(`❌ NFC-e com chave ${chaveNFCe} já foi CANCELADA anteriormente. Não é possível reemitir um documento cancelado.`);
                    }
                    if (docAnterior && docAnterior.status === 'rejeitado') {
                        console.warn('⚠️ [NuvemFiscal] NFC-e anterior foi rejeitada, permitindo nova tentativa...');
                    }
                } catch (erroConsulta) {
                    // Se não encontrar (erro 404), é normal - documento novo
                    if (!erroConsulta.message?.includes('404') && !erroConsulta.message?.includes('não encontrado')) {
                        console.warn('⚠️ [NuvemFiscal] Não foi possível validar documento anterior:', erroConsulta.message);
                    }
                }
            }

            console.log('✅ [NuvemFiscal] Documento validado, prosseguindo com emissão...');
            
            // 🔍 Extrair ambiente do payload (já foi definido corretamente em montarPayloadNFCe)
            const tpAmbDoPayload = dadosNFCe?.infNFe?.ide?.tpAmb || 2;
            const ambienteDoPayload = tpAmbDoPayload === 1 ? 'producao' : 'homologacao';
            
            // Atualizar this.ambiente com o valor correto do payload
            this.ambiente = ambienteDoPayload;
            
            console.log('🚀 [NuvemFiscal] Estado ambiente:', { 
                ambienteDoPayload,
                tpAmbDoPayload,
                ambiente_this: this.ambiente 
            });
            
            // Adicionar ambiente aos dados (string: 'homologacao' ou 'producao')
            const payload = {
                ...dadosNFCe,
                ambiente: this.ambiente  // Use o ambiente extraído do payload
            };
            
            // 🔍 Validação dupla para detectar se ainda há conflito
            const tpAmbPayload = payload.infNFe?.ide?.tpAmb || 2;
            const tpAmbEsperado = this.ambiente === 'producao' ? 1 : 2;
            
            if (tpAmbPayload !== tpAmbEsperado) {
                console.warn('⚠️ [NuvemFiscal] CONFLITO DE AMBIENTE DETECTADO!');
                console.warn('   Payload tpAmb:', tpAmbPayload === 1 ? 'PRODUÇÃO' : 'HOMOLOGAÇÃO');
                console.warn('   Ambiente esperado:', this.ambiente.toUpperCase());
                console.warn('   AJUSTANDO PAYLOAD PARA CORRESPONDER...');
                payload.infNFe.ide.tpAmb = tpAmbEsperado;
            }
            
            console.log('🚀 [NuvemFiscal] Enviando NFC-e:', {
                ambiente_empresa: this.ambiente,
                tpAmb_payload: payload.infNFe?.ide?.tpAmb,
                cMunFG: payload.infNFe?.ide?.cMunFG,
                cMun: payload.infNFe?.emit?.enderEmit?.cMun
            });

            try {
                const resultado = await this.request('/nfce', 'POST', payload);

                // ✅ Emissão bem-sucedida
                console.log('✅ [NuvemFiscal] NFC-e emitida com sucesso!');
                
                // Se retornar status "pendente", aguardar processamento
                if (resultado.status === 'pendente') {
                    return await this.aguardarProcessamento(resultado.id);
                }

                return resultado;
            } catch (erroEmissao) {
                // Tratamento específico para ValidationFailed
                if (erroEmissao.code === 'ValidationFailed') {
                    console.error('🛑 [NuvemFiscal] ERRO ValidationFailed:', erroEmissao.message);
                    
                    // Diagnosticar conflito de ambiente
                    if (erroEmissao.message?.includes('ambiente')) {
                        console.error('   ❌ Provável CONFLITO DE AMBIENTE!');
                        console.error('   Empresa configurada para:', this.ambiente.toUpperCase());
                        console.error('   Payload enviou:', payload.infNFe?.ide?.tpAmb === 1 ? 'PRODUÇÃO' : 'HOMOLOGAÇÃO');
                        console.error('   SOLUÇÃO: Verifique "nuvemfiscal_ambiente" em Configurações da Empresa');
                    }
                    
                    // Tentar obter status atual do documento para diagnóstico
                    try {
                        const statusAtual = await this.consultarNFCe(chaveNFCe);
                        erroEmissao.message += ` [Status atual: ${statusAtual.status}]`;
                    } catch (e) {
                        // Se erro ao consultar, continuar com mensagem anterior
                    }
                }
                throw erroEmissao;
            }
        } catch (erro) {
            console.error('Erro ao emitir NFC-e:', erro);
            throw erro;
        }
    }

    /**
     * Consultar NFC-e
     * GET /nfce/{id}
     * @param {string} id - ID da NFC-e retornado na emissão
     * @returns {Object} Status e dados completos da NFC-e com método para obter PDF
     */
    async consultarNFCe(id) {
        try {
            const resultado = await this.request(`/nfce/${id}`, 'GET');
            
            // Adicionar método para baixar PDF autenticado
            // O PDF da Nuvem Fiscal precisa do token Bearer
            if (resultado && resultado.id) {
                resultado.obterPDF = async () => {
                    const token = await this.getAccessToken();
                    const response = await fetch(`${this.baseURL}/nfce/${resultado.id}/pdf`, {
                        headers: {
                            'Authorization': `Bearer ${token}`,
                            'Accept': 'application/pdf'
                        }
                    });
                    
                    if (!response.ok) {
                        throw new Error(`Erro ao baixar PDF: ${response.status}`);
                    }
                    
                    const blob = await response.blob();
                    const url = URL.createObjectURL(blob);
                    return url;
                };
                
                // Para compatibilidade, adicionar flag indicando que precisa usar obterPDF()
                resultado.caminho_danfe = 'USE_OBTER_PDF_METHOD';
            }
            
            return resultado;
        } catch (erro) {
            console.error('Erro ao consultar NFC-e:', erro);
            throw erro;
        }
    }

    /**
     * Aguardar processamento assíncrono da NFC-e
     * Faz polling até status diferente de "pendente"
     */
    async aguardarProcessamento(id, maxTentativas = 30, intervalo = 2000) {
        for (let i = 0; i < maxTentativas; i++) {
            const resultado = await this.consultarNFCe(id);
            
            if (resultado.status !== 'pendente') {
                return resultado;
            }

            // Aguardar antes da próxima tentativa
            await new Promise(resolve => setTimeout(resolve, intervalo));
        }

        throw new Error('Timeout: NFC-e ainda está sendo processada após múltiplas tentativas');
    }

    /**
     * Cancelar NFC-e
     * POST /nfce/{id}/cancelamento
     * @param {string} id - ID da NFC-e
     * @param {string} justificativa - Motivo do cancelamento (min 15 caracteres)
     * @returns {Object} Resultado do cancelamento
     */
    async cancelarNFCe(id, justificativa) {
        try {
            if (!justificativa || justificativa.length < 15) {
                throw new Error('Justificativa deve ter no mínimo 15 caracteres');
            }

            // Validação pré-cancelamento: verificar se documento está autorizado e dentro do prazo
            console.log('🔍 [NuvemFiscal] Validando estado anterior da NFC-e para cancelamento ID:', id);
            
            try {
                const docAtual = await this.consultarNFCe(id);
                console.log('📋 [NuvemFiscal] Status atual do documento:', { id, status: docAtual.status });
                
                if (!docAtual || !docAtual.status) {
                    throw new Error(`❌ Documento com ID ${id} não encontrado ou sem status válido.`);
                }
                
                if (docAtual.status === 'cancelado') {
                    throw new Error(`❌ NFC-e já foi CANCELADA anteriormente. Não é possível cancelar novamente.`);
                }
                
                if (docAtual.status !== 'autorizado') {
                    throw new Error(`❌ NFC-e não está em estado autorizado. Status atual: "${docAtual.status}". Apenas documentos autorizados podem ser cancelados.`);
                }

                // Verificar janela de cancelamento (NFC-e: 30min, NF-e: 24h)
                if (docAtual.data_autorizacao) {
                    const dataAutorizacao = new Date(docAtual.data_autorizacao);
                    const agora = new Date();
                    const minutosPassados = (agora - dataAutorizacao) / 1000 / 60;
                    
                    // NFC-e tem janela de 30 minutos
                    if (minutosPassados > 30) {
                        console.warn(`⚠️ [NuvemFiscal] NFC-e foi autorizada há ${Math.floor(minutosPassados)} minutos. A janela de cancelamento é de 30 minutos.`);
                        // Continuar mesmo assim - deixar SEFAZ decidir
                    }
                }
                
                console.log('✅ [NuvemFiscal] Documento validado, prosseguindo com cancelamento...');
            } catch (erroConsulta) {
                console.error('⚠️ [NuvemFiscal] Erro ao validar documento para cancelamento:', erroConsulta.message);
                // Continuar com o cancelamento mesmo assim
            }

            const payload = {
                justificativa: justificativa
            };

            try {
                const resultado = await this.request(`/nfce/${id}/cancelamento`, 'POST', payload);

                // Se retornar status "pendente", aguardar processamento
                if (resultado.status === 'pendente') {
                    return await this.aguardarProcessamento(resultado.id);
                }

                return resultado;
            } catch (erroCancelamento) {
                // Tratamento específico para ValidationFailed
                if (erroCancelamento.code === 'ValidationFailed') {
                    console.error('🛑 [NuvemFiscal] Erro de validação SEFAZ ao cancelar:', erroCancelamento.message);
                    
                    // Tentar obter status atual do documento para diagnóstico
                    try {
                        const statusAtual = await this.consultarNFCe(id);
                        erroCancelamento.message += ` [Status atual: ${statusAtual.status}]`;
                    } catch (e) {
                        // Se erro ao consultar, continuar com mensagem anterior
                    }
                }
                throw erroCancelamento;
            }
        } catch (erro) {
            console.error('Erro ao cancelar NFC-e:', erro);
            throw erro;
        }
    }

    /**
     * Baixar PDF da NFC-e (DANFCE)
     * GET /nfce/{id}/pdf
     * @param {string} id - ID da NFC-e
     * @returns {Blob} Arquivo PDF
     */
    async baixarPDF(id) {
        try {
            return await this.request(`/nfce/${id}/pdf`, 'GET', null, {
                'Accept': 'application/pdf'
            });
        } catch (erro) {
            console.error('Erro ao baixar PDF:', erro);
            throw erro;
        }
    }

    /**
     * Baixar XML da NFC-e (nota completa)
     * GET /nfce/{id}/xml/nota - XML completo da NFC-e
     * @param {string} id - ID da NFC-e na Nuvem Fiscal
     * @returns {Blob} Arquivo XML
     */
    async baixarXML(id) {
        try {
            console.log('📥 [NuvemFiscal] Baixando XML da NFC-e:', id);
            
            const blob = await this.request(`/nfce/${id}/xml/nota`, 'GET', null, {
                'Accept': 'application/xml'
            });
            
            if (!blob || blob.size === 0) {
                throw new Error('XML recebido vazio da Nuvem Fiscal');
            }

            console.log('✅ [NuvemFiscal] XML baixado com sucesso, tamanho:', blob.size);
            this._triggerDownload(blob, `NFCE-${id}.xml`);
            return blob;
        } catch (erro) {
            console.error('❌ Erro ao baixar XML:', erro);
            throw erro;
        }
    }

    /**
     * Baixar XML de cancelamento da NFC-e
     * GET /nfce/{id}/cancelamento/xml
     * @param {string} id - ID da NFC-e na Nuvem Fiscal
     * @returns {Blob} Arquivo XML do cancelamento
     */
    async baixarXMLCancelamento(id) {
        try {
            console.log('📥 [NuvemFiscal] Baixando XML de cancelamento da NFC-e:', id);
            
            const blob = await this.request(`/nfce/${id}/cancelamento/xml`, 'GET', null, {
                'Accept': 'application/xml'
            });
            
            if (!blob || blob.size === 0) {
                throw new Error('XML de cancelamento recebido vazio da Nuvem Fiscal');
            }

            console.log('✅ [NuvemFiscal] XML de cancelamento baixado, tamanho:', blob.size);
            this._triggerDownload(blob, `NFCE-CANCELAMENTO-${id}.xml`);
            return blob;
        } catch (erro) {
            console.error('❌ Erro ao baixar XML de cancelamento:', erro);
            throw erro;
        }
    }

    /**
     * Baixar PDF de cancelamento da NFC-e
     * GET /nfce/{id}/cancelamento/pdf
     * @param {string} id - ID da NFC-e na Nuvem Fiscal
     * @returns {Blob} Arquivo PDF do cancelamento
     */
    async baixarPDFCancelamento(id) {
        try {
            console.log('📥 [NuvemFiscal] Baixando PDF de cancelamento da NFC-e:', id);
            
            const blob = await this.request(`/nfce/${id}/cancelamento/pdf`, 'GET', null, {
                'Accept': 'application/pdf'
            });
            
            if (!blob || blob.size === 0) {
                throw new Error('PDF de cancelamento recebido vazio da Nuvem Fiscal');
            }

            console.log('✅ [NuvemFiscal] PDF de cancelamento baixado, tamanho:', blob.size);
            return blob;
        } catch (erro) {
            console.error('❌ Erro ao baixar PDF de cancelamento:', erro);
            throw erro;
        }
    }

    /**
     * Obter blob do XML da NFC-e sem disparar download (para uso em ZIP bulk)
     * @param {string} id - ID da NFC-e
     * @returns {Blob}
     */
    async obterXMLBlob(id) {
        const blob = await this.request(`/nfce/${id}/xml/nota`, 'GET', null, { 'Accept': 'application/xml' });
        if (!blob || blob.size === 0) throw new Error('XML vazio retornado pela Nuvem Fiscal');
        return blob;
    }

    /**
     * Obter blob do XML de cancelamento da NFC-e sem disparar download (para uso em ZIP bulk)
     * @param {string} id - ID da NFC-e
     * @returns {Blob}
     */
    async obterXMLCancelamentoBlob(id) {
        const blob = await this.request(`/nfce/${id}/cancelamento/xml`, 'GET', null, { 'Accept': 'application/xml' });
        if (!blob || blob.size === 0) throw new Error('XML de cancelamento vazio retornado pela Nuvem Fiscal');
        return blob;
    }

    /**
     * Helper: disparar download de arquivo no navegador
     */
    _triggerDownload(blob, filename) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log('✅ [NuvemFiscal] Download iniciado:', filename);
    }

    /**
     * Consultar status do serviço SEFAZ
     * GET /nfce/sefaz/status
     * @param {string} cpfCnpj - CPF ou CNPJ da empresa
     * @param {string} uf - UF da empresa (opcional)
     * @returns {Object} Status do serviço
     */
    async consultarStatusSefaz(cpfCnpj, uf = null) {
        try {
            const cnpjLimpo = cpfCnpj.replace(/\D/g, '');
            let url = `/nfce/sefaz/status?cpf_cnpj=${cnpjLimpo}&ambiente=${this.ambiente}`;
            if (uf) {
                url += `&uf=${uf}`;
            }
            return await this.request(url, 'GET');
        } catch (erro) {
            console.error('Erro ao consultar status SEFAZ:', erro);
            throw erro;
        }
    }

    /**
     * Listar NFC-e emitidas
     * GET /nfce?cpf_cnpj={cpf_cnpj}&ambiente={ambiente}
     * @param {string} cpfCnpj - CPF ou CNPJ da empresa
     * @param {string} ambiente - 'homologacao' ou 'producao'
     * @param {number} top - Número máximo de registros (padrão: 10)
     * @returns {Object} Lista de NFC-e
     */
    async listarNFCe(cpfCnpj, ambiente = 'homologacao', top = 10, status = null) {
        try {
            const cnpjLimpo = cpfCnpj.replace(/\D/g, '');
            let url = `/nfce?cpf_cnpj=${cnpjLimpo}&ambiente=${ambiente}&$top=${top}&$orderby=data_emissao desc`;
            
            // Filtrar por status se especificado (ex: 'autorizado')
            if (status) {
                url += `&$filter=status eq '${status}'`;
            }
            
            console.log('📋 [NuvemFiscal] Listando NFC-e:', url);
            const resultado = await this.request(url, 'GET');
            console.log('📋 [NuvemFiscal] Resultado:', resultado);
            return resultado;
        } catch (erro) {
            console.error('Erro ao listar NFC-e:', erro);
            throw erro;
        }
    }

    /**
     * Configurar empresa para emissão de NFC-e
     * PUT /empresas/{cpf_cnpj}/nfce
     * Configura CRT, CSC e ambiente
     */
    async configurarEmpresa(cpfCnpj, config) {
        try {
            const cnpjLimpo = cpfCnpj.replace(/\D/g, '');
            
            const payload = {
                crt: String(config.crt), // Código de Regime Tributário como string
                id_csc: String(config.id_csc), // ID do CSC
                csc: String(config.csc), // Código de Segurança do Contribuinte
                ambiente: config.ambiente || this.ambiente
            };

            return await this.request(`/empresas/${cnpjLimpo}/nfce`, 'PUT', payload);
        } catch (erro) {
            console.error('Erro ao configurar empresa:', erro);
            throw erro;
        }
    }

    // ===================================
    // MÉTODOS DE CONSULTA
    // ===================================

    /**
     * Consultar CEP
     * GET /cep/{Cep}
     * @param {string} cep - CEP a consultar (com ou sem máscara)
     * @returns {Object} Dados do endereço
     */
    async consultarCEP(cep) {
        try {
            // Remover máscara do CEP
            const cepLimpo = cep.replace(/\D/g, '');

            if (cepLimpo.length !== 8) {
                throw new Error('CEP inválido');
            }

            const resultado = await this.request(`/cep/${cepLimpo}`, 'GET');
            
            // Retornar no formato padronizado
            return {
                cep: resultado.cep,
                logradouro: resultado.logradouro || '',
                complemento: resultado.complemento || '',
                bairro: resultado.bairro || '',
                cidade: resultado.municipio || '',
                uf: resultado.uf || '',
                codigo_ibge: resultado.codigo_ibge || '',
                tipo_logradouro: resultado.tipo_logradouro || ''
            };
        } catch (erro) {
            console.error('Erro ao consultar CEP:', erro);
            throw erro;
        }
    }

    /**
     * Consultar CNPJ
     * GET /cnpj/{Cnpj}
     * @param {string} cnpj - CNPJ a consultar (com ou sem máscara)
     * @returns {Object} Dados cadastrais da empresa
     */
    async consultarCNPJ(cnpj) {
        try {
            // Remover máscara do CNPJ
            const cnpjLimpo = cnpj.replace(/\D/g, '');

            if (cnpjLimpo.length !== 14) {
                throw new Error('CNPJ inválido');
            }

            const resultado = await this.request(`/cnpj/${cnpjLimpo}`, 'GET');

            // Retornar no formato padronizado
            return {
                cnpj: resultado.cnpj,
                razao_social: resultado.razao_social || '',
                nome_fantasia: resultado.nome_fantasia || '',
                situacao_cadastral: resultado.situacao_cadastral || '',
                data_situacao_cadastral: resultado.data_situacao_cadastral || '',
                cnae_principal: resultado.atividade_principal?.codigo || '',
                descricao_cnae: resultado.atividade_principal?.descricao || '',
                natureza_juridica: resultado.natureza_juridica?.codigo || '',
                descricao_natureza_juridica: resultado.natureza_juridica?.descricao || '',
                capital_social: resultado.capital_social || 0,
                porte: resultado.porte || '',
                data_abertura: resultado.data_inicio_atividade || '',
                
                // Endereço
                logradouro: resultado.endereco?.logradouro || '',
                numero: resultado.endereco?.numero || '',
                complemento: resultado.endereco?.complemento || '',
                bairro: resultado.endereco?.bairro || '',
                cep: resultado.endereco?.cep || '',
                cidade: resultado.endereco?.municipio || '',
                uf: resultado.endereco?.uf || '',
                
                // Contato
                telefone: resultado.telefones?.[0] || '',
                email: resultado.email || '',
                
                // Regime tributário
                simples_nacional: resultado.simples?.optante || false,
                simples_data_opcao: resultado.simples?.data_opcao || null,
                mei: resultado.mei?.optante || false,
                
                // Dados completos (caso precise acessar outros campos)
                dados_completos: resultado
            };
        } catch (erro) {
            console.error('Erro ao consultar CNPJ:', erro);
            throw erro;
        }
    }

    // ===================================
    // MÉTODOS AUXILIARES
    // ===================================

    /**
     * Obter código IBGE da UF a partir da sigla
     */
    obterCodigoUF(siglaUF) {
        const codigosUF = {
            'RO': 11, 'AC': 12, 'AM': 13, 'RR': 14, 'PA': 15, 'AP': 16, 'TO': 17,
            'MA': 21, 'PI': 22, 'CE': 23, 'RN': 24, 'PB': 25, 'PE': 26, 'AL': 27, 'SE': 28, 'BA': 29,
            'MG': 31, 'ES': 32, 'RJ': 33, 'SP': 35,
            'PR': 41, 'SC': 42, 'RS': 43,
            'MS': 50, 'MT': 51, 'GO': 52, 'DF': 53
        };
        return codigosUF[siglaUF?.toUpperCase()] || 35; // Default São Paulo
    }

    /**
     * 🔢 SINCRONIZAR NÚMERO DE NFC-e LOCALMENTE (FALLBACK)
     * Usado quando FiscalSystem não está disponível
     * Consulta banco local + API da Nuvem Fiscal
     */
    async sincronizarNumeroLocal(empresa) {
        try {
            console.log('🔄 [NuvemFiscal] Sincronizando número localmente...');
            
            // 🔧 VALOR CONFIGURADO PELO USUÁRIO (sempre usar como mínimo)
            const numeroConfigurado = parseInt(empresa.nfce_numero || 1);
            console.log('📋 Número configurado pelo usuário:', numeroConfigurado);
            
            // Buscar última nota no banco local
            const { data: ultimaNota } = await supabase
                .from('vendas')
                .select('numero_nfce')
                .eq('status_fiscal', 'EMITIDA_NFCE')
                .not('numero_nfce', 'is', null)
                .order('numero_nfce', { ascending: false })
                .limit(1);

            let proximoNumero = numeroConfigurado;  // COMEÇAR COM VALOR CONFIGURADO
            if (ultimaNota && ultimaNota.length > 0) {
                const ultimoLocal = parseInt(ultimaNota[0].numero_nfce);
                console.log('✅ Última nota local:', ultimoLocal);
                // Usar o maior entre configurado e último local
                proximoNumero = Math.max(numeroConfigurado, ultimoLocal + 1);
                console.log('📊 Comparação: configurado(' + numeroConfigurado + ') vs local(' + (ultimoLocal + 1) + ') → usando:', proximoNumero);
            } else {
                console.log('⚠️ Nenhuma nota local - usando número configurado:', numeroConfigurado);
            }
            
            // Consultar API da Nuvem Fiscal
            try {
                const cnpj = empresa.cnpj?.replace(/\D/g, '');
                const ambiente = (empresa.nuvemfiscal_ambiente || empresa.focusnfe_ambiente) === 1 ? 'producao' : 'homologacao';
                
                console.log('☁️ Consultando API Nuvem Fiscal para sincronização...');
                const ultimasNotas = await this.listarNFCe(cnpj, ambiente, 20, 'autorizado');
                
                if (ultimasNotas?.data && ultimasNotas.data.length > 0) {
                    const ultimoNumeroAPI = parseInt(ultimasNotas.data[0].numero);
                    console.log('☁️ Último número na API:', ultimoNumeroAPI);
                    
                    if (ultimoNumeroAPI >= proximoNumero) {
                        proximoNumero = ultimoNumeroAPI + 1;
                        console.log('🔄 Ajustado pela API para:', proximoNumero);
                    }
                }
            } catch (erroAPI) {
                console.warn('⚠️ Não foi consultar API, continuando com número local');
            }
            
            console.log('✅ Número sincronizado localmente:', proximoNumero);
            return proximoNumero;
        } catch (erro) {
            console.error('❌ Erro na sincronização local:', erro);
            return parseInt(empresa.nfce_numero || 1);
        }
    }

    /**
     * Montar payload de NFC-e a partir dos dados da venda
     * @param {Object} venda - Dados da venda com itens e cliente
     * @param {Object} empresa - Dados da empresa emitente
     * @returns {Object} Payload formatado para API Nuvem Fiscal
     */
    /**
     * Formatar número com casas decimais e garantir que retorna número, não string
     */
    static formatarNumero(valor, casasDecimais = 2) {
        return parseFloat(parseFloat(valor || 0).toFixed(casasDecimais));
    }

    async montarPayloadNFCe(venda, empresa) {
        try {
            console.log('📋 [NuvemFiscal] Dados recebidos:', { venda, empresa });
            
            // 🔢 USAR SINCRONIZAÇÃO CENTRALIZADA DO FISCAL SYSTEM
            let proximoNumero;
            if (typeof FiscalSystem !== 'undefined' && FiscalSystem) {
                try {
                    console.log('🔄 [NuvemFiscal] Usando sincronização centralizada (FiscalSystem)...');
                    proximoNumero = await FiscalSystem.obterProximoNumerNFCe(empresa, 'nuvem_fiscal');
                    console.log('✅ [NuvemFiscal] Número sincronizado via FiscalSystem:', proximoNumero);
                } catch (erroSync) {
                    console.warn('⚠️ [NuvemFiscal] Erro na sincronização centralizada, usando fallback:', erroSync.message);
                    // FALLBACK: Sincronização local (compatibilidade com versões antigas)
                    proximoNumero = await this.sincronizarNumeroLocal(empresa);
                }
            } else {
                console.warn('⚠️ [NuvemFiscal] FiscalSystem não disponível, usando sincronização local');
                // FALLBACK: Sincronização local
                proximoNumero = await this.sincronizarNumeroLocal(empresa);
            }
            
            console.log('📄 [NuvemFiscal] Próximo número NFC-e será:', proximoNumero);
            
            // Garantir valores numéricos válidos
            const subtotal = parseFloat(venda.subtotal || venda.valor_produtos || 0);
            const desconto = parseFloat(venda.desconto || 0);
            const valorTotal = parseFloat(venda.valor_total || venda.total || subtotal - desconto);
            const troco = parseFloat(venda.troco || 0);
            
            // valorFiscal é o total fiscal correto: vProd - vDesc
            // SEFAZ exige que vNF = vProd - vDesc (não pode usar valor_total que pode incluir taxa_cartao)
            const valorFiscal = parseFloat((subtotal - desconto).toFixed(2));
            
            console.log('💰 [NuvemFiscal] Valores calculados:', { subtotal, desconto, valorTotal, valorFiscal, troco });
            
            // Validar e formatar código do município (7 dígitos obrigatório)
            console.log('🏙️ [NuvemFiscal] Dados municipio:', {
                codigo_municipio: empresa.codigo_municipio,
                codigo_ibge: empresa.codigo_ibge,
                cidade: empresa.cidade,
                uf: empresa.uf
            });
            
            let codigoMunicipio = String(empresa.codigo_municipio || empresa.codigo_ibge || '3550308'); // Default: São Paulo
            if (codigoMunicipio.length < 7) {
                codigoMunicipio = codigoMunicipio.padStart(7, '0');
            }
            console.log('🏙️ [NuvemFiscal] Código município formatado:', codigoMunicipio);

            // ==========================================
            // VALIDAÇÃO FISCAL PRÉ-EMISSÃO (OPCIONAL)
            // ==========================================
            console.log('🔍 [NuvemFiscal] Validando configuração fiscal...');
            if (typeof ServicoFiscalService !== 'undefined' && ServicoFiscalService) {
                try {
                    const validacao = await ServicoFiscalService.validarConfigFiscal(empresa, venda.venda_itens);
                    
                    if (!validacao.valido) {
                        console.error('❌ [NuvemFiscal] Validação fiscal falhou:', validacao);
                        throw new Error(`Configuração fiscal inválida:\n${validacao.erros.join('\n')}`);
                    }
                    
                    if (validacao.avisos.length > 0) {
                        console.warn('⚠️ [NuvemFiscal] Avisos fiscais:', validacao.avisos);
                    }
                    
                    console.log('✅ [NuvemFiscal] Validação fiscal OK');
                } catch (validacaoError) {
                    console.warn('⚠️ [NuvemFiscal] Erro na validação fiscal (ignorado):', validacaoError.message);
                    // Continuar mesmo com erro - a validação é apenas informativa
                }
            } else {
                console.warn('⚠️ [NuvemFiscal] ServicoFiscalService não disponível, pulando validação fiscal');
            }

            // ==========================================
            // CALCULAR DADOS FISCAIS DE CADA ITEM
            // ==========================================
            console.log('🧮 [NuvemFiscal] Calculando impostos dos itens...');
            
            // Determinar UF destino (se tiver cliente com endereço, senão usa UF da empresa)
            const ufDestino = venda.clientes?.uf || empresa.uf || empresa.estado;
            
            // Calcular dados fiscais para cada item
            // Se ServicoFiscalService não estiver disponível, usar dados já presentes no venda_itens
            const itensComDadosFiscais = [];
            for (const item of venda.venda_itens) {
                let dadosFiscais = null;
                
                // Tentar usar ServicoFiscalService se disponível
                if (typeof ServicoFiscalService !== 'undefined' && ServicoFiscalService) {
                    try {
                        dadosFiscais = await ServicoFiscalService.calcularImpostosItem(
                            item,
                            empresa,
                            ufDestino
                        );
                        console.log(`📊 [NuvemFiscal] Item fiscal ${item.produto_id} calculado:`, dadosFiscais);
                    } catch (calcError) {
                        console.warn(`⚠️ [NuvemFiscal] Erro ao calcular impostos do item:`, calcError.message);
                        dadosFiscais = null; // Usar fallback
                    }
                } else {
                    console.log(`💡 [NuvemFiscal] ServicoFiscalService não disponível, usando dados do banco`);
                }
                
                // Se não conseguiu calcular, usar dados já presentes no item (do banco)
                if (!dadosFiscais) {
                    const cstIcms = item.cst_icms || '102';
                    // ✅ CORREÇÃO: CSOSNs sem BC ICMS: 102, 103, 300, 400, 500
                    const csosnSemBC = ['102', '103', '300', '400', '500'];
                    const temBCIcms = !csosnSemBC.includes(cstIcms);
                    
                    dadosFiscais = {
                        cfop: item.cfop || '5102', // 5102 = venda de produto
                        ncm: item.ncm || '22021000', // bebida não alcoólica
                        cst_icms: cstIcms,
                        cst_pis: item.cst_pis || '99',
                        cst_cofins: item.cst_cofins || '99',
                        origem: item.icms_origem || 0,
                        aliquota_icms: item.icms_aliquota || 0,
                        valor_icms: item.icms_valor || 0,
                        base_icms: temBCIcms ? (item.icms_base_calculo || item.valor_total || 0) : 0,
                        aliquota_pis: item.pis_aliquota || 0,
                        valor_pis: item.pis_valor || 0,
                        base_pis: item.pis_base_calculo || item.valor_total || 0,
                        aliquota_cofins: item.cofins_aliquota || 0,
                        valor_cofins: item.cofins_valor || 0,
                        base_cofins: item.cofins_base_calculo || item.valor_total || 0,
                        icms: {
                            base_calculo: temBCIcms ? (item.icms_base_calculo || item.valor_total || 0) : 0,
                            aliquota: item.icms_aliquota || 0,
                            valor: item.icms_valor || 0,
                            situacao_tributaria: cstIcms,
                            origem: item.icms_origem || 0
                        },
                        pis: {
                            base_calculo: item.pis_base_calculo || item.valor_total || 0,
                            aliquota: item.pis_aliquota || 0,
                            valor: item.pis_valor || 0,
                            situacao_tributaria: item.cst_pis || '99'
                        },
                        cofins: {
                            base_calculo: item.cofins_base_calculo || item.valor_total || 0,
                            aliquota: item.cofins_aliquota || 0,
                            valor: item.cofins_valor || 0,
                            situacao_tributaria: item.cst_cofins || '99'
                        }
                    };
                    console.log(`📊 [NuvemFiscal] Item ${item.produto_id} usando dados do banco:`, dadosFiscais);
                }
                
                itensComDadosFiscais.push({
                    ...item,
                    dadosFiscais
                });
            }
            
            // Calcular totais gerais da nota
            let totaisFiscais = null;
            if (typeof ServicoFiscalService !== 'undefined' && ServicoFiscalService) {
                try {
                    totaisFiscais = await ServicoFiscalService.calcularTotaisNota(
                        itensComDadosFiscais.map(i => i.dadosFiscais), 
                        empresa
                    );
                    console.log('💰 [NuvemFiscal] Totais fiscais calculados:', totaisFiscais);
                } catch (totalError) {
                    console.warn('⚠️ [NuvemFiscal] Erro ao calcular totais:',totalError.message);
                    totaisFiscais = null; // Usar fallback
                }
            }
            
            // Se não tem totais, calcular manualmente
            if (!totaisFiscais) {
                const totalICMS = itensComDadosFiscais.reduce((sum, item) => sum + (item.dadosFiscais.icms.valor || 0), 0);
                const totalPIS = itensComDadosFiscais.reduce((sum, item) => sum + (item.dadosFiscais.pis.valor || 0), 0);
                const totalCOFINS = itensComDadosFiscais.reduce((sum, item) => sum + (item.dadosFiscais.cofins.valor || 0), 0);
                
                // ✅ CORREÇÃO: Para Simples Nacional, verificar se o CSOSN permite BC ICMS
                // CSOSNs SEM base de cálculo: 102, 103, 300, 400, 500
                const csosnSemBC = ['102', '103', '300', '400', '500'];
                const crt = parseInt(empresa.regime_tributario_codigo || empresa.crt || '1');
                
                let baseICMS = 0;
                if (crt === 1 || crt === 2) {
                    // Simples Nacional - apenas somar BC dos itens que permitem
                    baseICMS = itensComDadosFiscais.reduce((sum, item) => {
                        const csosn = item.dadosFiscais.icms.situacao_tributaria || '102';
                        // Se o CSOSN não permite BC, não somar
                        if (csosnSemBC.includes(csosn)) {
                            return sum + 0;
                        }
                        return sum + (item.dadosFiscais.icms.base_calculo || 0);
                    }, 0);
                } else {
                    // Regime Normal - somar todas as BCs
                    baseICMS = itensComDadosFiscais.reduce((sum, item) => sum + (item.dadosFiscais.icms.base_calculo || 0), 0);
                }
                
                console.log('💰 [NuvemFiscal] Base ICMS calculada:', baseICMS, '(Regime:', crt === 1 || crt === 2 ? 'Simples Nacional' : 'Normal', ')');
                
                totaisFiscais = {
                    base_icms: baseICMS,
                    valor_icms: totalICMS,
                    valor_pis: totalPIS,
                    valor_cofins: totalCOFINS,
                    valor_ipi: 0,
                    total_impostos: totalICMS + totalPIS + totalCOFINS
                };
                console.log('💰 [NuvemFiscal] Totais fiscais calculados manualmente:', totaisFiscais);
            }

            // Montar itens com dados fiscais calculados
            const itens = itensComDadosFiscais.map((item, index) => {
                const fiscal = item.dadosFiscais;
                
                return {
                    numero_item: index + 1,
                    codigo_produto: item.codigo_produto || String(item.produto_id),
                    descricao: item.nome_produto,
                    cfop: fiscal.cfop, // Calculado dinamicamente (5102/6102)
                    ncm: fiscal.ncm, // Do banco de dados (obrigatório)
                    unidade_comercial: item.unidade || 'UN',
                    quantidade_comercial: item.quantidade,
                    valor_unitario_comercial: item.preco_unitario,
                    valor_bruto: item.subtotal,
                    unidade_tributavel: item.unidade || 'UN',
                    quantidade_tributavel: item.quantidade,
                    valor_unitario_tributavel: item.preco_unitario,
                    valor_desconto: item.desconto || 0,
                    icms: {
                        situacao_tributaria: fiscal.cst_icms, // Calculado por regime tributário
                        origem: fiscal.origem, // Do banco de dados (0-8)
                        aliquota: fiscal.aliquota_icms || 0,
                        valor: fiscal.valor_icms || 0,
                        base_calculo: fiscal.base_icms || 0
                    },
                    pis: {
                        situacao_tributaria: fiscal.cst_pis, // Calculado por regime
                        aliquota: fiscal.aliquota_pis || 0,
                        valor: fiscal.valor_pis || 0,
                        base_calculo: fiscal.base_pis || 0
                    },
                    cofins: {
                        situacao_tributaria: fiscal.cst_cofins, // Calculado por regime
                        aliquota: fiscal.aliquota_cofins || 0,
                        valor: fiscal.valor_cofins || 0,
                        base_calculo: fiscal.base_cofins || 0
                    }
                };
            });

            // Montar dados do destinatário (se houver cliente)
            let destinatario = null;
            if (venda.clientes) {
                destinatario = {
                    cpf_cnpj: venda.clientes.cpf_cnpj?.replace(/\D/g, ''),
                    nome_completo: venda.clientes.nome,
                    email: venda.clientes.email || null
                };

                if (venda.clientes.endereco || venda.clientes.logradouro) {
                    destinatario.endereco = {
                        logradouro: venda.clientes.logradouro || '',
                        numero: venda.clientes.numero || 'SN',
                        bairro: venda.clientes.bairro || '',
                        codigo_municipio: venda.clientes.codigo_ibge || empresa.codigo_municipio || empresa.codigo_ibge,
                        municipio: venda.clientes.cidade || empresa.cidade,
                        uf: venda.clientes.uf || empresa.uf || empresa.estado,
                        cep: venda.clientes.cep?.replace(/\D/g, '') || ''
                    };
                }
            }

            // A Nuvem Fiscal usa a estrutura XML da SEFAZ (infNFe, ide, emit, det, etc)
            // Diferente do FocusNFe que aceita formato simplificado
            
            // 🌍 DETERMINAR AMBIENTE CORRETO
            const ambienteResolvido = empresa.nuvemfiscal_ambiente || empresa.focusnfe_ambiente || 2;
            const tpAmbParaPayload = ambienteResolvido === 1 ? 1 : 2;
            const ambienteString = tpAmbParaPayload === 1 ? 'producao' : 'homologacao';
            
            console.log('🌍 [NuvemFiscal] Ambiente do payload:', {
                nuvemfiscal_ambiente: empresa.nuvemfiscal_ambiente,
                focusnfe_ambiente: empresa.focusnfe_ambiente,
                ambienteResolvido,
                tpAmb: tpAmbParaPayload,
                ambienteString
            });
            
            const payload = {
                referencia: `VENDA-${venda.id || Date.now()}`,
                // ambiente será adicionado pelo método emitirNFCe
                
                infNFe: {
                    versao: '4.00',
                    ide: {
                        cUF: this.obterCodigoUF(empresa.uf || empresa.estado), // Código UF do emitente
                        natOp: 'VENDA', // Natureza da operação
                        mod: 65, // Modelo 65 = NFC-e
                        serie: parseInt(empresa.serie_nfce || '1'),
                        nNF: parseInt(proximoNumero),
                        dhEmi: new Date().toISOString(),
                        tpNF: 1, // 1=Saída
                        idDest: 1, // 1=Operação interna
                        cMunFG: codigoMunicipio,
                        tpImp: 4, // 4=DANFE NFC-e
                        tpEmis: 1, // 1=Emissão normal
                        tpAmb: tpAmbParaPayload, // 1=Produção, 2=Homologação - BASEADO EM EMPRESA
                        finNFe: 1, // 1=Normal
                        indFinal: 1, // 1=Consumidor final
                        indPres: venda.tipo_venda === 'online' ? 4 : 1, // 1=Presencial, 4=Internet
                        procEmi: 0, // 0=Emissão com aplicativo do contribuinte
                        verProc: '1.0'
                    },
                    emit: {
                        CNPJ: empresa.cnpj?.replace(/\D/g, ''),
                        xNome: empresa.razao_social,
                        xFant: empresa.nome_fantasia || empresa.razao_social,
                        enderEmit: {
                            xLgr: empresa.logradouro || '',
                            nro: empresa.numero || 'SN',
                            xBairro: empresa.bairro || '',
                            cMun: codigoMunicipio,
                            xMun: empresa.cidade || '',
                            UF: empresa.uf || empresa.estado,
                            CEP: empresa.cep?.replace(/\D/g, '') || ''
                        },
                        IE: empresa.inscricao_estadual?.replace(/\D/g, '') || 'ISENTO',
                        CRT: parseInt(empresa.regime_tributario_codigo || empresa.crt || '1')
                    },
                    det: itens.map((item, index) => {
                        let quantidade = parseFloat(item.quantidade || item.qCom || 1);
                        let precoUnitario = parseFloat(item.preco_unitario || item.vUnCom || item.valor_unitario || 0);
                        let valorTotal = parseFloat(item.valor_total || item.vProd || 0);
                        
                        // Se valorTotal foi fornecido mas precoUnitario é 0, calcular o preço
                        if (valorTotal > 0 && precoUnitario === 0 && quantidade > 0) {
                            precoUnitario = valorTotal / quantidade;
                        }
                        
                        // Se precoUnitario foi fornecido mas valorTotal é 0, calcular o total
                        if (precoUnitario > 0 && valorTotal === 0) {
                            valorTotal = quantidade * precoUnitario;
                        }
                        
                        // Fallback final: se ainda está 0, usar subtotal da venda dividido por número de itens
                        if (valorTotal === 0 && subtotal > 0) {
                            valorTotal = subtotal / itens.length;
                            // Recalcular preço unitário se necessário
                            if (precoUnitario === 0 && quantidade > 0) {
                                precoUnitario = valorTotal / quantidade;
                            }
                        }
                        
                        // IMPORTANTE: vProd DEVE ser = vUnCom * qCom (com 2 casas decimais)
                        // Arredondar para 2 casas decimais ANTES de fazer a multiplicação
                        precoUnitario = parseFloat(precoUnitario.toFixed(2));
                        quantidade = parseFloat(quantidade.toFixed(4)); // quantidade pode ter mais casas
                        valorTotal = parseFloat((precoUnitario * quantidade).toFixed(2));
                        
                        console.log(`📦 [NuvemFiscal] Item ${index + 1}:`, { 
                            descricao: item.descricao,
                            quantidade, 
                            precoUnitario, 
                            valorTotal,
                            calculo: `${precoUnitario} × ${quantidade} = ${valorTotal}`
                        });
                        
                        // Montar estrutura de imposto baseada no regime tributário
                        let impostoICMS = {};
                        const crt = parseInt(empresa.regime_tributario_codigo || empresa.crt || '1');
                        
                        // ✅ Garantir que dadosFiscais existe
                        const dadosFiscais = item.dadosFiscais || {};
                        const icmsData = dadosFiscais.icms || {};
                        
                        if (crt === 1 || crt === 2) {
                            // Simples Nacional - usar CSOSN
                            const csosn = icmsData.situacao_tributaria || '102'; // Fallback para 102
                            const origemNumero = parseInt(icmsData.origem || 0) || 0; // Garantir inteiro
                            
                            // Mapeamento conforme CSOSN
                            if (csosn === '101') {
                                impostoICMS.ICMSSN101 = {
                                    orig: origemNumero,
                                    CSOSN: csosn,
                                    pCredSN: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0, 4),
                                    vCredICMSSN: NuvemFiscalService.formatarNumero(icmsData.valor || 0)
                                };
                            } else if (csosn === '102' || csosn === '103' || csosn === '300' || csosn === '400') {
                                impostoICMS[`ICMSSN${csosn}`] = {
                                    orig: origemNumero,
                                    CSOSN: csosn
                                };
                            } else if (csosn === '201' || csosn === '202' || csosn === '203') {
                                impostoICMS[`ICMSSN${csosn}`] = {
                                    orig: origemNumero,
                                    CSOSN: csosn,
                                    modBCST: '4',
                                    pMVAST: NuvemFiscalService.formatarNumero(0),
                                    pRedBCST: NuvemFiscalService.formatarNumero(0),
                                    vBCST: NuvemFiscalService.formatarNumero(0),
                                    pICMSST: NuvemFiscalService.formatarNumero(0),
                                    vICMSST: NuvemFiscalService.formatarNumero(0),
                                    pCredSN: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0, 4),
                                    vCredICMSSN: NuvemFiscalService.formatarNumero(icmsData.valor || 0)
                                };
                            } else if (csosn === '500') {
                                impostoICMS.ICMSSN500 = {
                                    orig: origemNumero,
                                    CSOSN: csosn,
                                    vBCSTRet: NuvemFiscalService.formatarNumero(0),
                                    vICMSSTRet: NuvemFiscalService.formatarNumero(0)
                                };
                            } else if (csosn === '900') {
                                impostoICMS.ICMSSN900 = {
                                    orig: origemNumero,
                                    CSOSN: csosn,
                                    modBC: '3',
                                    vBC: NuvemFiscalService.formatarNumero(icmsData.base_calculo || 0),
                                    pRedBC: NuvemFiscalService.formatarNumero(0),
                                    pICMS: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0),
                                    vICMS: NuvemFiscalService.formatarNumero(icmsData.valor || 0),
                                    modBCST: '4',
                                    pMVAST: NuvemFiscalService.formatarNumero(0),
                                    pRedBCST: NuvemFiscalService.formatarNumero(0),
                                    vBCST: NuvemFiscalService.formatarNumero(0),
                                    pICMSST: NuvemFiscalService.formatarNumero(0),
                                    vICMSST: NuvemFiscalService.formatarNumero(0),
                                    pCredSN: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0, 4),
                                    vCredICMSSN: NuvemFiscalService.formatarNumero(icmsData.valor || 0)
                                };
                            }
                        } else {
                            // Regime Normal - usar CST
                            const cst = icmsData.situacao_tributaria || '00';
                            const origemNumero = parseInt(icmsData.origem || 0) || 0; // Garantir inteiro
                            
                            if (cst === '00') {
                                impostoICMS.ICMS00 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    modBC: '3',
                                    vBC: NuvemFiscalService.formatarNumero(icmsData.base_calculo || 0),
                                    pICMS: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0),
                                    vICMS: NuvemFiscalService.formatarNumero(icmsData.valor || 0)
                                };
                            } else if (cst === '10') {
                                impostoICMS.ICMS10 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    modBC: '3',
                                    vBC: NuvemFiscalService.formatarNumero(icmsData.base_calculo || 0),
                                    pICMS: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0),
                                    vICMS: NuvemFiscalService.formatarNumero(icmsData.valor || 0),
                                    modBCST: '4',
                                    pMVAST: NuvemFiscalService.formatarNumero(0),
                                    pRedBCST: NuvemFiscalService.formatarNumero(0),
                                    vBCST: NuvemFiscalService.formatarNumero(0),
                                    pICMSST: NuvemFiscalService.formatarNumero(0),
                                    vICMSST: NuvemFiscalService.formatarNumero(0)
                                };
                            } else if (cst === '20') {
                                impostoICMS.ICMS20 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    modBC: '3',
                                    pRedBC: NuvemFiscalService.formatarNumero(0),
                                    vBC: NuvemFiscalService.formatarNumero(icmsData.base_calculo || 0),
                                    pICMS: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0),
                                    vICMS: NuvemFiscalService.formatarNumero(icmsData.valor || 0)
                                };
                            } else if (cst === '30') {
                                impostoICMS.ICMS30 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    modBCST: '4',
                                    pMVAST: NuvemFiscalService.formatarNumero(0),
                                    pRedBCST: NuvemFiscalService.formatarNumero(0),
                                    vBCST: NuvemFiscalService.formatarNumero(0),
                                    pICMSST: NuvemFiscalService.formatarNumero(0),
                                    vICMSST: NuvemFiscalService.formatarNumero(0)
                                };
                            } else if (cst === '40' || cst === '41' || cst === '50') {
                                impostoICMS.ICMS40 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    vICMSDeson: NuvemFiscalService.formatarNumero(0),
                                    motDesICMS: '9'
                                };
                            } else if (cst === '51') {
                                impostoICMS.ICMS51 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    modBC: '3',
                                    pRedBC: NuvemFiscalService.formatarNumero(0),
                                    vBC: NuvemFiscalService.formatarNumero(icmsData.base_calculo || 0),
                                    pICMS: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0),
                                    vICMS: NuvemFiscalService.formatarNumero(icmsData.valor || 0)
                                };
                            } else if (cst === '60') {
                                impostoICMS.ICMS60 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    vBCSTRet: NuvemFiscalService.formatarNumero(0),
                                    vICMSSTRet: NuvemFiscalService.formatarNumero(0)
                                };
                            } else if (cst === '70') {
                                impostoICMS.ICMS70 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    modBC: '3',
                                    pRedBC: NuvemFiscalService.formatarNumero(0),
                                    vBC: NuvemFiscalService.formatarNumero(icmsData.base_calculo || 0),
                                    pICMS: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0),
                                    vICMS: NuvemFiscalService.formatarNumero(icmsData.valor || 0),
                                    modBCST: '4',
                                    pMVAST: NuvemFiscalService.formatarNumero(0),
                                    pRedBCST: NuvemFiscalService.formatarNumero(0),
                                    vBCST: NuvemFiscalService.formatarNumero(0),
                                    pICMSST: NuvemFiscalService.formatarNumero(0),
                                    vICMSST: NuvemFiscalService.formatarNumero(0)
                                };
                            } else if (cst === '90') {
                                impostoICMS.ICMS90 = {
                                    orig: origemNumero,
                                    CST: cst,
                                    modBC: '3',
                                    vBC: NuvemFiscalService.formatarNumero(icmsData.base_calculo || 0),
                                    pRedBC: NuvemFiscalService.formatarNumero(0),
                                    pICMS: NuvemFiscalService.formatarNumero(icmsData.aliquota || 0),
                                    vICMS: NuvemFiscalService.formatarNumero(icmsData.valor || 0),
                                    modBCST: '4',
                                    pMVAST: NuvemFiscalService.formatarNumero(0),
                                    pRedBCST: NuvemFiscalService.formatarNumero(0),
                                    vBCST: NuvemFiscalService.formatarNumero(0),
                                    pICMSST: NuvemFiscalService.formatarNumero(0),
                                    vICMSST: NuvemFiscalService.formatarNumero(0)
                                };
                            }
                        }
                        
                        // Montar estrutura PIS/COFINS
                        let impostoPIS = {};
                        let impostoCOFINS = {};
                        
                        const cstPIS = item.pis.situacao_tributaria;
                        const cstCOFINS = item.cofins.situacao_tributaria;
                        
                        // PIS
                        if (cstPIS === '01' || cstPIS === '02') {
                            impostoPIS.PISAliq = {
                                CST: cstPIS,
                                vBC: NuvemFiscalService.formatarNumero(item.pis.base_calculo),
                                pPIS: NuvemFiscalService.formatarNumero(item.pis.aliquota, 4),
                                vPIS: NuvemFiscalService.formatarNumero(item.pis.valor)
                            };
                        } else if (cstPIS === '04' || cstPIS === '05' || cstPIS === '06' || cstPIS === '07' || cstPIS === '08' || cstPIS === '09') {
                            impostoPIS.PISNT = {
                                CST: cstPIS
                            };
                        } else if (cstPIS === '49' || cstPIS === '50' || cstPIS === '51' || cstPIS === '52' || cstPIS === '53' || cstPIS === '54' || cstPIS === '55' || cstPIS === '56' || cstPIS === '60' || cstPIS === '61' || cstPIS === '62' || cstPIS === '63' || cstPIS === '64' || cstPIS === '65' || cstPIS === '66' || cstPIS === '67' || cstPIS === '70' || cstPIS === '71' || cstPIS === '72' || cstPIS === '73' || cstPIS === '74' || cstPIS === '75' || cstPIS === '98' || cstPIS === '99') {
                            impostoPIS.PISOutr = {
                                CST: cstPIS,
                                vBC: NuvemFiscalService.formatarNumero(item.pis.base_calculo),
                                pPIS: NuvemFiscalService.formatarNumero(item.pis.aliquota, 4),
                                vPIS: NuvemFiscalService.formatarNumero(item.pis.valor)
                            };
                        }
                        
                        // COFINS
                        if (cstCOFINS === '01' || cstCOFINS === '02') {
                            impostoCOFINS.COFINSAliq = {
                                CST: cstCOFINS,
                                vBC: NuvemFiscalService.formatarNumero(item.cofins.base_calculo),
                                pCOFINS: NuvemFiscalService.formatarNumero(item.cofins.aliquota, 4),
                                vCOFINS: NuvemFiscalService.formatarNumero(item.cofins.valor)
                            };
                        } else if (cstCOFINS === '04' || cstCOFINS === '05' || cstCOFINS === '06' || cstCOFINS === '07' || cstCOFINS === '08' || cstCOFINS === '09') {
                            impostoCOFINS.COFINSNT = {
                                CST: cstCOFINS
                            };
                        } else if (cstCOFINS === '49' || cstCOFINS === '50' || cstCOFINS === '51' || cstCOFINS === '52' || cstCOFINS === '53' || cstCOFINS === '54' || cstCOFINS === '55' || cstCOFINS === '56' || cstCOFINS === '60' || cstCOFINS === '61' || cstCOFINS === '62' || cstCOFINS === '63' || cstCOFINS === '64' || cstCOFINS === '65' || cstCOFINS === '66' || cstCOFINS === '67' || cstCOFINS === '70' || cstCOFINS === '71' || cstCOFINS === '72' || cstCOFINS === '73' || cstCOFINS === '74' || cstCOFINS === '75' || cstCOFINS === '98' || cstCOFINS === '99') {
                            impostoCOFINS.COFINSOutr = {
                                CST: cstCOFINS,
                                vBC: NuvemFiscalService.formatarNumero(item.cofins.base_calculo),
                                pCOFINS: NuvemFiscalService.formatarNumero(item.cofins.aliquota, 4),
                                vCOFINS: NuvemFiscalService.formatarNumero(item.cofins.valor)
                            };
                        }
                        
                        return {
                            nItem: index + 1,
                            prod: {
                                cProd: String(item.codigo_produto || item.cProd || '000'),
                                cEAN: item.codigo_barras || 'SEM GTIN',
                                xProd: String(item.descricao || item.xProd || 'PRODUTO'),
                                NCM: item.ncm, // Obrigatório - vem do banco de dados
                                CFOP: item.cfop, // Calculado dinamicamente (5102/6102)
                                uCom: item.unidade || 'UN',
                                qCom: quantidade,
                                vUnCom: precoUnitario,
                                vProd: valorTotal,
                                cEANTrib: item.codigo_barras || 'SEM GTIN',
                                uTrib: item.unidade || 'UN',
                                qTrib: quantidade,
                                vUnTrib: precoUnitario,
                                indTot: 1
                            },
                            imposto: {
                                ICMS: impostoICMS,
                                PIS: impostoPIS,
                                COFINS: impostoCOFINS
                            }
                        };
                    }),
                    total: {
                        ICMSTot: {
                            vBC: NuvemFiscalService.formatarNumero(totaisFiscais.base_icms),
                            vICMS: NuvemFiscalService.formatarNumero(totaisFiscais.valor_icms),
                            vICMSDeson: NuvemFiscalService.formatarNumero(0),
                            vFCP: NuvemFiscalService.formatarNumero(0),
                            vBCST: NuvemFiscalService.formatarNumero(0),
                            vST: NuvemFiscalService.formatarNumero(0),
                            vFCPST: NuvemFiscalService.formatarNumero(0),
                            vFCPSTRet: NuvemFiscalService.formatarNumero(0),
                            vProd: NuvemFiscalService.formatarNumero(subtotal),
                            vFrete: NuvemFiscalService.formatarNumero(0),
                            vSeg: NuvemFiscalService.formatarNumero(0),
                            vDesc: NuvemFiscalService.formatarNumero(desconto),
                            vII: NuvemFiscalService.formatarNumero(0),
                            vIPI: NuvemFiscalService.formatarNumero(totaisFiscais.valor_ipi),
                            vIPIDevol: NuvemFiscalService.formatarNumero(0),
                            vPIS: NuvemFiscalService.formatarNumero(totaisFiscais.valor_pis),
                            vCOFINS: NuvemFiscalService.formatarNumero(totaisFiscais.valor_cofins),
                            vOutro: NuvemFiscalService.formatarNumero(0),
                            vNF: NuvemFiscalService.formatarNumero(valorFiscal),
                            vTotTrib: NuvemFiscalService.formatarNumero(totaisFiscais.total_impostos)
                        }
                    },
                    transp: {
                        modFrete: 9 // 9=Sem frete
                    },
                    pag: {
                        detPag: [{
                            tPag: this.mapearFormaPagamento(venda.forma_pagamento),
                            xPag: venda.forma_pagamento_descricao || this.obterDescricaoPagamento(venda.forma_pagamento),
                            vPag: NuvemFiscalService.formatarNumero(valorFiscal)
                        }],
                        vTroco: NuvemFiscalService.formatarNumero(troco)
                    }
                }
            };

            // Adicionar destinatário se houver
            if (destinatario && destinatario.cpf_cnpj) {
                payload.infNFe.dest = {
                    [destinatario.cpf_cnpj.length === 11 ? 'CPF' : 'CNPJ']: destinatario.cpf_cnpj,
                    xNome: destinatario.nome_completo
                };
            }

            // Adicionar informações adicionais se houver
            if (venda.observacoes) {
                payload.infNFe.infAdic = {
                    infCpl: venda.observacoes
                };
            }

            console.log('🏙️ [NuvemFiscal] Verificação final - cMunFG:', payload.infNFe.ide.cMunFG, 'cMun:', payload.infNFe.emit.enderEmit.cMun);
            console.log('📦 [NuvemFiscal] Payload completo:', JSON.stringify(payload, null, 2));

            return payload;
        } catch (erro) {
            console.error('Erro ao montar payload NFC-e:', erro);
            throw erro;
        }
    }

    /**
     * Mapear forma de pagamento do sistema para código da NFC-e
     */
    mapearFormaPagamento(formaPagamento) {
        const mapa = {
            'dinheiro': '01',
            'cartao_credito': '03',
            'cartao_debito': '04',
            'pix': '17',
            'transferencia': '18',
            'boleto': '15',
            'outros': '99'
        };

        return mapa[formaPagamento] || '99';
    }

    /**
     * Obter descrição legível da forma de pagamento
     */
    obterDescricaoPagamento(formaPagamento) {
        const descricoes = {
            'dinheiro': 'Dinheiro',
            'cartao_credito': 'Cartão de Crédito',
            'cartao_debito': 'Cartão de Débito',
            'pix': 'PIX',
            'transferencia': 'Transferência Bancária',
            'boleto': 'Boleto Bancário',
            'outros': 'Outros'
        };

        return descricoes[formaPagamento] || 'Outros';
    }

    /**
     * Validar resposta da API
     */
    validarResposta(resposta) {
        if (!resposta) {
            throw new Error('Resposta vazia da API');
        }

        if (resposta.status === 'rejeitado' || resposta.status === 'erro') {
            console.error('❌ [NuvemFiscal] Rejeição completa:', resposta);
            console.error('❌ [NuvemFiscal] Autorização:', resposta.autorizacao);
            
            // Buscar mensagens de erro em diferentes lugares
            let mensagens = '';
            
            if (resposta.autorizacao?.mensagens) {
                mensagens = resposta.autorizacao.mensagens.map(m => 
                    `[${m.codigo}] ${m.mensagem}`
                ).join('; ');
            } else if (resposta.autorizacao?.motivo_status) {
                mensagens = `[${resposta.autorizacao.codigo_status}] ${resposta.autorizacao.motivo_status}`;
            } else if (resposta.autorizacao?.motivo) {
                mensagens = `[${resposta.autorizacao.codigo_status}] ${resposta.autorizacao.motivo}`;
            } else if (resposta.mensagens) {
                mensagens = resposta.mensagens.map(m => m.mensagem).join('; ');
            } else if (resposta.motivo_status) {
                mensagens = `[${resposta.codigo_status}] ${resposta.motivo_status}`;
            } else {
                mensagens = 'Erro desconhecido';
            }
            
            throw new Error(`NFC-e rejeitada: ${mensagens}`);
        }

        return resposta;
    }

    // ===================================
    // MÉTODOS PARA NOTAS RECEBIDAS
    // ===================================
    // ⚠️ DEPRECATED: Os endpoints /nf-e e /nfce não funcionam mais
    // Use buscarDistribuicaoNFe() para NF-e distribuídas pelo SEFAZ

    /**
     * Consultar uma nota recebida (NF-e ou NFC-e) pela chave de acesso
     * ⚠️ Use buscarDistribuicaoNFe() para buscar notas distribuídas
     * @param {string} chaveAcesso - Chave de acesso da nota (44 dígitos)
     * @param {string} tipo - 'nfe' ou 'nfce'
     * @returns {Object} Dados da nota com ID para download
     */
    async consultarNotaRecebida(chaveAcesso, tipo = 'nfe') {
        try {
            const chave = chaveAcesso.replace(/\D/g, '');
            
            if (chave.length !== 44) {
                throw new Error('Chave de acesso inválida. Deve ter 44 dígitos.');
            }
            
            // Usar buscarDistribuicaoNFe para buscas reais
            console.warn('⚠️ consultarNotaRecebida() está deprecated. Use buscarDistribuicaoNFe() em vez disso.');
            throw new Error('Método deprecado. Use buscarDistribuicaoNFe()');
        } catch (erro) {
            console.error('Erro ao consultar nota recebida:', erro);
            throw erro;
        }
    }

    /**
     * Baixar XML de uma nota recebida
     * @param {string} notaId - ID da nota retornado na listagem
     * @param {string} tipo - 'nfe' ou 'nfce'
     * @returns {Blob} Arquivo XML
     */
    async baixarXMLNotaRecebida(notaId, tipo = 'nfe') {
        try {
            console.warn('⚠️ baixarXMLNotaRecebida() pode não funcionar. Use baixarXMLDistribuicao() para NF-e.');
            
            const endpoint = tipo.toLowerCase() === 'nfce' ? `/nfce/${notaId}/xml` : `/nf-e/${notaId}/xml`;
            
            console.log('📥 [NuvemFiscal] Baixando XML:', endpoint);
            return await this.request(endpoint, 'GET', null, {
                'Accept': 'application/xml'
            });
        } catch (erro) {
            console.error('Erro ao baixar XML da nota recebida:', erro);
            throw erro;
        }
    }

    /**
     * NOVOS MÉTODOS: Usar API de Distribuição NF-e do SEFAZ
     * Endpoints: GET /distribuicao-nf-e e POST /distribuicao-nf-e/download
     * Referência: https://dev.nuvemfiscal.com.br/docs/api/#tag/Distribuicao-NF-e
     */

    /**
     * Buscar documentos distribuídos via API de Distribuição NF-e do SEFAZ
     * Este endpoint retorna NF-e que foram oficialmente distribuídas pelo SEFAZ
     * @param {string} cpfCnpj - CPF/CNPJ da empresa (como destinatária)
     * @param {string} ambiente - 'homologacao' ou 'producao'
     * @param {number} top - Número máximo de registros a retornar
     * @param {string} dataInicio - Filtro de data de início (YYYY-MM-DD)
     * @param {string} dataFim - Filtro de data de fim (YYYY-MM-DD)
     * @returns {Object} Lista de documentos distribuídos
     */
    async buscarDistribuicaoNFe(cpfCnpj, ambiente = 'homologacao', top = 100, dataInicio = null, dataFim = null) {
        try {
            const cnpjLimpo = cpfCnpj.replace(/\D/g, '');
            
            // Construir URL base para distribuição (endpoint correto: /distribuicao/nfe/documentos)
            let url = `/distribuicao/nfe/documentos?`;
            const params = [];
            
            params.push(`cpf_cnpj=${cnpjLimpo}`);
            params.push(`ambiente=${ambiente}`);
            params.push(`$top=${top}`);
            params.push(`$orderby=data_emissao desc`);
            
            // Adicionar filtros de data se fornecidos
            if (dataInicio || dataFim) {
                let filtros = [];
                if (dataInicio) {
                    filtros.push(`data_emissao ge datetime'${dataInicio}T00:00:00'`);
                }
                if (dataFim) {
                    filtros.push(`data_emissao le datetime'${dataFim}T23:59:59'`);
                }
                if (filtros.length > 0) {
                    params.push(`$filter=${filtros.join(' and ')}`);
                }
            }
            
            url += params.join('&');
            
            console.log('📋 [NuvemFiscal] Buscando documentos (Distribuição NF-e):', url);
            const resultado = await this.request(url, 'GET');
            console.log('📋 [NuvemFiscal] Documentos distribuídos encontrados:', resultado?.data?.length || 0);
            
            return resultado;
        } catch (erro) {
            console.error('Erro ao buscar documentos distribuídos:', erro);
            throw erro;
        }
    }

    /**
     * Baixar XML usando a API de Distribuição NF-e
     * @param {string} documentoId - ID do documento retornado na listagem
     * @returns {Blob} Arquivo XML
     */
    async baixarXMLDistribuicao(documentoId) {
        try {
            if (!documentoId) {
                throw new Error('ID do documento é obrigatório.');
            }
            
            console.log('📥 [NuvemFiscal] Baixando XML via Distribuição:', documentoId);
            
            return await this.request(
                `/distribuicao/nfe/documentos/${documentoId}/xml`,
                'GET',
                null,
                { 'Accept': 'application/xml' }
            );
        } catch (erro) {
            console.error('Erro ao baixar XML da distribuição:', erro);
            throw erro;
        }
    }

    /**
     * Download com PDF (alternativa)
     * @param {string} documentoId - ID do documento
     * @returns {Blob} Arquivo PDF
     */
    async baixarPDFDistribuicao(documentoId) {
        try {
            if (!documentoId) {
                throw new Error('ID do documento é obrigatório.');
            }
            
            console.log('📥 [NuvemFiscal] Baixando PDF via Distribuição:', documentoId);
            
            return await this.request(
                `/distribuicao/nfe/documentos/${documentoId}/pdf`,
                'GET',
                null,
                { 'Accept': 'application/xml' }
            );
        } catch (erro) {
            console.error('Erro ao baixar XML da distribuição (POST):', erro);
            throw erro;
        }
    }
}

// Exportar instância única
const NuvemFiscal = new NuvemFiscalService();
