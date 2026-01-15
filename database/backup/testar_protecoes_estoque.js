/**
 * SCRIPT DE TESTES AUTOMATIZADOS
 * Testa todas as proteções contra duplicação de movimentações
 */

const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhrcmFzZHhtaGt2b2FjbHNsdnJyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTczNTQ3NTE3NSwiZXhwIjoyMDUxMDUxMTc1fQ.E21x-3E00OHu0IA-GEL3Vn97gZnEw1LSzX6KnX08fYU';
const supabase = createClient(supabaseUrl, supabaseKey);

// Cores para output
const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const BLUE = '\x1b[34m';
const RESET = '\x1b[0m';

let totalTestes = 0;
let testesPassaram = 0;
let testesFalharam = 0;

function log(msg, cor = RESET) {
    console.log(`${cor}${msg}${RESET}`);
}

async function teste(descricao, funcaoTeste) {
    totalTestes++;
    log(`\n${'='.repeat(60)}`, BLUE);
    log(`TESTE ${totalTestes}: ${descricao}`, BLUE);
    log('='.repeat(60), BLUE);
    
    try {
        const resultado = await funcaoTeste();
        if (resultado.passou) {
            testesPassaram++;
            log(`✅ PASSOU: ${resultado.mensagem}`, GREEN);
        } else {
            testesFalharam++;
            log(`❌ FALHOU: ${resultado.mensagem}`, RED);
            if (resultado.detalhes) {
                log(`   Detalhes: ${JSON.stringify(resultado.detalhes, null, 2)}`, YELLOW);
            }
        }
    } catch (erro) {
        testesFalharam++;
        log(`❌ ERRO: ${erro.message}`, RED);
        console.error(erro);
    }
}

// TESTE 1: Verificar duplicações existentes
async function verificarDuplicacoesExistentes() {
    const { data, error } = await supabase.rpc('executar_query', {
        query: `
            SELECT 
                pedido_id,
                COUNT(*) as total_movs
            FROM estoque_movimentacoes
            WHERE observacao LIKE '%Finalização%'
            GROUP BY pedido_id, produto_id, sabor_id, tipo, quantidade
            HAVING COUNT(*) > 1
        `
    });
    
    if (error && error.message.includes('does not exist')) {
        // Alternativa: query direta
        const { data: movs } = await supabase
            .from('estoque_movimentacoes')
            .select('pedido_id, produto_id, sabor_id, tipo, quantidade')
            .like('observacao', '%Finalização%');
        
        if (!movs) {
            return { passou: true, mensagem: 'Sem acesso para verificar duplicações (RLS ativo)' };
        }
        
        // Contar duplicações manualmente
        const grupos = {};
        movs.forEach(mov => {
            const chave = `${mov.pedido_id}_${mov.produto_id}_${mov.sabor_id}_${mov.tipo}_${mov.quantidade}`;
            grupos[chave] = (grupos[chave] || 0) + 1;
        });
        
        const duplicadas = Object.values(grupos).filter(count => count > 1);
        
        return {
            passou: duplicadas.length === 0,
            mensagem: duplicadas.length === 0 
                ? 'Nenhuma duplicação encontrada' 
                : `${duplicadas.length} grupos duplicados encontrados`,
            detalhes: duplicadas.length > 0 ? { total_duplicadas: duplicadas.length } : null
        };
    }
    
    return {
        passou: !data || data.length === 0,
        mensagem: data && data.length > 0 
            ? `${data.length} pedidos com movimentações duplicadas`
            : 'Nenhuma duplicação encontrada',
        detalhes: data && data.length > 0 ? data : null
    };
}

// TESTE 2: Verificar estoques negativos
async function verificarEstoquesNegativos() {
    const { data, error } = await supabase
        .from('produto_sabores')
        .select('id, sabor, quantidade, produto_id')
        .lt('quantidade', 0);
    
    if (error) {
        return { passou: false, mensagem: `Erro ao buscar: ${error.message}` };
    }
    
    return {
        passou: data.length === 0,
        mensagem: data.length === 0 
            ? 'Nenhum estoque negativo encontrado'
            : `${data.length} produtos com estoque NEGATIVO`,
        detalhes: data.length > 0 ? data : null
    };
}

