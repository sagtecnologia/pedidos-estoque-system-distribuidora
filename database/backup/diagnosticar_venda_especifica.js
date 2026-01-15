// =====================================================
// DIAGNÓSTICO DE VENDA ESPECÍFICA
// Verifica dados de uma venda e seus itens
// =====================================================

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/+esm';

// CONFIGURAÇÃO DO SUPABASE
const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// ⚠️  ALTERE AQUI O NÚMERO DA VENDA QUE DESEJA DIAGNOSTICAR
const VENDA_ID = 'VND202601081155';

console.log('🔍 DIAGNÓSTICO DE VENDA ESPECÍFICA');
console.log('===================================\n');
console.log(`📋 Venda: ${VENDA_ID}\n`);

// 1. Buscar dados da venda
console.log('1️⃣ DADOS DA VENDA:');
console.log('------------------');

const { data: venda, error: vendaError } = await supabase
    .from('pedidos')
    .select(`
        *,
        solicitante:users!pedidos_solicitante_id_fkey(id, full_name, email),
        aprovador:users!pedidos_aprovador_id_fkey(id, full_name, email),
        cliente:clientes(id, nome, cpf_cnpj, whatsapp)
    `)
    .eq('numero', VENDA_ID)
    .single();

if (vendaError) {
    console.error('❌ Erro ao buscar venda:', vendaError);
} else if (!venda) {
    console.log('❌ Venda não encontrada!');
} else {
    console.log('✅ Venda encontrada:');
    console.log('   ID:', venda.id);
    console.log('   Número:', venda.numero);
    console.log('   Tipo:', venda.tipo);
    console.log('   Status:', venda.status);
    console.log('   Total:', venda.total);
    console.log('   Solicitante:', venda.solicitante?.full_name);
    console.log('   Cliente:', venda.cliente?.nome);
    console.log('   Data Criação:', venda.created_at);
    console.log('   Data Atualização:', venda.updated_at);
}

console.log('\n');

// 2. Buscar itens da venda
if (venda) {
    console.log('2️⃣ ITENS DA VENDA:');
    console.log('------------------');

    const { data: itens, error: itensError } = await supabase
        .from('pedido_itens')
        .select(`
            *,
            produto:produtos(id, codigo, nome, unidade, preco),
            sabor:produto_sabores(id, sabor, quantidade)
        `)
        .eq('pedido_id', venda.id)
        .order('created_at');

    if (itensError) {
        console.error('❌ Erro ao buscar itens:', itensError);
    } else {
        console.log(`✅ Total de itens: ${itens.length}\n`);
        
        if (itens.length === 0) {
            console.log('⚠️  NENHUM ITEM ENCONTRADO!');
            console.log('   Este é o problema: a venda existe mas não tem itens associados.\n');
        } else {
            let totalCalculado = 0;
            
            itens.forEach((item, index) => {
                console.log(`   Item ${index + 1}:`);
                console.log(`   - ID: ${item.id}`);
                console.log(`   - Produto: ${item.produto?.nome || 'N/A'}`);
                console.log(`   - Sabor: ${item.sabor?.sabor || 'N/A'}`);
                console.log(`   - Quantidade: ${item.quantidade}`);
                console.log(`   - Preço Unitário: R$ ${item.preco_unitario}`);
                console.log(`   - Subtotal: R$ ${item.subtotal}`);
                console.log('');
                
                totalCalculado += parseFloat(item.subtotal || 0);
            });
            
            console.log('   📊 TOTAIS:');
            console.log(`   - Total da Venda (campo): R$ ${venda.total}`);
            console.log(`   - Total Calculado (soma): R$ ${totalCalculado.toFixed(2)}`);
            
            if (Math.abs(venda.total - totalCalculado) > 0.01) {
                console.log('   ⚠️  DIVERGÊNCIA DETECTADA!');
            } else {
                console.log('   ✅ Totais conferem!');
            }
        }
    }
    
    console.log('\n');
    
    // 3. Verificar RLS (Row Level Security)
    console.log('3️⃣ VERIFICAÇÃO DE PERMISSÕES (RLS):');
    console.log('-----------------------------------');
    
    // Tentar buscar com usuário atual
    const { data: checkVenda } = await supabase
        .from('pedidos')
        .select('id, numero')
        .eq('id', venda.id)
        .single();
    
    const { data: checkItens } = await supabase
        .from('pedido_itens')
        .select('id')
        .eq('pedido_id', venda.id);
    
    console.log(`   Venda acessível: ${checkVenda ? '✅ SIM' : '❌ NÃO'}`);
    console.log(`   Itens acessíveis: ${checkItens ? `✅ SIM (${checkItens.length} itens)` : '❌ NÃO'}`);
    
    if (checkVenda && (!checkItens || checkItens.length === 0) && itens.length > 0) {
        console.log('\n   ⚠️  POSSÍVEL PROBLEMA DE RLS!');
        console.log('   A venda é acessível mas os itens não estão sendo retornados.');
        console.log('   Verifique as políticas RLS da tabela pedido_itens.');
    }
}

console.log('\n');

// 4. Verificar histórico de movimentações
if (venda) {
    console.log('4️⃣ MOVIMENTAÇÕES DE ESTOQUE:');
    console.log('----------------------------');

    const { data: movimentacoes, error: movError } = await supabase
        .from('movimentacoes_estoque')
        .select('*')
        .eq('pedido_id', venda.id)
        .order('created_at');

    if (movError) {
        console.error('❌ Erro ao buscar movimentações:', movError);
    } else {
        console.log(`   Total de movimentações: ${movimentacoes?.length || 0}`);
        
        if (movimentacoes && movimentacoes.length > 0) {
            movimentacoes.forEach((mov, index) => {
                console.log(`\n   Movimentação ${index + 1}:`);
                console.log(`   - Tipo: ${mov.tipo}`);
                console.log(`   - Produto/Sabor: ${mov.produto_id} / ${mov.sabor_id || 'N/A'}`);
                console.log(`   - Quantidade: ${mov.quantidade}`);
                console.log(`   - Data: ${mov.created_at}`);
            });
        }
    }
}

console.log('\n');
console.log('═══════════════════════════════════');
console.log('📝 RESUMO DO DIAGNÓSTICO');
console.log('═══════════════════════════════════');

if (!venda) {
    console.log('❌ Venda não encontrada no banco de dados');
} else if (itens && itens.length === 0) {
    console.log('⚠️  PROBLEMA IDENTIFICADO:');
    console.log('   - Venda existe no banco de dados');
    console.log('   - Mas NÃO possui itens associados');
    console.log('   - Isso explica por que não aparece nada nos detalhes\n');
    console.log('💡 POSSÍVEIS CAUSAS:');
    console.log('   1. Itens foram deletados acidentalmente');
    console.log('   2. Problema durante a criação da venda');
    console.log('   3. Política RLS bloqueando acesso aos itens');
    console.log('   4. Venda criada mas itens nunca foram adicionados\n');
    console.log('🔧 AÇÕES SUGERIDAS:');
    console.log('   1. Verificar se há itens deletados (usar histórico se disponível)');
    console.log('   2. Verificar políticas RLS da tabela pedido_itens');
    console.log('   3. Se necessário, recriar os itens da venda');
} else {
    console.log('✅ Venda e itens encontrados e acessíveis');
    console.log('   O problema pode estar no frontend ou cache do navegador');
}

console.log('\n✅ Diagnóstico concluído!');
