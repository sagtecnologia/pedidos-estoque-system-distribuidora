-- =====================================================
-- MIGRAÇÃO: CRIAR USUÁRIO ADMINISTRADOR PADRÃO
-- Execute este script no Supabase SQL Editor
-- =====================================================

-- INSTRUÇÕES:
-- 1. Primeiro, você precisa criar o usuário no Supabase Auth manualmente:
--    - Vá em Authentication > Users
--    - Clique em "Add user" > "Create new user"
--    - Email: brunoallencar@hotmail.com
--    - Senha: Bb93163087@@
--    - Confirme email automaticamente
--    - Copie o UUID gerado
--
-- 2. Depois, execute este script substituindo 'SEU-UUID-AQUI' pelo UUID copiado

-- Substituir SEU-UUID-AQUI pelo UUID do usuário criado no passo 1
INSERT INTO users (id, email, full_name, role, active, created_at, updated_at) 
VALUES (
    'SEU-UUID-AQUI', -- SUBSTITUA PELO UUID DO USUÁRIO
    'brunoallencar@hotmail.com', 
    'Administrador Sistema', 
    'ADMIN', 
    true,
    NOW(),
    NOW()
)
ON CONFLICT (email) 
DO UPDATE SET 
    active = true, 
    role = 'ADMIN',
    updated_at = NOW();

SELECT 'Usuário administrador criado/atualizado com sucesso!' as status;
SELECT 'Email: brunoallencar@hotmail.com' as credenciais;
SELECT 'IMPORTANTE: Altere a senha após o primeiro login!' as aviso;
