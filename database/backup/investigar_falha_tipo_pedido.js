// =====================================================
// INVESTIGAÇÃO: Falha de Tipo de Pedido
// Verificar se pedidos de VENDA estão sendo registrados como COMPRA
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function investigarFalhaTipoPedido() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     🔍 INVESTIGAÇÃO: FALHA DE TIPO DE PEDIDO              ║');
    console.log('║     Verificando se vendas geram entradas no estoque       ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    try {
        // 1. BUSCAR TODOS OS PEDIDOS
        console.log('📦 Buscando todos os pedidos...\n');
        const { data: pedidos, error: errPedidos } = await supabase
            .from('pedidos')
            .select('id, numero, tipo_pedido, status, total, created_at, data_finalizacao')
            .order('created_at', { ascending: false });

        if (errPedidos) {
            console.error('❌ Erro ao buscar pedidos:', errPedidos);
            return;
        }

        console.log(`✅ Encontrados ${pedidos.length} pedidos\n`);

        // 2. CONTAR PEDIDOS POR TIPO
        const contagemPorTipo = pedidos.reduce((acc, p) => {
            acc[p.tipo_pedido] = (acc[p.tipo_pedido] || 0) + 1;
            return acc;
        }, {});

        console.log('📊 PEDIDOS POR TIPO:\n');
        console.table(contagemPorTipo);

        // 3. BUSCAR TODAS AS MOVIMENTAÇÕES
        console.log('\n🔄 Buscando movimentações de estoque...\n');
        const { data: movimentacoes, error: errMov } = await supabase
            .from('estoque_movimentacoes')
            .select('id, pedido_id, tipo, quantidade, observacao, created_at')
            .not('pedido_id', 'is', null)
            .order('created_at', { ascending: false });

        if (errMov) {
            console.error('❌ Erro ao buscar movimentações:', errMov);
            return;
        }

        console.log(`✅ Encontradas ${movimentacoes.length} movimentações vinculadas a pedidos\n`);

        // 4. VERIFICAR INCONSISTÊNCIAS
        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('🚨 VERIFICANDO INCONSISTÊNCIAS...\n');

        const problemas = [];

        for (const pedido of pedidos) {
            const movsDoPedido = movimentacoes.filter(m => m.pedido_id === pedido.id);
            
            if (movsDoPedido.length === 0) continue;

            // VERIFICAÇÃO CRÍTICA: Se o pedido é VENDA, NÃO deve ter movimentações de ENTRADA
            if (pedido.tipo_pedido === 'VENDA') {
                const entradasIndevidas = movsDoPedido.filter(m => m.tipo === 'ENTRADA');
                
                if (entradasIndevidas.length > 0) {
                    problemas.push({
                        tipo_problema: '⚠️ VENDA COM ENTRADA',
                        pedido_numero: pedido.numero,
                        pedido_tipo: pedido.tipo_pedido,
                        status: pedido.status,
                        total: parseFloat(pedido.total).toFixed(2),
                        movs_entrada: entradasIndevidas.length,
                        movs_saida: movsDoPedido.filter(m => m.tipo === 'SAIDA').length,
                        data: pedido.created_at?.substring(0, 16)
                    });
                }
            }

            // VERIFICAÇÃO: Se o pedido é COMPRA, NÃO deve ter movimentações de SAÍDA
            if (pedido.tipo_pedido === 'COMPRA') {
                const saidasIndevidas = movsDoPedido.filter(m => m.tipo === 'SAIDA');
                
                if (saidasIndevidas.length > 0) {
                    problemas.push({
                        tipo_problema: '⚠️ COMPRA COM SAÍDA',
                        pedido_numero: pedido.numero,
                        pedido_tipo: pedido.tipo_pedido,
                        status: pedido.status,
                        total: parseFloat(pedido.total).toFixed(2),
                        movs_entrada: movsDoPedido.filter(m => m.tipo === 'ENTRADA').length,
                        movs_saida: saidasIndevidas.length,
                        data: pedido.created_at?.substring(0, 16)
                    });
                }
            }

            // VERIFICAÇÃO: Pedido com movimentações de ENTRADA E SAÍDA ao mesmo tempo
            const temEntrada = movsDoPedido.some(m => m.tipo === 'ENTRADA');
            const temSaida = movsDoPedido.some(m => m.tipo === 'SAIDA');
            
            if (temEntrada && temSaida) {
                problemas.push({
                    tipo_problema: '🔥 ENTRADA E SAÍDA',
                    pedido_numero: pedido.numero,
                    pedido_tipo: pedido.tipo_pedido,
                    status: pedido.status,
                    total: parseFloat(pedido.total).toFixed(2),
                    movs_entrada: movsDoPedido.filter(m => m.tipo === 'ENTRADA').length,
                    movs_saida: movsDoPedido.filter(m => m.tipo === 'SAIDA').length,
                    data: pedido.created_at?.substring(0, 16)
                });
            }
        }

        // 5. EXIBIR RESULTADOS
        if (problemas.length > 0) {
            console.log('🔥 PROBLEMAS ENCONTRADOS!\n');
            console.table(problemas);

            console.log('\n═══════════════════════════════════════════════════════════');
            console.log('📋 DETALHAMENTO DOS PROBLEMAS:\n');

            for (const problema of problemas) {
                console.log(`\n🚨 ${problema.tipo_problema}`);
                console.log(`   Pedido: ${problema.pedido_numero} (${problema.pedido_tipo})`);
                console.log(`   Status: ${problema.status}`);
                console.log(`   Total: R$ ${problema.total}`);
                console.log(`   Entradas: ${problema.movs_entrada} | Saídas: ${problema.movs_saida}`);
                console.log(`   Data: ${problema.data}`);

                // Buscar detalhes das movimentações problemáticas
                const pedidoCompleto = pedidos.find(p => p.numero === problema.pedido_numero);
                const movsDetalhadas = movimentacoes.filter(m => m.pedido_id === pedidoCompleto.id);
                
                console.log(`\n   Movimentações deste pedido:`);
                movsDetalhadas.forEach(m => {
                    console.log(`   - ${m.tipo}: ${m.quantidade} unidades | ${m.observacao || 'Sem observação'}`);
                });
            }

        } else {
            console.log('✅ NENHUM PROBLEMA ENCONTRADO!\n');
            console.log('Todos os pedidos estão com o tipo de movimentação correto:');
            console.log('- Pedidos de VENDA só geraram SAÍDAS');
            console.log('- Pedidos de COMPRA só geraram ENTRADAS');
        }

        // 6. VERIFICAR PEDIDOS SEM MOVIMENTAÇÕES
        console.log('\n═══════════════════════════════════════════════════════════\n');
        console.log('📊 PEDIDOS SEM MOVIMENTAÇÕES:\n');

        const pedidosSemMov = pedidos.filter(p => {
            const movs = movimentacoes.filter(m => m.pedido_id === p.id);
            return movs.length === 0 && p.status === 'FINALIZADO';
        });

        if (pedidosSemMov.length > 0) {
            console.log(`⚠️ Encontrados ${pedidosSemMov.length} pedidos finalizados sem movimentações!\n`);
            console.table(pedidosSemMov.map(p => ({
                numero: p.numero,
                tipo: p.tipo_pedido,
                status: p.status,
                total: parseFloat(p.total).toFixed(2),
                data: p.data_finalizacao?.substring(0, 16) || 'Sem data'
            })));
        } else {
            console.log('✅ Todos os pedidos finalizados têm movimentações.');
        }

        // 7. ESTATÍSTICAS FINAIS
        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('📈 ESTATÍSTICAS FINAIS:\n');
        
        const vendas = pedidos.filter(p => p.tipo_pedido === 'VENDA');
        const compras = pedidos.filter(p => p.tipo_pedido === 'COMPRA');
        
        console.log(`Total de pedidos: ${pedidos.length}`);
        console.log(`- Vendas: ${vendas.length}`);
        console.log(`- Compras: ${compras.length}`);
        console.log(`\nTotal de movimentações: ${movimentacoes.length}`);
        console.log(`- Entradas: ${movimentacoes.filter(m => m.tipo === 'ENTRADA').length}`);
        console.log(`- Saídas: ${movimentacoes.filter(m => m.tipo === 'SAIDA').length}`);
        console.log(`\nProblemas encontrados: ${problemas.length}`);
        console.log(`Pedidos finalizados sem movimentações: ${pedidosSemMov.length}`);

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('✨ INVESTIGAÇÃO CONCLUÍDA!');
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Erro durante investigação:', error);
    }
}

// Executar
investigarFalhaTipoPedido().then(() => {
    console.log('👋 Processo finalizado!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Erro fatal:', err);
    process.exit(1);
});
