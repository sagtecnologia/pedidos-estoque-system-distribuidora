-- ADICIONAR CONFIGURAÇÕES DE WHATSAPP API
-- Execute este SQL no Supabase para adicionar campos de integração WhatsApp

-- Adicionar colunas para configuração da API do WhatsApp
ALTER TABLE empresa_config 
ADD COLUMN IF NOT EXISTS whatsapp_api_provider VARCHAR(50), -- 'evolution', 'twilio', 'baileys', 'outro'
ADD COLUMN IF NOT EXISTS whatsapp_api_url TEXT, -- URL da API
ADD COLUMN IF NOT EXISTS whatsapp_api_key TEXT, -- Token/Key da API
ADD COLUMN IF NOT EXISTS whatsapp_numero_origem VARCHAR(20), -- Número de origem (com DDI)
ADD COLUMN IF NOT EXISTS whatsapp_instance_id VARCHAR(100); -- ID da instância (para Evolution API)

COMMENT ON COLUMN empresa_config.whatsapp_api_provider IS 'Provedor da API: evolution, twilio, baileys, outro';
COMMENT ON COLUMN empresa_config.whatsapp_api_url IS 'URL base da API do WhatsApp';
COMMENT ON COLUMN empresa_config.whatsapp_api_key IS 'Token/Key de autenticação da API';
COMMENT ON COLUMN empresa_config.whatsapp_numero_origem IS 'Número de origem com DDI (ex: 5511999999999)';
COMMENT ON COLUMN empresa_config.whatsapp_instance_id IS 'ID da instância (usado em Evolution API)';

SELECT 'Campos de WhatsApp API adicionados com sucesso!' as resultado;
