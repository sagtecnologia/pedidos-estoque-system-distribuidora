const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function reconstruirSabores() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║  🔧 RECONSTRUINDO SABORES A PARTIR DAS MOVIMENTAÇÕES     ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    // 1. Buscar todos os produtos
    const { data: produtos } = await supabase
        .from('produtos')
        .select('id, codigo, nome, estoque_atual')
        .eq('active', true);

    console.log(`📦 ${produtos?.length || 0} produtos ativos encontrados\n`);

    // 2. Para cada produto, calcular estoque das movimentações
    const estoquePorProduto = {};
    
    for (const produto of produtos || []) {
        const { data: movs } = await supabase
            .from('estoque_movimentacoes')
            .select('tipo, quantidade')
            .eq('produto_id', produto.id);

        const entrada = movs?.filter(m => m.tipo === 'ENTRADA').reduce((sum, m) => sum + m.quantidade, 0) || 0;
        const saida = movs?.filter(m => m.tipo === 'SAIDA').reduce((sum, m) => sum + m.quantidade, 0) || 0;
        const estoque = entrada - saida;

        estoquePorProduto[produto.id] = {
            codigo: produto.codigo,
            nome: produto.nome,
            estoque_atual: produto.estoque_atual,
            estoque_calculado: estoque,
            entrada,
            saida
        };

        console.log(`${produto.codigo}: Atual=${produto.estoque_atual} | Calculado=${estoque} (E:${entrada} - S:${saida})`);
    }

    // 3. Buscar sabores existentes ou criar baseado em padrão
    console.log('\n\n🍰 VERIFICANDO SABORES...\n');

    let saboresRecriados = 0;
    let erros = 0;

    for (const produto of produtos || []) {
        const estoque = estoquePorProduto[produto.id];
        
        if (estoque.estoque_atual === 0) {
            console.log(`⏭️  ${estoque.codigo}: Estoque zero, pulando`);
            continue;
        }

        // Buscar sabores existentes
        let { data: saboresExistentes } = await supabase
            .from('produto_sabores')
            .select('*')
            .eq('produto_id', produto.id)
            .eq('ativo', true);

        // Se não existir, criar um sabor padrão
        if (!saboresExistentes || saboresExistentes.length === 0) {
            console.log(`➕ ${estoque.codigo}: Criando sabor padrão MIX`);
            
            const { data: novoSabor, error } = await supabase
                .from('produto_sabores')
                .insert({
                    produto_id: produto.id,
                    sabor: 'MIX',
                    quantidade: estoque.estoque_atual,
                    ativo: true
                })
                .select();

            if (error) {
                console.log(`   ❌ Erro ao criar: ${error.message}`);
                erros++;
            } else {
                console.log(`   ✅ Sabor criado com ${estoque.estoque_atual} unidades`);
                saboresRecriados++;
            }
        } else {
            // Distribuir estoque entre sabores existentes
            const totalSabores = saboresExistentes.length;
            const quantidadePorSabor = estoque.estoque_atual / totalSabores;

            console.log(`📊 ${estoque.codigo}: Distribuindo ${estoque.estoque_atual} entre ${totalSabores} sabores`);

            for (const sabor of saboresExistentes) {
                const { error } = await supabase
                    .from('produto_sabores')
                    .update({ quantidade: quantidadePorSabor })
                    .eq('id', sabor.id);

                if (error) {
                    console.log(`   ❌ Erro ao atualizar ${sabor.sabor}: ${error.message}`);
                    erros++;
                } else {
                    console.log(`   ✅ ${sabor.sabor}: ${quantidadePorSabor} unidades`);
                    saboresRecriados++;
                }
            }
        }
    }

    // 4. Verificar resultado
    console.log('\n\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║  📊 RESULTADO                                             ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    const { data: saboresFinais } = await supabase
        .from('produto_sabores')
        .select('*, produtos(codigo, nome, preco_compra, preco_venda)');

    const valorCompra = saboresFinais?.reduce((sum, s) => 
        sum + (s.quantidade * (s.produtos?.preco_compra || 0)), 0) || 0;
    
    const valorVenda = saboresFinais?.reduce((sum, s) => 
        sum + (s.quantidade * (s.produtos?.preco_venda || 0)), 0) || 0;

    console.log(`✅ Sabores processados: ${saboresRecriados}`);
    console.log(`❌ Erros: ${erros}`);
    console.log(`\n💰 Valor Total Compra: R$ ${valorCompra.toFixed(2)}`);
    console.log(`💰 Valor Total Venda: R$ ${valorVenda.toFixed(2)}`);
    console.log(`\n🍰 Total de sabores: ${saboresFinais?.length || 0}`);
}

reconstruirSabores().catch(console.error);
