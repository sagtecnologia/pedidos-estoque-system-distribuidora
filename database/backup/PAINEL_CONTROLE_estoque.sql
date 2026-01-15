-- =====================================================
-- 🎛️ PAINEL DE CONTROLE - GESTÃO DE ESTOQUE
-- =====================================================
-- Este é o ponto de entrada principal para gestão de estoque
-- Use este script para escolher qual ação tomar
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║        🎛️  PAINEL DE CONTROLE - GESTÃO DE ESTOQUE        ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
' as "BEM-VINDO";

-- =====================================================
-- 📊 STATUS ATUAL DO SISTEMA
-- =====================================================

SELECT '📊 STATUS ATUAL DO SISTEMA' as "SEÇÃO";

-- Produtos
SELECT 
    '🏷️ PRODUTOS' as "Categoria",
    COUNT(*) as "Total",
    COUNT(CASE WHEN estoque_atual = 0 THEN 1 END) as "Sem Estoque",
    COUNT(CASE WHEN estoque_atual < 0 THEN 1 END) as "⚠️ Negativos",
    COUNT(CASE WHEN estoque_atual > 0 AND estoque_atual <= estoque_minimo THEN 1 END) as "⚠️ Estoque Baixo"
FROM produtos
WHERE active = true;

-- Movimentações
SELECT 
    '📦 MOVIMENTAÇÕES' as "Categoria",
    COUNT(*) as "Total",
    COUNT(CASE WHEN tipo = 'ENTRADA' THEN 1 END) as "Entradas",
    COUNT(CASE WHEN tipo = 'SAIDA' THEN 1 END) as "Saídas",
    COUNT(CASE WHEN created_at >= NOW() - INTERVAL '7 days' THEN 1 END) as "Últimos 7 Dias"
FROM estoque_movimentacoes;

-- Verificação Rápida de Inconsistências
WITH inconsistencias AS (
    SELECT 
        p.id,
        ABS(p.estoque_atual - COALESCE(SUM(CASE WHEN em.tipo = 'ENTRADA' THEN em.quantidade ELSE -em.quantidade END), 0)) as diferenca
    FROM produtos p
    LEFT JOIN estoque_movimentacoes em ON p.id = em.produto_id
    WHERE p.active = true
    GROUP BY p.id, p.estoque_atual
)
SELECT 
    '⚠️ INCONSISTÊNCIAS' as "Categoria",
    COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) as "Produtos Afetados",
    CASE 
        WHEN COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) = 0 THEN '✅ Sistema OK'
        WHEN COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) < 5 THEN '⚠️ Poucos Problemas'
        WHEN COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) < 20 THEN '⚠️ Problemas Moderados'
        ELSE '❌ Muitos Problemas'
    END as "Status",
    CASE 
        WHEN COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) = 0 THEN '➡️ Nenhuma ação necessária'
        WHEN COUNT(CASE WHEN diferenca > 0.01 THEN 1 END) < 5 THEN '➡️ Use CORRIGIR_produto_especifico.sql'
        ELSE '➡️ Use REPROCESSAR_estoque_completo.sql'
    END as "Recomendação"
FROM inconsistencias;

-- Verificação de Duplicatas
WITH duplicatas AS (
    SELECT 
        pedido_id,
        produto_id,
        tipo,
        quantidade,
        DATE(created_at) as data,
        COUNT(*) as ocorrencias
    FROM estoque_movimentacoes
    WHERE pedido_id IS NOT NULL
    GROUP BY pedido_id, produto_id, tipo, quantidade, DATE(created_at)
    HAVING COUNT(*) > 1
)
SELECT 
    '🔄 DUPLICATAS' as "Categoria",
    COALESCE(SUM(ocorrencias - 1), 0) as "Movimentações Duplicadas",
    CASE 
        WHEN COALESCE(SUM(ocorrencias - 1), 0) = 0 THEN '✅ Nenhuma duplicata'
        WHEN COALESCE(SUM(ocorrencias - 1), 0) < 5 THEN '⚠️ Poucas duplicatas'
        ELSE '❌ Muitas duplicatas'
    END as "Status",
    CASE 
        WHEN COALESCE(SUM(ocorrencias - 1), 0) = 0 THEN '➡️ Nenhuma ação necessária'
        ELSE '➡️ Use REPROCESSAR_estoque_completo.sql'
    END as "Recomendação"
