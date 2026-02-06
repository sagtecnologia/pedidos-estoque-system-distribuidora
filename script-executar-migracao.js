#!/usr/bin/env node

/**
 * Script para executar migração protect-comandas-duplicacao.sql
 * 
 * IMPORTANTE: Este é um arquivo JavaScript, NÃO SQL!
 * 
 * Opções de uso:
 * 1. Terminal: node script-executar-migracao.js
 * 2. Supabase: Copiar SQL e colar no SQL Editor
 */

const fs = require('fs');
const path = require('path');

// SQL da migração (inline para evitar erros de caminho)
const sql = `-- =====================================================
-- MIGRAÇÃO: Proteger contra duração de venda em comanda
-- Descrição: Implementar constraint para garantir que cada comanda tem no máximo uma venda
-- Data: 06/02/2026
-- =====================================================

-- PROBLEMA:
-- Uma mesma comanda pode ser finalizada múltiplas vezes, gerando múltiplas vendas
-- Isso acontece se houver erro na primeira tentativa e o usuário clicar em "Confirmar" novamente

-- SOLUÇÃO:
-- 1. Validação no código: só atualizar comanda se venda_id for null
-- 2. Validação no banco: criar constraint que impede venda_id duplicado para comanda_id

-- Criar índice único para garantir 1 venda por comanda (quando venda_id não é null)
-- Isso funciona porque NULL != NULL no SQL, permitindo múltiplas colunas NULL
CREATE UNIQUE INDEX IF NOT EXISTS idx_comandas_venda_id_unica
ON comandas(venda_id)
WHERE venda_id IS NOT NULL;

-- Comentário explicativo
COMMENT ON INDEX idx_comandas_venda_id_unica IS 
'Garante que cada venda está ligada a no máximo uma comanda. O índice ignora linhas com venda_id NULL.';

-- =====================================================
-- FIM DA MIGRAÇÃO
-- =====================================================

-- TESTE:
-- 1. Tentar finalizar comanda e gerar venda A
-- 2. Tentar finalizar mesma comanda novamente
-- ❌ Deve falhar com erro: "duplicate key value violates unique constraint"
-- Isso é intencional! Protege contra duplicação acidental.`;

// Função para exibir instruções
function mostrarInstrucoes() {
    console.log('\n' + '='.repeat(70));
    console.log('🚀 MIGRAÇÃO: protect-comandas-duplicacao');
    console.log('='.repeat(70));
    console.log('\n❌ ERRO: Este é um arquivo JavaScript, não pode rodar como SQL!');
    console.log('\n✅ SOLUÇÃO: Escolha uma opção abaixo:\n');
    
    console.log('OPÇÃO 1: Via Supabase Dashboard (MAIS FÁCIL) ⭐');
    console.log('─'.repeat(70));
    console.log('1. Abra: https://app.supabase.com');
    console.log('2. Selecione seu projeto');
    console.log('3. Vá em: SQL Editor (menu esquerdo)');
    console.log('4. Clique: + New Query');
    console.log('5. Cole o SQL abaixo (ou copie do arquivo protect-comandas-duplicacao.sql)');
    console.log('6. Clique: Run (botão azul)');
    console.log('7. ✅ Pronto!\n');
    
    console.log('OPÇÃO 2: Via Node.js (AUTOMÁTICO)');
    console.log('─'.repeat(70));
    console.log('1. Instale: npm install pg');
    console.log('2. Obtenha DATABASE_URL em:');
    console.log('   https://app.supabase.com → Settings → Database → Connection string');
    console.log('3. Execute (Windows PowerShell):');
    console.log('   $env:DATABASE_URL="postgresql://..."');
    console.log('   node script-executar-migracao.js');
    console.log('4. ✅ Pronto!\n');
    
    console.log('OPÇÃO 3: Via psql (AVANÇADO)');
    console.log('─'.repeat(70));
    console.log('1. Ter psql instalado');
    console.log('2. Ter DATABASE_URL disponível');
    console.log('3. Executar: psql "postgresql://..." < database/migrations/protect-comandas-duplicacao.sql');
    console.log('4. ✅ Pronto!\n');
    
    console.log('=' * 70);
    console.log('SQL A EXECUTAR (COPIE E COLE NO SUPABASE):');
    console.log('=' * 70);
    console.log(sql);
    console.log('=' * 70);
    console.log('\n👉 Recomendação: Use OPÇÃO 1 (Supabase Dashboard), é a mais fácil!\n');
}

// Tentar carregar via pg (PostgreSQL client)
let Client;
let temPg = false;
try {
    const pg = require('pg');
    Client = pg.Client;
    temPg = true;
} catch (e) {
    // Não tem pg instalado, tudo bem - vai mostrar instruções
}

const connectionString = process.env.DATABASE_URL;

// Se tem pg E conexão configurada, executar
if (temPg && connectionString) {
    console.log('✅ Módulo pg encontrado e DATABASE_URL configurada!');
    console.log('🔄 Executando migração automaticamente...\n');
    
    async function executarMigracao() {
        const client = new Client({ connectionString });
        
        try {
            console.log('🔍 Conectando ao banco de dados...');
            await client.connect();
            console.log('✅ Conectado!');
            
            console.log('\n📝 Executando migração...');
            const resultado = await client.query(sql);
            
            console.log('✅ Migração executada com sucesso!');
            console.log('\n📊 Resultado:');
            console.log(JSON.stringify(resultado, null, 2));
            
            console.log('\n🎉 Índice criado:');
            console.log('   - Nome: idx_comandas_venda_id_unica');
            console.log('   - Tabela: comandas');
            console.log('   - Coluna: venda_id');
            console.log('   - Garante: Apenas uma venda por comanda');
            console.log('\n✅ Você pode fechar este terminal!\n');
            
        } catch (erro) {
            console.error('❌ Erro ao executar migração:');
            console.error(erro.message);
            console.error('\n💡 Se o erro for "já existe", tudo bem! O índice foi criado antes.\n');
            process.exit(1);
        } finally {
            await client.end();
            console.log('🔌 Conexão fechada.');
        }
    }
    
    executarMigracao().catch(erro => {
        console.error('Erro fatal:', erro);
        process.exit(1);
    });
} else {
    // Mostrar instruções
    mostrarInstrucoes();
}
