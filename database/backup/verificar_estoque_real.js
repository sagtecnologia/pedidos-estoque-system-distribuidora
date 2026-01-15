// =====================================================
// VERIFICAÇÃO DE ESTOQUE REAL
// Calcula: Estoque Inicial + Entradas - Saídas
// =====================================================

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

async function verificarEstoqueReal() {
    console.log('\n╔═══════════════════════════════════════════════════════════╗');
    console.log('║     📊 VERIFICAÇÃO DE ESTOQUE REAL                        ║');
    console.log('║     (Estoque Atual + Entradas - Saídas)                   ║');
    console.log('╚═══════════════════════════════════════════════════════════╝\n');

    try {
        // 1. BUSCAR TODOS OS PRODUTOS ATIVOS
        console.log('🔍 Buscando produtos...\n');
        const { data: produtos, error: errProdutos } = await supabase
            .from('produtos')
            .select('id, codigo, nome, estoque_atual')
            .eq('active', true)
            .order('codigo');

        if (errProdutos) {
            console.error('❌ Erro ao buscar produtos:', errProdutos);
            return;
        }

        console.log(`✅ Encontrados ${produtos.length} produtos ativos\n`);

        // 2. BUSCAR TODAS AS MOVIMENTAÇÕES
        console.log('🔍 Buscando movimentações...\n');
        const { data: movimentacoes, error: errMov } = await supabase
            .from('estoque_movimentacoes')
            .select('produto_id, tipo, quantidade, sabor_id');

        if (errMov) {
            console.error('❌ Erro ao buscar movimentações:', errMov);
            return;
        }

        console.log(`✅ Encontradas ${movimentacoes.length} movimentações\n`);

        // 3. CALCULAR ESTOQUE REAL PARA CADA PRODUTO
        const resultado = [];
        let totalDiferenca = 0;
        let produtosComDiferenca = 0;

        for (const produto of produtos) {
            // Filtrar movimentações do produto (sem considerar sabor específico para total geral)
            const movsEntrada = movimentacoes.filter(
                m => m.produto_id === produto.id && m.tipo === 'ENTRADA'
            );
            
            const movsSaida = movimentacoes.filter(
                m => m.produto_id === produto.id && m.tipo === 'SAIDA'
            );

            // Calcular totais
            const totalEntradas = movsEntrada.reduce((sum, m) => sum + parseFloat(m.quantidade || 0), 0);
            const totalSaidas = movsSaida.reduce((sum, m) => sum + parseFloat(m.quantidade || 0), 0);
            const estoqueCalculado = totalEntradas - totalSaidas;
            const estoqueAtual = parseFloat(produto.estoque_atual || 0);
            const diferenca = estoqueAtual - estoqueCalculado;

            if (Math.abs(diferenca) > 0.01) {
                totalDiferenca += Math.abs(diferenca);
                produtosComDiferenca++;
            }

            resultado.push({
                codigo: produto.codigo,
                nome: produto.nome.substring(0, 30),
                estoque_atual: estoqueAtual.toFixed(2),
                entradas: totalEntradas.toFixed(2),
                saidas: totalSaidas.toFixed(2),
                calculado: estoqueCalculado.toFixed(2),
                diferenca: diferenca.toFixed(2),
                status: Math.abs(diferenca) < 0.01 ? '✅' : '⚠️'
            });
        }

        // 4. EXIBIR RESULTADOS
        console.log('═══════════════════════════════════════════════════════════\n');
        console.log('📋 RESUMO GERAL:\n');
        console.log(`Total de produtos: ${produtos.length}`);
        console.log(`Produtos com diferença: ${produtosComDiferenca}`);
        console.log(`Produtos corretos: ${produtos.length - produtosComDiferenca}`);
        console.log(`\nTotal de movimentações: ${movimentacoes.length}`);
        console.log(`- Entradas: ${movimentacoes.filter(m => m.tipo === 'ENTRADA').length}`);
        console.log(`- Saídas: ${movimentacoes.filter(m => m.tipo === 'SAIDA').length}`);
        console.log('\n═══════════════════════════════════════════════════════════\n');

        // Mostrar produtos com diferença primeiro
        const comDiferenca = resultado.filter(r => Math.abs(parseFloat(r.diferenca)) > 0.01);
        const semDiferenca = resultado.filter(r => Math.abs(parseFloat(r.diferenca)) <= 0.01);

        if (comDiferenca.length > 0) {
            console.log('⚠️  PRODUTOS COM DIFERENÇA:\n');
            console.table(comDiferenca);
        }

        console.log('\n✅ PRODUTOS CORRETOS (primeiros 20):\n');
        console.table(semDiferenca.slice(0, 20));

        // 5. VERIFICAR PRODUTOS COM SABORES
        console.log('\n═══════════════════════════════════════════════════════════\n');
        console.log('🍰 VERIFICANDO PRODUTOS COM SABORES...\n');

        const { data: sabores, error: errSabores } = await supabase
            .from('produto_sabores')
            .select('id, produto_id, sabor, quantidade, produtos(codigo, nome)');

        if (errSabores) {
            console.error('❌ Erro ao buscar sabores:', errSabores);
        } else if (sabores && sabores.length > 0) {
            console.log(`✅ Encontrados ${sabores.length} registros de sabores\n`);

            const resultadoSabores = [];

            for (const sabor of sabores) {
                const movsEntradaSabor = movimentacoes.filter(
                    m => m.produto_id === sabor.produto_id && 
                         m.sabor_id === sabor.id && 
                         m.tipo === 'ENTRADA'
                );
                
                const movsSaidaSabor = movimentacoes.filter(
                    m => m.produto_id === sabor.produto_id && 
                         m.sabor_id === sabor.id && 
                         m.tipo === 'SAIDA'
                );

                const totalEntradasSabor = movsEntradaSabor.reduce((sum, m) => sum + parseFloat(m.quantidade || 0), 0);
                const totalSaidasSabor = movsSaidaSabor.reduce((sum, m) => sum + parseFloat(m.quantidade || 0), 0);
                const estoqueCalculadoSabor = totalEntradasSabor - totalSaidasSabor;
                const estoqueAtualSabor = parseFloat(sabor.quantidade || 0);
                const diferencaSabor = estoqueAtualSabor - estoqueCalculadoSabor;

                resultadoSabores.push({
                    codigo: sabor.produtos.codigo,
                    produto: sabor.produtos.nome.substring(0, 20),
                    sabor: sabor.sabor.substring(0, 15),
                    estoque: estoqueAtualSabor.toFixed(2),
                    entradas: totalEntradasSabor.toFixed(2),
                    saidas: totalSaidasSabor.toFixed(2),
                    calculado: estoqueCalculadoSabor.toFixed(2),
                    diferenca: diferencaSabor.toFixed(2),
                    status: Math.abs(diferencaSabor) < 0.01 ? '✅' : '⚠️'
                });
            }

            const saboresComDif = resultadoSabores.filter(r => Math.abs(parseFloat(r.diferenca)) > 0.01);
            const saboresOk = resultadoSabores.filter(r => Math.abs(parseFloat(r.diferenca)) <= 0.01);

            if (saboresComDif.length > 0) {
                console.log('⚠️  SABORES COM DIFERENÇA:\n');
                console.table(saboresComDif);
            }

            console.log(`\n✅ SABORES CORRETOS: ${saboresOk.length} de ${resultadoSabores.length}\n`);
            if (saboresOk.length > 0) {
                console.table(saboresOk.slice(0, 10));
            }
        }

        console.log('\n═══════════════════════════════════════════════════════════');
        console.log('✨ VERIFICAÇÃO CONCLUÍDA!');
        console.log('═══════════════════════════════════════════════════════════\n');

    } catch (error) {
        console.error('❌ Erro durante verificação:', error);
    }
}

// Executar
verificarEstoqueReal().then(() => {
    console.log('👋 Processo finalizado!');
    process.exit(0);
}).catch(err => {
    console.error('💥 Erro fatal:', err);
    process.exit(1);
});
