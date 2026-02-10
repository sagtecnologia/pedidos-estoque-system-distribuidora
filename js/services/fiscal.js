/**
 * Sistema de Emissão Fiscal - NFC-e e NF-e
 * Desacoplado do PDV - pode ser emitido em qualquer momento
 */

class FiscalSystem {
    /**
     * Inicializar sistema fiscal
     */
    static async init() {
        this.setupEventos();
    }

    /**
     * Emitir NFC-e com dados da venda diretamente (usado pelo PDV antes de salvar a venda)
     * @param {Object} vendaData - Dados da venda
     * @param {Array} itensData - Itens da venda
     * @param {Array} pagamentosData - Pagamentos da venda
     * @param {Object} clienteData - Cliente (opcional)
     * @returns {Object} Resultado da emissão
     */
    static async emitirNFCeDireto(vendaData, itensData, pagamentosData, clienteData = null) {
        try {
            console.log('🔄 [FiscalSystem] Iniciando emissão NFC-e com dados diretos...');

            // Verificar qual provedor de API fiscal está configurado
            const { data: config } = await supabase
                .from('empresa_config')
                .select('api_fiscal_provider, cnpj, razao_social')
                .single();

            const provider = config?.api_fiscal_provider || 'focus_nfe';
            
            console.log(`📋 [FiscalSystem] Provedor configurado: ${provider}`);
            console.log(`🏢 [FiscalSystem] Empresa: ${config?.razao_social} - CNPJ: ${config?.cnpj}`);

            let resultado;

            if (provider === 'nuvem_fiscal') {
                console.log('☁️ [FiscalSystem] Usando Nuvem Fiscal para emissão...');
                
                // ===== EMISSÃO VIA NUVEM FISCAL =====
                const { data: empresa } = await supabase
                    .from('empresa_config')
                    .select('*')
                    .single();

                // Montar objeto venda com estrutura esperada
                const venda = {
                    ...vendaData,
                    venda_itens: itensData,
                    clientes: clienteData
                };

                // 🔢 ===== INCREMENTAR NÚMERO ATOMICAMENTE ANTES DA EMISSÃO =====
                let numeroObtido = null;
                try {
                    numeroObtido = await this.obterProximoNumerNFCeComIncremento(empresa, 'nuvem_fiscal');
                    console.log('✅ [FiscalSystem] Número NFC-e reservado atomicamente:', numeroObtido);
                } catch (erroIncremento) {
                    console.error('❌ [FiscalSystem] Falha ao obter/incrementar número NFC-e:', erroIncremento.message);
                    throw new Error(`Falha ao gerar número de NFC-e: ${erroIncremento.message}`);
                }

                // Montar payload para Nuvem Fiscal (agora com número já sincronizado)
                const payload = await NuvemFiscal.montarPayloadNFCe(venda, empresa);

                // Emitir via Nuvem Fiscal
                try {
                    resultado = await NuvemFiscal.emitirNFCe(payload);

                    // Validar resultado
                    NuvemFiscal.validarResposta(resultado);

                    console.log('✅ [FiscalSystem] Resposta Nuvem Fiscal:', resultado);

                    // Mapear resposta da Nuvem Fiscal para formato padrão
                    if (resultado.status === 'autorizado') {
                        // ✅ Preparar dados do documento fiscal para salvar no banco
                        const documentoFiscalData = {
                            // venda_id será adicionado depois pelo PDV
                            tipo_documento: 'NFCE',
                            numero_documento: resultado.numero?.toString() || '0',
                            serie: parseInt(resultado.serie || '1'),
                            chave_acesso: resultado.chave_acesso || resultado.chave,
                            protocolo_autorizacao: resultado.autorizacao?.numero_protocolo || resultado.protocolo,
                            status_sefaz: '100', // Autorizado
                            mensagem_sefaz: resultado.autorizacao?.mensagem || 'Autorizado o uso da NFC-e',
                            valor_total: vendaData.total,
                            natureza_operacao: 'VENDA',
                            data_emissao: vendaData.data_emissao || new Date().toISOString(),
                            data_autorizacao: new Date().toISOString(),
                            xml_nota: resultado.caminho_xml || null,
                            xml_retorno: JSON.stringify(resultado),
                            tentativas_emissao: 1,
                            ultima_tentativa: new Date().toISOString(),
                            api_provider: 'nuvem_fiscal',
                            nfce_id: resultado.id // ✅ ID Nuvem Fiscal para download do XML
                        };

                        console.log('✅ [FiscalSystem] NFC-e autorizada! Número utilizado:', resultado.numero);
                        return {
                            success: true,
                            status: 'autorizado',
                            status_sefaz: 'autorizado',
                            numero: resultado.numero,
                            chave_nfe: resultado.chave_acesso || resultado.chave,
                            protocolo: resultado.autorizacao?.numero_protocolo || resultado.protocolo,
                            caminho_xml_nota_fiscal: resultado.caminho_xml,
                            caminho_danfe: resultado.caminho_danfe,
                            nfce_id: resultado.id, // ✅ ID da nota na Nuvem Fiscal
                            ref: resultado.referencia || resultado.id, // ✅ Referência para exibição
                            provider: 'nuvem_fiscal',
                            mensagem: 'NFC-e autorizada pela SEFAZ via Nuvem Fiscal',
                            documentoFiscalData // ✅ Dados para salvar na tabela documentos_fiscais
                        };
                    } else {
                        const mensagens = resultado.mensagens?.map(m => m.mensagem).join('; ') || 'Erro desconhecido';
                        // ⚠️ Se rejeitada, REVOGAR o incremento do número
                        await this.reverterIncrementoNumerNFCe(numeroObtido);
                        throw new Error('NFC-e rejeitada SEFAZ: ' + mensagens);
                    }
                } catch (erroEmissao) {
                    // ⚠️ Falha na emissão - REVOGAR o incremento do número
                    console.error('❌ [FiscalSystem] Erro na emissão, revogando número:', erroEmissao.message);
                    try {
                        await this.reverterIncrementoNumerNFCe(numeroObtido);
                    } catch (erroRollback) {
                        console.warn('⚠️ [FiscalSystem] Não foi possível reverter incremento (manual fix needed):', erroRollback.message);
                    }
                    throw erroEmissao;
                }
            } else {
                console.log('🎯 [FiscalSystem] Usando Focus NFe para emissão...');
                
                // 🔢 ===== INCREMENTAR NÚMERO ATOMICAMENTE ANTES DA EMISSÃO =====
                let numeroObtido = null;
                try {
                    numeroObtido = await this.obterProximoNumerNFCeComIncremento(empresa, 'focus_nfe');
                    console.log('✅ [FiscalSystem] Número NFC-e reservado atomicamente:', numeroObtido);
                } catch (erroIncremento) {
                    console.error('❌ [FiscalSystem] Falha ao obter/incrementar número NFC-e:', erroIncremento.message);
                    throw new Error(`Falha ao gerar número de NFC-e: ${erroIncremento.message}`);
                }

                // ===== EMISSÃO VIA FOCUS NFE =====
                const venda = {
                    ...vendaData,
                    venda_itens: itensData,
                    clientes: clienteData
                };

                try {
                    resultado = await FocusNFe.emitirNFCe(venda, itensData, pagamentosData, clienteData);

                    console.log('✅ [FiscalSystem] Resposta Focus NFe:', resultado);

                    // ✅ Se autorizado, número já foi incrementado atomicamente
                    if ((resultado.success || resultado.status === 'autorizado') && resultado.numero) {
                        console.log('✅ [FiscalSystem] NFC-e autorizada! Número utilizado:', resultado.numero);
                        return resultado;
                    } else {
                        // ⚠️ Se não autorizada, REVOGAR o incremento do número
                        await this.reverterIncrementoNumerNFCe(numeroObtido);
                        console.warn('⚠️ [FiscalSystem] Emissão não foi autorizada, número revertido');
                        throw new Error(`Emissão não autorizada: ${resultado.mensagem || resultado.status}`);
                    }
                } catch (erroEmissao) {
                    // ⚠️ Falha na emissão - REVOGAR o incremento do número
                    console.error('❌ [FiscalSystem] Erro na emissão, revogando número:', erroEmissao.message);
                    try {
                        await this.reverterIncrementoNumerNFCe(numeroObtido);
                    } catch (erroRollback) {
                        console.warn('⚠️ [FiscalSystem] Não foi possível reverter incremento (manual fix needed):', erroRollback.message);
                    }
                    throw erroEmissao;
                }
            }
        } catch (error) {
            console.error('❌ [FiscalSystem] Erro ao emitir NFC-e:', error);
            
            // Melhorar mensagem de erro para o usuário
            let mensagemUsuario = error.message || 'Erro desconhecido ao emitir NFC-e';
            
            if (error.code === 'ValidationFailed') {
                mensagemUsuario = `❌ ERRO DE VALIDAÇÃO (${error.code}): ${error.message}\n\nPossíveis causas:\n` +
                    `• NFC-e com este número já foi AUTORIZADA\n` +
                    `• NFC-e com este número já foi CANCELADA\n` +
                    `• Incrementar o número sequencial da NFC-e\n` +
                    `• Aguarde alguns segundos e tente novamente`;
            } else if (error.message?.includes('já foi AUTORIZADA') || error.message?.includes('já foi emitida')) {
                mensagemUsuario = `❌ Erro ao emitir NFC-e:\n\nEste documento já foi autorizado anteriormente!\n\n` +
                    `SOLUÇÃO: Incrementar o número sequencial da NFC-e no leiaute de produtos ou no PDV e tentar novamente.`;
            }
            
            const errorToThrow = new Error(mensagemUsuario);
            errorToThrow.originalError = error;
            throw errorToThrow;
        }
    }

