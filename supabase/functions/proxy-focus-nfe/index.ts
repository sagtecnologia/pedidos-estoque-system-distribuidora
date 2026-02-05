// Supabase Edge Function: proxy-focus-nfe
// Proxy para evitar CORS ao chamar API Focus NFe
// Deploy: supabase functions deploy proxy-focus-nfe

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders })
  }

  try {
    // Verificar se tem body
    const body = await req.text()
    if (!body) {
      return new Response(
        JSON.stringify({ erro: "Body vazio. Esta função deve ser chamada via POST com dados JSON." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    const { endpoint, method = 'GET', data, token, ambiente } = JSON.parse(body)

    if (!endpoint) {
      return new Response(
        JSON.stringify({ erro: "Endpoint é obrigatório" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Inicializar Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Se não passou token, buscar do banco
    let focusToken = token;
    let focusAmbiente = ambiente;

    if (!focusToken) {
      const { data: config, error: configError } = await supabaseClient
        .from('empresa_config')
        .select('focusnfe_token, focusnfe_ambiente')
        .single()

      if (configError || !config) {
        throw new Error('Configurações da empresa não encontradas')
      }

      focusToken = config.focusnfe_token
      focusAmbiente = config.focusnfe_ambiente
    }

    if (!focusToken) {
      throw new Error('Token Focus NFe não configurado')
    }

    // Determinar URL base
    const baseUrl = focusAmbiente === 1 
      ? 'https://api.focusnfe.com.br'
      : 'https://homologacao.focusnfe.com.br'

    console.log(`📤 Proxy: ${method} ${baseUrl}${endpoint}`)

    // Fazer requisição para Focus NFe
    const response = await fetch(`${baseUrl}${endpoint}`, {
      method: method,
      headers: {
        'Authorization': `Basic ${btoa(focusToken + ':')}`,
        'Content-Type': 'application/json'
      },
      body: data ? JSON.stringify(data) : undefined
    })

    // Verificar se resposta é JSON
    const contentType = response.headers.get('content-type')
    let result
    
    if (contentType && contentType.includes('application/json')) {
      result = await response.json()
    } else {
      const text = await response.text()
      result = { resposta: text, tipo: 'text' }
    }

    return new Response(JSON.stringify(result), {
      status: response.status,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (error) {
    console.error('Erro no proxy Focus NFe:', error)
    return new Response(
      JSON.stringify({ 
        erro: error.message,
        detalhes: 'Verifique se o token Focus NFe está configurado corretamente'
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})