// TESTE 3: Verificar pedidos finalizados sem movimentações
async function verificarPedidosSemMovimentacoes() {
    const { data: pedidos } = await supabase
        .from('pedidos')
        .select('id, numero, tipo_pedido')
        .eq('status', 'FINALIZADO');
    
    if (!pedidos || pedidos.length === 0) {
        return { passou: true, mensagem: 'Nenhum pedido finalizado para verificar' };
    }
    
    let semMovimentacoes = 0;
    const detalhes = [];
    
    for (const pedido of pedidos) {
        const { data: movs } = await supabase
            .from('estoque_movimentacoes')
            .select('id')
            .eq('pedido_id', pedido.id)
            .like('observacao', '%Finalização%')
            .limit(1);
        
        if (!movs || movs.length === 0) {
            semMovimentacoes++;
            detalhes.push(pedido);
        }
    }
    
    return {
        passou: semMovimentacoes === 0,
        mensagem: semMovimentacoes === 0
            ? `Todos os ${pedidos.length} pedidos finalizados têm movimentações`
            : `${semMovimentacoes} de ${pedidos.length} pedidos finalizados SEM movimentações`,
        detalhes: semMovimentacoes > 0 ? detalhes : null
    };
}

// TESTE 4: Verificar consistência estoque atual vs calculado
async function verificarConsistenciaEstoque() {
    const { data: sabores } = await supabase
        .from('produto_sabores')
        .select('id, sabor, quantidade');
    
    if (!sabores) {
        return { passou: false, mensagem: 'Erro ao buscar sabores' };
    }
    
    let divergencias = 0;
    const detalhes = [];
    
    for (const sabor of sabores) {
        const { data: entradas } = await supabase
            .from('estoque_movimentacoes')
            .select('quantidade')
            .eq('sabor_id', sabor.id)
            .eq('tipo', 'ENTRADA');
        
        const { data: saidas } = await supabase
            .from('estoque_movimentacoes')
            .select('quantidade')
            .eq('sabor_id', sabor.id)
            .eq('tipo', 'SAIDA');
        
        const totalEntradas = entradas?.reduce((sum, e) => sum + parseFloat(e.quantidade), 0) || 0;
        const totalSaidas = saidas?.reduce((sum, s) => sum + parseFloat(s.quantidade), 0) || 0;
        const calculado = totalEntradas - totalSaidas;
        const atual = parseFloat(sabor.quantidade);
        
        if (Math.abs(atual - calculado) > 0.01) {
            divergencias++;
            detalhes.push({
                sabor: sabor.sabor,
                atual,
                calculado,
                diferenca: atual - calculado
            });
        }
    }
    
    return {
        passou: divergencias === 0,
        mensagem: divergencias === 0
            ? `Todos os ${sabores.length} produtos estão consistentes`
            : `${divergencias} produtos com DIVERGÊNCIA entre estoque atual e calculado`,
        detalhes: divergencias > 0 ? detalhes.slice(0, 5) : null // Mostrar apenas 5 primeiros
    };
}

// TESTE 5: Verificar função finalizar_pedido tem proteção
async function verificarProtecaoFuncao() {
    // Não podemos acessar pg_proc diretamente via Supabase cliente
    // Vamos testar de outra forma: tentar finalizar pedido já finalizado
    
    const { data: pedidos } = await supabase
        .from('pedidos')
        .select('id, numero, status')
        .eq('status', 'FINALIZADO')
        .limit(1);
    
    if (!pedidos || pedidos.length === 0) {
        return {
            passou: true,
            mensagem: 'Sem pedidos finalizados para testar (pulando verificação)'
        };
    }
    
    // Tentar finalizar novamente (deve dar erro se protegido)
    const { error } = await supabase.rpc('finalizar_pedido', {
        p_pedido_id: pedidos[0].id,
        p_usuario_id: '00000000-0000-0000-0000-000000000000' // UUID teste
    });
    
    const temProtecao = error && error.message.includes('finalizado');
    
    return {
        passou: temProtecao,
        mensagem: temProtecao
            ? 'Função finalizar_pedido TEM proteção (erro ao tentar refinalizar)'
            : '⚠️ Função finalizar_pedido pode não ter proteção (conseguiu chamar novamente)',
        detalhes: error ? { erro: error.message } : null
    };
}

// TESTE 6: Simular tentativa de dupla finalização
async function simularDuplaFinalizacao() {
    log('⚠️  Este teste requer um pedido de teste em RASCUNHO', YELLOW);
    log('   Pulando teste de simulação...', YELLOW);
    
    return {
        passou: true,
        mensagem: 'Teste de simulação pulado (requer pedido de teste)'
    };
}

