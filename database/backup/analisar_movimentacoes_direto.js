// =====================================================
// ANÁLISE DIRETA: Movimentações por código de produto
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function analisarMovimentacoes() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     🔍 ANÁLISE DIRETA: IGN-0006                           ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    try {
        // 1. BUSCAR O PRODUTO
        const { data: produto } = await supabase
            .from('produtos')
            .select('id, codigo, nome, estoque_atual')
            .eq('codigo', 'IGN-0006')
            .single();

        if (!produto) {
            console.error('❌ Produto não encontrado');
            return;
        }

        console.log('📦 Produto:', produto.nome);
        console.log('   Estoque Total:', produto.estoque_atual, '\n');

        // 2. BUSCAR TODAS AS MOVIMENTAÇÕES DESTE PRODUTO
        const { data: movs } = await supabase
            .from('estoque_movimentacoes')
            .select(`
                *,
                produto_sabores(sabor, quantidade)
            `)
            .eq('produto_id', produto.id)
            .order('created_at', { ascending: true });

        console.log(`✅ Total de movimentações: ${movs.length}\n`);

        // 3. AGRUPAR POR SABOR
        const porSabor = {};
        
        for (const mov of movs) {
            const saborNome = mov.produto_sabores?.sabor || 'SEM SABOR';
            
            if (!porSabor[saborNome]) {
                porSabor[saborNome] = {
                    sabor: saborNome,
                    sabor_id: mov.sabor_id,
                    entradas: [],
                    saidas: [],
                    movs: []
                };
            }
            
            porSabor[saborNome].movs.push(mov);
            
            if (mov.tipo === 'ENTRADA') {
                porSabor[saborNome].entradas.push(mov);
            } else {
                porSabor[saborNome].saidas.push(mov);
            }
        }

        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('🍰 RESUMO POR SABOR:\n');

        for (const [saborNome, dados] of Object.entries(porSabor)) {
            const totalEnt = dados.entradas.reduce((s, m) => s + parseFloat(m.quantidade), 0);
            const totalSai = dados.saidas.reduce((s, m) => s + parseFloat(m.quantidade), 0);
            const saldo = totalEnt - totalSai;
            
            console.log(`📍 Sabor: ${saborNome}`);
            console.log(`   ⬆️  Entradas: ${dados.entradas.length}x = ${totalEnt.toFixed(2)} unidades`);
            console.log(`   ⬇️  Saídas: ${dados.saidas.length}x = ${totalSai.toFixed(2)} unidades`);
            console.log(`   📊 Saldo: ${saldo.toFixed(2)} unidades`);
            
            if (dados.movs[0]?.produto_sabores) {
                console.log(`   💾 Estoque Real: ${dados.movs[0].produto_sabores.quantidade}`);
            }
            console.log('');
        }

        // 4. BUSCAR SABOR COM PROBLEMA (AÇAI ICE ou estoque negativo)
        let saborProblema = null;
        
        for (const [saborNome, dados] of Object.entries(porSabor)) {
            if (saborNome.includes('AÇAI') || saborNome.includes('ACAI')) {
                saborProblema = dados;
                break;
            }
        }

        if (!saborProblema) {
            // Buscar qualquer sabor com estoque negativo
            for (const mov of movs) {
                if (mov.produto_sabores && parseFloat(mov.produto_sabores.quantidade) < 0) {
                    saborProblema = porSabor[mov.produto_sabores.sabor];
                    break;
                }
            }
        }

        if (!saborProblema) {
            // Pegar o primeiro sabor
            saborProblema = Object.values(porSabor)[0];
        }

        if (!saborProblema) {
            console.log('❌ Não foi possível identificar o sabor problemático\n');
            return;
        }

        console.log('═══════════════════════════════════════════════════════════\n');
        console.log(`🎯 ANÁLISE DETALHADA: ${saborProblema.sabor}\n`);

        // 5. HISTÓRICO COMPLETO
        console.log('📜 HISTÓRICO COMPLETO:\n');
        
        const historico = saborProblema.movs.map(m => ({
            data: m.created_at.substring(0, 16).replace('T', ' '),
            tipo: m.tipo === 'ENTRADA' ? '⬆️  ENT' : '⬇️  SAI',
            qtd: parseFloat(m.quantidade).toFixed(2),
            antes: parseFloat(m.estoque_anterior || 0).toFixed(2),
            depois: parseFloat(m.estoque_novo || 0).toFixed(2),
            obs: (m.observacao || '').substring(0, 35),
            pedido: m.pedido_id ? m.pedido_id.substring(0, 8) : '---'
        }));

        console.table(historico);

        // 6. BUSCAR PEDIDOS
        const pedidosIds = [...new Set(saborProblema.movs.filter(m => m.pedido_id).map(m => m.pedido_id))];
        
        if (pedidosIds.length > 0) {
            console.log('\n═══════════════════════════════════════════════════════════\n');
            console.log('📋 PEDIDOS RELACIONADOS:\n');

            const { data: pedidos } = await supabase
                .from('pedidos')
                .select('*')
                .in('id', pedidosIds)
                .order('created_at');

            if (pedidos) {
                const tabelaPedidos = pedidos.map(p => {
                    const movsP = saborProblema.movs.filter(m => m.pedido_id === p.id);
                    const ent = movsP.filter(m => m.tipo === 'ENTRADA').reduce((s, m) => s + parseFloat(m.quantidade), 0);
                    const sai = movsP.filter(m => m.tipo === 'SAIDA').reduce((s, m) => s + parseFloat(m.quantidade), 0);
                    
                    return {
                        numero: p.numero,
                        tipo: p.tipo_pedido,
                        status: p.status,
                        entradas: ent.toFixed(2),
                        saidas: sai.toFixed(2),
                        data: p.created_at.substring(0, 10),
                        finalizado: p.data_finalizacao ? p.data_finalizacao.substring(0, 10) : '---'
                    };
                });

                console.table(tabelaPedidos);

                // ANÁLISE DO PROBLEMA
                console.log('\n🔍 DIAGNÓSTICO:\n');
                
                const compras = pedidos.filter(p => p.tipo_pedido === 'COMPRA');
                const vendas = pedidos.filter(p => p.tipo_pedido === 'VENDA');
                const finalizados = pedidos.filter(p => p.status === 'FINALIZADO');
                const cancelados = pedidos.filter(p => p.status === 'CANCELADO');

                console.log(`📦 Pedidos de COMPRA: ${compras.length} (${compras.filter(p => p.status === 'FINALIZADO').length} finalizados)`);
                console.log(`🛒 Pedidos de VENDA: ${vendas.length} (${vendas.filter(p => p.status === 'FINALIZADO').length} finalizados)`);
                console.log(`✅ Finalizados: ${finalizados.length}`);
                console.log(`❌ Cancelados: ${cancelados.length}\n`);

                // Calcular estoque baseado nos pedidos finalizados
                const pedidosFin = pedidos.filter(p => p.status === 'FINALIZADO');
                let estoqueSimulado = 0;
                
                console.log('💡 SIMULAÇÃO DE ESTOQUE (apenas finalizados):\n');
                for (const p of pedidosFin) {
                    const movsP = saborProblema.movs.filter(m => m.pedido_id === p.id);
                    for (const m of movsP) {
                        if (m.tipo === 'ENTRADA') {
                            estoqueSimulado += parseFloat(m.quantidade);
                            console.log(`   ${p.numero} (COMPRA): +${m.quantidade} → Estoque: ${estoqueSimulado.toFixed(2)}`);
                        } else {
                            estoqueSimulado -= parseFloat(m.quantidade);
                            console.log(`   ${p.numero} (VENDA): -${m.quantidade} → Estoque: ${estoqueSimulado.toFixed(2)}`);
                        }
                    }
                }

                const totalEnt = saborProblema.entradas.reduce((s, m) => s + parseFloat(m.quantidade), 0);
                const totalSai = saborProblema.saidas.reduce((s, m) => s + parseFloat(m.quantidade), 0);

                console.log(`\n📊 TOTAIS:`);
                console.log(`   Entradas totais: ${totalEnt.toFixed(2)}`);
                console.log(`   Saídas totais: ${totalSai.toFixed(2)}`);
                console.log(`   Estoque simulado: ${estoqueSimulado.toFixed(2)}\n`);
            }
        }

        console.log('═══════════════════════════════════════════════════════════');
        console.log('✨ ANÁLISE CONCLUÍDA!');
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Erro:', error);
    }
}

analisarMovimentacoes().then(() => {
    console.log('👋 Processo finalizado!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Erro fatal:', err);
    process.exit(1);
});
