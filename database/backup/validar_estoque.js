/**
 * SCRIPT DE VARREDURA E VALIDAÇÃO DE ESTOQUE
 * 
 * Este script analisa o estoque do sistema e identifica inconsistências:
 * - Produtos com estoque negativo
 * - Movimentações duplicadas
 * - Pedidos finalizados sem movimentação
 * - Movimentações sem pedido correspondente
 * - Sabores com estoque incorreto
 * 
 * Execute com: node database/validar_estoque.js
 */

const { createClient } = require('@supabase/supabase-js');

const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Cores para o console
const colors = {
    reset: '\x1b[0m',
    bright: '\x1b[1m',
    red: '\x1b[31m',
    green: '\x1b[32m',
    yellow: '\x1b[33m',
    blue: '\x1b[34m',
    magenta: '\x1b[35m',
    cyan: '\x1b[36m'
};

function log(message, color = 'reset') {
    console.log(`${colors[color]}${message}${colors.reset}`);
}

function separator() {
    console.log('='.repeat(80));
}

async function validarEstoque() {
    try {
        log('\n🔍 INICIANDO VARREDURA DE VALIDAÇÃO DE ESTOQUE', 'bright');
        log(`⏰ Data/Hora: ${new Date().toLocaleString('pt-BR')}`, 'cyan');
        separator();

        const problemas = {
            produtosNegativos: [],
            saboresNegativos: [],
            pedidosFinalizadosSemMovimentacao: [],
            movimentacoesDuplicadas: [],
            movimentacoesSemPedido: [],
            pedidosSemItens: [],
            discrepanciasCalculadas: []
        };

        // 1. VALIDAR PRODUTOS COM ESTOQUE NEGATIVO
        log('\n📦 1. Verificando produtos com estoque negativo...', 'yellow');
        const { data: produtosNegativos } = await supabase
            .from('produtos')
            .select('id, codigo, nome, estoque_atual, unidade')
            .lt('estoque_atual', 0);

        if (produtosNegativos && produtosNegativos.length > 0) {
            problemas.produtosNegativos = produtosNegativos;
            log(`   ❌ Encontrados ${produtosNegativos.length} produtos com estoque NEGATIVO:`, 'red');
            produtosNegativos.forEach(p => {
                log(`      • ${p.codigo} - ${p.nome}: ${p.estoque_atual} ${p.unidade}`, 'red');
            });
        } else {
            log('   ✅ Nenhum produto com estoque negativo', 'green');
        }

        // 2. VALIDAR SABORES COM ESTOQUE NEGATIVO
        log('\n🎨 2. Verificando sabores com estoque negativo...', 'yellow');
        const { data: saboresNegativos } = await supabase
            .from('produto_sabores')
            .select('id, sabor, quantidade, produto:produtos(codigo, nome)')
            .lt('quantidade', 0);

        if (saboresNegativos && saboresNegativos.length > 0) {
            problemas.saboresNegativos = saboresNegativos;
            log(`   ❌ Encontrados ${saboresNegativos.length} sabores com estoque NEGATIVO:`, 'red');
            saboresNegativos.forEach(s => {
                log(`      • ${s.produto.codigo} - Sabor: ${s.sabor}: ${s.quantidade} unidades`, 'red');
            });
        } else {
            log('   ✅ Nenhum sabor com estoque negativo', 'green');
        }

        // 3. VALIDAR PEDIDOS FINALIZADOS SEM MOVIMENTAÇÃO
        log('\n📋 3. Verificando pedidos finalizados sem movimentação de estoque...', 'yellow');
        const { data: pedidosFinalizados } = await supabase
            .from('pedidos')
            .select('id, numero, status, tipo_pedido, total, data_finalizacao')
            .eq('status', 'FINALIZADO')
            .not('data_finalizacao', 'is', null);

        if (pedidosFinalizados) {
            for (const pedido of pedidosFinalizados) {
                const { data: movimentacoes } = await supabase
                    .from('estoque_movimentacoes')
                    .select('id')
                    .eq('pedido_id', pedido.id);

                if (!movimentacoes || movimentacoes.length === 0) {
                    problemas.pedidosFinalizadosSemMovimentacao.push(pedido);
                }
            }

            if (problemas.pedidosFinalizadosSemMovimentacao.length > 0) {
                log(`   ❌ Encontrados ${problemas.pedidosFinalizadosSemMovimentacao.length} pedidos finalizados SEM MOVIMENTAÇÃO:`, 'red');
                problemas.pedidosFinalizadosSemMovimentacao.forEach(p => {
                    log(`      • ${p.numero} - Tipo: ${p.tipo_pedido} - Total: R$ ${p.total}`, 'red');
                    log(`        Finalizado em: ${new Date(p.data_finalizacao).toLocaleString('pt-BR')}`, 'red');
                });
            } else {
                log('   ✅ Todos os pedidos finalizados têm movimentação', 'green');
            }
        }

        // 4. DETECTAR MOVIMENTAÇÕES DUPLICADAS (mesmo pedido, produto, quantidade e data)
        log('\n🔄 4. Detectando movimentações duplicadas...', 'yellow');
        const { data: todasMovimentacoes } = await supabase
            .from('estoque_movimentacoes')
            .select('id, pedido_id, produto_id, quantidade, tipo, created_at, pedido:pedidos(numero)')
            .order('created_at', { ascending: false });

        if (todasMovimentacoes) {
            const movimentacoesMap = new Map();
            
            todasMovimentacoes.forEach(mov => {
                if (!mov.pedido_id) return;
                
                const key = `${mov.pedido_id}_${mov.produto_id}_${mov.quantidade}_${mov.tipo}`;
                
                if (!movimentacoesMap.has(key)) {
                    movimentacoesMap.set(key, []);
                }
                movimentacoesMap.get(key).push(mov);
            });

            movimentacoesMap.forEach((movs, key) => {
                if (movs.length > 1) {
                    // Verificar se foram criadas em horários muito próximos (menos de 5 segundos)
                    for (let i = 0; i < movs.length - 1; i++) {
                        const date1 = new Date(movs[i].created_at).getTime();
                        const date2 = new Date(movs[i + 1].created_at).getTime();
                        const diff = Math.abs(date1 - date2);
                        
                        if (diff < 5000) { // Menos de 5 segundos
                            problemas.movimentacoesDuplicadas.push({
                                pedido: movs[0].pedido?.numero,
                                movimentacoes: movs,
                                diferencaTempo: diff
                            });
                            break;
                        }
                    }
                }
            });

            if (problemas.movimentacoesDuplicadas.length > 0) {
                log(`   ❌ Encontradas ${problemas.movimentacoesDuplicadas.length} possíveis DUPLICAÇÕES:`, 'red');
                problemas.movimentacoesDuplicadas.forEach(d => {
                    log(`      • Pedido ${d.pedido} - ${d.movimentacoes.length} movimentações idênticas`, 'red');
                    log(`        Diferença de tempo: ${d.diferencaTempo}ms`, 'red');
                });
            } else {
                log('   ✅ Nenhuma movimentação duplicada detectada', 'green');
            }
        }

        // 5. MOVIMENTAÇÕES SEM PEDIDO
        log('\n🔍 5. Verificando movimentações sem pedido associado...', 'yellow');
        const { data: movsSemPedido } = await supabase
            .from('estoque_movimentacoes')
            .select('id, produto_id, quantidade, tipo, created_at, produto:produtos(codigo, nome)')
            .is('pedido_id', null);

        if (movsSemPedido && movsSemPedido.length > 0) {
            problemas.movimentacoesSemPedido = movsSemPedido;
            log(`   ⚠️  Encontradas ${movsSemPedido.length} movimentações SEM PEDIDO (ajustes manuais):`, 'yellow');
            movsSemPedido.slice(0, 5).forEach(m => {
                log(`      • ${m.produto.codigo} - ${m.tipo}: ${m.quantidade} (${new Date(m.created_at).toLocaleString('pt-BR')})`, 'yellow');
            });
            if (movsSemPedido.length > 5) {
                log(`      ... e mais ${movsSemPedido.length - 5} movimentações`, 'yellow');
            }
        } else {
            log('   ✅ Todas as movimentações têm pedido associado', 'green');
        }

        // 6. PEDIDOS SEM ITENS
        log('\n📦 6. Verificando pedidos sem itens...', 'yellow');
        const { data: todosPedidos } = await supabase
            .from('pedidos')
            .select('id, numero, status');

        if (todosPedidos) {
            for (const pedido of todosPedidos) {
                const { data: itens } = await supabase
                    .from('pedido_itens')
                    .select('id')
                    .eq('pedido_id', pedido.id);

                if (!itens || itens.length === 0) {
                    problemas.pedidosSemItens.push(pedido);
                }
            }

            if (problemas.pedidosSemItens.length > 0) {
                log(`   ⚠️  Encontrados ${problemas.pedidosSemItens.length} pedidos SEM ITENS:`, 'yellow');
                problemas.pedidosSemItens.forEach(p => {
                    log(`      • ${p.numero} - Status: ${p.status}`, 'yellow');
                });
            } else {
                log('   ✅ Todos os pedidos têm itens', 'green');
            }
        }

        // 7. VERIFICAR DISCREPÂNCIAS ENTRE ESTOQUE CALCULADO E REGISTRADO
        log('\n🧮 7. Verificando discrepâncias entre estoque calculado e registrado...', 'yellow');
        const { data: todosProdutos } = await supabase
            .from('produtos')
            .select('id, codigo, nome, estoque_inicial, estoque_atual, unidade');

        if (todosProdutos) {
            for (const produto of todosProdutos) {
                // Calcular estoque baseado nas movimentações
                const { data: movimentacoesProduto } = await supabase
                    .from('estoque_movimentacoes')
                    .select('quantidade, tipo')
                    .eq('produto_id', produto.id);

                if (movimentacoesProduto) {
                    let estoqueCalculado = produto.estoque_inicial || 0;
                    
                    movimentacoesProduto.forEach(mov => {
                        if (mov.tipo === 'ENTRADA') {
                            estoqueCalculado += mov.quantidade;
                        } else if (mov.tipo === 'SAIDA') {
                            estoqueCalculado -= mov.quantidade;
                        }
                    });

                    const diferenca = Math.abs(estoqueCalculado - produto.estoque_atual);
                    
                    // Considerar discrepância se a diferença for maior que 0.01
                    if (diferenca > 0.01) {
                        problemas.discrepanciasCalculadas.push({
                            produto,
                            estoqueCalculado,
                            estoqueRegistrado: produto.estoque_atual,
                            diferenca
                        });
                    }
                }
            }

            if (problemas.discrepanciasCalculadas.length > 0) {
                log(`   ❌ Encontradas ${problemas.discrepanciasCalculadas.length} DISCREPÂNCIAS de estoque:`, 'red');
                problemas.discrepanciasCalculadas.forEach(d => {
                    log(`      • ${d.produto.codigo} - ${d.produto.nome}`, 'red');
                    log(`        Registrado: ${d.estoqueRegistrado} ${d.produto.unidade}`, 'red');
                    log(`        Calculado: ${d.estoqueCalculado.toFixed(2)} ${d.produto.unidade}`, 'red');
                    log(`        Diferença: ${d.diferenca.toFixed(2)} ${d.produto.unidade}`, 'red');
                });
            } else {
                log('   ✅ Todos os estoques estão consistentes', 'green');
            }
        }

        // RESUMO FINAL
        separator();
        log('\n📊 RESUMO DA VALIDAÇÃO', 'bright');
        separator();
        
        const totalProblemas = 
            problemas.produtosNegativos.length +
            problemas.saboresNegativos.length +
            problemas.pedidosFinalizadosSemMovimentacao.length +
            problemas.movimentacoesDuplicadas.length +
            problemas.discrepanciasCalculadas.length;

        const totalAvisos = 
            problemas.movimentacoesSemPedido.length +
            problemas.pedidosSemItens.length;

        log(`\n❌ PROBLEMAS CRÍTICOS: ${totalProblemas}`, totalProblemas > 0 ? 'red' : 'green');
        log(`   • Produtos com estoque negativo: ${problemas.produtosNegativos.length}`, 'red');
        log(`   • Sabores com estoque negativo: ${problemas.saboresNegativos.length}`, 'red');
        log(`   • Pedidos finalizados sem movimentação: ${problemas.pedidosFinalizadosSemMovimentacao.length}`, 'red');
        log(`   • Movimentações duplicadas: ${problemas.movimentacoesDuplicadas.length}`, 'red');
        log(`   • Discrepâncias de estoque: ${problemas.discrepanciasCalculadas.length}`, 'red');

        log(`\n⚠️  AVISOS: ${totalAvisos}`, totalAvisos > 0 ? 'yellow' : 'green');
        log(`   • Movimentações sem pedido: ${problemas.movimentacoesSemPedido.length}`, 'yellow');
        log(`   • Pedidos sem itens: ${problemas.pedidosSemItens.length}`, 'yellow');

        separator();

        if (totalProblemas === 0 && totalAvisos === 0) {
            log('\n✅ ESTOQUE VALIDADO COM SUCESSO!', 'green');
            log('   Não foram encontrados problemas ou inconsistências.', 'green');
        } else {
            log('\n⚠️  VALIDAÇÃO CONCLUÍDA COM PROBLEMAS', 'yellow');
            log('   Execute o script de correção para resolver as inconsistências.', 'yellow');
            log('   Comando: node database/corrigir_inconsistencias_estoque.js', 'cyan');
        }

        separator();

        return problemas;

    } catch (error) {
        log('\n❌ ERRO AO VALIDAR ESTOQUE:', 'red');
        console.error(error);
        throw error;
    }
}

// Executar se for chamado diretamente
if (require.main === module) {
    validarEstoque()
        .then(() => {
            log('\n✅ Script concluído', 'green');
            process.exit(0);
        })
        .catch(error => {
            log('\n❌ Erro fatal:', 'red');
            console.error(error);
            process.exit(1);
        });
}

module.exports = { validarEstoque };
