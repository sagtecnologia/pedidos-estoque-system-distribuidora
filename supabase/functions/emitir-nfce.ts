// Supabase Edge Function: emitir-nfce
// Deploy: supabase functions deploy emitir-nfce
// Secrets: supabase secrets set FOCUS_NFE_TOKEN=seu_token

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
    const { venda_id, itens, pagamentos, cliente } = await req.json()

    if (!venda_id || !itens || !pagamentos) {
      return new Response(
        JSON.stringify({ erro: "Dados incompletos: venda_id, itens e pagamentos são obrigatórios" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      )
    }

    // Inicializar Supabase Client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Buscar configurações da empresa
    const { data: config, error: configError } = await supabaseClient
      .from('empresa_config')
      .select('*')
      .single()

    if (configError || !config) {
      throw new Error('Configurações da empresa não encontradas')
    }

    if (!config.focusnfe_token) {
      throw new Error('Token Focus NFe não configurado')
    }

    // Determinar ambiente e URL
    const ambiente = config.focusnfe_ambiente || 2
    const baseUrl = ambiente === 1 
      ? 'https://api.focusnfe.com.br'
      : 'https://homologacao.focusnfe.com.br'

    // Buscar dados da venda
    const { data: venda, error: vendaError } = await supabaseClient
      .from('vendas')
      .select('*')
      .eq('id', venda_id)
      .single()

    if (vendaError || !venda) {
      throw new Error('Venda não encontrada')
    }

    // Gerar referência única
    const ref = `NFCE-${Date.now()}-${venda.numero_venda}`

    // Montar payload da NFC-e
    const payload = {
      natureza_operacao: 'VENDA AO CONSUMIDOR',
      forma_pagamento: 0, // 0=À vista
      tipo_documento: 1, // 1=Saída
      finalidade_emissao: 1, // 1=Normal
      consumidor_final: 1,
      presenca_comprador: 1,
      cnpj_emitente: config.cnpj?.replace(/\D/g, ''),
      valor_produtos: venda.subtotal,
      valor_desconto: venda.desconto_valor || 0,
      valor_total: venda.total,
      
      // Itens
      items: itens.map((item: any, index: number) => ({
        numero_item: index + 1,
        codigo_produto: item.codigo_barras || item.produto_id.substring(0, 14),
        descricao: item.descricao.substring(0, 120),
        codigo_ncm: item.ncm || '22021000',
        cfop: item.cfop || '5102',
        unidade_comercial: item.unidade || 'UN',
        quantidade_comercial: item.quantidade,
        valor_unitario_comercial: item.preco_unitario,
        valor_bruto: item.subtotal + (item.desconto_valor || 0),
        valor_desconto: item.desconto_valor || 0,
        icms_origem: 0,
        icms_situacao_tributaria: item.cst_icms || '102',
        pis_situacao_tributaria: '49',
        cofins_situacao_tributaria: '49'
      })),

      // Formas de pagamento
      formas_pagamento: pagamentos.map((pag: any) => ({
        forma_pagamento: mapearFormaPagamento(pag.tipo),
        valor_pagamento: pag.valor
      }))
    }

    // Adicionar CSC se configurado
    if (config.csc_id && config.csc_token) {
      payload.id_token_csrt = config.csc_id
      payload.csrt = config.csc_token
    }

    // Adicionar cliente se informado
    if (cliente?.cpf_cnpj) {
      const doc = cliente.cpf_cnpj.replace(/\D/g, '')
      if (doc.length === 11) {
        payload.cpf_destinatario = doc
      } else if (doc.length === 14) {
        payload.cnpj_destinatario = doc
      }
      payload.nome_destinatario = cliente.nome
    }

    // Enviar para Focus NFe
    const focusToken = config.focusnfe_token

    // Enviar para Focus NFe
    const focusToken = config.focusnfe_token
    const response = await fetch(`${baseUrl}/v2/nfce?ref=${ref}`, {
      method: "POST",
      headers: {
        "Authorization": `Basic ${btoa(focusToken + ":")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(payload)
    })

    const resultado = await response.json()

    // Salvar documento fiscal no banco
    const { data: docFiscal, error: docError } = await supabaseClient
      .from('documentos_fiscais')
      .insert({
        tipo: 'NFCE',
        venda_id: venda.id,
        cliente_id: cliente?.id,
        focusnfe_ref: ref,
        valor_total: venda.total,
        status: resultado.status === 'autorizado' ? 'AUTORIZADA' : 
               resultado.status === 'processando_autorizacao' ? 'PROCESSANDO' : 'REJEITADA',
        status_sefaz: resultado.status_sefaz,
        motivo_sefaz: resultado.mensagem_sefaz,
        chave: resultado.chave_nfe,
        protocolo: resultado.protocolo,
        focusnfe_url_danfe: resultado.caminho_danfe,
        focusnfe_url_xml: resultado.caminho_xml_nota_fiscal
      })
      .select()
      .single()

    if (docError) {
      console.error('Erro ao salvar documento fiscal:', docError)
    }

    return new Response(JSON.stringify({
      success: resultado.status !== 'erro_autorizacao',
      ref,
      ...resultado
    }), {
      status: response.ok ? 200 : 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (error) {
    console.error('Erro na Edge Function:', error)
    return new Response(
      JSON.stringify({ erro: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    )
  }
})

// Função auxiliar para mapear forma de pagamento
function mapearFormaPagamento(tipo: string): string {
  const mapa: Record<string, string> = {
    'DINHEIRO': '01',
    'CHEQUE': '02',
    'CREDITO': '03',
    'DEBITO': '04',
    'CREDIARIO': '05',
    'VALE_ALIMENTACAO': '10',
    'VALE_REFEICAO': '11',
    'VALE_PRESENTE': '12',
    'VALE_COMBUSTIVEL': '13',
    'BOLETO': '15',
    'DEPOSITO': '16',
    'PIX': '17',
    'TRANSFERENCIA': '18',
    'CASHBACK': '19',
    'SEM_PAGAMENTO': '90',
    'OUTROS': '99'
  }
  return mapa[tipo] || '99'
}

      headers: {"Content-Type": "application/json"}
    })
  } catch (error) {
    return new Response(
      JSON.stringify({ erro: error.message }),
      { status: 500, headers: {"Content-Type": "application/json"} }
    )
  }
})
