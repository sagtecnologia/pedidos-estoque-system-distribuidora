const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function buscarTudo() {
    console.log('\n🔍 BUSCANDO TODOS OS DADOS\n');
    
    // TODOS os pedidos
    const { data: pedidos } = await supabase
        .from('pedidos')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(20);

    console.log('📦 PEDIDOS (últimos 20):');
    console.table(pedidos?.map(p => ({
        numero: p.numero,
        tipo: p.tipo_pedido,
        status: p.status,
        total: parseFloat(p.total).toFixed(2),
        criado: p.created_at?.substring(0, 10),
        finalizado: p.data_finalizacao?.substring(0, 10) || '---'
    })));

    // TODAS as movimentações
    const { data: movs } = await supabase
        .from('estoque_movimentacoes')
        .select('*')
        .order('created_at', { ascending: false })
        .limit(10);

    console.log('\n📊 MOVIMENTAÇÕES (últimas 10):');
    console.table(movs?.map(m => ({
        tipo: m.tipo,
        quantidade: m.quantidade,
        observacao: m.observacao?.substring(0, 40),
        criado: m.created_at?.substring(0, 16)
    })));

    // TODOS os sabores
    const { data: sabores } = await supabase
        .from('produto_sabores')
        .select('*, produtos(codigo, nome, preco_compra, preco_venda)')
        .limit(100);

    console.log('\n🍰 PRODUTO_SABORES (total):');
    console.log('Total:', sabores?.length || 0);
    
    if (sabores && sabores.length > 0) {
        console.table(sabores.slice(0, 10).map(s => ({
            codigo: s.produtos?.codigo,
            sabor: s.sabor,
            qtd: s.quantidade,
            preco_compra: s.produtos?.preco_compra,
            valor: (s.quantidade * (s.produtos?.preco_compra || 0)).toFixed(2)
        })));
    }

    // Produtos com estoque
    const { data: produtos } = await supabase
        .from('produtos')
        .select('codigo, nome, estoque_atual, preco_compra, preco_venda')
        .eq('active', true)
        .neq('estoque_atual', 0)
        .order('estoque_atual', { ascending: false })
        .limit(10);

    console.log('\n📦 PRODUTOS COM ESTOQUE (top 10):');
    console.table(produtos);

    // Estatísticas gerais
    const { count: totalPedidos } = await supabase
        .from('pedidos')
        .select('*', { count: 'exact', head: true });

    const { count: totalMovs } = await supabase
        .from('estoque_movimentacoes')
        .select('*', { count: 'exact', head: true });

    const { count: totalSabores } = await supabase
        .from('produto_sabores')
        .select('*', { count: 'exact', head: true });

    const { count: totalProdutos } = await supabase
        .from('produtos')
        .select('*', { count: 'exact', head: true });

    console.log('\n📊 ESTATÍSTICAS GERAIS:');
    console.table({
        'Total Pedidos': totalPedidos || 0,
        'Total Movimentações': totalMovs || 0,
        'Total Sabores': totalSabores || 0,
        'Total Produtos': totalProdutos || 0
    });
}

buscarTudo().catch(console.error);