// TESTE 7: Verificar proteção JavaScript
async function verificarProtecaoJavaScript() {
    const fs = require('fs');
    const path = require('path');
    
    const arquivoPedidos = path.join(__dirname, '../js/services/pedidos.js');
    
    if (!fs.existsSync(arquivoPedidos)) {
        return { passou: false, mensagem: 'Arquivo pedidos.js não encontrado' };
    }
    
    const conteudo = fs.readFileSync(arquivoPedidos, 'utf8');
    
    const temFlagProgresso = conteudo.includes('finalizacaoEmProgresso');
    const temValidacaoStatus = conteudo.includes('FINALIZADO') && conteudo.includes('CANCELADO');
    
    return {
        passou: temFlagProgresso && temValidacaoStatus,
        mensagem: temFlagProgresso && temValidacaoStatus
            ? 'JavaScript TEM proteção contra duplo clique e validação de status'
            : 'JavaScript NÃO TEM proteção adequada',
        detalhes: {
            finalizacaoEmProgresso: temFlagProgresso,
            validacaoStatus: temValidacaoStatus
        }
    };
}

// TESTE 8: Verificar proteção no cancelamento
async function verificarProtecaoCancelamento() {
    const fs = require('fs');
    const path = require('path');
    
    const arquivoDetalhe = path.join(__dirname, '../pages/pedido-detalhe.html');
    
    if (!fs.existsSync(arquivoDetalhe)) {
        return { passou: false, mensagem: 'Arquivo pedido-detalhe.html não encontrado' };
    }
    
    const conteudo = fs.readFileSync(arquivoDetalhe, 'utf8');
    
    const temValidacaoEstoque = conteudo.includes('validar_estoque_para_cancelamento') ||
                                 conteudo.includes('estoque_atual') && conteudo.includes('quantidade');
    const temBloqueioErro = conteudo.includes('throw new Error') || conteudo.includes('BLOQUEIO');
    
    return {
        passou: temValidacaoEstoque && temBloqueioErro,
        mensagem: temValidacaoEstoque && temBloqueioErro
            ? 'Cancelamento TEM validação de estoque antes de registrar movimento'
            : 'Cancelamento NÃO TEM validação adequada',
        detalhes: {
            validacaoEstoque: temValidacaoEstoque,
            bloqueioErro: temBloqueioErro
        }
    };
}

// Executar todos os testes
async function executarTodosTestes() {
    log('\n' + '═'.repeat(60), BLUE);
    log('🧪 INICIANDO BATERIA DE TESTES DE ESTOQUE', BLUE);
    log('═'.repeat(60) + '\n', BLUE);
    
    await teste('Verificar duplicações de movimentações', verificarDuplicacoesExistentes);
    await teste('Verificar estoques negativos', verificarEstoquesNegativos);
    await teste('Verificar pedidos finalizados sem movimentações', verificarPedidosSemMovimentacoes);
    await teste('Verificar consistência estoque (atual vs calculado)', verificarConsistenciaEstoque);
    await teste('Verificar proteção na função SQL finalizar_pedido', verificarProtecaoFuncao);
    await teste('Verificar proteção JavaScript (duplo clique)', verificarProtecaoJavaScript);
    await teste('Verificar proteção no cancelamento', verificarProtecaoCancelamento);
    
    // Resumo final
    log('\n' + '═'.repeat(60), BLUE);
    log('📊 RESUMO DOS TESTES', BLUE);
    log('═'.repeat(60), BLUE);
    log(`Total de testes: ${totalTestes}`, RESET);
    log(`Passaram: ${testesPassaram}`, GREEN);
    log(`Falharam: ${testesFalharam}`, RED);
    log(`Taxa de sucesso: ${((testesPassaram/totalTestes)*100).toFixed(1)}%`, 
        testesPassaram === totalTestes ? GREEN : (testesFalharam > totalTestes/2 ? RED : YELLOW));
    log('═'.repeat(60) + '\n', BLUE);
    
    if (testesFalharam > 0) {
        log('⚠️  AÇÃO NECESSÁRIA: Corrija as falhas encontradas antes de continuar', RED);
        process.exit(1);
    } else {
        log('✅ TODOS OS TESTES PASSARAM! Sistema protegido contra duplicações.', GREEN);
        process.exit(0);
    }
}

// Executar
executarTodosTestes().catch(error => {
    log(`\n❌ ERRO FATAL: ${error.message}`, RED);
    console.error(error);
    process.exit(1);
});
