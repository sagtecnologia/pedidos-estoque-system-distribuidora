// =====================================================
// SERVIÇO: IMPRESSÃO DE PEDIDOS
// =====================================================

/**
 * Imprimir pedido de compra
 */
async function imprimirPedidoCompra(pedidoId) {
    try {
        showLoading(true);

        // Buscar dados do pedido
        const { data: pedido, error: pedidoError } = await supabase
            .from('pedidos')
            .select(`
                *,
                solicitante:users!pedidos_solicitante_id_fkey(full_name),
                aprovador:users!pedidos_aprovador_id_fkey(full_name),
                fornecedor:fornecedores(nome, cnpj, whatsapp, endereco)
            `)
            .eq('id', pedidoId)
            .single();

        if (pedidoError) throw pedidoError;

        // Buscar itens do pedido
        const { data: itens, error: itensError } = await supabase
            .from('pedido_itens')
            .select('*, produto:produtos(id, codigo, nome, unidade, marca), sabor:produto_sabores(sabor)')
            .eq('pedido_id', pedidoId)
            .order('created_at', { ascending: true });

        if (itensError) throw itensError;

        // Buscar configurações da empresa
        const empresaConfig = await getEmpresaConfig();

        // Gerar HTML para impressão
        const html = gerarHTMLPedidoCompra(pedido, itens, empresaConfig);

        // Abrir janela de impressão
        const printWindow = window.open('', '_blank');
        printWindow.document.write(html);
        printWindow.document.close();
        printWindow.focus();
        
        // Aguardar carregar imagens antes de imprimir
        setTimeout(() => {
            printWindow.print();
            printWindow.close();
        }, 500);

    } catch (error) {
        handleError(error, 'Erro ao imprimir pedido');
    } finally {
        showLoading(false);
    }
}

/**
 * Imprimir pedido de venda
 */
async function imprimirPedidoVenda(pedidoId) {
    try {
        showLoading(true);

        // Buscar dados do pedido
        const { data: pedido, error: pedidoError } = await supabase
            .from('pedidos')
            .select(`
                *,
                solicitante:users!pedidos_solicitante_id_fkey(full_name),
                aprovador:users!pedidos_aprovador_id_fkey(full_name),
                cliente:clientes(nome, cpf_cnpj, tipo, contato, whatsapp, endereco, cidade, estado)
            `)
            .eq('id', pedidoId)
            .single();

        if (pedidoError) throw pedidoError;

        // Buscar itens do pedido
        const { data: itens, error: itensError } = await supabase
            .from('pedido_itens')
            .select('*, produto:produtos(id, codigo, nome, unidade, marca), sabor:produto_sabores(sabor)')
            .eq('pedido_id', pedidoId)
            .order('created_at', { ascending: true });

        if (itensError) throw itensError;

        // Buscar configurações da empresa
        const empresaConfig = await getEmpresaConfig();

        // Gerar HTML para impressão
        const html = gerarHTMLPedidoVenda(pedido, itens, empresaConfig);

        // Abrir janela de impressão
        const printWindow = window.open('', '_blank');
        printWindow.document.write(html);
        printWindow.document.close();
        printWindow.focus();
        
        // Aguardar carregar imagens antes de imprimir
        setTimeout(() => {
            printWindow.print();
            printWindow.close();
        }, 500);

    } catch (error) {
        handleError(error, 'Erro ao imprimir pedido');
    } finally {
        showLoading(false);
    }
}

/**
 * Gerar HTML para impressão de pedido de compra
 */