    /**
     * Emitir NFC-e (Nota Fiscal do Consumidor Eletrônica)
     * Fluxo: Venda finalizada → Emissão NFC-e → Atualizar status
     */
    static async emitirNFCe(vendaId, tentativa = 1) {
        try {
            const maxTentativas = 3;
            const delayRetry = tentativa * 5000; // 5s, 10s, 15s

            // Buscar venda
            const { data: venda, error: erroV } = await supabase
                .from('vendas')
                .select('*')
                .eq('id', vendaId)
                .single();

            if (erroV) throw new Error('Venda não encontrada');

            // Buscar itens
            const { data: itens } = await supabase
                .from('venda_itens')
                .select('*')
                .eq('venda_id', vendaId);
            venda.venda_itens = itens || [];

            // Buscar cliente
            if (venda.cliente_id) {
                const { data: cliente } = await supabase
                    .from('clientes')
                    .select('*')
                    .eq('id', venda.cliente_id)
                    .single();
                venda.clientes = cliente;
            }

            // Verificar se já foi emitida
            if (venda.status_fiscal !== 'SEM_DOCUMENTO_FISCAL' && venda.status_fiscal !== 'REJEITADA_SEFAZ') {
                throw new Error('NFC-e já foi emitida para esta venda');
            }

            // Atualizar status para "pendente"
            await supabase
                .from('vendas')
                .update({ status_fiscal: 'PENDENTE_EMISSAO' })
                .eq('id', vendaId);

            // Verificar qual provedor de API fiscal está configurado
            const { data: config } = await supabase
                .from('empresa_config')
                .select('api_fiscal_provider')
                .single();

            const provider = config?.api_fiscal_provider || 'focus_nfe';

            let resultado;

            if (provider === 'nuvem_fiscal') {
                // ===== EMISSÃO VIA NUVEM FISCAL =====
                // Buscar dados da empresa
                const { data: empresa } = await supabase
                    .from('empresa_config')
                    .select('*')
                    .single();

                // Montar payload para Nuvem Fiscal
                const payload = await NuvemFiscal.montarPayloadNFCe(venda, empresa);

                // Emitir via Nuvem Fiscal
                resultado = await NuvemFiscal.emitirNFCe(payload);

                // Validar resultado
                NuvemFiscal.validarResposta(resultado);

                // Mapear resposta da Nuvem Fiscal para formato padrão
                if (resultado.status === 'autorizado') {
                    const numeroEmitido = parseInt(resultado.numero);
                    
                    await supabase
                        .from('vendas')
                        .update({
                            status_fiscal: 'EMITIDA_NFCE',
                            numero_nfce: numeroEmitido,
                            chave_acesso_nfce: resultado.chave_acesso || resultado.chave,
                            protocolo_nfce: resultado.autorizacao?.numero_protocolo || resultado.protocolo,
                            xml_nfce: resultado.xml || null
                        })
                        .eq('id', vendaId);

                    await this.registrarDocumentoFiscal(vendaId, 'NFCE', resultado);

                    // 💾 ATUALIZAR NÚMERO NFC-e NA CONFIGURAÇÃO
                    await this.atualizarNumerNFCeConfig(numeroEmitido);

                    return {
                        sucesso: true,
                        numero: resultado.numero,
                        chave: resultado.chave_acesso || resultado.chave,
                        protocolo: resultado.autorizacao?.numero_protocolo || resultado.protocolo,
                        provider: 'nuvem_fiscal'
                    };
                } else if (resultado.status === 'rejeitado' || resultado.status === 'erro') {
                    const mensagens = resultado.mensagens?.map(m => m.mensagem).join('; ') || 'Erro desconhecido';
                    await supabase
                        .from('vendas')
                        .update({
                            status_fiscal: 'REJEITADA_SEFAZ',
                            mensagem_erro_fiscal: mensagens
                        })
                        .eq('id', vendaId);

                    throw new Error('NFC-e rejeitada SEFAZ: ' + mensagens);
                }
            } else {
                // ===== EMISSÃO VIA FOCUS NFE (ORIGINAL) =====
                // Montar XML da NFC-e
                const xml = await this.montarXmlNFCe(venda);

                // Enviar para Focus NFe via Edge Function
                const { data: resultadoFocus, error: erroEmissao } = await supabase.functions
                    .invoke('emitir-nfce', {
                        body: {
                            xml: xml,
                            vendor_id: venda.id
                        }
                    });

                if (erroEmissao) {
                    if (tentativa < maxTentativas) {
                        console.log(`Tentativa ${tentativa}/${maxTentativas} falhou. Aguardando ${delayRetry}ms...`);
                        setTimeout(() => this.emitirNFCe(vendaId, tentativa + 1), delayRetry);
                        return;
                    } else {
                        throw new Error('Máximo de tentativas atingido');
                    }
                }

                resultado = resultadoFocus;

                // Atualizar venda com dados da NFC-e
                if (resultado.status === 'autorizada') {
                    const numeroEmitido = parseInt(resultado.numero);
                    
                    await supabase
                        .from('vendas')
                        .update({
                            status_fiscal: 'EMITIDA_NFCE',
                            numero_nfce: numeroEmitido,
                            chave_acesso_nfce: resultado.chave,
                            protocolo_nfce: resultado.protocolo,
                            xml_nfce: xml
                        })
                        .eq('id', vendaId);

                    // Registrar documento fiscal
                    await this.registrarDocumentoFiscal(vendaId, 'NFCE', resultado);

                    // 💾 ATUALIZAR NÚMERO NFC-e NA CONFIGURAÇÃO
                    await this.atualizarNumerNFCeConfig(numeroEmitido);

                    return {
                        sucesso: true,
                        numero: resultado.numero,
                        chave: resultado.chave,
                        protocolo: resultado.protocolo,
                        provider: 'focus_nfe'
                    };
                } else if (resultado.status === 'rejeitada') {
                    await supabase
                        .from('vendas')
                        .update({
                            status_fiscal: 'REJEITADA_SEFAZ',
                            mensagem_erro_fiscal: resultado.mensagem
                        })
                        .eq('id', vendaId);

                    throw new Error('NFC-e rejeitada SEFAZ: ' + resultado.mensagem);
                }
            }
        } catch (error) {
            console.error('Erro ao emitir NFC-e:', error);
            
            // Atualizar status para rejeitada
            await supabase
                .from('vendas')
                .update({
                    status_fiscal: 'REJEITADA_SEFAZ',
                    mensagem_erro_fiscal: error.message
                })
                .eq('id', vendaId);

            return {
                sucesso: false,
                erro: error.message
            };
        }
    }

