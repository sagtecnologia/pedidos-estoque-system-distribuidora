const SefazDireta = {
    ENDPOINT: `${SUPABASE_URL}/functions/v1/sefaz-nfce`,

    async invoke(action, payload = {}) {
        const { data: { session } = {} } = await supabase.auth.getSession();
        const headers = {
            'Content-Type': 'application/json',
            'apikey': SUPABASE_ANON_KEY
        };

        if (session?.access_token) {
            headers['Authorization'] = `Bearer ${session.access_token}`;
        }

        const response = await fetch(this.ENDPOINT, {
            method: 'POST',
            headers,
            body: JSON.stringify({
                action,
                ...payload
            })
        });

        const data = await response.json().catch(() => ({}));
        if (!response.ok) {
            throw new Error(data?.erro || data?.message || `Falha na SEFAZ direta (${response.status})`);
        }

        return data;
    },

    async getConfig() {
        const config = await getEmpresaConfig();
        if (!config) {
            throw new Error('Configurações da empresa não encontradas');
        }

        if (!config.certificado_digital || !config.senha_certificado) {
            throw new Error('Certificado A1 e senha são obrigatórios para emissão direta na SEFAZ');
        }

        if (!config.cnpj || !config.inscricao_estadual || !config.estado) {
            throw new Error('CNPJ, inscrição estadual e UF da empresa são obrigatórios para emissão direta na SEFAZ');
        }

        if (!config.csc_id || !config.csc_token) {
            throw new Error('CSC ID e CSC Token são obrigatórios para NFC-e direta na SEFAZ');
        }

        return config;
    },

    normalizarFormaPagamento(tipo) {
        const mapa = {
            DINHEIRO: 'dinheiro',
            CASH: 'dinheiro',
            CREDITO: 'cartao_credito',
            CARTAO_CREDITO: 'cartao_credito',
            cartao_credito: 'cartao_credito',
            DEBITO: 'cartao_debito',
            CARTAO_DEBITO: 'cartao_debito',
            cartao_debito: 'cartao_debito',
            PIX: 'pix',
            pix: 'pix',
            TRANSFERENCIA: 'transferencia',
            BOLETO: 'boleto',
            OUTROS: 'outros'
        };

        return mapa[tipo] || 'outros';
    },

    obterDescricaoPagamento(tipoNormalizado) {
        const mapa = {
            dinheiro: 'Dinheiro',
            cartao_credito: 'Cartão de Crédito',
            cartao_debito: 'Cartão de Débito',
            pix: 'PIX',
            transferencia: 'Transferência Bancária',
            boleto: 'Boleto Bancário',
            outros: 'Outros'
        };

        return mapa[tipoNormalizado] || 'Outros';
    },

    construirVendaParaPayload(vendaData, itensData, pagamentosData, clienteData) {
        const pagamentos = Array.isArray(pagamentosData) ? pagamentosData : [];
        const formaPagamentoNormalizada = this.normalizarFormaPagamento(
            pagamentos[0]?.tipo || vendaData?.forma_pagamento || 'OUTROS'
        );

        return {
            ...vendaData,
            total: vendaData.total ?? vendaData.valor_total ?? 0,
            subtotal: vendaData.subtotal ?? vendaData.valor_produtos ?? vendaData.total ?? 0,
            desconto: vendaData.desconto ?? vendaData.desconto_valor ?? 0,
            troco: vendaData.troco ?? vendaData.valor_troco ?? 0,
            forma_pagamento: formaPagamentoNormalizada,
            forma_pagamento_descricao: this.obterDescricaoPagamento(formaPagamentoNormalizada),
            venda_itens: itensData || [],
            clientes: clienteData || null,
            pagamentos
        };
    },

    async montarPayloadNFCe(vendaData, itensData, pagamentosData, clienteData = null, options = {}) {
        const empresa = options.empresaConfig || await this.getConfig();
        const venda = this.construirVendaParaPayload(vendaData, itensData, pagamentosData, clienteData);

        if (typeof NuvemFiscal === 'undefined' || typeof NuvemFiscal.montarPayloadNFCe !== 'function') {
            throw new Error('Serviço fiscal base indisponível para montar a NFC-e');
        }

        const payload = await NuvemFiscal.montarPayloadNFCe(venda, empresa);
        const tpAmb = parseInt(empresa.focusnfe_ambiente || empresa.nuvemfiscal_ambiente || 2, 10) === 1 ? 1 : 2;

        payload.referencia = `VENDA-${vendaData.id || vendaData.numero_venda || Date.now()}`;
        payload.infNFe.ide.serie = parseInt(empresa.nfce_serie || 1, 10);
        payload.infNFe.ide.nNF = parseInt(options.numeroNfce || payload.infNFe.ide.nNF || empresa.nfce_numero || 1, 10);
        payload.infNFe.ide.tpAmb = tpAmb;
        payload.infNFe.ide.natOp = empresa.natureza_operacao_padrao || 'VENDA';
        payload.infNFe.ide.verProc = 'PEDIDOS-ESTOQUE';
        payload.infNFe.emit.xNome = empresa.razao_social || empresa.nome_empresa;
        payload.infNFe.emit.xFant = empresa.nome_empresa || empresa.razao_social;
        payload.infNFe.emit.enderEmit.nro = empresa.endereco_numero || empresa.numero || 'SN';
        payload.infNFe.emit.enderEmit.xMun = empresa.cidade || payload.infNFe.emit.enderEmit.xMun || '';
        payload.infNFe.emit.enderEmit.UF = empresa.estado || payload.infNFe.emit.enderEmit.UF || '';
        payload.infNFe.emit.enderEmit.CEP = (empresa.cep || '').replace(/\D/g, '') || payload.infNFe.emit.enderEmit.CEP || '';
        payload.infNFe.emit.IE = (empresa.inscricao_estadual || '').replace(/\D/g, '');
        payload.infNFe.emit.CRT = parseInt(empresa.regime_tributario_codigo || empresa.regime_tributario || 1, 10);

        payload.infNFe.pag.detPag = (venda.pagamentos?.length ? venda.pagamentos : [{
            tipo: venda.forma_pagamento,
            valor: venda.total
        }]).map((pagamento) => {
            const forma = this.normalizarFormaPagamento(pagamento.tipo);
            return {
                tPag: NuvemFiscal.mapearFormaPagamento(forma),
                xPag: this.obterDescricaoPagamento(forma),
                vPag: parseFloat(Number(pagamento.valor || 0).toFixed(2))
            };
        });

        payload.infNFe.pag.vTroco = parseFloat(Number(venda.troco || 0).toFixed(2));

        return payload;
    },

    async validarCertificadoLocal(base64, senha) {
        return await this.invoke('validar_certificado', {
            certificado: base64,
            senha
        });
    },

    async consultarStatusServico() {
        const config = await this.getConfig();
        return await this.invoke('status', {
            cnpj: config.cnpj,
            uf: config.estado,
            ambiente: parseInt(config.focusnfe_ambiente || config.nuvemfiscal_ambiente || 2, 10)
        });
    },

    async emitirNFCe(vendaData, itensData, pagamentosData, clienteData = null, options = {}) {
        const empresa = options.empresaConfig || await this.getConfig();
        const payload = await this.montarPayloadNFCe(vendaData, itensData, pagamentosData, clienteData, options);
        const resultado = await this.invoke('emitir', {
            ambiente: parseInt(empresa.focusnfe_ambiente || empresa.nuvemfiscal_ambiente || 2, 10),
            uf: empresa.estado,
            payload
        });

        if (!resultado?.success) {
            const rejeicao = this.montarResultadoRejeicao(resultado, vendaData, payload);
            const erro = new Error(rejeicao.mensagem || 'Falha ao emitir NFC-e pela SEFAZ direta');
            erro.detalhesFiscal = rejeicao;
            throw erro;
        }

        const dataEmissao = resultado.data_emissao || payload?.infNFe?.ide?.dhEmi || new Date().toISOString();
        const dataAutorizacao = resultado.data_autorizacao || new Date().toISOString();

        return {
            success: true,
            status: 'autorizado',
            status_sefaz: 'autorizado',
            numero: resultado.numero,
            serie: resultado.serie,
            chave_nfe: resultado.chave_acesso,
            chave_acesso: resultado.chave_acesso,
            protocolo: resultado.protocolo,
            caminho_danfe: resultado.xml_proc ? this.gerarDanfeUrlFromXml(resultado.xml_proc) : null,
            provider: 'sefaz_direta',
            xml: resultado.xml_proc || resultado.xml_assinado || null,
            xml_proc: resultado.xml_proc || null,
            mensagem: resultado.mensagem || 'NFC-e autorizada pela SEFAZ',
            data_emissao: dataEmissao,
            data_autorizacao: dataAutorizacao,
            documentoFiscalData: {
                tipo_documento: 'NFCE',
                numero_documento: String(resultado.numero || '0'),
                serie: parseInt(resultado.serie || 1, 10),
                chave_acesso: resultado.chave_acesso,
                protocolo_autorizacao: resultado.protocolo,
                status_sefaz: '100',
                mensagem_sefaz: resultado.mensagem || 'Autorizado o uso da NFC-e',
                valor_total: vendaData.total,
                natureza_operacao: payload?.infNFe?.ide?.natOp || 'VENDA',
                data_emissao: dataEmissao,
                data_autorizacao: dataAutorizacao,
                xml_nota: resultado.xml_proc || resultado.xml_assinado || null,
                xml_retorno: JSON.stringify(resultado),
                tentativas_emissao: 1,
                ultima_tentativa: new Date().toISOString(),
                api_provider: 'sefaz_direta'
            }
        };
    },

    montarResultadoRejeicao(resultado, vendaData, payload) {
        const numero = String(
            resultado?.numero ||
            payload?.infNFe?.ide?.nNF ||
            vendaData?.numero_nfce ||
            '0'
        );
        const serie = parseInt(
            resultado?.serie ||
            payload?.infNFe?.ide?.serie ||
            vendaData?.serie ||
            1,
            10
        );
        const chaveAcesso = (
            resultado?.chave_acesso ||
            resultado?.chave_nfe ||
            payload?.infNFe?.['@_Id']?.replace(/^NFe/i, '') ||
            null
        );
        const statusSefaz = String(
            resultado?.codigo_status ||
            resultado?.status_sefaz ||
            resultado?.cStat ||
            '999'
        );
        const mensagem = resultado?.mensagem || resultado?.xMotivo || 'NFC-e rejeitada pela SEFAZ';
        const dataEmissao = resultado?.data_emissao || payload?.infNFe?.ide?.dhEmi || new Date().toISOString();
        const xmlRetorno = typeof resultado?.xml_retorno === 'string'
            ? resultado.xml_retorno
            : JSON.stringify(resultado || {}, null, 2);

        return {
            success: false,
            status: 'rejeitado',
            status_sefaz: statusSefaz,
            numero,
            serie,
            chave_acesso: chaveAcesso,
            chave_nfe: chaveAcesso,
            protocolo: resultado?.protocolo || null,
            provider: 'sefaz_direta',
            mensagem,
            xml_retorno: xmlRetorno,
            resultado_bruto: resultado,
            documentoFiscalData: {
                tipo_documento: 'NFCE',
                numero_documento: numero,
                serie,
                chave_acesso: chaveAcesso,
                protocolo_autorizacao: resultado?.protocolo || null,
                status_sefaz: statusSefaz,
                mensagem_sefaz: mensagem,
                valor_total: vendaData?.total || 0,
                natureza_operacao: payload?.infNFe?.ide?.natOp || 'VENDA',
                data_emissao: dataEmissao,
                data_autorizacao: null,
                xml_nota: resultado?.xml_assinado || null,
                xml_retorno: xmlRetorno,
                tentativas_emissao: 1,
                ultima_tentativa: new Date().toISOString(),
                api_provider: 'sefaz_direta'
            }
        };
    },

    async consultarDocumento(chaveAcesso, tipo = 'nfce') {
        const config = await this.getConfig();
        const resultado = await this.invoke('consultar', {
            ambiente: parseInt(config.focusnfe_ambiente || config.nuvemfiscal_ambiente || 2, 10),
            uf: config.estado,
            chave_acesso: chaveAcesso,
            tipo
        });

        return {
            ...resultado,
            caminho_danfe: await this.baixarDANFE(chaveAcesso, tipo)
        };
    },

    async cancelarDocumento(chaveAcesso, justificativa, tipo = 'nfce') {
        const config = await this.getConfig();
        const resultado = await this.invoke('cancelar', {
            ambiente: parseInt(config.focusnfe_ambiente || config.nuvemfiscal_ambiente || 2, 10),
            uf: config.estado,
            chave_acesso: chaveAcesso,
            justificativa,
            tipo
        });

        return {
            sucesso: !!resultado.success,
            status: resultado.status || 'cancelado',
            status_sefaz: resultado.status_sefaz || '135',
            protocolo: resultado.protocolo,
            mensagem: resultado.mensagem || 'Cancelamento autorizado pela SEFAZ',
            provider: 'sefaz_direta'
        };
    },

    async obterXmlSalvo(chaveAcesso) {
        const { data: doc } = await supabase
            .from('documentos_fiscais')
            .select('xml_nota, xml_retorno')
            .eq('chave_acesso', chaveAcesso)
            .maybeSingle();

        if (doc?.xml_nota) {
            return doc.xml_nota;
        }

        const { data: venda } = await supabase
            .from('vendas')
            .select('xml_nfce')
            .eq('chave_acesso_nfce', chaveAcesso)
            .maybeSingle();

        return venda?.xml_nfce || null;
    },

    async baixarXML(chaveAcesso, tipo = 'nfce') {
        let xmlContent = await this.obterXmlSalvo(chaveAcesso);

        if (!xmlContent) {
            const consulta = await this.consultarDocumento(chaveAcesso, tipo);
            xmlContent = consulta.xml_proc || consulta.xml || null;
        }

        if (!xmlContent) {
            throw new Error('XML da NFC-e não encontrado');
        }

        const blob = new Blob([xmlContent], { type: 'application/xml' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `NFCE-${chaveAcesso}.xml`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);

        return blob;
    },

    obterPrimeiroElemento(ctx, nomeLocal) {
        if (!ctx || !nomeLocal) {
            return null;
        }

        if (typeof ctx.getElementsByTagNameNS === 'function') {
            return ctx.getElementsByTagNameNS('*', nomeLocal)[0] || null;
        }

        if (typeof ctx.getElementsByTagName === 'function') {
            return ctx.getElementsByTagName(nomeLocal)[0] || null;
        }

        return null;
    },

    obterTextoNo(ctx, seletor) {
        const partes = String(seletor || '')
            .split('>')
            .map((parte) => parte.trim())
            .filter(Boolean);

        let atual = ctx;
        for (const parte of partes) {
            atual = this.obterPrimeiroElemento(atual, parte);
            if (!atual) {
                return '';
            }
        }

        return atual.textContent?.trim() || '';
    },

    escapeHtml(valor) {
        return String(valor ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    },

    formatarMoeda(valor) {
        return Number(valor || 0).toLocaleString('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        });
    },

    montarHtmlDanfe(xmlContent) {
        const parser = new DOMParser();
        const xml = parser.parseFromString(xmlContent, 'application/xml');

        const emitente = {
            nome: this.obterTextoNo(xml, 'emit > xFant') || this.obterTextoNo(xml, 'emit > xNome'),
            razao: this.obterTextoNo(xml, 'emit > xNome'),
            cnpj: this.obterTextoNo(xml, 'emit > CNPJ'),
            ie: this.obterTextoNo(xml, 'emit > IE'),
            endereco: [
                this.obterTextoNo(xml, 'enderEmit > xLgr'),
                this.obterTextoNo(xml, 'enderEmit > nro'),
                this.obterTextoNo(xml, 'enderEmit > xBairro'),
                this.obterTextoNo(xml, 'enderEmit > xMun'),
                this.obterTextoNo(xml, 'enderEmit > UF')
            ].filter(Boolean).join(', ')
        };

        const info = {
            numero: this.obterTextoNo(xml, 'ide > nNF'),
            serie: this.obterTextoNo(xml, 'ide > serie'),
            emissao: this.obterTextoNo(xml, 'ide > dhEmi'),
            chave: this.obterTextoNo(xml, 'protNFe > chNFe') || this.obterTextoNo(xml, 'infProt > chNFe') || this.obterPrimeiroElemento(xml, 'infNFe')?.getAttribute('Id') || '',
            protocolo: this.obterTextoNo(xml, 'protNFe > nProt') || this.obterTextoNo(xml, 'infProt > nProt'),
            total: this.obterTextoNo(xml, 'ICMSTot > vNF'),
            qrCode: this.obterTextoNo(xml, 'infNFeSupl > qrCode')
        };

        const itens = Array.from(xml.getElementsByTagNameNS('*', 'det')).map((item) => ({
            codigo: this.obterTextoNo(item, 'prod > cProd'),
            descricao: this.obterTextoNo(item, 'prod > xProd'),
            quantidade: this.obterTextoNo(item, 'prod > qCom'),
            unidade: this.obterTextoNo(item, 'prod > uCom'),
            valorUnitario: this.obterTextoNo(item, 'prod > vUnCom'),
            valorTotal: this.obterTextoNo(item, 'prod > vProd')
        }));

        return `<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>DANFCE ${this.escapeHtml(info.numero)}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 24px; color: #111827; }
        h1, h2, p { margin: 0; }
        .topo { display: flex; justify-content: space-between; gap: 24px; margin-bottom: 20px; }
        .bloco { border: 1px solid #d1d5db; border-radius: 8px; padding: 16px; }
        .titulo { font-size: 22px; font-weight: 700; margin-bottom: 12px; }
        .muted { color: #6b7280; font-size: 12px; }
        .grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 10px; }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; }
        th, td { border-bottom: 1px solid #e5e7eb; padding: 8px; text-align: left; font-size: 13px; }
        th { background: #f9fafb; }
        .total { margin-top: 16px; text-align: right; font-size: 18px; font-weight: 700; }
        .qrcode { margin-top: 20px; word-break: break-all; font-size: 11px; }
    </style>
</head>
<body>
    <div class="topo">
        <div class="bloco" style="flex: 2;">
            <div class="titulo">${this.escapeHtml(emitente.nome || 'Emitente')}</div>
            <p>${this.escapeHtml(emitente.razao)}</p>
            <p>CNPJ: ${this.escapeHtml(emitente.cnpj)} | IE: ${this.escapeHtml(emitente.ie)}</p>
            <p>${this.escapeHtml(emitente.endereco)}</p>
        </div>
        <div class="bloco" style="flex: 1;">
            <h2>NFC-e</h2>
            <p>Número: ${this.escapeHtml(info.numero)}</p>
            <p>Série: ${this.escapeHtml(info.serie)}</p>
            <p>Emissão: ${this.escapeHtml(info.emissao)}</p>
            <p>Protocolo: ${this.escapeHtml(info.protocolo)}</p>
        </div>
    </div>

    <div class="bloco">
        <div class="muted">Chave de acesso</div>
        <div>${this.escapeHtml(info.chave.replace(/^NFe/i, ''))}</div>
    </div>

    <table>
        <thead>
            <tr>
                <th>Código</th>
                <th>Descrição</th>
                <th>Qtd</th>
                <th>UN</th>
                <th>Vlr Unit.</th>
                <th>Vlr Total</th>
            </tr>
        </thead>
        <tbody>
            ${itens.map((item) => `
                <tr>
                    <td>${this.escapeHtml(item.codigo)}</td>
                    <td>${this.escapeHtml(item.descricao)}</td>
                    <td>${this.escapeHtml(item.quantidade)}</td>
                    <td>${this.escapeHtml(item.unidade)}</td>
                    <td>${this.escapeHtml(item.valorUnitario)}</td>
                    <td>${this.escapeHtml(item.valorTotal)}</td>
                </tr>
            `).join('')}
        </tbody>
    </table>

    <div class="total">Total da NFC-e: ${this.formatarMoeda(info.total)}</div>

    ${info.qrCode ? `
        <div class="bloco qrcode">
            <div class="muted">Consulta por QR Code</div>
            <div>${this.escapeHtml(info.qrCode)}</div>
        </div>
    ` : ''}
</body>
</html>`;
    },

    gerarDanfeUrlFromXml(xmlContent) {
        const html = this.montarHtmlDanfe(xmlContent);
        const blob = new Blob([html], { type: 'text/html' });
        return URL.createObjectURL(blob);
    },

    async baixarDANFE(chaveAcesso, tipo = 'nfce') {
        let xmlContent = await this.obterXmlSalvo(chaveAcesso);

        if (!xmlContent) {
            const consulta = await this.invoke('consultar', {
                chave_acesso: chaveAcesso,
                tipo
            });
            xmlContent = consulta.xml_proc || consulta.xml || null;
        }

        if (!xmlContent) {
            throw new Error('XML da NFC-e não encontrado para gerar o DANFE');
        }

        return this.gerarDanfeUrlFromXml(xmlContent);
    }
};

window.SefazDireta = SefazDireta;
