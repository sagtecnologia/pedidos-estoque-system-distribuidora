const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verificar() {
    console.log('\n🔍 VERIFICANDO STATUS DOS PEDIDOS\n');
    
    // Todos os pedidos de 2026
    const { data: pedidos } = await supabase
        .from('pedidos')
        .select('id, numero, tipo_pedido, status, total, data_finalizacao, created_at')
        .gte('created_at', '2026-01-01')
        .order('created_at', { ascending: false });

    console.log('Total de pedidos em 2026:', pedidos?.length || 0);
    
    // Agrupar por status
    const porStatus = pedidos?.reduce((acc, p) => {
        acc[p.status] = (acc[p.status] || 0) + 1;
        return acc;
    }, {});

    console.log('\n📊 Pedidos por Status:');
    console.table(porStatus);

    console.log('\n📦 Detalhes dos Pedidos:\n');
    console.table(pedidos?.map(p => ({
        numero: p.numero,
        tipo: p.tipo_pedido,
        status: p.status,
        total: parseFloat(p.total).toFixed(2),
        data_finalizacao: p.data_finalizacao,
        criado_em: p.created_at
    })));

    // Verificar movimentações por pedido
    console.log('\n📊 MOVIMENTAÇÕES POR PEDIDO:\n');
    
    for (const ped of pedidos || []) {
        const { data: movs } = await supabase
            .from('estoque_movimentacoes')
            .select('tipo, quantidade, observacao')
            .eq('pedido_id', ped.id);

        if (movs && movs.length > 0) {
            const entrada = movs.filter(m => m.tipo === 'ENTRADA').reduce((sum, m) => sum + m.quantidade, 0);
            const saida = movs.filter(m => m.tipo === 'SAIDA').reduce((sum, m) => sum + m.quantidade, 0);
            
            console.log(`${ped.numero} (${ped.status}): ${movs.length} movs | ENTRADA: ${entrada} | SAIDA: ${saida}`);
        }
    }

    // Verificar valores em produto_sabores
    console.log('\n💰 VALORES EM PRODUTO_SABORES:\n');
    
    const { data: sabores } = await supabase
        .from('produto_sabores')
        .select('id, produto_id, sabor, quantidade, produtos(codigo, nome, preco_compra, preco_venda)');

    const totalCompra = sabores?.reduce((sum, s) => sum + (s.quantidade * (s.produtos?.preco_compra || 0)), 0) || 0;
    const totalVenda = sabores?.reduce((sum, s) => sum + (s.quantidade * (s.produtos?.preco_venda || 0)), 0) || 0;

    console.log(`Valor Total Compra: R$ ${totalCompra.toFixed(2)}`);
    console.log(`Valor Total Venda: R$ ${totalVenda.toFixed(2)}`);
    console.log(`\nTotal de sabores: ${sabores?.length || 0}`);
    console.log(`Sabores com quantidade > 0: ${sabores?.filter(s => s.quantidade > 0).length || 0}`);
    console.log(`Sabores com quantidade = 0: ${sabores?.filter(s => s.quantidade === 0).length || 0}`);
    console.log(`Sabores com quantidade < 0: ${sabores?.filter(s => s.quantidade < 0).length || 0}`);
}

verificar().catch(console.error);
