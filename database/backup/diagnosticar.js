// =====================================================
// DIAGNÓSTICO DIRETO NO SUPABASE
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function diagnosticar() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     🔍 DIAGNÓSTICO COMPLETO                               ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    // 1. PEDIDOS FINALIZADOS
    console.log('📦 PEDIDOS DE COMPRA FINALIZADOS\n');
    const { data: pedidos, error: errPedidos } = await supabase.rpc('exec_sql', {
        query: `
            SELECT 
                ped.id::text as id_pedido,
                ped.status,
                ROUND(ped.total::numeric, 2) as valor_total,
                ped.data_finalizacao,
                COUNT(pi.id) as itens_no_pedido
            FROM pedidos ped
            LEFT JOIN pedido_itens pi ON ped.id = pi.pedido_id
            WHERE ped.status = 'FINALIZADO'
              AND ped.created_at >= '2026-01-06'
            GROUP BY ped.id, ped.status, ped.total, ped.data_finalizacao
            ORDER BY ped.data_finalizacao DESC
        `
    });

    if (errPedidos) {
        console.error('Erro:', errPedidos);
    } else {
        console.table(pedidos);
    }

    // 2. MOVIMENTAÇÕES DOS PEDIDOS
    console.log('\n📊 MOVIMENTAÇÕES DOS PEDIDOS FINALIZADOS\n');
    const { data: movPedidos } = await supabase
        .from('estoque_movimentacoes')
        .select(`
            pedido_id,
            tipo,
            quantidade,
            observacao,
            pedidos!inner(status, created_at)
        `)
        .eq('pedidos.status', 'FINALIZADO')
        .gte('pedidos.created_at', '2026-01-06');

    console.log('Total de movimentações:', movPedidos?.length || 0);
    console.table(movPedidos?.slice(0, 10));

    // 3. MOVIMENTAÇÕES TOTAIS POR TIPO
    console.log('\n📈 RESUMO DE MOVIMENTAÇÕES\n');
    const { data: resumoMov } = await supabase
        .from('estoque_movimentacoes')
        .select('tipo, quantidade');

    const resumo = resumoMov?.reduce((acc, m) => {
        acc[m.tipo] = (acc[m.tipo] || 0) + 1;
        return acc;
    }, {});

    console.table(resumo);

    // 4. PRODUTOS SEM MOVIMENTAÇÕES DE ENTRADA
    console.log('\n⚠️ PRODUTOS SEM ENTRADA (mas com estoque)\n');
    const { data: produtos } = await supabase
        .from('produtos')
        .select('codigo, nome, estoque_atual')
        .eq('active', true)
        .neq('estoque_atual', 0);

    const { data: movimentacoes } = await supabase
        .from('estoque_movimentacoes')
        .select('produto_id')
        .eq('tipo', 'ENTRADA');

    const produtosComEntrada = new Set(movimentacoes?.map(m => m.produto_id));
    const semEntrada = produtos?.filter(p => !produtosComEntrada.has(p.id));

    console.log('Produtos sem entrada:', semEntrada?.length || 0);
    console.table(semEntrada?.slice(0, 10));

    // 5. ITENS DE PEDIDOS SEM MOVIMENTAÇÕES
    console.log('\n🔍 VERIFICANDO ITENS SEM MOVIMENTAÇÕES\n');
    
    const { data: pedidosFinalizados } = await supabase
        .from('pedidos')
        .select('id')
        .eq('status', 'FINALIZADO')
        .gte('created_at', '2026-01-06');

    console.log('Pedidos finalizados:', pedidosFinalizados?.length || 0);

    for (const ped of pedidosFinalizados || []) {
        const { data: itens } = await supabase
            .from('pedido_itens')
            .select('id, produto_id, quantidade, produtos(codigo, nome)')
            .eq('pedido_id', ped.id);

        const { data: movs } = await supabase
            .from('estoque_movimentacoes')
            .select('id, produto_id')
            .eq('pedido_id', ped.id);

        const produtosComMov = new Set(movs?.map(m => m.produto_id));
        const itensSemMov = itens?.filter(i => !produtosComMov.has(i.produto_id));

        if (itensSemMov?.length > 0) {
            console.log(`\nPedido ${ped.id} - Itens sem movimentação:`);
            console.table(itensSemMov.map(i => ({
                codigo: i.produtos.codigo,
                nome: i.produtos.nome,
                quantidade: i.quantidade
            })));
        }
    }

    // 6. COMPARAÇÃO FINAL
    console.log('\n📊 COMPARAÇÃO: PEDIDOS x MOVIMENTAÇÕES\n');
    
    const { data: totalPedidos } = await supabase
        .from('pedidos')
        .select('total')
        .eq('status', 'FINALIZADO')
        .gte('created_at', '2026-01-06');

    const valorTotalPedidos = totalPedidos?.reduce((sum, p) => sum + parseFloat(p.total), 0) || 0;

    const { data: movEntrada } = await supabase
        .from('estoque_movimentacoes')
        .select('quantidade, observacao')
        .eq('tipo', 'ENTRADA')
        .ilike('observacao', '%pedido compra%');

    console.table([
        {
            origem: 'PEDIDOS FINALIZADOS',
            quantidade: pedidosFinalizados?.length || 0,
            valor: valorTotalPedidos.toFixed(2)
        },
        {
            origem: 'MOVIMENTAÇÕES ENTRADA',
            quantidade: movEntrada?.length || 0,
            valor: '---'
        }
    ]);

    // 7. OBSERVAÇÕES DAS MOVIMENTAÇÕES
    console.log('\n📝 OBSERVAÇÕES DAS MOVIMENTAÇÕES\n');
    const { data: todasMovs } = await supabase
        .from('estoque_movimentacoes')
        .select('observacao, tipo, quantidade');

    const obsAgrupadas = todasMovs?.reduce((acc, m) => {
        const key = `${m.observacao || 'NULL'} | ${m.tipo}`;
        if (!acc[key]) acc[key] = { observacao: m.observacao, tipo: m.tipo, count: 0, total: 0 };
        acc[key].count++;
        acc[key].total += m.quantidade;
        return acc;
    }, {});

    const obsOrdenadas = Object.values(obsAgrupadas || {})
        .sort((a, b) => b.count - a.count)
        .slice(0, 10);

    console.table(obsOrdenadas);

    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║  📋 CONCLUSÃO                                             ║');
    console.log('║                                                           ║');
    console.log('║  Verifique os resultados acima                            ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');
}

diagnosticar().catch(console.error);
