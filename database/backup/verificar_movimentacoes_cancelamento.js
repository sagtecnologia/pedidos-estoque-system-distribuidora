/**
 * VERIFICAR MOVIMENTAÇÕES DE CANCELAMENTO
 * Identifica se há movimentações duplicadas de cancelamento
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrcmFzZHhtaGt2b2FjbHNsdnJyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNTQ3NTE3NSwiZXhwIjoyMDUxMDUxMTc1fQ.E21x-3E00OHu0IA-GEL3Vn97gZnEw1LSzX6KnX08fYU';
const supabase = createClient(supabaseUrl, supabaseKey);

async function verificarCancelamentos() {
    console.log('\n🔍 VERIFICANDO MOVIMENTAÇÕES DE CANCELAMENTO...\n');
    
    // Buscar produto IGN-0006
    const { data: produto } = await supabase
        .from('produtos')
        .select('id, codigo, nome')
        .eq('codigo', 'IGN-0006')
        .single();
    
    if (!produto) {
        console.log('❌ Produto IGN-0006 não encontrado');
        return;
    }
    
    console.log(`📦 Produto: ${produto.codigo} - ${produto.nome}\n`);
    
    // Buscar todos os sabores
    const { data: sabores } = await supabase
        .from('produto_sabores')
        .select('id, sabor, quantidade')
        .eq('produto_id', produto.id);
    
    console.log('📊 ESTOQUE ATUAL:');
    sabores.forEach(s => {
        console.log(`   ${s.sabor}: ${s.quantidade} unidades`);
    });
    
    // Buscar movimentações de cancelamento
    const { data: movsCancelamento } = await supabase
        .from('estoque_movimentacoes')
        .select(`
            *,
            pedidos!pedido_id(numero, status, tipo_pedido),
            produto_sabores!sabor_id(sabor)
        `)
        .eq('produto_id', produto.id)
        .like('observacao', '%Cancelamento%')
        .order('created_at', { ascending: false });
    
    console.log(`\n🔍 MOVIMENTAÇÕES DE CANCELAMENTO (${movsCancelamento?.length || 0}):\n`);
    
    if (movsCancelamento && movsCancelamento.length > 0) {
        movsCancelamento.forEach((mov, idx) => {
            console.log(`${idx + 1}. Pedido: ${mov.pedidos?.numero || 'N/A'}`);
            console.log(`   Status: ${mov.pedidos?.status || 'N/A'}`);
            console.log(`   Tipo: ${mov.tipo} - ${mov.quantidade} unidades`);
            console.log(`   Sabor: ${mov.produto_sabores?.sabor || 'N/A'}`);
            console.log(`   Estoque: ${mov.estoque_anterior} → ${mov.estoque_novo}`);
            console.log(`   Data: ${new Date(mov.created_at).toLocaleString('pt-BR')}`);
            console.log(`   Observação: ${mov.observacao}`);
            console.log('');
        });
    } else {
        console.log('   Nenhuma movimentação de cancelamento encontrada');
    }
    
    // Buscar pedidos com possível problema
    console.log('\n⚠️ VERIFICANDO PEDIDOS COM STATUS INCONSISTENTE:\n');
    
    const { data: pedidosProblema } = await supabase
        .from('pedidos')
        .select(`
            id,
            numero,
            status,
            tipo_pedido,
            created_at
        `)
        .eq('status', 'FINALIZADO')
        .order('created_at', { ascending: false })
        .limit(10);
    
    if (pedidosProblema) {
        for (const pedido of pedidosProblema) {
            // Verificar se tem movimentações de cancelamento mas status ainda é FINALIZADO
            const { data: movsCancel } = await supabase
                .from('estoque_movimentacoes')
                .select('id')
                .eq('pedido_id', pedido.id)
                .like('observacao', '%Cancelamento%');
            
            if (movsCancel && movsCancel.length > 0) {
                console.log(`❌ PROBLEMA: ${pedido.numero}`);
                console.log(`   Status: ${pedido.status} (mas tem ${movsCancel.length} movimentações de cancelamento!)`);
                console.log(`   Tipo: ${pedido.tipo_pedido}`);
                console.log('');
            }
        }
    }
    
    // Sugestão de correção
    console.log('\n💡 SUGESTÃO:\n');
    console.log('Se encontrou movimentações de cancelamento duplicadas:');
    console.log('1. Execute o script EXECUTAR_URGENTE_ajustar_estoque.sql');
    console.log('2. Isso vai limpar TODAS as movimentações e reconstruir do zero');
    console.log('3. Apenas pedidos com status=FINALIZADO serão processados');
    console.log('4. Pedidos com movimentações de cancelamento mas status FINALIZADO serão ignorados\n');
}

verificarCancelamentos().catch(console.error);
