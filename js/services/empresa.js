// =====================================================
// SERVIÇO: CONFIGURAÇÕES DA EMPRESA
// =====================================================

/**
 * Buscar configurações da empresa
 */
async function getEmpresaConfig() {
    try {
        const { data, error } = await supabase
            .from('empresa_config')
            .select('*')
            .limit(1);

        if (error) throw error;
        return data && data.length > 0 ? data[0] : null;
    } catch (error) {
        console.error('Erro ao buscar configurações da empresa:', error);
        return null;
    }
}

/**
 * Atualizar configurações da empresa
 */
async function updateEmpresaConfig(empresaData) {
    try {
        // Buscar o ID do registro existente
        const { data: existing, error: selectError } = await supabase
            .from('empresa_config')
            .select('id')
            .limit(1);

        if (selectError) {
            console.error('Erro ao buscar config existente:', selectError);
            throw selectError;
        }

        let result;
        if (existing && existing.length > 0) {
            // Atualizar registro existente
            console.log('Atualizando registro existente:', existing[0].id);
            result = await supabase
                .from('empresa_config')
                .update(empresaData)
                .eq('id', existing[0].id)
                .select();
        } else {
            // Criar novo registro
            console.log('Criando novo registro');
            result = await supabase
                .from('empresa_config')
                .insert(empresaData)
                .select();
        }

        console.log('Resultado da operação:', result);
        
        if (result.error) {
            console.error('Erro na operação:', result.error);
            throw result.error;
        }
        
        if (!result.data || result.data.length === 0) {
            console.error('Nenhum dado retornado após salvar');
            throw new Error('Falha ao salvar configurações - nenhum dado retornado');
        }
        
        return result.data[0];
    } catch (error) {
        console.error('Erro ao atualizar configurações da empresa:', error);
        throw error;
    }
}

/**
 * Upload de logo da empresa
 */
async function uploadLogo(file) {
    try {
        // Validar arquivo
        if (!file.type.startsWith('image/')) {
            throw new Error('Apenas imagens são permitidas');
        }

        // Limitar tamanho (2MB)
        if (file.size > 2 * 1024 * 1024) {
            throw new Error('A imagem deve ter no máximo 2MB');
        }

        // Gerar nome único para o arquivo
        const fileExt = file.name.split('.').pop();
        const fileName = `logo-${Date.now()}.${fileExt}`;

        // Fazer upload
        const { data, error } = await supabase.storage
            .from('company-logos')
            .upload(fileName, file, {
                cacheControl: '3600',
                upsert: false
            });

        if (error) throw error;

        // Obter URL pública
        const { data: { publicUrl } } = supabase.storage
            .from('company-logos')
            .getPublicUrl(fileName);

        return publicUrl;
    } catch (error) {
        console.error('Erro ao fazer upload da logo:', error);
        throw error;
    }
}

/**
 * Deletar logo antiga
 */
async function deleteLogo(logoUrl) {
    try {
        if (!logoUrl) return;

        // Extrair nome do arquivo da URL
        const fileName = logoUrl.split('/').pop();

        const { error } = await supabase.storage
            .from('company-logos')
            .remove([fileName]);

        if (error) throw error;
    } catch (error) {
        console.error('Erro ao deletar logo:', error);
        // Não propagar erro pois é uma operação secundária
    }
}

/**
 * Obter logo da empresa (para usar no navbar/sidebar)
 */
async function getEmpresaLogo() {
    try {
        const config = await getEmpresaConfig();
        return config?.logo_url || null;
    } catch (error) {
        return null;
    }
}
