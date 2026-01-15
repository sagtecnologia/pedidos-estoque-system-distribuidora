// =====================================================
// ANÁLISE: Movimentações de produto específico
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function analisarProduto() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     🔍 ANÁLISE: IGN-0006 - AÇAI ICE                      ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    try {
        // 1. BUSCAR O PRODUTO E SABOR
        console.log('🔍 Buscando produto IGN-0006...\n');
        
        const { data: produto, error: err1 } = await supabase
            .from('produtos')
            .select('id, codigo, nome, estoque_atual')
            .eq('codigo', 'IGN-0006')
            .single();

        if (err1 || !produto) {
            console.error('❌ Erro ao buscar produto:', err1);
            return;
        }

        console.log('📦 Produto encontrado:');
        console.log(`   Código: ${produto.codigo}`);
        console.log(`   Nome: ${produto.nome}`);
        console.log(`   Estoque Total: ${produto.estoque_atual}\n`);

        // 2. BUSCAR O SABOR ESPECÍFICO
        const { data: sabores, error: err2 } = await supabase
            .from('produto_sabores')
            .select('id, sabor, quantidade')
            .eq('produto_id', produto.id)
            .or('sabor.ilike.%AÇAI%ICE%,sabor.ilike.%ACAI%ICE%');

        if (err2) {
            console.error('❌ Erro ao buscar sabores:', err2);
            return;
        }

        if (!sabores || sabores.length === 0) {
            // Buscar todos os sabores deste produto
            const { data: todosSabores } = await supabase
                .from('produto_sabores')
                .select('id, sabor, quantidade')
                .eq('produto_id', produto.id);
            
            console.log('\n⚠️  Sabor AÇAI ICE não encontrado. Sabores disponíveis:');
            console.table(todosSabores);
            
            if (!todosSabores || todosSabores.length === 0) {
                console.log('❌ Este produto não tem sabores cadastrados\n');
                return;
            }
            
            // Usar o primeiro sabor com quantidade negativa ou o que tiver mais movimentações
            console.log('\n🔍 Buscando sabor com estoque negativo...\n');
            const saborNegativo = todosSabores.find(s => parseFloat(s.quantidade) < 0);
            if (saborNegativo) {
                sabores.push(saborNegativo);
                console.log(`✅ Encontrado sabor com estoque negativo: ${saborNegativo.sabor}\n`);
            } else {
                console.log('❌ Nenhum sabor com estoque negativo. Usando primeiro sabor.\n');
                sabores.push(todosSabores[0]);
            }
        }

        const sabor = sabores[0];
        console.log('🍰 Sabor encontrado:');
        console.log(`   Sabor: ${sabor.sabor}`);
        console.log(`   Estoque Atual: ${sabor.quantidade}\n`);

        // 3. BUSCAR TODAS AS MOVIMENTAÇÕES DESTE SABOR
        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('📊 MOVIMENTAÇÕES DO PRODUTO:\n');

        const { data: movimentacoes, error: err3 } = await supabase
            .from('estoque_movimentacoes')
            .select(`
                id,
                tipo,
                quantidade,
                estoque_anterior,
                estoque_novo,
                observacao,
                created_at,
                pedido_id,
                usuario_id
            `)
            .eq('produto_id', produto.id)
            .eq('sabor_id', sabor.id)
            .order('created_at', { ascending: true });

        if (err3) {
            console.error('❌ Erro ao buscar movimentações:', err3);
            return;
        }

        console.log(`✅ Total de movimentações: ${movimentacoes.length}\n`);

        // 4. AGRUPAR POR TIPO
        const entradas = movimentacoes.filter(m => m.tipo === 'ENTRADA');
        const saidas = movimentacoes.filter(m => m.tipo === 'SAIDA');

        const totalEntradas = entradas.reduce((sum, m) => sum + parseFloat(m.quantidade), 0);
        const totalSaidas = saidas.reduce((sum, m) => sum + parseFloat(m.quantidade), 0);
        const estoqueCalculado = totalEntradas - totalSaidas;

        console.log('📈 RESUMO:');
        console.log(`   ✅ Entradas: ${entradas.length} movimentações = ${totalEntradas.toFixed(2)} unidades`);
        console.log(`   ❌ Saídas: ${saidas.length} movimentações = ${totalSaidas.toFixed(2)} unidades`);
        console.log(`   📦 Estoque Calculado: ${estoqueCalculado.toFixed(2)} unidades`);
        console.log(`   🏷️  Estoque Real (banco): ${sabor.quantidade} unidades`);
        console.log(`   ${estoqueCalculado.toFixed(2) === parseFloat(sabor.quantidade).toFixed(2) ? '✅' : '⚠️'} Diferença: ${(parseFloat(sabor.quantidade) - estoqueCalculado).toFixed(2)}\n`);

        // 5. EXIBIR HISTÓRICO COMPLETO
        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('📜 HISTÓRICO COMPLETO (cronológico):\n');

        const historico = movimentacoes.map(m => ({
            data: m.created_at.substring(0, 16).replace('T', ' '),
            tipo: m.tipo === 'ENTRADA' ? '⬆️  ENTRADA' : '⬇️  SAÍDA',
            quantidade: parseFloat(m.quantidade).toFixed(2),
            antes: parseFloat(m.estoque_anterior || 0).toFixed(2),
            depois: parseFloat(m.estoque_novo || 0).toFixed(2),
            observacao: (m.observacao || 'Sem obs').substring(0, 40),
            pedido: m.pedido_id ? m.pedido_id.substring(0, 8) : '---'
        }));

        console.table(historico);

        // 6. BUSCAR PEDIDOS RELACIONADOS
        console.log('\n═══════════════════════════════════════════════════════════\n');
        console.log('📋 PEDIDOS RELACIONADOS:\n');

        const pedidosIds = [...new Set(movimentacoes.filter(m => m.pedido_id).map(m => m.pedido_id))];
        
        if (pedidosIds.length === 0) {
            console.log('ℹ️  Não há pedidos relacionados\n');
        } else {
            const { data: pedidos, error: err4 } = await supabase
                .from('pedidos')
                .select('id, numero, tipo_pedido, status, total, created_at, data_finalizacao')
                .in('id', pedidosIds)
                .order('created_at', { ascending: true });

            if (err4) {
                console.error('❌ Erro ao buscar pedidos:', err4);
            } else {
                const pedidosDetalhados = pedidos.map(p => {
                    const movsDestePedido = movimentacoes.filter(m => m.pedido_id === p.id);
                    const entradasPedido = movsDestePedido.filter(m => m.tipo === 'ENTRADA');
                    const saidasPedido = movsDestePedido.filter(m => m.tipo === 'SAIDA');
                    
                    return {
                        numero: p.numero,
                        tipo: p.tipo_pedido,
                        status: p.status,
                        total: `R$ ${parseFloat(p.total).toFixed(2)}`,
                        entradas: entradasPedido.reduce((sum, m) => sum + parseFloat(m.quantidade), 0).toFixed(2),
                        saidas: saidasPedido.reduce((sum, m) => sum + parseFloat(m.quantidade), 0).toFixed(2),
                        data: p.created_at.substring(0, 10),
                        finalizado: p.data_finalizacao ? p.data_finalizacao.substring(0, 10) : '---'
                    };
                });

                console.table(pedidosDetalhados);

                // Análise de problema
                console.log('\n🔍 ANÁLISE DO PROBLEMA:\n');
                
                const pedidosCompra = pedidos.filter(p => p.tipo_pedido === 'COMPRA');
                const pedidosVenda = pedidos.filter(p => p.tipo_pedido === 'VENDA');
                
                console.log(`📦 Pedidos de COMPRA: ${pedidosCompra.length}`);
                console.log(`🛒 Pedidos de VENDA: ${pedidosVenda.length}\n`);

                // Identificar o pedido problemático
                const pedidosFinalizados = pedidos.filter(p => p.status === 'FINALIZADO');
                const pedidosCancelados = pedidos.filter(p => p.status === 'CANCELADO');

                console.log(`✅ Finalizados: ${pedidosFinalizados.length}`);
                console.log(`❌ Cancelados: ${pedidosCancelados.length}\n`);

                // Verificar se há pedidos duplicados
                const movsPorObs = {};
                for (const mov of movimentacoes) {
                    const obs = mov.observacao || 'Sem observação';
                    if (!movsPorObs[obs]) {
                        movsPorObs[obs] = [];
                    }
                    movsPorObs[obs].push(mov);
                }

                console.log('🔥 POSSÍVEIS FINALIZAÇÕES DUPLICADAS:\n');
                let temDuplicatas = false;
                for (const [obs, movs] of Object.entries(movsPorObs)) {
                    if (movs.length > 1 && obs.includes('Finalização')) {
                        temDuplicatas = true;
                        const pedidosDupls = [...new Set(movs.map(m => m.pedido_id))];
                        console.log(`   ⚠️  "${obs}": ${movs.length} movimentações`);
                        console.log(`      Pedidos: ${pedidosDupls.length}`);
                        
                        for (const pId of pedidosDupls) {
                            const p = pedidos.find(ped => ped.id === pId);
                            const movsP = movs.filter(m => m.pedido_id === pId);
                            console.log(`      - ${p?.numero || 'Desconhecido'}: ${movsP.length}x de ${movsP[0].quantidade}`);
                        }
                    }
                }

                if (!temDuplicatas) {
                    console.log('   ✅ Não há finalizações duplicadas detectadas\n');
                } else {
                    console.log('\n   🔥 ISSO EXPLICA O PROBLEMA!\n');
                }
            }
        }

        // 7. SOLUÇÃO PROPOSTA
        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('💡 SOLUÇÃO PARA O PROBLEMA:\n');
        console.log('O erro ocorre porque o produto foi VENDIDO após a COMPRA.');
        console.log('Agora você quer cancelar a COMPRA, mas não há estoque suficiente.\n');
        console.log('OPÇÕES:\n');
        console.log('1. ❌ NÃO cancelar este pedido de compra (recomendado)');
        console.log('   - Manter a compra como está');
        console.log('   - O produto foi legalmente vendido\n');
        console.log('2. ⚠️  Cancelar as VENDAS primeiro, depois a COMPRA');
        console.log('   - Reverter as vendas que usaram este estoque');
        console.log('   - Depois cancelar a compra\n');
        console.log('3. 🔧 Ajuste manual de estoque');
        console.log('   - Adicionar entrada manual para compensar');
        console.log('   - Depois cancelar a compra\n');

        console.log('═══════════════════════════════════════════════════════════');
        console.log('✨ ANÁLISE CONCLUÍDA!');
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Erro:', error);
    }
}

analisarProduto().then(() => {
    console.log('👋 Processo finalizado!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Erro fatal:', err);
    process.exit(1);
});