function gerarHTMLPedidoCompra(pedido, itens, empresaConfig) {
    const statusLabels = {
        'RASCUNHO': 'Rascunho',
        'ENVIADO': 'Aguardando Aprovação',
        'APROVADO': 'Aprovado',
        'REJEITADO': 'Rejeitado',
        'FINALIZADO': 'Finalizado'
    };

    const total = itens.reduce((sum, item) => sum + (item.quantidade * item.preco_unitario), 0);
    const totalQuantidade = itens.reduce((sum, item) => sum + item.quantidade, 0);

    // Agrupar itens por marca e produto
    const itensAgrupados = {};
    itens.forEach(item => {
        const marca = item.produto.marca || 'Sem Marca';
        const produtoId = item.produto.id;
        const produtoNome = item.produto.nome;
        
        if (!itensAgrupados[marca]) {
            itensAgrupados[marca] = {};
        }
        
        if (!itensAgrupados[marca][produtoId]) {
            itensAgrupados[marca][produtoId] = {
                codigo: item.produto.codigo,
                nome: produtoNome,
                unidade: item.produto.unidade,
                sabores: [],
                totalProduto: 0,
                totalQuantidade: 0
            };
        }
        
        itensAgrupados[marca][produtoId].sabores.push({
            sabor: item.sabor?.sabor || 'Padrão',
            quantidade: item.quantidade,
            preco_unitario: item.preco_unitario,
            subtotal: item.quantidade * item.preco_unitario
        });
        
        itensAgrupados[marca][produtoId].totalProduto += item.quantidade * item.preco_unitario;
        itensAgrupados[marca][produtoId].totalQuantidade += item.quantidade;
    });

    return `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pedido de Compra ${pedido.numero}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: Arial, sans-serif;
            padding: 20px;
            color: #333;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 3px solid #2563eb;
            padding-bottom: 15px;
            margin-bottom: 20px;
        }

        .logo-section {
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .logo {
            width: 80px;
            height: 80px;
            object-fit: contain;
        }

        .company-info h1 {
            font-size: 22px;
            color: #1e40af;
            margin-bottom: 5px;
        }

        .company-info p {
            font-size: 11px;
            color: #666;
            line-height: 1.4;
        }

        .document-title {
            text-align: right;
        }

        .document-title h2 {
            font-size: 24px;
            color: #1e3a8a;
            margin-bottom: 5px;
        }

        .document-title .numero {
            font-size: 16px;
            color: #666;
        }

        .info-section {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }

        .info-box {
            border: 1px solid #ddd;
            padding: 15px;
            border-radius: 5px;
        }

        .info-box h3 {
            font-size: 14px;
            color: #1e40af;
            margin-bottom: 10px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }

        .info-row {
            display: flex;
            margin-bottom: 8px;
            font-size: 12px;
        }

        .info-label {
            font-weight: bold;
            width: 120px;
            color: #555;
        }

        .info-value {
            flex: 1;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }

        thead {
            background-color: #2563eb;
            color: white;
        }

        th {
            padding: 12px 8px;
            text-align: left;
            font-size: 12px;
            font-weight: bold;
        }

        td {
            padding: 10px 8px;
            border-bottom: 1px solid #ddd;
            font-size: 12px;
        }

        tbody tr:hover {
            background-color: #f9fafb;
        }

        .text-right {
            text-align: right;
        }

        .totais {
            margin-left: auto;
            width: 300px;
            border: 2px solid #2563eb;
            padding: 15px;
            border-radius: 5px;
        }

        .total-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            font-size: 13px;
        }

        .total-row.final {
            font-size: 18px;
            font-weight: bold;
            color: #1e40af;
            border-top: 2px solid #2563eb;
            padding-top: 8px;
            margin-top: 8px;
        }

        .observacoes {
            margin-top: 20px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
            background-color: #f9fafb;
        }

        .observacoes h3 {
            font-size: 14px;
            margin-bottom: 8px;
            color: #1e40af;
        }

        .observacoes p {
            font-size: 12px;
            line-height: 1.6;
            white-space: pre-wrap;
        }

        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            font-size: 11px;
            color: #666;
        }

        .assinaturas {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 40px;
            margin: 40px 0;
        }

        .assinatura {
            text-align: center;
        }

        .linha-assinatura {
            border-top: 1px solid #333;
            margin-top: 60px;
            padding-top: 8px;
            font-size: 12px;
        }

        .status-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: bold;
        }

        .status-RASCUNHO { background-color: #f3f4f6; color: #6b7280; }
        .status-ENVIADO { background-color: #fef3c7; color: #92400e; }
        .status-APROVADO { background-color: #d1fae5; color: #065f46; }
        .status-REJEITADO { background-color: #fee2e2; color: #991b1b; }
        .status-FINALIZADO { background-color: #dbeafe; color: #1e40af; }

        @media print {
            body { padding: 0; }
            .info-section { page-break-inside: avoid; }
            table { page-break-inside: auto; }
            tr { page-break-inside: avoid; }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo-section">
            ${empresaConfig?.logo_url ? `<img src="${empresaConfig.logo_url}" alt="Logo" class="logo">` : ''}
            <div class="company-info">
                <h1>${empresaConfig?.nome_empresa || 'Sistema de Compras'}</h1>
                ${empresaConfig?.endereco ? `<p>${empresaConfig.endereco}</p>` : ''}
                ${empresaConfig?.cidade && empresaConfig?.estado ? `<p>${empresaConfig.cidade} - ${empresaConfig.estado}</p>` : ''}
                ${empresaConfig?.telefone ? `<p>Tel: ${empresaConfig.telefone}</p>` : ''}
                ${empresaConfig?.email ? `<p>Email: ${empresaConfig.email}</p>` : ''}
            </div>
        </div>
        <div class="document-title">
            <h2>PEDIDO DE COMPRA</h2>
            <p class="numero">Nº ${pedido.numero}</p>
            <span class="status-badge status-${pedido.status}">${statusLabels[pedido.status]}</span>
        </div>
    </div>

    <div class="info-section">
        <div class="info-box">
            <h3>Informações do Pedido</h3>
            <div class="info-row">
                <span class="info-label">Data Emissão:</span>
                <span class="info-value">${formatDateTime(pedido.created_at)}</span>
            </div>
            <div class="info-row">
                <span class="info-label">Solicitante:</span>
                <span class="info-value">${pedido.solicitante?.full_name || '-'}</span>
            </div>
            ${pedido.aprovador ? `
            <div class="info-row">
                <span class="info-label">Aprovado por:</span>
                <span class="info-value">${pedido.aprovador.full_name}</span>
            </div>
            <div class="info-row">
                <span class="info-label">Data Aprovação:</span>
                <span class="info-value">${pedido.data_aprovacao ? formatDateTime(pedido.data_aprovacao) : '-'}</span>
            </div>
            ` : ''}
        </div>

        <div class="info-box">
            <h3>Dados do Fornecedor</h3>
            ${pedido.fornecedor ? `
                <div class="info-row">
                    <span class="info-label">Nome:</span>
                    <span class="info-value">${pedido.fornecedor.nome}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">CNPJ:</span>
                    <span class="info-value">${pedido.fornecedor.cnpj || '-'}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">WhatsApp:</span>
                    <span class="info-value">${pedido.fornecedor.whatsapp || '-'}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Endereço:</span>
                    <span class="info-value">${pedido.fornecedor.endereco || '-'}</span>
                </div>
            ` : '<p style="color: #999; font-size: 12px;">Fornecedor não informado</p>'}
        </div>
    </div>

    <table>
        <thead>
            <tr>
                <th style="width: 12%;">Código</th>
                <th style="width: 38%;">Produto / Sabor</th>
                <th style="width: 8%;">Unid.</th>
                <th style="width: 10%;" class="text-right">Qtd</th>
                <th style="width: 14%;" class="text-right">Preço Un.</th>
                <th style="width: 14%;" class="text-right">Subtotal</th>
            </tr>
        </thead>
        <tbody>
            ${Object.keys(itensAgrupados).map(marca => `
                <tr style="background-color: #e5e7eb;">
                    <td colspan="6" style="font-weight: bold; padding: 8px; font-size: 13px;">🏷️ ${marca}</td>
                </tr>
                ${Object.values(itensAgrupados[marca]).map(produto => `
                    <tr style="background-color: #f9fafb;">
                        <td style="font-weight: bold;">${produto.codigo}</td>
                        <td style="font-weight: bold;" colspan="2">${produto.nome}</td>
                        <td class="text-right" style="font-weight: bold;">${produto.totalQuantidade} ${produto.unidade}</td>
                        <td colspan="2" class="text-right" style="font-weight: bold; color: #1e40af;">${formatCurrency(produto.totalProduto)}</td>
                    </tr>
                    ${produto.sabores.map(sabor => `
                        <tr>
                            <td></td>
                            <td style="padding-left: 20px; font-size: 11px; color: #666;">└─ ${sabor.sabor}</td>
                            <td style="font-size: 11px;">${produto.unidade}</td>
                            <td class="text-right" style="font-size: 11px;">${sabor.quantidade}</td>
                            <td class="text-right" style="font-size: 11px;">${formatCurrency(sabor.preco_unitario)}</td>
                            <td class="text-right" style="font-size: 11px;">${formatCurrency(sabor.subtotal)}</td>
                        </tr>
                    `).join('')}
                `).join('')}
            `).join('')}
        </tbody>
    </table>

    <div class="totais">
        <div class="total-row">
            <span>Total de Itens:</span>
            <span><strong>${totalQuantidade}</strong></span>
        </div>
        <div class="total-row final">
            <span>TOTAL GERAL:</span>
            <span>${formatCurrency(total)}</span>
        </div>
    </div>

    ${pedido.observacoes ? `
        <div class="observacoes">
            <h3>Observações</h3>
            <p>${pedido.observacoes}</p>
        </div>
    ` : ''}

    <div class="assinaturas">
        <div class="assinatura">
            <div class="linha-assinatura">
                Solicitante<br>
                ${pedido.solicitante?.full_name || ''}
            </div>
        </div>
        <div class="assinatura">
            <div class="linha-assinatura">
                Aprovador<br>
                ${pedido.aprovador?.full_name || ''}
            </div>
        </div>
    </div>

    <div class="footer">
        <p>Documento gerado em ${formatDateTime(new Date())}</p>
        ${empresaConfig?.website ? `<p>${empresaConfig.website}</p>` : ''}
    </div>
</body>
</html>
    `;
}

