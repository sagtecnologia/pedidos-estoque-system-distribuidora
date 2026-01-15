const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function investigar() {
    console.log('\n🔍 INVESTIGANDO MOVIMENTAÇÕES\n');

    // Buscar algumas movimentações
    const { data: movs, error } = await supabase
        .from('estoque_movimentacoes')
        .select('id, pedido_id, tipo, quantidade, observacao, created_at')
        .order('created_at', { ascending: false })
        .limit(20);

    if (error) {
        console.log('❌ Erro ao buscar:', error.message);
        return;
    }

    console.log(`Total encontrado: ${movs?.length || 0}\n`);
    console.table(movs?.map(m => ({
        id: m.id.substring(0, 8),
        pedido: m.pedido_id?.substring(0, 8) || 'NULL',
        tipo: m.tipo,
        qtd: m.quantidade,
        obs: m.observacao?.substring(0, 30),
        data: m.created_at?.substring(0, 16)
    })));

    // Tentar deletar uma por uma
    console.log('\n🗑️  Tentando deletar...\n');
    
    for (const mov of movs?.slice(0, 5) || []) {
        const { error: delError } = await supabase
            .from('estoque_movimentacoes')
            .delete()
            .eq('id', mov.id);

        if (delError) {
            console.log(`❌ ${mov.id.substring(0, 8)}: ${delError.message}`);
        } else {
            console.log(`✅ ${mov.id.substring(0, 8)}: Deletado`);
        }
    }
}

investigar().catch(console.error);