FROM duplicatas;

-- =====================================================
-- 🎯 MENU DE AÇÕES DISPONÍVEIS
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║                   🎯 AÇÕES DISPONÍVEIS                    ║
╚═══════════════════════════════════════════════════════════╝
' as "MENU";

SELECT '
┌───────────────────────────────────────────────────────────┐
│                                                           │
│  🔍 OPÇÃO 1: DIAGNÓSTICO COMPLETO                        │
│                                                           │
│  📄 Script: DIAGNOSTICO_estoque_completo.sql             │
│                                                           │
│  ✅ Use quando:                                           │
│     • Quiser ver o estado atual do estoque               │
│     • Identificar produtos com problemas                 │
│     • Ver quantas duplicatas existem                     │
│     • Antes de qualquer correção                         │
│                                                           │
│  ⏱️ Tempo estimado: 10-30 segundos                        │
│  🛡️ Segurança: 100% seguro (só leitura)                  │
│                                                           │
└───────────────────────────────────────────────────────────┘
' as "OPÇÃO 1";

SELECT '
┌───────────────────────────────────────────────────────────┐
│                                                           │
│  🔧 OPÇÃO 2: REPROCESSAMENTO COMPLETO                    │
│                                                           │
│  📄 Script: REPROCESSAR_estoque_completo.sql             │
│                                                           │
│  ✅ Use quando:                                           │
│     • Diagnóstico mostrar muitos problemas (>5)          │
│     • Houver muitas duplicatas                           │
│     • Estoque geral está bagunçado                       │
│     • Após cancelamento problemático                     │
│                                                           │
│  ⚠️ IMPORTANTE:                                            │
│     • Requer decisão manual (COMMIT/ROLLBACK)            │
│     • Faz backup automático                              │
│     • Mostra tudo antes de alterar                       │
│     • Pode ser revertido                                 │
│                                                           │
│  ⏱️ Tempo estimado: 30 segundos - 5 minutos              │
│  🛡️ Segurança: Alta (usa transação)                      │
│                                                           │
└───────────────────────────────────────────────────────────┘
' as "OPÇÃO 2";

SELECT '
┌───────────────────────────────────────────────────────────┐
│                                                           │
│  ✅ OPÇÃO 3: VALIDAÇÃO                                   │
│                                                           │
│  📄 Script: VALIDACAO_estoque.sql                        │
│                                                           │
│  ✅ Use quando:                                           │
│     • Após executar reprocessamento                      │
│     • Para confirmar que tudo está OK                    │
│     • Para gerar relatório de auditoria                  │
│                                                           │
│  📊 Executa 5 testes automáticos                          │
│                                                           │
│  ⏱️ Tempo estimado: 15-45 segundos                        │
│  🛡️ Segurança: 100% seguro (só leitura)                  │
│                                                           │
└───────────────────────────────────────────────────────────┘
' as "OPÇÃO 3";

SELECT '
┌───────────────────────────────────────────────────────────┐
│                                                           │
│  🎯 OPÇÃO 4: CORREÇÃO PONTUAL (1 Produto)               │
│                                                           │
│  📄 Script: CORRIGIR_produto_especifico.sql              │
│                                                           │
│  ✅ Use quando:                                           │
│     • Apenas 1 ou poucos produtos com problema           │
│     • Souber exatamente qual produto corrigir            │
│     • Quiser ajuste rápido e específico                  │
│     • Não quiser mexer em tudo                           │
│                                                           │
│  📝 Permite:                                              │
│     • Buscar produto por código ou nome                  │
│     • Ver histórico completo                             │
│     • Remover duplicatas do produto                      │
│     • Recalcular ou ajustar manualmente                  │
│                                                           │
│  ⏱️ Tempo estimado: 5-15 segundos                         │
│  🛡️ Segurança: Alta (usa transação)                      │
│                                                           │
└───────────────────────────────────────────────────────────┘
' as "OPÇÃO 4";

