# =====================================================
# GUIA - EXTRAIR SCHEMA DO SUPABASE
# =====================================================

## Método 1: Usando Supabase CLI (RECOMENDADO)

### 1. Instalar Supabase CLI
```powershell
# Windows (com Scoop)
scoop bucket add supabase https://github.com/supabase/scoop-bucket.git
scoop install supabase

# Ou baixar direto:
# https://github.com/supabase/cli/releases
```

### 2. Login no Supabase
```powershell
supabase login
```

### 3. Linkar com seu projeto
```powershell
# Substituir PROJECT_ID pelo ID do seu projeto
supabase link --project-ref PROJECT_ID
```

### 4. Extrair schema completo
```powershell
# Gera migrations com todo o schema
supabase db pull

# Ou salvar direto em um arquivo
supabase db dump --local > database/schema-backup-$(Get-Date -Format "yyyy-MM-dd").sql
```

---

## Método 2: Pelo Dashboard do Supabase

1. Acesse: **Table Editor** → **Clique nos 3 pontinhos** → **Download as SQL**
2. Isso baixa apenas as tabelas, não inclui functions/triggers

---

## Método 3: Via pgAdmin ou DBeaver

### Conectar com pgAdmin:
1. Host: `db.PROJECT_ID.supabase.co`
2. Port: `5432`
3. Database: `postgres`
4. User: `postgres`
5. Password: `[sua senha do projeto]`

### Extrair schema:
- **pgAdmin**: Tools → Backup → Format: Plain → Include: Schema only
- **DBeaver**: Ferramentas → Exportar → Estrutura do banco de dados

---

## Método 4: Executar SQL no Supabase Editor

Execute o script `extrair-schema-completo.sql` criado anteriormente.
Copie os resultados seção por seção:
1. Funções → Salve em `schema.sql`
2. Triggers → Adicione ao `schema.sql`
3. Views → Adicione ao `schema.sql`
4. Índices → Adicione ao `schema.sql`
5. Constraints → Adicione ao `schema.sql`

---

## Recomendação

Use o **Supabase CLI** (`supabase db pull`) pois:
- ✅ Gera migrations automáticas
- ✅ Inclui TUDO (tables, functions, triggers, policies, etc)
- ✅ Mantém histórico de mudanças
- ✅ Pode aplicar em outros ambientes

---

## Configurar Supabase CLI no projeto

```powershell
# 1. Inicializar Supabase no projeto
cd c:\Users\Lenovo\OneDrive\Documentos\projetos\pedidos-estoque-system-distribuidora
supabase init

# 2. Linkar com projeto remoto
supabase link --project-ref SEU_PROJECT_ID

# 3. Puxar schema atual
supabase db pull

# 4. Aplicar migrations locais no remoto
supabase db push
```

Isso cria a pasta `supabase/migrations/` com todas as mudanças do banco.
