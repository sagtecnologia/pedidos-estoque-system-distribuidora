/**
 * Serviço de Cálculo Fiscal e Tributação
 * Calcula ICMS, PIS, COFINS, IPI conforme regime tributário
 * Busca configurações de produto, categoria e alíquotas estaduais
 */

console.log('📋 [ServicoFiscal] Carregando arquivo servico-fiscal.js...');

class ServicoFiscal {
    constructor() {
        this.empresaConfig = null;
        this.cache = {
            produtos: new Map(),
            categorias: new Map(),
            aliquotas: new Map()
        };
    }

    /**
     * Carregar configuração da empresa
     */
    async carregarConfigEmpresa() {
        if (this.empresaConfig) return this.empresaConfig;

        const { data, error } = await supabase
            .from('empresa_config')
            .select('*')
            .single();

        if (error) throw new Error('Configuração da empresa não encontrada');

        this.empresaConfig = data;
        return data;
    }

    /**
     * Buscar dados fiscais do produto (com fallback para categoria)
     */
    async buscarDadosFiscaisProduto(produtoId) {
        // Verificar cache
        if (this.cache.produtos.has(produtoId)) {
            return this.cache.produtos.get(produtoId);
        }

        // Buscar produto com dados fiscais
        const { data: produto, error } = await supabase
            .from('produtos')
            .select(`
                *,
                categorias!inner (
                    id,
                    nome,
                    categoria_impostos (*)
                )
            `)
            .eq('id', produtoId)
            .maybeSingle();

        if (error) {
            console.error('Erro ao buscar produto:', error);
            return null;
        }

        // Se não achou produto, retornar null
        if (!produto) {
            console.warn('Produto não encontrado:', produtoId);
            return null;
        }

        // Montar dados fiscais (produto tem prioridade sobre categoria)
        const categoriaImpostos = produto.categorias?.categoria_impostos?.[0];
        
        const dadosFiscais = {
            // Dados básicos
            codigo_barras: produto.codigo_barras || 'SEM GTIN',
            ncm: produto.ncm || categoriaImpostos?.ncm_padrao || '22021000', // Padrão: bebidas não alcoólicas
            cfop_venda: produto.cfop_venda || categoriaImpostos?.cfop_padrao || '5102',
            cfop_compra: produto.cfop_compra || '1102',
            origem: produto.origem || categoriaImpostos?.origem_padrao || '0',
            cest: produto.cest || null,
            
            // CST/CSOSN
            cst_icms: produto.cst_icms || categoriaImpostos?.cst_icms || '102',
            cst_pis: produto.cst_pis || '49',
            cst_cofins: produto.cst_cofins || '49',
            cst_ipi: produto.cst_ipi || null,
            
            // Alíquotas
            aliquota_icms: parseFloat(produto.aliquota_icms || categoriaImpostos?.aliquota_icms || 0),
            aliquota_pis: parseFloat(produto.aliquota_pis || categoriaImpostos?.aliquota_pis || 0),
            aliquota_cofins: parseFloat(produto.aliquota_cofins || categoriaImpostos?.aliquota_cofins || 0),
            aliquota_ipi: parseFloat(produto.aliquota_ipi || categoriaImpostos?.aliquota_ipi || 0),
            
            // Dados do produto
            unidade: produto.unidade || 'UN',
            descricao_nfe: produto.descricao_nfe || produto.nome
        };

        // Salvar no cache
        this.cache.produtos.set(produtoId, dadosFiscais);
        
        return dadosFiscais;
    }

    /**
     * Retornar dados fiscais padrão para produto sem configuração completa
     */
    obterDadosFiscaisPadrao(nomeProduct = 'Produto') {
        return {
            codigo_barras: 'SEM GTIN',
            ncm: '22021000', // Bebidas não alcoólicas
            cfop_venda: '5102',
            cfop_compra: '1102',
            origem: '0',
            cest: null,
            cst_icms: '102', // ICMS tributado
            cst_pis: '49', // PIS não tributado
            cst_cofins: '49', // COFINS não tributado
            cst_ipi: null,
            aliquota_icms: 0,
            aliquota_pis: 0,
            aliquota_cofins: 0,
            aliquota_ipi: 0,
            unidade: 'UN',
            descricao_nfe: nomeProduct
        };
    }