/**
 * Gerar HTML para impressão de pedido de venda
 */
function gerarHTMLPedidoVenda(pedido, itens, empresaConfig) {
    const statusLabels = {
        'RASCUNHO': 'Rascunho',
        'ENVIADO': 'Aguardando Aprovação',
        'APROVADO': 'Aprovado',
        'REJEITADO': 'Rejeitado',
        'FINALIZADO': 'Finalizado'
    };

    const total = itens.reduce((sum, item) => sum + (item.quantidade * item.preco_unitario), 0);
    const totalQuantidade = itens.reduce((sum, item) => sum + item.quantidade, 0);
    
    // Agrupar itens por marca e produto
    const itensAgrupados = {};
    itens.forEach(item => {
        const marca = item.produto.marca || 'Sem Marca';
        const produtoId = item.produto.id;
        const produtoNome = item.produto.nome;
        
        if (!itensAgrupados[marca]) {
            itensAgrupados[marca] = {};
        }
        
        if (!itensAgrupados[marca][produtoId]) {
            itensAgrupados[marca][produtoId] = {
                codigo: item.produto.codigo,
                nome: produtoNome,
                unidade: item.produto.unidade,
                sabores: [],
                totalProduto: 0,
                totalQuantidade: 0
            };
        }
        
        itensAgrupados[marca][produtoId].sabores.push({
            sabor: item.sabor?.sabor || 'Padrão',
            quantidade: item.quantidade,
            preco_unitario: item.preco_unitario,
            subtotal: item.quantidade * item.preco_unitario
        });
        
        itensAgrupados[marca][produtoId].totalProduto += item.quantidade * item.preco_unitario;
        itensAgrupados[marca][produtoId].totalQuantidade += item.quantidade;
    });

    return `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Pedido de Venda ${pedido.numero}</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: Arial, sans-serif;
            padding: 20px;
            color: #333;
        }

        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            border-bottom: 3px solid #059669;
            padding-bottom: 15px;
            margin-bottom: 20px;
        }

        .logo-section {
            display: flex;
            align-items: center;
            gap: 15px;
        }

        .logo {
            width: 80px;
            height: 80px;
            object-fit: contain;
        }

        .company-info h1 {
            font-size: 22px;
            color: #047857;
            margin-bottom: 5px;
        }

        .company-info p {
            font-size: 11px;
            color: #666;
            line-height: 1.4;
        }

        .document-title {
            text-align: right;
        }

        .document-title h2 {
            font-size: 24px;
            color: #065f46;
            margin-bottom: 5px;
        }

        .document-title .numero {
            font-size: 16px;
            color: #666;
        }

        .info-section {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 20px;
        }

        .info-box {
            border: 1px solid #ddd;
            padding: 15px;
            border-radius: 5px;
        }

        .info-box h3 {
            font-size: 14px;
            color: #047857;
            margin-bottom: 10px;
            border-bottom: 1px solid #ddd;
            padding-bottom: 5px;
        }

        .info-row {
            display: flex;
            margin-bottom: 8px;
            font-size: 12px;
        }

        .info-label {
            font-weight: bold;
            width: 120px;
            color: #555;
        }

        .info-value {
            flex: 1;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin-bottom: 20px;
        }

        thead {
            background-color: #059669;
            color: white;
        }

        th {
            padding: 12px 8px;
            text-align: left;
            font-size: 12px;
            font-weight: bold;
        }

        td {
            padding: 10px 8px;
            border-bottom: 1px solid #ddd;
            font-size: 12px;
        }

        tbody tr:hover {
            background-color: #f9fafb;
        }

        .text-right {
            text-align: right;
        }

        .totais {
            margin-left: auto;
            width: 300px;
            border: 2px solid #059669;
            padding: 15px;
            border-radius: 5px;
        }

        .total-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            font-size: 13px;
        }

        .total-row.final {
            font-size: 18px;
            font-weight: bold;
            color: #047857;
            border-top: 2px solid #059669;
            padding-top: 8px;
            margin-top: 8px;
        }

        .observacoes {
            margin-top: 20px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
            background-color: #f9fafb;
        }

        .observacoes h3 {
            font-size: 14px;
            margin-bottom: 8px;
            color: #047857;
        }

        .observacoes p {
            font-size: 12px;
            line-height: 1.6;
            white-space: pre-wrap;
        }

        .footer {
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid #ddd;
            text-align: center;
            font-size: 11px;
            color: #666;
        }

        .assinaturas {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 40px;
            margin: 40px 0;
        }

        .assinatura {
            text-align: center;
        }

        .linha-assinatura {
            border-top: 1px solid #333;
            margin-top: 60px;
            padding-top: 8px;
            font-size: 12px;
        }

        .status-badge {
            display: inline-block;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 11px;
            font-weight: bold;
        }

        .status-RASCUNHO { background-color: #f3f4f6; color: #6b7280; }
        .status-ENVIADO { background-color: #fef3c7; color: #92400e; }
        .status-APROVADO { background-color: #d1fae5; color: #065f46; }
        .status-REJEITADO { background-color: #fee2e2; color: #991b1b; }
        .status-FINALIZADO { background-color: #dbeafe; color: #1e40af; }

        @media print {
            body { padding: 0; }
            .info-section { page-break-inside: avoid; }
            table { page-break-inside: auto; }
            tr { page-break-inside: avoid; }
        }
    </style>
</head>
<body>
    <div class="header">
        <div class="logo-section">
            ${empresaConfig?.logo_url ? `<img src="${empresaConfig.logo_url}" alt="Logo" class="logo">` : ''}
            <div class="company-info">
                <h1>${empresaConfig?.nome_empresa || 'Sistema de Compras'}</h1>
                ${empresaConfig?.endereco ? `<p>${empresaConfig.endereco}</p>` : ''}
                ${empresaConfig?.cidade && empresaConfig?.estado ? `<p>${empresaConfig.cidade} - ${empresaConfig.estado}</p>` : ''}
                ${empresaConfig?.telefone ? `<p>Tel: ${empresaConfig.telefone}</p>` : ''}
                ${empresaConfig?.email ? `<p>Email: ${empresaConfig.email}</p>` : ''}
            </div>
        </div>
        <div class="document-title">
            <h2>PEDIDO DE VENDA</h2>
            <p class="numero">Nº ${pedido.numero}</p>
            <span class="status-badge status-${pedido.status}">${statusLabels[pedido.status]}</span>
        </div>
    </div>

    <div class="info-section">
        <div class="info-box">
            <h3>Informações do Pedido</h3>
            <div class="info-row">
                <span class="info-label">Data Emissão:</span>
                <span class="info-value">${formatDateTime(pedido.created_at)}</span>
            </div>
            <div class="info-row">
                <span class="info-label">Vendedor:</span>
                <span class="info-value">${pedido.solicitante?.full_name || '-'}</span>
            </div>
            ${pedido.aprovador ? `
            <div class="info-row">
                <span class="info-label">Aprovado por:</span>
                <span class="info-value">${pedido.aprovador.full_name}</span>
            </div>
            <div class="info-row">
                <span class="info-label">Data Aprovação:</span>
                <span class="info-value">${pedido.data_aprovacao ? formatDateTime(pedido.data_aprovacao) : '-'}</span>
            </div>
            ` : ''}
        </div>

        <div class="info-box">
            <h3>Dados do Cliente</h3>
            ${pedido.cliente ? `
                <div class="info-row">
                    <span class="info-label">Nome:</span>
                    <span class="info-value">${pedido.cliente.nome}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">${pedido.cliente.tipo === 'FISICA' ? 'CPF' : 'CNPJ'}:</span>
                    <span class="info-value">${pedido.cliente.cpf_cnpj || '-'}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Contato:</span>
                    <span class="info-value">${pedido.cliente.contato || '-'}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">WhatsApp:</span>
                    <span class="info-value">${pedido.cliente.whatsapp || '-'}</span>
                </div>
                <div class="info-row">
                    <span class="info-label">Endereço:</span>
                    <span class="info-value">${pedido.cliente.endereco || '-'}</span>
                </div>
                ${pedido.cliente.cidade && pedido.cliente.estado ? `
                <div class="info-row">
                    <span class="info-label">Cidade/UF:</span>
                    <span class="info-value">${pedido.cliente.cidade} - ${pedido.cliente.estado}</span>
                </div>
                ` : ''}
            ` : '<p style="color: #999; font-size: 12px;">Cliente não informado</p>'}
        </div>
    </div>

    <table>
        <thead>
            <tr>
                <th style="width: 12%;">Código</th>
                <th style="width: 38%;">Produto / Sabor</th>
                <th style="width: 8%;">Unid.</th>
                <th style="width: 10%;" class="text-right">Qtd</th>
                <th style="width: 14%;" class="text-right">Preço Un.</th>
                <th style="width: 14%;" class="text-right">Subtotal</th>
            </tr>
        </thead>
        <tbody>
            ${Object.keys(itensAgrupados).map(marca => `
                <tr style="background-color: #e5e7eb;">
                    <td colspan="6" style="font-weight: bold; padding: 8px; font-size: 13px;">🏷️ ${marca}</td>
                </tr>
                ${Object.values(itensAgrupados[marca]).map(produto => `
                    <tr style="background-color: #f9fafb;">
                        <td style="font-weight: bold;">${produto.codigo}</td>
                        <td style="font-weight: bold;" colspan="2">${produto.nome}</td>
                        <td class="text-right" style="font-weight: bold;">${produto.totalQuantidade} ${produto.unidade}</td>
                        <td colspan="2" class="text-right" style="font-weight: bold; color: #047857;">${formatCurrency(produto.totalProduto)}</td>
                    </tr>
                    ${produto.sabores.map(sabor => `
                        <tr>
                            <td></td>
                            <td style="padding-left: 20px; font-size: 11px; color: #666;">└─ ${sabor.sabor}</td>
                            <td style="font-size: 11px;">${produto.unidade}</td>
                            <td class="text-right" style="font-size: 11px;">${sabor.quantidade}</td>
                            <td class="text-right" style="font-size: 11px;">${formatCurrency(sabor.preco_unitario)}</td>
                            <td class="text-right" style="font-size: 11px;">${formatCurrency(sabor.subtotal)}</td>
                        </tr>
                    `).join('')}
                `).join('')}
            `).join('')}
        </tbody>
    </table>

    <div class="totais">
        <div class="total-row">
            <span>Total de Itens:</span>
            <span><strong>${totalQuantidade}</strong></span>
        </div>
        <div class="total-row final">
            <span>TOTAL GERAL:</span>
            <span>${formatCurrency(total)}</span>
        </div>
    </div>

    ${pedido.observacoes ? `
        <div class="observacoes">
            <h3>Observações</h3>
            <p>${pedido.observacoes}</p>
        </div>
    ` : ''}

    <div class="assinaturas">
        <div class="assinatura">
            <div class="linha-assinatura">
                Vendedor<br>
                ${pedido.solicitante?.full_name || ''}
            </div>
        </div>
        <div class="assinatura">
            <div class="linha-assinatura">
                Cliente<br>
                ${pedido.cliente?.nome || ''}
            </div>
        </div>
    </div>

    <div class="footer">
        <p>Documento gerado em ${formatDateTime(new Date())}</p>
        ${empresaConfig?.website ? `<p>${empresaConfig.website}</p>` : ''}
    </div>
</body>
</html>
    `;
}
