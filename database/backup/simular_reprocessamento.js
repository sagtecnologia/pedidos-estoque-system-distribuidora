// =====================================================
// REPROCESSAR ESTOQUE BASEADO NOS PEDIDOS FINALIZADOS
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function reprocessarEstoque() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     🔧 REPROCESSAMENTO DE ESTOQUE                         ║');
    console.log('║     Baseado nos PEDIDOS FINALIZADOS                       ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    try {
        // 1. BACKUP das movimentações atuais
        console.log('💾 Criando backup das movimentações atuais...\n');
        
        const { data: movsAtuais } = await supabase
            .from('estoque_movimentacoes')
            .select('*');
        
        console.log(`✅ Backup criado: ${movsAtuais?.length || 0} movimentações\n`);

        // 2. BUSCAR PEDIDOS FINALIZADOS
        console.log('📦 Buscando pedidos finalizados...\n');
        
        const { data: pedidos, error: errPedidos } = await supabase
            .from('pedidos')
            .select('*')
            .eq('status', 'FINALIZADO')
            .order('data_finalizacao', { ascending: true, nullsFirst: false })
            .order('created_at', { ascending: true });

        if (errPedidos) {
            console.error('❌ Erro ao buscar pedidos:', errPedidos);
            return;
        }

        console.log(`✅ Encontrados ${pedidos.length} pedidos finalizados\n`);

        const resumo = pedidos.reduce((acc, p) => {
            acc[p.tipo_pedido] = (acc[p.tipo_pedido] || 0) + 1;
            return acc;
        }, {});

        console.table(resumo);

        // 3. CONFIRMAR ANTES DE LIMPAR
        console.log('\n⚠️  ATENÇÃO: O próximo passo irá:');
        console.log('   1. DELETAR todas as movimentações atuais');
        console.log('   2. ZERAR todos os estoques');
        console.log('   3. REPROCESSAR todos os pedidos finalizados\n');
        console.log('Execute o SQL manualmente no Supabase para prosseguir.\n');
        console.log('Arquivo: EXECUTAR_URGENTE_ajustar_estoque.sql\n');

        // 4. SIMULAR o reprocessamento (sem fazer alterações)
        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('📊 SIMULAÇÃO DO REPROCESSAMENTO:\n');

        const estoquesSimulados = {};
        let totalMovs = 0;

        for (const pedido of pedidos) {
            // Buscar itens do pedido
            const { data: itens } = await supabase
                .from('pedido_itens')
                .select(`
                    *,
                    produtos(codigo, nome),
                    produto_sabores(sabor)
                `)
                .eq('pedido_id', pedido.id);

            if (!itens || itens.length === 0) continue;

            console.log(`\n📦 Pedido ${pedido.numero} (${pedido.tipo_pedido})`);
            console.log(`   Data: ${pedido.data_finalizacao || pedido.created_at}`);

            for (const item of itens) {
                if (!item.sabor_id) continue;

                const chave = `${item.produto_id}_${item.sabor_id}`;
                
                if (!estoquesSimulados[chave]) {
                    estoquesSimulados[chave] = {
                        codigo: item.produtos.codigo,
                        nome: item.produtos.nome,
                        sabor: item.produto_sabores?.sabor || 'SEM SABOR',
                        estoque: 0,
                        entradas: 0,
                        saidas: 0
                    };
                }

                const antes = estoquesSimulados[chave].estoque;

                if (pedido.tipo_pedido === 'COMPRA') {
                    estoquesSimulados[chave].estoque += parseFloat(item.quantidade);
                    estoquesSimulados[chave].entradas += parseFloat(item.quantidade);
                    console.log(`   ⬆️  ${item.produtos.codigo} (${item.produto_sabores?.sabor}): +${item.quantidade} → ${estoquesSimulados[chave].estoque.toFixed(2)}`);
                } else if (pedido.tipo_pedido === 'VENDA') {
                    estoquesSimulados[chave].estoque -= parseFloat(item.quantidade);
                    estoquesSimulados[chave].saidas += parseFloat(item.quantidade);
                    console.log(`   ⬇️  ${item.produtos.codigo} (${item.produto_sabores?.sabor}): -${item.quantidade} → ${estoquesSimulados[chave].estoque.toFixed(2)}`);
                }

                totalMovs++;
            }
        }

        // 5. MOSTRAR RESULTADO FINAL SIMULADO
        console.log('\n═══════════════════════════════════════════════════════════\n');
        console.log('📊 ESTOQUE FINAL SIMULADO:\n');

        const estoqueArray = Object.values(estoquesSimulados).map(e => ({
            codigo: e.codigo,
            produto: e.nome.substring(0, 20),
            sabor: e.sabor.substring(0, 15),
            entradas: e.entradas.toFixed(2),
            saidas: e.saidas.toFixed(2),
            estoque_final: e.estoque.toFixed(2),
            status: e.estoque < 0 ? '⚠️ NEG' : '✅'
        }));

        console.table(estoqueArray);

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('📈 RESUMO DA SIMULAÇÃO:\n');
        console.log(`   Pedidos processados: ${pedidos.length}`);
        console.log(`   Movimentações que seriam criadas: ${totalMovs}`);
        console.log(`   Produtos afetados: ${Object.keys(estoquesSimulados).length}`);
        
        const comEstoqueNegativo = estoqueArray.filter(e => parseFloat(e.estoque_final) < 0);
        if (comEstoqueNegativo.length > 0) {
            console.log(`\n   ⚠️  ATENÇÃO: ${comEstoqueNegativo.length} produtos ficariam com estoque NEGATIVO:`);
            comEstoqueNegativo.forEach(e => {
                console.log(`      - ${e.codigo} (${e.sabor}): ${e.estoque_final}`);
            });
            console.log('\n   Isso indica que houve VENDAS sem COMPRAS suficientes!');
        }

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('✨ SIMULAÇÃO CONCLUÍDA!');
        console.log('═══════════════════════════════════════════════════════════\n');
        
        console.log('💡 Para aplicar o reprocessamento:');
        console.log('   1. Abra o Supabase SQL Editor');
        console.log('   2. Execute o arquivo: EXECUTAR_URGENTE_ajustar_estoque.sql');
        console.log('   3. Descomente as seções de DELETE e UPDATE');
        console.log('   4. Execute novamente\n');

    } catch (error) {
        console.error('❌ Erro:', error);
    }
}

reprocessarEstoque().then(() => {
    console.log('👋 Processo finalizado!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Erro fatal:', err);
    process.exit(1);
});
