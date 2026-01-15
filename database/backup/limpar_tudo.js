const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function limparTudo() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║  🧹 LIMPANDO TUDO PARA REFINALIZAR                       ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    // 1. Contar o que existe
    const { count: countMovs } = await supabase
        .from('estoque_movimentacoes')
        .select('*', { count: 'exact', head: true });

    const { count: countSabores } = await supabase
        .from('produto_sabores')
        .select('*', { count: 'exact', head: true });

    const { data: produtosComEstoque } = await supabase
        .from('produtos')
        .select('id, codigo, estoque_atual')
        .neq('estoque_atual', 0);

    console.log('📊 Estado atual:');
    console.log(`   • ${countMovs || 0} movimentações`);
    console.log(`   • ${countSabores || 0} sabores`);
    console.log(`   • ${produtosComEstoque?.length || 0} produtos com estoque\n`);

    // 2. Deletar movimentações (todas, sem filtro)
    console.log('🗑️  Deletando movimentações...');
    
    // Buscar todas as IDs
    const { data: todasMovs } = await supabase
        .from('estoque_movimentacoes')
        .select('id');

    let deletadas = 0;
    for (const mov of todasMovs || []) {
        const { error } = await supabase
            .from('estoque_movimentacoes')
            .delete()
            .eq('id', mov.id);
        
        if (!error) deletadas++;
    }

    console.log(`   ✅ ${deletadas} movimentações deletadas`);

    // 3. Zerar sabores
    console.log('🍰 Zerando sabores...');
    const { error: errSabores } = await supabase
        .from('produto_sabores')
        .update({ quantidade: 0 })
        .neq('id', '00000000-0000-0000-0000-000000000000');

    if (errSabores) {
        console.log(`   ❌ Erro: ${errSabores.message}`);
    } else {
        console.log(`   ✅ ${countSabores || 0} sabores zerados`);
    }

    // 4. Zerar estoque dos produtos
    console.log('📦 Zerando estoque...');
    let produtosZerados = 0;
    
    for (const produto of produtosComEstoque || []) {
        const { error } = await supabase
            .from('produtos')
            .update({ estoque_atual: 0 })
            .eq('id', produto.id);

        if (!error) {
            produtosZerados++;
            console.log(`   ✅ ${produto.codigo}: ${produto.estoque_atual} → 0`);
        }
    }

    // 5. Verificar resultado
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║  ✅ LIMPEZA CONCLUÍDA                                     ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    const { count: finalMovs } = await supabase
        .from('estoque_movimentacoes')
        .select('*', { count: 'exact', head: true });

    const { count: finalSabores } = await supabase
        .from('produto_sabores')
        .select('*', { count: 'exact', head: true })
        .gt('quantidade', 0);

    const { data: finalEstoque } = await supabase
        .from('produtos')
        .select('id')
        .neq('estoque_atual', 0);

    console.log('📊 Estado final:');
    console.log(`   • ${finalMovs || 0} movimentações`);
    console.log(`   • ${finalSabores || 0} sabores com quantidade > 0`);
    console.log(`   • ${finalEstoque?.length || 0} produtos com estoque\n`);

    console.log('📋 PRÓXIMOS PASSOS:');
    console.log('   1. Reabra os pedidos de COMPRA para rascunho');
    console.log('   2. Reabra os pedidos de VENDA para rascunho');
    console.log('   3. Finalize os pedidos de COMPRA novamente');
    console.log('   4. Finalize os pedidos de VENDA novamente\n');
}

limparTudo().catch(console.error);