    /**
     * Emitir NF-e (Nota Fiscal Eletrônica) para B2B
     */
    static async emitirNFe(vendaId) {
        try {
            // Verificar se venda é para cliente PJ
            const { data: venda, error: erroV } = await supabase
                .from('vendas')
                .select('*')
                .eq('id', vendaId)
                .single();

            if (erroV) throw new Error('Venda não encontrada');

            // Buscar itens
            const { data: itens } = await supabase
                .from('venda_itens')
                .select('*')
                .eq('venda_id', vendaId);
            venda.venda_itens = itens || [];

            // Buscar cliente
            if (venda.cliente_id) {
                const { data: cliente } = await supabase
                    .from('clientes')
                    .select('*')
                    .eq('id', venda.cliente_id)
                    .single();
                venda.clientes = cliente;
            }

            if (!venda.cliente_id || venda.clientes.tipo !== 'PJ') {
                throw new Error('NF-e apenas para clientes PJ');
            }

            // Atualizar status
            await supabase
                .from('vendas')
                .update({ status_fiscal: 'PENDENTE_EMISSAO' })
                .eq('id', vendaId);

            // Montar XML da NF-e
            const xml = await this.montarXmlNFe(venda);

            // Enviar para Focus NFe
            const { data: resultado, error: erroEmissao } = await supabase.functions
                .invoke('emitir-nfe', {
                    body: {
                        xml: xml,
                        vendor_id: venda.id
                    }
                });

            if (erroEmissao) throw erroEmissao;

            // Atualizar venda
            await supabase
                .from('vendas')
                .update({
                    status_fiscal: 'EMITIDA_NFE',
                    numero_nfe: resultado.numero,
                    chave_acesso_nfe: resultado.chave,
                    protocolo_nfe: resultado.protocolo,
                    xml_nfe: xml
                })
                .eq('id', vendaId);

            // Registrar documento fiscal
            await this.registrarDocumentoFiscal(vendaId, 'NFE', resultado);

            return {
                sucesso: true,
                numero: resultado.numero,
                chave: resultado.chave,
                protocolo: resultado.protocolo
            };
        } catch (error) {
            console.error('Erro ao emitir NF-e:', error);
            return {
                sucesso: false,
                erro: error.message
            };
        }
    }

