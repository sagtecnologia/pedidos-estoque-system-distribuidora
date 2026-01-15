// =====================================================
// TESTE: Criar pedido de VENDA e verificar movimentações
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function testarTipoPedido() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     🧪 TESTE: Verificar tipo de pedido e movimentações    ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    try {
        // ANÁLISE 1: Verificar se há pedidos com tipo NULL ou inválido
        console.log('🔍 1. Verificando tipos de pedido inválidos...\n');
        
        const { data: pedidosInvalidos, error: err1 } = await supabase
            .from('pedidos')
            .select('id, numero, tipo_pedido, status, created_at')
            .or('tipo_pedido.is.null,tipo_pedido.not.in.(VENDA,COMPRA)');

        if (err1) {
            console.log(`   ℹ️  Não foi possível verificar (pode ser RLS): ${err1.message}\n`);
        } else if (pedidosInvalidos && pedidosInvalidos.length > 0) {
            console.log('   ⚠️  PEDIDOS COM TIPO INVÁLIDO:\n');
            console.table(pedidosInvalidos);
        } else {
            console.log('   ✅ Não há pedidos com tipo inválido\n');
        }

        // ANÁLISE 2: Verificar movimentações que não seguem o padrão
        console.log('🔍 2. Verificando movimentações inconsistentes...\n');
        
        const { data: movimentacoes, error: err2 } = await supabase
            .from('estoque_movimentacoes')
            .select('*')
            .not('pedido_id', 'is', null)
            .limit(500);

        if (err2) {
            console.log(`   ⚠️  Erro ao buscar movimentações: ${err2.message}\n`);
        } else {
            console.log(`   ✅ Encontradas ${movimentacoes.length} movimentações\n`);

            // Verificar observações para detectar padrão
            const padraoEntrada = /entrada|compra/i;
            const padraoSaida = /saída|sa[ií]da|venda/i;

            const inconsistencias = [];

            for (const mov of movimentacoes) {
                const obs = mov.observacao || '';
                
                // Se a observação indica ENTRADA mas o tipo é SAÍDA
                if (padraoEntrada.test(obs) && mov.tipo === 'SAIDA') {
                    inconsistencias.push({
                        problema: '⚠️ Observação indica ENTRADA mas tipo é SAÍDA',
                        tipo: mov.tipo,
                        observacao: obs.substring(0, 50),
                        pedido_id: mov.pedido_id,
                        quantidade: mov.quantidade,
                        data: mov.created_at?.substring(0, 16)
                    });
                }

                // Se a observação indica SAÍDA mas o tipo é ENTRADA
                if (padraoSaida.test(obs) && mov.tipo === 'ENTRADA') {
                    inconsistencias.push({
                        problema: '⚠️ Observação indica SAÍDA mas tipo é ENTRADA',
                        tipo: mov.tipo,
                        observacao: obs.substring(0, 50),
                        pedido_id: mov.pedido_id,
                        quantidade: mov.quantidade,
                        data: mov.created_at?.substring(0, 16)
                    });
                }
            }

            if (inconsistencias.length > 0) {
                console.log('   🚨 INCONSISTÊNCIAS ENCONTRADAS:\n');
                console.table(inconsistencias);
            } else {
                console.log('   ✅ Não há inconsistências entre observações e tipos\n');
            }

            // Estatísticas
            const entradas = movimentacoes.filter(m => m.tipo === 'ENTRADA').length;
            const saidas = movimentacoes.filter(m => m.tipo === 'SAIDA').length;
            
            console.log('   📊 Estatísticas:');
            console.log(`   - Total: ${movimentacoes.length} movimentações`);
            console.log(`   - Entradas: ${entradas} (${(entradas/movimentacoes.length*100).toFixed(1)}%)`);
            console.log(`   - Saídas: ${saidas} (${(saidas/movimentacoes.length*100).toFixed(1)}%)`);
        }

        // ANÁLISE 3: Verificar se há duplicação de movimentações para o mesmo pedido
        console.log('\n🔍 3. Verificando duplicação de movimentações...\n');

        if (movimentacoes && movimentacoes.length > 0) {
            const movsPorPedido = {};
            
            for (const mov of movimentacoes) {
                if (!movsPorPedido[mov.pedido_id]) {
                    movsPorPedido[mov.pedido_id] = { entradas: 0, saidas: 0, total: 0 };
                }
                
                movsPorPedido[mov.pedido_id].total++;
                if (mov.tipo === 'ENTRADA') {
                    movsPorPedido[mov.pedido_id].entradas++;
                } else {
                    movsPorPedido[mov.pedido_id].saidas++;
                }
            }

            // Encontrar pedidos com ENTRADA E SAÍDA
            const pedidosComAmbos = Object.entries(movsPorPedido)
                .filter(([pedidoId, stats]) => stats.entradas > 0 && stats.saidas > 0)
                .map(([pedidoId, stats]) => ({
                    pedido_id: pedidoId,
                    entradas: stats.entradas,
                    saidas: stats.saidas,
                    total: stats.total
                }));

            if (pedidosComAmbos.length > 0) {
                console.log('   🔥 PEDIDOS COM ENTRADA E SAÍDA SIMULTÂNEAS:\n');
                console.table(pedidosComAmbos);
                console.log('\n   ⚠️  ISSO PODE INDICAR UMA FALHA!\n');
            } else {
                console.log('   ✅ Nenhum pedido tem entrada e saída ao mesmo tempo\n');
            }

            // Estatísticas gerais
            const totalPedidos = Object.keys(movsPorPedido).length;
            const pedidosComEntrada = Object.values(movsPorPedido).filter(s => s.entradas > 0 && s.saidas === 0).length;
            const pedidosComSaida = Object.values(movsPorPedido).filter(s => s.saidas > 0 && s.entradas === 0).length;

            console.log('   📊 Resumo:');
            console.log(`   - Pedidos únicos com movimentações: ${totalPedidos}`);
            console.log(`   - Apenas com ENTRADAS: ${pedidosComEntrada}`);
            console.log(`   - Apenas com SAÍDAS: ${pedidosComSaida}`);
            console.log(`   - Com AMBOS (entrada+saída): ${pedidosComAmbos.length}`);
        }

        // ANÁLISE 4: Verificar código fonte da função finalizar_pedido
        console.log('\n🔍 4. Verificando lógica da função finalizar_pedido...\n');
        
        const { data: funcao, error: err4 } = await supabase
            .rpc('exec_sql', {
                query: `
                    SELECT prosrc 
                    FROM pg_proc 
                    WHERE proname = 'finalizar_pedido'
                    LIMIT 1
                `
            });

        if (err4 || !funcao || funcao.length === 0) {
            console.log('   ⚠️  Não foi possível buscar o código da função\n');
        } else {
            const codigo = funcao[0].prosrc;
            
            // Verificar se há alguma lógica invertida
            const temLogicaCompra = /COMPRA.*ENTRADA/i.test(codigo);
            const temLogicaVenda = /VENDA.*SAIDA/i.test(codigo) || /VENDA.*SA[ÍI]DA/i.test(codigo);
            
            console.log(`   ${temLogicaCompra ? '✅' : '⚠️'}  Lógica COMPRA → ENTRADA: ${temLogicaCompra ? 'Presente' : 'Ausente'}`);
            console.log(`   ${temLogicaVenda ? '✅' : '⚠️'}  Lógica VENDA → SAÍDA: ${temLogicaVenda ? 'Presente' : 'Ausente'}`);

            if (!temLogicaCompra || !temLogicaVenda) {
                console.log('\n   ⚠️  A lógica da função pode estar incompleta!\n');
            }
        }

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('✨ ANÁLISE CONCLUÍDA!');
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Erro durante teste:', error);
    }
}

// Executar
testarTipoPedido().then(() => {
    console.log('👋 Processo finalizado!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Erro fatal:', err);
    process.exit(1);
});
