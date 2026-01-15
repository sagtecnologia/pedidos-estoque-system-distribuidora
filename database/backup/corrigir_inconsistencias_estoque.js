/**
 * SCRIPT DE CORREÇÃO DE INCONSISTÊNCIAS DE ESTOQUE
 * 
 * Este script corrige automaticamente problemas identificados pela validação:
 * - Recalcula estoques baseado em movimentações
 * - Remove movimentações duplicadas
 * - Corrige sabores com estoque negativo
 * 
 * ⚠️  ATENÇÃO: Este script modifica dados! Faça backup antes de executar.
 * 
 * Execute com: node database/corrigir_inconsistencias_estoque.js
 */

const { createClient } = require('@supabase/supabase-js');
const { validarEstoque } = require('./validar_estoque.js');

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

async function confirmarExecucao() {
    const readline = require('readline').createInterface({
        input: process.stdin,
        output: process.stdout
    });

    return new Promise((resolve) => {
        readline.question('\n⚠️  Este script irá MODIFICAR dados do banco. Deseja continuar? (S/N): ', (answer) => {
            readline.close();
            resolve(answer.toUpperCase() === 'S' || answer.toUpperCase() === 'SIM');
        });
    });
}

async function corrigirInconsistencias() {
    try {
        log('\n🔧 INICIANDO CORREÇÃO DE INCONSISTÊNCIAS DE ESTOQUE', 'bright');
        log(`⏰ Data/Hora: ${new Date().toLocaleString('pt-BR')}`, 'cyan');
        separator();

        // Primeiro, executar validação para identificar problemas
        log('\n🔍 Executando validação prévia...', 'yellow');
        const problemas = await validarEstoque();

        const totalProblemas = 
            problemas.produtosNegativos.length +
            problemas.saboresNegativos.length +
            problemas.pedidosFinalizadosSemMovimentacao.length +
            problemas.movimentacoesDuplicadas.length +
            problemas.discrepanciasCalculadas.length;

        if (totalProblemas === 0) {
            log('\n✅ Nenhum problema para corrigir!', 'green');
            return;
        }

        // Pedir confirmação
        const confirmado = await confirmarExecucao();
        if (!confirmado) {
            log('\n❌ Operação cancelada pelo usuário', 'yellow');
            return;
        }

        separator();
        log('\n🔧 INICIANDO CORREÇÕES...', 'bright');
        
        const correcoes = {
            duplicadasRemovidas: 0,
            estoquesRecalculados: 0,
            saboresCorrigidos: 0,
            erros: []
        };

        // 1. REMOVER MOVIMENTAÇÕES DUPLICADAS
        if (problemas.movimentacoesDuplicadas.length > 0) {
            log('\n🗑️  1. Removendo movimentações duplicadas...', 'yellow');
            
            for (const dup of problemas.movimentacoesDuplicadas) {
                try {
                    // Manter apenas a primeira movimentação, remover as demais
                    const movsOrdenadas = dup.movimentacoes.sort((a, b) => 
                        new Date(a.created_at) - new Date(b.created_at)
                    );
                    
                    // Remover todas exceto a primeira
                    for (let i = 1; i < movsOrdenadas.length; i++) {
                        const { error } = await supabase
                            .from('estoque_movimentacoes')
                            .delete()
                            .eq('id', movsOrdenadas[i].id);

                        if (error) throw error;
                        
                        correcoes.duplicadasRemovidas++;
                        log(`   ✅ Removida movimentação duplicada ID ${movsOrdenadas[i].id}`, 'green');
                    }
                } catch (error) {
                    log(`   ❌ Erro ao remover duplicata: ${error.message}`, 'red');
                    correcoes.erros.push({ tipo: 'remover_duplicata', erro: error.message });
                }
            }
            
            log(`   ✅ Total de movimentações duplicadas removidas: ${correcoes.duplicadasRemovidas}`, 'green');
        }

        // 2. RECALCULAR ESTOQUES COM DISCREPÂNCIA
        if (problemas.discrepanciasCalculadas.length > 0) {
            log('\n🧮 2. Recalculando estoques com discrepância...', 'yellow');
            
            for (const disc of problemas.discrepanciasCalculadas) {
                try {
                    const { error } = await supabase
                        .from('produtos')
                        .update({ estoque_atual: disc.estoqueCalculado })
                        .eq('id', disc.produto.id);

                    if (error) throw error;
                    
                    correcoes.estoquesRecalculados++;
                    log(`   ✅ ${disc.produto.codigo}: ${disc.estoqueRegistrado} → ${disc.estoqueCalculado.toFixed(2)} ${disc.produto.unidade}`, 'green');
                } catch (error) {
                    log(`   ❌ Erro ao recalcular ${disc.produto.codigo}: ${error.message}`, 'red');
                    correcoes.erros.push({ tipo: 'recalcular_estoque', produto: disc.produto.codigo, erro: error.message });
                }
            }
            
            log(`   ✅ Total de estoques recalculados: ${correcoes.estoquesRecalculados}`, 'green');
        }

        // 3. CORRIGIR SABORES COM ESTOQUE NEGATIVO
        if (problemas.saboresNegativos.length > 0) {
            log('\n🎨 3. Corrigindo sabores com estoque negativo...', 'yellow');
            
            for (const sabor of problemas.saboresNegativos) {
                try {
                    // Para sabores negativos, podemos:
                    // 1. Zerar o estoque (opção conservadora)
                    // 2. Recalcular baseado em movimentações
                    
                    // Vamos usar a opção conservadora: zerar
                    const { error } = await supabase
                        .from('produto_sabores')
                        .update({ quantidade: 0 })
                        .eq('id', sabor.id);

                    if (error) throw error;
                    
                    correcoes.saboresCorrigidos++;
                    log(`   ✅ ${sabor.produto.codigo} - Sabor ${sabor.sabor}: ${sabor.quantidade} → 0`, 'green');
                } catch (error) {
                    log(`   ❌ Erro ao corrigir sabor: ${error.message}`, 'red');
                    correcoes.erros.push({ tipo: 'corrigir_sabor', erro: error.message });
                }
            }
            
            log(`   ✅ Total de sabores corrigidos: ${correcoes.saboresCorrigidos}`, 'green');
        }

        // 4. AVISOS SOBRE PROBLEMAS QUE REQUEREM ATENÇÃO MANUAL
        if (problemas.pedidosFinalizadosSemMovimentacao.length > 0) {
            log('\n⚠️  4. Pedidos finalizados sem movimentação (REQUER ATENÇÃO MANUAL):', 'yellow');
            log('   Estes pedidos foram marcados como finalizados mas não geraram movimentação.', 'yellow');
            log('   Ação recomendada: Verificar manualmente e reprocessar se necessário.', 'yellow');
            
            problemas.pedidosFinalizadosSemMovimentacao.forEach(p => {
                log(`   • ${p.numero} - Finalizado em ${new Date(p.data_finalizacao).toLocaleString('pt-BR')}`, 'yellow');
            });
        }

        // RESUMO FINAL
        separator();
        log('\n📊 RESUMO DAS CORREÇÕES', 'bright');
        separator();
        
        log(`\n✅ CORREÇÕES REALIZADAS:`, 'green');
        log(`   • Movimentações duplicadas removidas: ${correcoes.duplicadasRemovidas}`, 'green');
        log(`   • Estoques recalculados: ${correcoes.estoquesRecalculados}`, 'green');
        log(`   • Sabores corrigidos: ${correcoes.saboresCorrigidos}`, 'green');

        if (correcoes.erros.length > 0) {
            log(`\n❌ ERROS ENCONTRADOS: ${correcoes.erros.length}`, 'red');
            correcoes.erros.forEach(erro => {
                log(`   • ${erro.tipo}: ${erro.erro}`, 'red');
            });
        }

        separator();

        // Executar validação novamente para confirmar correções
        log('\n🔍 Executando validação pós-correção...', 'yellow');
        const problemasPos = await validarEstoque();

        const totalProblemasPos = 
            problemasPos.produtosNegativos.length +
            problemasPos.saboresNegativos.length +
            problemasPos.pedidosFinalizadosSemMovimentacao.length +
            problemasPos.movimentacoesDuplicadas.length +
            problemasPos.discrepanciasCalculadas.length;

        if (totalProblemasPos === 0) {
            log('\n✅ CORREÇÃO BEM-SUCEDIDA! Estoque validado com sucesso.', 'green');
        } else {
            log(`\n⚠️  Ainda existem ${totalProblemasPos} problemas que requerem atenção.`, 'yellow');
            log('   Execute o script de validação para mais detalhes.', 'yellow');
        }

        separator();

    } catch (error) {
        log('\n❌ ERRO AO CORRIGIR INCONSISTÊNCIAS:', 'red');
        console.error(error);
        throw error;
    }
}

// Executar se for chamado diretamente
if (require.main === module) {
    corrigirInconsistencias()
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

module.exports = { corrigirInconsistencias };