    /**
     * Consultar status de documento fiscal
     */
    static async consultarDocumentoFiscal(vendaId) {
        try {
            const { data: venda, error: erroV } = await supabase
                .from('vendas')
                .select('*')
                .eq('id', vendaId)
                .single();

            if (erroV) throw erroV;

            const tipo = venda.numero_nfce ? 'NFCE' : 'NFE';
            const chave = venda.numero_nfce ? venda.chave_acesso_nfce : venda.chave_acesso_nfe;

            if (!chave) {
                return { status: 'nao_emitida', mensagem: 'Documento ainda não foi emitido' };
            }

            // Consultar via Edge Function
            const { data: resultado, error: erroConsulta } = await supabase.functions
                .invoke('consultar-nf', {
                    body: {
                        chave: chave,
                        tipo: tipo
                    }
                });

            if (erroConsulta) throw erroConsulta;

            return resultado;
        } catch (error) {
            console.error('Erro ao consultar documento:', error);
            return {
                status: 'erro',
                mensagem: error.message
            };
        }
    }

    /**
     * Cancelar documento fiscal
     */
    static async cancelarDocumentoFiscal(vendaId, motivo) {
        try {
            const { data: venda, error: erroV } = await supabase
                .from('vendas')
                .select('*')
                .eq('id', vendaId)
                .single();

            if (erroV) throw erroV;

            const tipo = venda.numero_nfce ? 'NFCE' : 'NFE';
            const chave = venda.numero_nfce ? venda.chave_acesso_nfce : venda.chave_acesso_nfe;

            if (!chave) throw new Error('Nenhum documento para cancelar');

            // Cancelar via Edge Function
            const { data: resultado, error: erroCancelamento } = await supabase.functions
                .invoke('cancelar-nf', {
                    body: {
                        chave: chave,
                        motivo: motivo,
                        tipo: tipo
                    }
                });

            if (erroCancelamento) throw erroCancelamento;

            // Atualizar venda
            await supabase
                .from('vendas')
                .update({
                    status_fiscal: 'CANCELADA',
                    status_venda: 'CANCELADA'
                })
                .eq('id', vendaId);

            return {
                sucesso: true,
                protocolo: resultado.protocolo
            };
        } catch (error) {
            console.error('Erro ao cancelar documento:', error);
            return {
                sucesso: false,
                erro: error.message
            };
        }
    }

    /**
     * Montar XML NFC-e
     */
    static async montarXmlNFCe(venda) {
        const empresa = await this.obterEmpresa();
        const cliente = venda.clientes || {};

        // 🔢 OBTER PRÓXIMO NÚMERO SINCRONIZADO
        const provider = empresa.api_fiscal_provider || 'focus_nfe';
        const numeroNFCe = await this.obterProximoNumerNFCe(empresa, provider);
        
        // 🌍 DETERMINAR AMBIENTE COM PRIORIDADE CORRETA
        const ambienteParaXml = provider === 'nuvem_fiscal' 
            ? (empresa.nuvemfiscal_ambiente || empresa.focusnfe_ambiente || 2)
            : (empresa.focusnfe_ambiente || 2);
        
        console.log(`📋 [FiscalSystem] Usando número NFC-e: ${numeroNFCe} (Provider: ${provider}, Ambiente: ${ambienteParaXml})`);

        let itensXml = '';
        venda.venda_itens.forEach((item, idx) => {
            itensXml += `
            <det nItem="${idx + 1}">
                <prod>
                    <code>${item.sku || item.produto_id}</code>
                    <xProd>${item.nome}</xProd>
                    <NCM>22021000</NCM>
                    <CFOP>5102</CFOP>
                    <uCom>UN</uCom>
                    <qCom>${item.quantidade}</qCom>
                    <vUnCom>${item.preco_unitario}</vUnCom>
                    <vItem>${item.total}</vItem>
                </prod>
            </det>`;
        });

        const xml = `<?xml version="1.0" encoding="UTF-8"?>
<nfce>
    <infNFe versao="4.00">
        <ide>
            <cUF>${this.obterCodigoEstado(empresa.estado)}</cUF>
            <natOp>VENDA</natOp>
            <mod>65</mod>
            <serie>${empresa.nfce_serie}</serie>
            <nNF>${numeroNFCe}</nNF>
            <dEmi>${new Date().toISOString().split('T')[0].replace(/-/g, '')}</dEmi>
            <hEmi>${new Date().toISOString().split('T')[1].substring(0, 8).replace(/:/g, '')}</hEmi>
            <indFinal>1</indFinal>
            <indPres>1</indPres>
            <idDest>1</idDest>
            <cMunFG>${empresa.codigo_municipio}</cMunFG>
            <tpEmis>1</tpEmis>
            <cDV>0</cDV>
            <tpAmb>${ambienteParaXml}</tpAmb>
            <finNFe>1</finNFe>
            <indIntermed>0</indIntermed>
            <procEmi>0</procEmi>
            <verProc>4.0</verProc>
        </ide>
        
        <emit>
            <CNPJ>${empresa.cnpj.replace(/\D/g, '')}</CNPJ>
            <xNome>${empresa.nome_empresa}</xNome>
            <xFant>${empresa.nome_empresa}</xFant>
            <enderEmit>
                <xLgr>${empresa.logradouro}</xLgr>
                <nro>${empresa.numero}</nro>
                <xBairro>${empresa.bairro}</xBairro>
                <cMun>${empresa.codigo_municipio}</cMun>
                <UF>${empresa.estado}</UF>
                <CEP>${empresa.cep.replace(/\D/g, '')}</CEP>
            </enderEmit>
            <IE>${empresa.inscricao_estadual}</IE>
            <IM>${empresa.inscricao_municipal || '0'}</IM>
            <CNAE>${empresa.cnae || '4723700'}</CNAE>
            <CRT>${empresa.regime_tributario}</CRT>
        </emit>
        
        <dest>
            ${cliente.cpf_cnpj ? `<${cliente.tipo === 'PJ' ? 'CNPJ' : 'CPF'}>${cliente.cpf_cnpj.replace(/\D/g, '')}</${cliente.tipo === 'PJ' ? 'CNPJ' : 'CPF'}>` : '<CNPJ>16716114000172</CNPJ>'}
            <xNome>${cliente.nome || 'CONSUMIDOR'}</xNome>
            ${cliente.endereco ? `<enderDest>
                <xLgr>${cliente.endereco}</xLgr>
                <nro>${cliente.numero || '0'}</nro>
                <xBairro>${cliente.bairro || 'SN'}</xBairro>
                <cMun>${this.obterCodigoMunicipio(cliente.cidade, cliente.estado)}</cMun>
                <UF>${cliente.estado || empresa.estado}</UF>
            </enderDest>` : ''}
        </dest>
        
        <det>
            ${itensXml}
        </det>
        
        <total>
            <ICMSTot>
                <vBC>0.00</vBC>
                <vICMS>0.00</vICMS>
                <vICMSDeson>0.00</vICMSDeson>
                <vFCP>0.00</vFCP>
                <vBCST>0.00</vBCST>
                <vST>0.00</vST>
                <vFCPST>0.00</vFCPST>
                <vFCPSTRet>0.00</vFCPSTRet>
                <vProd>${venda.subtotal}</vProd>
                <vFrete>0.00</vFrete>
                <vSeg>0.00</vSeg>
                <vDesc>${venda.desconto}</vDesc>
                <vII>0.00</vII>
                <vIPI>0.00</vIPI>
                <vIPIDevol>0.00</vIPIDevol>
                <vPIS>0.00</vPIS>
                <vCOFINS>0.00</vCOFINS>
                <vOutro>0.00</vOutro>
                <vNF>${venda.total}</vNF>
            </ICMSTot>
        </total>
        
        <pag>
            <detPag>
                <tPag>${this.mapearFormaPagamento(venda.forma_pagamento)}</tPag>
                <vPag>${venda.total}</vPag>
            </detPag>
        </pag>
        
        <infAdic>
            <infCpl>Venda via PDV. NFC-e gerada automaticamente.</infCpl>
        </infAdic>
    </infNFe>
</nfce>`;

        return xml;
    }

