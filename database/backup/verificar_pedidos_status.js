const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verificarPedidos() {
    console.log('\n🔍 VERIFICANDO PEDIDOS\n');

    // Buscar todos os pedidos
    const { data: pedidos } = await supabase
        .from('pedidos')
        .select('*')
        .order('created_at', { ascending: false });

    console.log(`Total de pedidos: ${pedidos?.length || 0}\n`);

    if (pedidos && pedidos.length > 0) {
        const porStatus = pedidos.reduce((acc, p) => {
            acc[p.status] = (acc[p.status] || 0) + 1;
            return acc;
        }, {});

        console.log('📊 Pedidos por status:');
        console.table(porStatus);

        console.log('\n📦 Detalhes dos pedidos:\n');
        console.table(pedidos.map(p => ({
            numero: p.numero,
            tipo: p.tipo_pedido,
            status: p.status,
            total: parseFloat(p.total).toFixed(2),
            criado: p.created_at?.substring(0, 10)
        })));

        // Verificar movimentações desses pedidos
        console.log('\n📊 MOVIMENTAÇÕES DOS PEDIDOS:\n');
        for (const ped of pedidos) {
            const { data: movs } = await supabase
                .from('estoque_movimentacoes')
                .select('id, tipo, quantidade')
                .eq('pedido_id', ped.id);

            if (movs && movs.length > 0) {
                console.log(`${ped.numero} (${ped.status}): ${movs.length} movimentações`);
            }
        }
    } else {
        console.log('⚠️  Nenhum pedido encontrado no banco!');
        console.log('Os pedidos foram deletados?');
    }

    // Verificar movimentações órfãs
    const { data: movsOrfas } = await supabase
        .from('estoque_movimentacoes')
        .select('id, pedido_id');

    const pedidosIds = new Set(pedidos?.map(p => p.id) || []);
    const orfas = movsOrfas?.filter(m => !pedidosIds.has(m.pedido_id)) || [];

    console.log(`\n⚠️  Movimentações órfãs (sem pedido): ${orfas.length}`);
}

verificarPedidos().catch(console.error);
