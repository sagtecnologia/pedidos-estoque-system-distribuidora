// =====================================================
// CORREÇÃO: Pedidos com status errado após cancelamento
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function corrigirPedidosCancelados() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     🔧 CORREÇÃO: Status de pedidos cancelados             ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    try {
        // 1. BUSCAR TODAS AS MOVIMENTAÇÕES DE CANCELAMENTO
        console.log('🔍 Buscando movimentações de cancelamento...\n');
        
        const { data: movsCancelamento, error: err1 } = await supabase
            .from('estoque_movimentacoes')
            .select('pedido_id, observacao, created_at')
            .or('observacao.ilike.%cancelamento%,observacao.ilike.%reabertura%')
            .not('pedido_id', 'is', null);

        if (err1) {
            console.error('❌ Erro:', err1);
            return;
        }

        console.log(`✅ Encontradas ${movsCancelamento.length} movimentações de cancelamento\n`);

        if (movsCancelamento.length === 0) {
            console.log('ℹ️  Não há pedidos cancelados para corrigir\n');
            return;
        }

        // 2. OBTER IDS ÚNICOS DOS PEDIDOS
        const pedidosIds = [...new Set(movsCancelamento.map(m => m.pedido_id))];
        console.log(`📋 Total de pedidos envolvidos: ${pedidosIds.length}\n`);

        // 3. BUSCAR STATUS ATUAL DESSES PEDIDOS
        const { data: pedidos, error: err2 } = await supabase
            .from('pedidos')
            .select('id, numero, tipo_pedido, status, created_at')
            .in('id', pedidosIds);

        if (err2) {
            console.error('❌ Erro ao buscar pedidos:', err2);
            return;
        }

        // 4. IDENTIFICAR PEDIDOS COM STATUS ERRADO
        const pedidosComProblema = pedidos.filter(p => {
            // Verificar se tem movimentação de cancelamento mas não está CANCELADO nem RASCUNHO
            const temCancelamento = movsCancelamento.some(m => 
                m.pedido_id === p.id && 
                m.observacao.toLowerCase().includes('cancelamento definitivo')
            );
            
            return temCancelamento && p.status !== 'CANCELADO';
        });

        console.log('═══════════════════════════════════════════════════════════\n');
        
        if (pedidosComProblema.length === 0) {
            console.log('✅ Todos os pedidos cancelados estão com status correto!\n');
            return;
        }

        console.log(`⚠️  PEDIDOS COM STATUS INCORRETO: ${pedidosComProblema.length}\n`);
        console.table(pedidosComProblema.map(p => ({
            numero: p.numero,
            tipo: p.tipo_pedido,
            status_atual: p.status,
            status_esperado: 'CANCELADO'
        })));

        // 5. PERGUNTAR SE DESEJA CORRIGIR
        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('🔧 CORREÇÃO AUTOMÁTICA\n');
        console.log('Para corrigir esses pedidos, execute o seguinte SQL no Supabase:\n');
        
        for (const pedido of pedidosComProblema) {
            console.log(`-- Pedido ${pedido.numero}`);
            console.log(`UPDATE pedidos SET status = 'CANCELADO' WHERE id = '${pedido.id}';`);
        }

        console.log('\n-- OU execute todos de uma vez:');
        console.log(`UPDATE pedidos SET status = 'CANCELADO' WHERE id IN ('${pedidosComProblema.map(p => p.id).join("','")}');\n`);

        // 6. VERIFICAR PEDIDOS DUPLICADOS (finalizados múltiplas vezes)
        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('🔍 Verificando pedidos finalizados múltiplas vezes...\n');

        const { data: todasMovs, error: err3 } = await supabase
            .from('estoque_movimentacoes')
            .select('pedido_id, tipo, quantidade, observacao, created_at')
            .not('pedido_id', 'is', null)
            .order('created_at');

        if (err3) {
            console.error('❌ Erro:', err3);
            return;
        }

        // Agrupar por pedido e verificar duplicações
        const movsPorPedido = {};
        for (const mov of todasMovs) {
            if (!movsPorPedido[mov.pedido_id]) {
                movsPorPedido[mov.pedido_id] = [];
            }
            movsPorPedido[mov.pedido_id].push(mov);
        }

        const pedidosDuplicados = [];
        
        for (const [pedidoId, movs] of Object.entries(movsPorPedido)) {
            // Verificar se há múltiplas movimentações idênticas no mesmo horário/próximas
            const finalizacoes = movs.filter(m => 
                m.observacao && 
                (m.observacao.includes('Finalização pedido') || 
                 m.observacao.includes('Entrada - Finalização'))
            );

            if (finalizacoes.length > 1) {
                // Verificar se são realmente duplicadas (mesmo produto, mesma quantidade, horário próximo)
                const grupos = {};
                for (const fin of finalizacoes) {
                    const chave = `${fin.tipo}_${fin.quantidade}_${fin.created_at.substring(0, 16)}`;
                    grupos[chave] = (grupos[chave] || 0) + 1;
                }

                const temDuplicadas = Object.values(grupos).some(count => count > 1);
                if (temDuplicadas) {
                    const pedido = pedidos.find(p => p.id === pedidoId);
                    pedidosDuplicados.push({
                        pedido_numero: pedido?.numero || 'Desconhecido',
                        pedido_id: pedidoId,
                        total_finalizacoes: finalizacoes.length,
                        movs_duplicadas: Object.values(grupos).filter(c => c > 1).reduce((a, b) => a + b, 0)
                    });
                }
            }
        }

        if (pedidosDuplicados.length > 0) {
            console.log('⚠️  PEDIDOS FINALIZADOS MÚLTIPLAS VEZES:\n');
            console.table(pedidosDuplicados);
            console.log('\n🔥 ISSO INDICA UM BUG! O pedido foi finalizado mais de uma vez.');
            console.log('📝 Possíveis causas:');
            console.log('   - Duplo clique no botão de finalizar');
            console.log('   - Falta de proteção contra múltiplos cliques');
            console.log('   - Ausência de verificação de status antes de finalizar');
        } else {
            console.log('✅ Não há pedidos finalizados múltiplas vezes\n');
        }

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('✨ ANÁLISE CONCLUÍDA!');
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Erro:', error);
    }
}

corrigirPedidosCancelados().then(() => {
    console.log('👋 Processo finalizado!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Erro fatal:', err);
    process.exit(1);
});