    /**
     * Montar XML NF-e
     */
    static async montarXmlNFe(venda) {
        // Similar ao NFC-e, mas com campos específicos para B2B
        return await this.montarXmlNFCe(venda);
    }

    /**
     * Registrar documento fiscal
     */
    static async registrarDocumentoFiscal(vendaId, tipo, resultado) {
        try {
            await supabase
                .from('documentos_fiscais')
                .insert({
                    venda_id: vendaId,
                    tipo_documento: tipo,
                    numero_documento: resultado.numero,
                    serie: resultado.serie,
                    chave_acesso: resultado.chave,
                    protocolo_autorizacao: resultado.protocolo,
                    status_sefaz: 'AUTORIZADA',
                    data_autorizacao: new Date().toISOString()
                });
        } catch (error) {
            console.error('Erro ao registrar documento:', error);
        }
    }

    /**
     * Consultar documento fiscal (NFC-e ou NF-e)
     * @param {string} chaveAcesso - Chave de acesso do documento
     * @param {string} tipo - Tipo do documento ('nfce' ou 'nfe')
     * @returns {Object} Dados do documento consultado
     */
    static async consultarDocumento(chaveAcesso, tipo = 'nfce') {
        try {
            const { data: config } = await supabase
                .from('empresa_config')
                .select('api_fiscal_provider')
                .single();

            const provider = config?.api_fiscal_provider || 'focus_nfe';

            if (provider === 'nuvem_fiscal') {
                // Nuvem Fiscal usa ID da nota, não chave de acesso
                // Buscar ID da nota no banco pela chave de acesso
                const { data: venda } = await supabase
                    .from('vendas')
                    .select('nfce_id')
                    .eq('chave_acesso_nfce', chaveAcesso)
                    .maybeSingle();

                if (!venda?.nfce_id) {
                    throw new Error('ID da nota não encontrado no banco de dados. Verifique se a nota foi emitida pela Nuvem Fiscal.');
                }

                return await NuvemFiscal.consultarNFCe(venda.nfce_id);
            } else {
                return await FocusNFe.consultarDocumento(chaveAcesso, tipo);
            }
        } catch (erro) {
            console.error('Erro ao consultar documento:', erro);
            throw erro;
        }
    }