    /**
        const cacheKey = `${ufOrigem}-${ufDestino}-${categoriaId || 'geral'}`;
        
        if (this.cache.aliquotas.has(cacheKey)) {
            return this.cache.aliquotas.get(cacheKey);
        }

        let query = supabase
            .from('aliquotas_estaduais')
            .select('*')
            .eq('estado_origem', ufOrigem)
            .eq('estado_destino', ufDestino)
            .eq('ativo', true)
            .lte('vigencia_inicio', new Date().toISOString().split('T')[0]);

        // Filtrar por categoria se fornecida
        if (categoriaId) {
            query = query.eq('categoria_id', categoriaId);
        } else {
            query = query.is('categoria_id', null);
        }

        const { data } = await query.order('vigencia_inicio', { ascending: false }).limit(1).single();

        if (data) {
            this.cache.aliquotas.set(cacheKey, data);
        }

        return data;
    }

    /**
     * Calcular impostos de um item
     */
    async calcularImpostosItem(item, empresa, ufDestino = null) {
        // Validar item
        if (!item || !item.produto_id) {
            console.warn('Item inválido para calcular impostos:', item);
            return this.impostosZerados();
        }

        const dadosFiscais = await this.buscarDadosFiscaisProduto(item.produto_id);
        
        if (!dadosFiscais) {
            console.warn('Dados fiscais não encontrados para produto:', item.produto_id);
            return this.impostosZerados();
        }

        const valorProduto = parseFloat(item.subtotal || (item.quantidade * item.preco_unitario));
        const desconto = parseFloat(item.desconto || 0);
        const baseCalculo = valorProduto - desconto;

        // Determinar se é operação interestadual
        const ufEmpresa = empresa.estado || empresa.uf;
        const operacaoInterestadual = ufDestino && ufDestino !== ufEmpresa;

        // Buscar alíquota (interestadual se necessário)
        let aliquotaICMS = dadosFiscais.aliquota_icms;
        if (operacaoInterestadual) {
            const aliquotaInterestadual = await this.buscarAliquotaInterestadual(
                ufEmpresa,
                ufDestino,
                item.categoria_id
            );
            if (aliquotaInterestadual) {
                aliquotaICMS = aliquotaInterestadual.aliquota_icms;
            }
        }

        // Regime tributário
        const crt = parseInt(empresa.regime_tributario_codigo || empresa.crt || '1');
        const simplesNacional = crt === 1 || crt === 2;

        let valorICMS = 0;
        let valorPIS = 0;
        let valorCOFINS = 0;
        let valorIPI = 0;

        // Calcular ICMS
        if (!simplesNacional && dadosFiscais.cst_icms !== '40' && dadosFiscais.cst_icms !== '41') {
            // Regime Normal: calcular ICMS
            valorICMS = (baseCalculo * aliquotaICMS) / 100;
        }
        // Simples Nacional: ICMS já está incluso no regime, não destacar

        // Calcular PIS e COFINS
        if (dadosFiscais.cst_pis === '01' || dadosFiscais.cst_pis === '02') {
            valorPIS = (baseCalculo * dadosFiscais.aliquota_pis) / 100;
        }
        
        if (dadosFiscais.cst_cofins === '01' || dadosFiscais.cst_cofins === '02') {
            valorCOFINS = (baseCalculo * dadosFiscais.aliquota_cofins) / 100;
        }

        // Calcular IPI (se aplicável)
        if (dadosFiscais.aliquota_ipi > 0 && dadosFiscais.cst_ipi) {
            valorIPI = (baseCalculo * dadosFiscais.aliquota_ipi) / 100;
        }

        return {
            // Dados fiscais para a nota
            ncm: dadosFiscais.ncm,
            cfop: operacaoInterestadual 
                ? dadosFiscais.cfop_venda.replace('5', '6') // 5102 -> 6102
                : dadosFiscais.cfop_venda,
            origem: dadosFiscais.origem,
            cest: dadosFiscais.cest,
            codigo_barras: dadosFiscais.codigo_barras,
            unidade: dadosFiscais.unidade,
            
            // CST
            cst_icms: dadosFiscais.cst_icms,
            cst_pis: dadosFiscais.cst_pis,
            cst_cofins: dadosFiscais.cst_cofins,
            cst_ipi: dadosFiscais.cst_ipi,
            
            // Valores calculados
            baseCalculo: parseFloat(baseCalculo.toFixed(2)),
            aliquotaICMS: parseFloat(aliquotaICMS.toFixed(2)),
            valorICMS: parseFloat(valorICMS.toFixed(2)),
            aliquotaPIS: parseFloat(dadosFiscais.aliquota_pis.toFixed(2)),
            valorPIS: parseFloat(valorPIS.toFixed(2)),
            aliquotaCOFINS: parseFloat(dadosFiscais.aliquota_cofins.toFixed(2)),
            valorCOFINS: parseFloat(valorCOFINS.toFixed(2)),
            aliquotaIPI: parseFloat(dadosFiscais.aliquota_ipi.toFixed(2)),
            valorIPI: parseFloat(valorIPI.toFixed(2)),
            
            // Total de impostos
            totalImpostos: parseFloat((valorICMS + valorPIS + valorCOFINS + valorIPI).toFixed(2)),
            
            // Flags
            simplesNacional,
            operacaoInterestadual
        };
    }

    /**
     * Retornar impostos zerados (fallback)
     */
    impostosZerados() {
        return {
            ncm: '00000000',
            cfop: '5102',
            origem: '0',
            cest: null,
            codigo_barras: 'SEM GTIN',
            unidade: 'UN',
            cst_icms: '102',
            cst_pis: '49',
            cst_cofins: '49',
            cst_ipi: null,
            baseCalculo: 0,
            aliquotaICMS: 0,
            valorICMS: 0,
            aliquotaPIS: 0,
            valorPIS: 0,
            aliquotaCOFINS: 0,
            valorCOFINS: 0,
            aliquotaIPI: 0,
            valorIPI: 0,
            totalImpostos: 0,
            simplesNacional: true,
            operacaoInterestadual: false
        };
    }