SELECT '
┌───────────────────────────────────────────────────────────┐
│                                                           │
│  🆘 OPÇÃO 5: EMERGÊNCIA / RESTAURAR                      │
│                                                           │
│  📄 Script: EMERGENCIA_restaurar_estoque.sql             │
│                                                           │
│  ⚠️ Use APENAS quando:                                    │
│     • Algo deu muito errado                              │
│     • Estoque foi zerado por engano                      │
│     • Precisa desfazer reprocessamento                   │
│     • Não consegue fazer ROLLBACK                        │
│                                                           │
│  🔧 3 Opções de Restauração:                              │
│     1. Restaurar do backup                               │
│     2. Recalcular do zero                                │
│     3. Restaurar produto específico                      │
│                                                           │
│  ⏱️ Tempo estimado: 30 segundos - 2 minutos              │
│  🛡️ Segurança: Alta (usa transação)                      │
│                                                           │
└───────────────────────────────────────────────────────────┘
' as "OPÇÃO 5";

-- =====================================================
-- 🗺️ FLUXOGRAMA DE DECISÃO
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║              🗺️  FLUXOGRAMA DE DECISÃO                   ║
╚═══════════════════════════════════════════════════════════╝

                    [INÍCIO]
                       ↓
          ┌────────────────────────┐
          │ Qual é sua situação?   │
          └────────────────────────┘
                       ↓
        ╔═════════════╩═════════════╗
        ↓                           ↓
   [Não sei]                [Já sei o problema]
        ↓                           ↓
        ↓                  ┌────────────────┐
        ↓                  │ Quantos        │
        ↓                  │ produtos?      │
        ↓                  └────────────────┘
        ↓                           ↓
        ↓                  ╔════════╩════════╗
        ↓                  ↓                 ↓
        ↓             [1-5 produtos]   [Muitos produtos]
        ↓                  ↓                 ↓
        ↓            OPÇÃO 4              OPÇÃO 2
        ↓            Correção         Reprocessamento
        ↓             Pontual            Completo
        ↓                  ↓                 ↓
        ↓                  └─────────┬───────┘
        ↓                            ↓
   OPÇÃO 1                     OPÇÃO 3
  Diagnóstico                 Validação
        ↓                            ↓
        └────────────────┬───────────┘
                         ↓
                    [Tudo OK?]
                         ↓
                 ╔═══════╩═══════╗
                 ↓               ↓
              [SIM]           [NÃO]
                 ↓               ↓
            [FIM] ✅         OPÇÃO 2 ou
                          OPÇÃO 5 (emergência)

' as "FLUXOGRAMA";

-- =====================================================
-- 📚 DOCUMENTAÇÃO
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║                  📚 DOCUMENTAÇÃO                          ║
╚═══════════════════════════════════════════════════════════╝

📖 Guia Completo:
   → GUIA_REPROCESSAMENTO_ESTOQUE.md
   Passo a passo detalhado, FAQ, exemplos

📄 Resumo Executivo:
   → SOLUCAO_REPROCESSAMENTO_ESTOQUE.md
   Visão geral da solução, fluxos, exemplos práticos

🛠️ Scripts SQL:
   1. DIAGNOSTICO_estoque_completo.sql
   2. REPROCESSAR_estoque_completo.sql
   3. VALIDACAO_estoque.sql
   4. CORRIGIR_produto_especifico.sql
   5. EMERGENCIA_restaurar_estoque.sql

' as "DOCUMENTAÇÃO";

-- =====================================================
-- 💡 DICAS ÚTEIS
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║                     💡 DICAS ÚTEIS                        ║
╚═══════════════════════════════════════════════════════════╝

1️⃣  SEMPRE faça backup antes de correções
    • Backup do Supabase ou export SQL

2️⃣  Execute diagnóstico ANTES de corrigir
    • Saiba o tamanho do problema primeiro

3️⃣  Leia os resultados com atenção
    • Scripts mostram tudo antes de alterar

4️⃣  Use transações corretamente
    • COMMIT para confirmar
    • ROLLBACK para cancelar

5️⃣  Valide após correções
    • Use VALIDACAO_estoque.sql

6️⃣  Monitore semanalmente
    • Execute diagnóstico 1x por semana