    /**
     * Cancelar documento fiscal (NFC-e ou NF-e)
     * @param {string} chaveAcesso - Chave de acesso do documento
     * @param {string} justificativa - Justificativa do cancelamento (mínimo 15 caracteres)
     * @param {string} tipo - Tipo do documento ('nfce' ou 'nfe')
     * @returns {Object} Resultado do cancelamento
     */
    static async cancelarDocumento(chaveAcesso, justificativa, tipo = 'nfce') {
        try {
            const { data: config } = await supabase
                .from('empresa_config')
                .select('api_fiscal_provider')
                .single();

            const provider = config?.api_fiscal_provider || 'focus_nfe';

            if (provider === 'nuvem_fiscal') {
                // Nuvem Fiscal usa ID da nota, não chave de acesso
                // Tentar buscar ID da nota em documentos_fiscais primeiro (notas de distribuição)
                const { data: docFiscal } = await supabase
                    .from('documentos_fiscais')
                    .select('id, nfce_id, chave_acesso')
                    .eq('chave_acesso', chaveAcesso)
                    .maybeSingle();

                let nfceId = docFiscal?.nfce_id;

                // Se não encontrou em documentos_fiscais, tentar vendas (notas normais do PDV)
                if (!nfceId) {
                    const { data: venda } = await supabase
                        .from('vendas')
                        .select('id, nfce_id, status_fiscal')
                        .eq('chave_acesso_nfce', chaveAcesso)
                        .maybeSingle();
                    
                    nfceId = venda?.nfce_id;
                }

                if (!nfceId) {
                    throw new Error('ID da nota não encontrado no banco de dados. Verifique se a nota foi emitida pela Nuvem Fiscal.');
                }

                // Cancelar via Nuvem Fiscal
                const resultado = await NuvemFiscal.cancelarNFCe(nfceId, justificativa);
                
                // Validar resposta da Nuvem Fiscal
                // Status 'registrado' significa que o evento foi processado com sucesso
                if (resultado && (resultado.status === 'registrado' || resultado.status === 'cancelado')) {
                    console.log('✅ [FiscalSystem] Cancelamento processado com sucesso pela Nuvem Fiscal');
                    
                    return {
                        sucesso: true,
                        status: 'cancelado',
                        status_sefaz: '135',
                        mensagem: 'Cancelamento autorizado pela SEFAZ',
                        resultado_nuvem: resultado
                    };
                } else {
                    throw new Error('Resposta inesperada da Nuvem Fiscal ao cancelar: ' + JSON.stringify(resultado));
                }
            } else {
                return await FocusNFe.cancelarDocumento(chaveAcesso, justificativa, tipo);
            }
        } catch (erro) {
            console.error('Erro ao cancelar documento:', erro);
            
            // Detectar se documento já foi cancelado e sincronizar banco
            if (erro.message?.includes('[Status atual: cancelado]') || 
                erro.message?.includes('já foi CANCELADA')) {
                
                console.log('⚠️ [FiscalSystem] Documento já estava cancelado na SEFAZ. Sincronizando banco de dados...');
                console.log('📋 [FiscalSystem] Chave de acesso:', chaveAcesso);
                
                try {
                    // Buscar documento por chave de acesso (procura em documentos_fiscais ou vendas)
                    let docFiscal = null;
                    
                    // Primeiro, tenta em documentos_fiscais (distribuição ou notas de saída)
                    const { data: docFromFiscal } = await supabase
                        .from('documentos_fiscais')
                        .select('id, numero_documento, status_sefaz')
                        .eq('chave_acesso', chaveAcesso)
                        .maybeSingle();
                    
                    if (docFromFiscal?.id) {
                        docFiscal = docFromFiscal;
                    } else {
                        // Tenta em vendas (vendas normais do PDV)
                        const { data: vendaFromDB } = await supabase
                            .from('vendas')
                            .select('id, numero_nfce, status_fiscal')
                            .eq('chave_acesso_nfce', chaveAcesso)
                            .maybeSingle();
                        
                        if (vendaFromDB?.id) {
                            docFiscal = { id: vendaFromDB.id, tipo: 'venda', ...vendaFromDB };
                        }
                    }

                    console.log('🔍 [FiscalSystem] Documento já cancelado encontrado:', { docFiscal });

                    if (docFiscal?.id) {
                        // Atualizar status do documento
                        const tabelaAtualizar = docFiscal.tipo === 'venda' ? 'vendas' : 'documentos_fiscais';
                        const campoAtualizacao = docFiscal.tipo === 'venda' 
                            ? { status_fiscal: 'CANCELADA_NFCE', data_cancelamento: new Date().toISOString() }
                            : { status_sefaz: '135' };
                        
                        await supabase
                            .from(tabelaAtualizar)
                            .update(campoAtualizacao)
                            .eq('id', docFiscal.id);
                        
                        return {
                            sucesso: true,
                            status: 'cancelado',
                            status_sefaz: '135',
                            sincronizado: true,
                            mensagem: 'Documento já estava cancelado na SEFAZ. Status sincronizado no banco.'
                        };
                    }
                } catch (erroSync) {
                    console.warn('⚠️ [FiscalSystem] Erro ao sincronizar após detectar cancelamento prévio:', erroSync.message);
                }
                
                return {
                    sucesso: true,
                    status: 'cancelado',
                    status_sefaz: '135',
                    aviso: true,
                    mensagem: 'Documento já estava cancelado na SEFAZ'
                };
            }
            
            // Melhorar mensagem de erro para o usuário
            let mensagemUsuario = erro.message || 'Erro desconhecido ao cancelar documento';
            
            if (erro.code === 'ValidationFailed') {
                mensagemUsuario = `❌ ERRO DE VALIDAÇÃO (${erro.code}): ${erro.message}\n\nPossíveis causas:\n` +
                    `• NFC-e já foi cancelada anteriormente\n` +
                    `• Prazo para cancelamento expirou (30 minutos para NFC-e)\n` +
                    `• Documento em estado inválido\n\n` +
                    `Contate seu gerente se o problema persistir.`;
            } else if (mensagemUsuario.includes('já CANCELADA')) {
                mensagemUsuario = `❌ Erro ao cancelar:\n\nEste documento já foi cancelado anteriormente.\n\nNão é permitido cancelar um documento que já foi cancelado.`;
            } else if (mensagemUsuario.includes('não está em estado') || mensagemUsuario.includes('não pode ser cancelado')) {
                mensagemUsuario = `❌ Erro ao cancelar:\n\n${mensagemUsuario}\n\nVerifique o status do documento e tente novamente.`;
            }
            
            const errorToThrow = new Error(mensagemUsuario);
            errorToThrow.originalError = erro;
            throw errorToThrow;
        }
    }

    /**
     * Baixar DANFE (PDF) de um documento
     * @param {string} referencia - Referência ou chave de acesso
     * @param {string} tipo - Tipo do documento ('nfce' ou 'nfe')
     * @returns {string} URL do PDF
     */
    static async baixarDANFE(referencia, tipo = 'nfce') {
        try {
            const { data: config } = await supabase
                .from('empresa_config')
                .select('api_fiscal_provider')
                .single();

            const provider = config?.api_fiscal_provider || 'focus_nfe';

            let pdfBlobOrUrl = null;

            if (provider === 'nuvem_fiscal') {
                // Nuvem Fiscal usa ID da nota, não chave de acesso
                // Buscar ID da nota no banco pela chave de acesso
                const { data: venda } = await supabase
                    .from('vendas')
                    .select('nfce_id')
                    .eq('chave_acesso_nfce', referencia)
                    .maybeSingle();

                if (!venda?.nfce_id) {
                    throw new Error('ID da nota não encontrado no banco de dados. Verifique se a nota foi emitida pela Nuvem Fiscal.');
                }

                pdfBlobOrUrl = await NuvemFiscal.baixarPDF(venda.nfce_id);
                
                // Se for um Blob, converter para URL
                if (pdfBlobOrUrl instanceof Blob) {
                    const blobUrl = URL.createObjectURL(pdfBlobOrUrl);
                    console.log('📄 [FiscalService] Blob convertido para URL:', blobUrl.substring(0, 50) + '...');
                    return blobUrl;
                }
            } else {
                pdfBlobOrUrl = await FocusNFe.baixarDANFE(referencia, tipo);
                
                // Se for um Blob, converter para URL
                if (pdfBlobOrUrl instanceof Blob) {
                    const blobUrl = URL.createObjectURL(pdfBlobOrUrl);
                    console.log('📄 [FiscalService] Blob convertido para URL:', blobUrl.substring(0, 50) + '...');
                    return blobUrl;
                }
            }
            
            return pdfBlobOrUrl; // Já é uma URL
        } catch (erro) {
            console.error('Erro ao baixar DANFE:', erro);
            throw erro;
        }
    }