    /**
     * Calcular totais de impostos para a nota inteira
     */
    async calcularTotaisNota(itens, empresa, ufDestino = null) {
        const totais = {
            vBC: 0,      // Base de cálculo ICMS
            vICMS: 0,    // Valor ICMS
            vPIS: 0,     // Valor PIS
            vCOFINS: 0,  // Valor COFINS
            vIPI: 0,     // Valor IPI
            vTotTrib: 0  // Total aproximado de tributos
        };

        for (const item of itens) {
            const impostos = await this.calcularImpostosItem(item, empresa, ufDestino);
            
            totais.vBC += impostos.baseCalculo;
            totais.vICMS += impostos.valorICMS;
            totais.vPIS += impostos.valorPIS;
            totais.vCOFINS += impostos.valorCOFINS;
            totais.vIPI += impostos.valorIPI;
            totais.vTotTrib += impostos.totalImpostos;
        }

        // Arredondar para 2 casas decimais
        Object.keys(totais).forEach(key => {
            totais[key] = parseFloat(totais[key].toFixed(2));
        });

        return totais;
    }

    /**
     * Determinar CSOSN para Simples Nacional
     */
    determinarCSOSN(cstConfigurado, permiteCredito = false) {
        // Mapeamento CST -> CSOSN para Simples Nacional
        const mapeamento = {
            '00': '102',  // Tributada -> Tributada pelo SN sem permissão de crédito
            '40': '300',  // Isenta -> Imune
            '41': '400',  // Não tributada -> Não tributada pelo SN
            '60': '500'   // ICMS cobrado anteriormente por ST
        };

        // Se já é CSOSN (3 dígitos começando com 1-5)
        if (cstConfigurado && cstConfigurado.length === 3) {
            return cstConfigurado;
        }

        // Mapear CST para CSOSN
        return mapeamento[cstConfigurado] || '102';
    }

    /**
     * Validar configuração fiscal antes de emitir
     */
    async validarConfigFiscal(empresa, itens) {
        const erros = [];
        const avisos = [];

        // Validar empresa
        if (!empresa?.cnpj) erros.push('CNPJ da empresa não configurado');
        if (!empresa?.inscricao_estadual) erros.push('Inscrição Estadual não configurada');
        
        // Código IBGE (7 dígitos) - usar default se não houver
        const codigoMunicipio = empresa?.codigo_municipio || '5208707'; // Default do usuário
        if (codigoMunicipio.length !== 7) {
            avisos.push('Código IBGE do município pode estar inválido');
        }

        // CRT (Regime Tributário) - usar default Simples Nacional se não configurado
        const crt = empresa?.regime_tributario_codigo || '1'; // 1 = Simples Nacional
        if (!empresa?.regime_tributario_codigo) {
            avisos.push('Usando Simples Nacional como regime padrão');
        }
        
        // CSC para NFC-e - aviso apenas
        if (!empresa?.csc_id || !empresa?.csc_token) {
            avisos.push('CSC não configurado - NFC-e pode ser rejeitada (configure em Dados Fiscais)');
        }

        // Validar produtos - usar dados padrão se não tiverem configuração
        for (const item of itens) {
            try {
                const dadosFiscais = await this.buscarDadosFiscaisProduto(item.produto_id);
                
                if (!dadosFiscais) {
                    // Criar dados padrão para o produto
                    console.warn(`⚠️ Produto ${item.produto_id} sem dados fiscais - usando defaults`);
                    
                    // Não é erro, apenas aviso - usaremos dados padrão
                    avisos.push(`Produto ${item.nome_produto || item.produto_id} sem NCM - usando padrão 22021000`);
                }
            } catch (erro) {
                console.warn(`Erro ao validar produto ${item.produto_id}:`, erro);
            }
        }

        // Mostrar mensagem consolidada
        if (avisos.length > 0) {
            console.warn('⚠️ Avisos de configuração:', avisos);
        }

        return {
            valido: erros.length === 0,
            erros,
            avisos,
            crt,
            codigoMunicipio
        };
    }

    /**
     * Limpar cache (chamar quando alterar configurações)
     */
    limparCache() {
        this.cache.produtos.clear();
        this.cache.categorias.clear();
        this.cache.aliquotas.clear();
        this.empresaConfig = null;
    }
}

// Exportar instância única (disponível globalmente)
// Usar var para garantir escopo global mesmo se houver falha na inicialização
try {
    var ServicoFiscalService = new ServicoFiscal();
    console.log('✅ [ServicoFiscal] Instância criada com sucesso');
} catch (erro) {
    console.error('❌ [ServicoFiscal] Erro ao criar instância:', erro);
    console.warn('⚠️ [ServicoFiscal] Código fiscal funcionará em modo fallback');
    var ServicoFiscalService = null;
}