7️⃣  Em caso de dúvida, use ROLLBACK
    • Melhor prevenir que remediar

' as "DICAS";

-- =====================================================
-- 🎯 RECOMENDAÇÃO BASEADA NO STATUS
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║            🎯 RECOMENDAÇÃO PARA SUA SITUAÇÃO              ║
╚═══════════════════════════════════════════════════════════╝
' as "RECOMENDAÇÃO";

WITH status_sistema AS (
    SELECT 
        COUNT(CASE WHEN p.estoque_atual < 0 THEN 1 END) as negativos,
        (
            SELECT COUNT(*)
            FROM (
                SELECT 
                    p2.id,
                    ABS(p2.estoque_atual - COALESCE(SUM(CASE WHEN em2.tipo = 'ENTRADA' THEN em2.quantidade ELSE -em2.quantidade END), 0)) as diferenca
                FROM produtos p2
                LEFT JOIN estoque_movimentacoes em2 ON p2.id = em2.produto_id
                WHERE p2.active = true
                GROUP BY p2.id, p2.estoque_atual
            ) v
            WHERE diferenca > 0.01
        ) as inconsistentes,
        (
            SELECT COALESCE(SUM(ocorrencias - 1), 0)
            FROM (
                SELECT COUNT(*) as ocorrencias
                FROM estoque_movimentacoes
                WHERE pedido_id IS NOT NULL
                GROUP BY pedido_id, produto_id, tipo, quantidade, DATE(created_at)
                HAVING COUNT(*) > 1
            ) d
        ) as duplicatas
    FROM produtos p
    WHERE p.active = true
)
SELECT 
    CASE 
        WHEN negativos = 0 AND inconsistentes = 0 AND duplicatas = 0 THEN 
            '✅ SEU SISTEMA ESTÁ OK!
            
            ➡️ Nenhuma ação necessária
            ➡️ Execute VALIDACAO_estoque.sql para confirmar
            ➡️ Configure monitoramento semanal'
            
        WHEN inconsistentes <= 5 AND duplicatas <= 10 THEN 
            '⚠️ POUCOS PROBLEMAS DETECTADOS
            
            ➡️ Execute DIAGNOSTICO_estoque_completo.sql
            ➡️ Veja quais produtos estão afetados
            ➡️ Use CORRIGIR_produto_especifico.sql para cada um
            ➡️ Depois execute VALIDACAO_estoque.sql'
            
        ELSE 
            '❌ PROBLEMAS SIGNIFICATIVOS DETECTADOS
            
            ➡️ 1. Execute DIAGNOSTICO_estoque_completo.sql
            ➡️ 2. Faça backup completo do banco
            ➡️ 3. Execute REPROCESSAR_estoque_completo.sql
            ➡️ 4. Revise os resultados
            ➡️ 5. COMMIT se tudo OK, ROLLBACK se não
            ➡️ 6. Execute VALIDACAO_estoque.sql
            
            ⚠️ ATENÇÃO: Problemas encontrados:
            • ' || negativos || ' produtos com estoque negativo
            • ' || inconsistentes || ' produtos com estoque inconsistente
            • ' || duplicatas || ' movimentações duplicadas'
    END as "Recomendação Personalizada"
FROM status_sistema;

-- =====================================================
-- 📞 SUPORTE
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║                      📞 SUPORTE                           ║
╚═══════════════════════════════════════════════════════════╝

Se encontrar problemas:

1. ⏸️  PARE imediatamente
2. 🔄 Execute ROLLBACK; (se em transação)
3. 📸 Copie mensagens de erro
4. 📧 Entre em contato com suporte técnico
5. 📋 Informe qual script estava executando

⚠️ NÃO tente corrigir na força bruta!
⚠️ NÃO execute múltiplos scripts ao mesmo tempo!
⚠️ NÃO ignore mensagens de erro!

' as "SUPORTE";

-- =====================================================
-- FIM DO PAINEL
-- =====================================================

SELECT '
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║              ✅ Painel de Controle Pronto                 ║
║                                                           ║
║         Escolha uma opção acima e execute o script        ║
║         correspondente na pasta database/                 ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
' as "FIM";