    /**
     * Baixar XML de um documento
     * @param {string} referencia - Referência ou chave de acesso
     * @param {string} tipo - Tipo do documento ('nfce' ou 'nfe')
     * @returns {string} Conteúdo XML
     */
    static async baixarXML(referencia, tipo = 'nfce') {
        try {
            const { data: config } = await supabase
                .from('empresa_config')
                .select('api_fiscal_provider')
                .single();

            const provider = config?.api_fiscal_provider || 'focus_nfe';

            if (provider === 'nuvem_fiscal') {
                // Nuvem Fiscal usa ID da nota, não chave de acesso
                // Tentar múltiplas formas de encontrar o ID:
                // 1. Buscar por chave_acesso em documentos_fiscais (campo chave_acesso)
                const { data: docFiscal } = await supabase
                    .from('documentos_fiscais')
                    .select('id, chave_acesso')
                    .eq('chave_acesso', referencia)
                    .eq('tipo_documento', 'NFCE')
                    .maybeSingle();
                
                if (docFiscal) {
                    console.log('✅ Documento fiscal encontrado em documentos_fiscais, usando ID Nuvem Fiscal...');
                }

                // 2. Se não encontrou em documentos_fiscais, tentar em vendas
                if (!docFiscal) {
                    const { data: venda } = await supabase
                        .from('vendas')
                        .select('nfce_id')
                        .eq('chave_acesso_nfce', referencia)
                        .maybeSingle();

                    if (venda?.nfce_id) {
                        console.log('✅ Nota encontrada em vendas, ID Nuvem Fiscal:', venda.nfce_id);
                        return await NuvemFiscal.baixarXML(venda.nfce_id);
                    }
                }
                
                if (docFiscal?.id) {
                    console.log('✅ Documento encontrado, ID:', docFiscal.id);
                    return await NuvemFiscal.baixarXML(docFiscal.id);
                }

                throw new Error('ID da nota não encontrado no banco de dados. Verifique se a nota foi emitida pela Nuvem Fiscal e salva corretamente.');
            } else {
                return await FocusNFe.baixarXML(referencia, tipo);
            }
        } catch (erro) {
            console.error('❌ Erro ao baixar XML:', erro);
            throw erro;
        }
    }

    /**
     * Obter empresa
     */
    static async obterEmpresa() {
        const { data } = await supabase.from('empresa_config').select('*').single();
        return data || {};
    }

    /**
     * Mapear forma de pagamento para código SEFAZ
     */
    static mapearFormaPagamento(forma) {
        const mapa = {
            'DINHEIRO': '01',
            'CARTAO_CREDITO': '02',
            'CARTAO_DEBITO': '03',
            'PIX': '26',
            'CHEQUE': '04',
            'PRAZO': '05',
            'VALE': '07'
        };
        return mapa[forma] || '01';
    }

    /**
     * Obter código de estado
     */
    static obterCodigoEstado(estado) {
        const mapa = {
            'AC': '24', 'AL': '17', 'AP': '16', 'AM': '03', 'BA': '05',
            'CE': '07', 'DF': '26', 'ES': '32', 'GO': '52', 'MA': '11',
            'MT': '28', 'MS': '50', 'MG': '31', 'PA': '15', 'PB': '21',
            'PR': '41', 'PE': '25', 'PI': '22', 'RJ': '33', 'RN': '24',
            'RS': '43', 'RO': '23', 'RR': '24', 'SC': '42', 'SP': '35',
            'SE': '28', 'TO': '29'
        };
        return mapa[estado] || '35';
    }

    /**
     * Setup de eventos
     */
    static setupEventos() {
        // Eventos de emissão fiscal
    }

    /**
     * Obter código município (placeholder)
     */
    static obterCodigoMunicipio(cidade, estado) {
        return '3550308'; // São Paulo padrão
    }

    /**
     * 🔢 SINCRONIZAR E OBTER PRÓXIMO NÚMERO DE NFC-e
     * Verifica o último número emitido (sucesso) e retorna o próximo
     * Sincroniza entre banco local, configuração da empresa e API da SEFAZ
     * 
     * @param {Object} empresa - Dados da empresa configurada
     * @param {String} provider - 'focus_nfe' ou 'nuvem_fiscal'
     * @returns {Promise<Number>} Próximo número valid para emitir
     */
    static async obterProximoNumerNFCe(empresa, provider = 'focus_nfe') {
        try {
            console.log('🔢 [FiscalSystem] Sincronizando numeração NFC-e...');
            
            // 🔧 VALOR CONFIGURADO PELO USUÁRIO (sempre usar como mínimo)
            const numeroConfigurado = parseInt(empresa.nfce_numero || 1);
            console.log('📋 Número configurado pelo usuário:', numeroConfigurado);
            
            // ===== 1. BUSCAR ÚLTIMAS NOTAS AUTORIZADAS NO BANCO LOCAL =====
            const { data: ultimaNota } = await supabase
                .from('vendas')
                .select('numero_nfce')
                .eq('status_fiscal', 'EMITIDA_NFCE') // Apenas notas autorizadas
                .not('numero_nfce', 'is', null)
                .order('numero_nfce', { ascending: false })
                .limit(1);

            let proximoNumero = numeroConfigurado;  // COMEÇAR COM VALOR CONFIGURADO
            
            if (ultimaNota && ultimaNota.length > 0) {
                const ultimoLocal = parseInt(ultimaNota[0].numero_nfce || 0);
                console.log('✅ Última nota AUTORIZADA local:', ultimoLocal);
                // Usar o maior entre configurado e último local
                proximoNumero = Math.max(numeroConfigurado, ultimoLocal + 1);
                console.log('📊 Comparação: configurado(' + numeroConfigurado + ') vs local(' + (ultimoLocal + 1) + ') → usando:', proximoNumero);
            } else {
                console.log('⚠️ Nenhuma nota autorizada encontrada no banco local - usando configuração');
            }

            // ===== 2. SINCRONIZAR COM API (Se Nuvem Fiscal) =====
            if (provider === 'nuvem_fiscal' && typeof NuvemFiscalService !== 'undefined') {
                try {
                    const cnpj = empresa.cnpj?.replace(/\D/g, '');
                    const ambiente = (empresa.nuvemfiscal_ambiente || empresa.focusnfe_ambiente) === 1 ? 'producao' : 'homologacao';
                    
                    console.log('☁️ Consultando últimas notas na Nuvem Fiscal (CNPJ:', cnpj, ', Ambiente:', ambiente + ')');
                    
                    // Buscar últimas 20 notas autorizadas
                    const resposta = await NuvemFiscalService.listarNFCe(cnpj, ambiente, 20, 'autorizado');
                    
                    if (resposta?.data && resposta.data.length > 0) {
                        const ultimoNumeroAPI = parseInt(resposta.data[0].numero || 0);
                        console.log('☁️ Último número AUTORIZADO na API:', ultimoNumeroAPI);
                        
                        if (ultimoNumeroAPI >= proximoNumero) {
                            proximoNumero = ultimoNumeroAPI + 1;
                            console.log('🔄 Ajustado para próximo número da API:', proximoNumero);
                        }
                    }
                } catch (erroAPI) {
                    console.warn('⚠️ Não foi possível sincronizar com Nuvem Fiscal:', erroAPI.message);
                    // Continuar com número local em caso de falha
                }
            }

            console.log('📊 Próximo número NFC-e a ser usado:', proximoNumero);
            return proximoNumero;

        } catch (erro) {
            console.error('❌ Erro ao sincronizar numeração NFC-e:', erro);
            // Fallback para número configurado
            return parseInt(empresa.nfce_numero || 1);
        }
    }

    /**
     * 🔐 OBTER E INCREMENTAR NÚMERO NFC-e DE FORMA ATÔMICA
     * Incrementa o número ANTES da emissão para evitar duplicidade
     * Se a emissão falhar, deve ser revertido com reverterIncrementoNumerNFCe()
     * 
     * @param {Object} empresa - Dados da empresa
     * @param {String} provider - Provider ('focus_nfe' ou 'nuvem_fiscal')
     * @returns {Number} Número obtido (já foi incrementado no config)
     */
    static async obterProximoNumerNFCeComIncremento(empresa, provider = 'focus_nfe') {
        try {
            console.log('🔐 [FiscalSystem] Obtendo e incrementando número NFC-e atomicamente...');
            
            // 1️⃣ Sincronizar com último número autorizado
            const proximoNumero = await this.obterProximoNumerNFCe(empresa, provider);
            console.log('📊 [FiscalSystem] Próximo número sincronizado:', proximoNumero);
            
            // 2️⃣ INCREMENTAR ATOMICAMENTE no banco
            // Usar validação na query para evitar race condition
            const { data: configAtual, error: erroSelect } = await supabase
                .from('empresa_config')
                .select('id, nfce_numero')
                .single();
                
            if (erroSelect || !configAtual) {
                throw new Error(`Não foi possível obter configuração da empresa: ${erroSelect?.message}`);
            }
            
            // Validação extra: garantir que o número está correto antes de incrementar
            if (parseInt(configAtual.nfce_numero || 1) !== proximoNumero) {
                console.warn('⚠️ [FiscalSystem] Número em config divergente, sincronizando...');
            }
            
            // UPDATE com validação: só atualiza se o número em BD corresponde ao esperado
            const numeroProxEsperado = proximoNumero + 1;
            const { error: erroUpdate, data: dataUpdate } = await supabase
                .from('empresa_config')
                .update({ nfce_numero: numeroProxEsperado })
                .eq('id', configAtual.id)
                .eq('nfce_numero', proximoNumero) // ⚠️ Validação de concorrência
                .select();
            
            if (erroUpdate) {
                throw new Error(`Falha ao incrementar número: ${erroUpdate.message}`);
            }
            
            if (!dataUpdate || dataUpdate.length === 0) {
                // Verificar se o número já foi incrementado por outra requisição
                const { data: configAtualizado } = await supabase
                    .from('empresa_config')
                    .select('nfce_numero')
                    .single();
                    
                const numeroAtual = parseInt(configAtualizado?.nfce_numero || 1);
                if (numeroAtual > proximoNumero) {
                    console.warn('⚠️ [FiscalSystem] Número já foi incrementado por outra requisição, usando novo número:', numeroAtual);
                    return await this.obterProximoNumerNFCeComIncremento(empresa, provider);
                }
                
                throw new Error('Não foi possível incrementar o número (validação de concorrência falhou)');
            }
            
            console.log('✅ [FiscalSystem] Número NFC-e reservado e incrementado atomicamente:', proximoNumero);
            return proximoNumero;
            
        } catch (erro) {
            console.error('❌ [FiscalSystem] Erro ao obter/incrementar número NFC-e:', erro.message);
            throw erro;
        }
    }

    /**
     * ⚠️ REVOGAR INCREMENTO DE NÚMERO NFC-e
     * Deve ser chamado se a emissão falhar após obterProximoNumerNFCeComIncremento
     * Recua o número de volta para o anterior
     * 
     * @param {Number} numeroObtido - Número que foi obtido (será decrementado)
     */
    static async reverterIncrementoNumerNFCe(numeroObtido) {
        try {
            if (!numeroObtido || numeroObtido < 1) {
                console.warn('⚠️ [FiscalSystem] Número inválido para reversão:', numeroObtido);
                return;
            }
            
            console.log('⚠️ [FiscalSystem] Revertendo incremento de número NFC-e para:', numeroObtido);
            
            const { error } = await supabase
                .from('empresa_config')
                .update({ nfce_numero: numeroObtido })
                .eq('nfce_numero', numeroObtido + 1);
            
            if (error) {
                console.error('❌ [FiscalSystem] Erro ao reverter número:', error.message);
                throw error;
            }
            
            console.log('✅ [FiscalSystem] Número NFC-e revertido com sucesso para:', numeroObtido);
        } catch (erro) {
            console.error('❌ [FiscalSystem] Falha ao reverter incremento:', erro.message);
            throw erro;
        }
    }

    /**
     * 💾 ATUALIZAR NÚMERO NFC-e NA CONFIGURAÇÃO
     * Incrementa e salva o número da próxima NFC-e após emissão bem-sucedida
     * 
     * @param {String} numeroEmitido - Número que foi emitido
     */
    static async atualizarNumerNFCeConfig(numeroEmitido) {
        try {
            console.log('💾 Atualizando número NFC-e configurado para:', numeroEmitido + 1);
            
            await supabase
                .from('empresa_config')
                .update({ nfce_numero: numeroEmitido + 1 })
                .eq('id', (await supabase.from('empresa_config').select('id').single()).data.id);
                
            console.log('✅ Número NFC-e atualizado com sucesso');
        } catch (erro) {
            console.warn('⚠️ Não foi possível atualizar número NFC-e configurado:', erro.message);
            // Continuar de qualquer forma, pois o número foi emitido
        }
    }
}

// Criar alias para compatibilidade
const FiscalService = FiscalSystem;

// Inicializar
document.addEventListener('DOMContentLoaded', () => FiscalSystem.init());
