Vou te enviar o schema do meu banco atual e você crie um schema do meu banco de dando atualizado :
-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.aliquotas_estaduais (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  estado_origem character varying NOT NULL,
  estado_destino character varying NOT NULL,
  categoria_id uuid,
  aliquota_icms numeric DEFAULT 0.00,
  aliquota_pis numeric DEFAULT 0.00,
  aliquota_cofins numeric DEFAULT 0.00,
  vigencia_inicio date NOT NULL,
  vigencia_fim date,
  ativo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT aliquotas_estaduais_pkey PRIMARY KEY (id),
  CONSTRAINT aliquotas_estaduais_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id)
);
CREATE TABLE public.auditoria_log (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  tabela_nome character varying NOT NULL,
  operacao character varying NOT NULL,
  registro_id uuid,
  dados_antigos jsonb,
  dados_novos jsonb,
  usuario_id uuid,
  ip_address character varying,
  user_agent text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT auditoria_log_pkey PRIMARY KEY (id),
  CONSTRAINT auditoria_log_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id)
);
CREATE TABLE public.caixa_movimentacoes (
  id uuid NOT NULL,
  sessao_id uuid NOT NULL,
  tipo character varying NOT NULL CHECK (tipo::text = ANY (ARRAY['SANGRIA'::character varying, 'SUPRIMENTO'::character varying]::text[])),
  valor numeric NOT NULL,
  motivo text,
  responsavel_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT caixa_movimentacoes_pkey PRIMARY KEY (id),
  CONSTRAINT caixa_movimentacoes_sessao_id_fkey FOREIGN KEY (sessao_id) REFERENCES public.caixa_sessoes(id)
);
CREATE TABLE public.caixa_sessoes (
  caixa_id uuid,
  operador_id uuid,
  data_abertura timestamp with time zone DEFAULT now(),
  data_fechamento timestamp with time zone,
  valor_abertura numeric DEFAULT 0,
  valor_fechamento numeric,
  valor_vendas numeric DEFAULT 0,
  valor_sangrias numeric DEFAULT 0,
  valor_suprimentos numeric DEFAULT 0,
  diferenca numeric,
  status character varying DEFAULT 'ABERTO'::character varying CHECK (status::text = ANY (ARRAY['ABERTO'::character varying, 'FECHADO'::character varying, 'CONFERIDO'::character varying]::text[])),
  observacoes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  CONSTRAINT caixa_sessoes_pkey PRIMARY KEY (id),
  CONSTRAINT fk_caixa_sessoes_caixa FOREIGN KEY (caixa_id) REFERENCES public.caixas(id),
  CONSTRAINT fk_caixa_sessoes_operador FOREIGN KEY (operador_id) REFERENCES public.users(id)
);
CREATE TABLE public.caixas (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  numero integer NOT NULL UNIQUE,
  descricao character varying,
  serie_pdv character varying,
  ativo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  nome character varying,
  impressora_nfce character varying,
  impressora_cupom character varying,
  terminal character varying,
  CONSTRAINT caixas_pkey PRIMARY KEY (id)
);
CREATE TABLE public.categoria_impostos (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  categoria_id uuid NOT NULL UNIQUE,
  aliquota_icms numeric DEFAULT 0.00,
  aliquota_pis numeric DEFAULT 0.00,
  aliquota_cofins numeric DEFAULT 0.00,
  aliquota_ipi numeric DEFAULT 0.00,
  cst_icms character varying DEFAULT '00'::character varying,
  ncm_padrao character varying,
  cfop_padrao character varying DEFAULT '5102'::character varying,
  origem_padrao character varying DEFAULT '0'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categoria_impostos_pkey PRIMARY KEY (id),
  CONSTRAINT categoria_impostos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id)
);
CREATE TABLE public.categorias (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nome character varying NOT NULL UNIQUE,
  descricao text,
  ativo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT categorias_pkey PRIMARY KEY (id)
);
CREATE TABLE public.clientes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nome character varying NOT NULL,
  tipo character varying,
  cpf_cnpj character varying UNIQUE,
  inscricao_estadual character varying,
  endereco text,
  numero character varying,
  complemento text,
  bairro character varying,
  cidade character varying,
  estado character varying,
  cep character varying,
  telefone character varying,
  whatsapp character varying,
  email character varying,
  limite_credito numeric DEFAULT 0.00,
  saldo_devedor numeric DEFAULT 0.00,
  tabela_preco_custom boolean DEFAULT false,
  ativo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT clientes_pkey PRIMARY KEY (id)
);
CREATE TABLE public.contas_pagar (
  id uuid NOT NULL,
  numero_documento character varying,
  descricao character varying NOT NULL,
  fornecedor_id uuid,
  pedido_compra_id uuid,
  valor_original numeric NOT NULL,
  valor_desconto numeric DEFAULT 0,
  valor_juros numeric DEFAULT 0,
  valor_multa numeric DEFAULT 0,
  valor_pago numeric DEFAULT 0,
  valor_total numeric DEFAULT (((valor_original - valor_desconto) + valor_juros) + valor_multa),
  data_emissao date DEFAULT CURRENT_DATE,
  data_vencimento date NOT NULL,
  data_pagamento date,
  forma_pagamento character varying,
  conta_bancaria character varying,
  status character varying DEFAULT 'PENDENTE'::character varying CHECK (status::text = ANY (ARRAY['PENDENTE'::character varying, 'PAGO'::character varying, 'PAGO_PARCIAL'::character varying, 'VENCIDO'::character varying, 'CANCELADO'::character varying]::text[])),
  categoria character varying DEFAULT 'FORNECEDOR'::character varying,
  centro_custo character varying,
  parcela_atual integer DEFAULT 1,
  total_parcelas integer DEFAULT 1,
  observacoes text,
  usuario_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT contas_pagar_pkey PRIMARY KEY (id),
  CONSTRAINT contas_pagar_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id),
  CONSTRAINT contas_pagar_pedido_compra_id_fkey FOREIGN KEY (pedido_compra_id) REFERENCES public.pedidos_compra(id)
);
CREATE TABLE public.contas_receber (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  venda_id uuid,
  cliente_id uuid NOT NULL,
  valor_original numeric NOT NULL,
  valor_pago numeric DEFAULT 0.00,
  valor_pendente numeric NOT NULL,
  data_vencimento date NOT NULL,
  data_pagamento date,
  juros numeric DEFAULT 0.00,
  multa numeric DEFAULT 0.00,
  desconto numeric DEFAULT 0.00,
  status_pagamento character varying DEFAULT 'ABERTO'::character varying,
  observacoes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  valor_recebido numeric DEFAULT 0,
  status character varying DEFAULT 'PENDENTE'::character varying,
  valor_desconto numeric DEFAULT 0,
  valor_juros numeric DEFAULT 0,
  valor_multa numeric DEFAULT 0,
  data_recebimento date,
  numero_documento character varying,
  descricao character varying,
  data_emissao date DEFAULT CURRENT_DATE,
  forma_recebimento character varying,
  conta_bancaria character varying,
  categoria character varying DEFAULT 'VENDA'::character varying,
  parcela_atual integer DEFAULT 1,
  total_parcelas integer DEFAULT 1,
  usuario_id uuid,
  CONSTRAINT contas_receber_pkey PRIMARY KEY (id),
  CONSTRAINT contas_receber_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id),
  CONSTRAINT contas_receber_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id)
);
CREATE TABLE public.documentos_fiscais (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  venda_id uuid NOT NULL,
  tipo_documento character varying NOT NULL,
  numero_documento character varying,
  serie integer,
  chave_acesso character varying,
  protocolo_autorizacao character varying,
  status_sefaz character varying,
  mensagem_sefaz text,
  xml_nota text,
  xml_retorno text,
  valor_total numeric,
  natureza_operacao character varying,
  data_emissao timestamp with time zone,
  data_autorizacao timestamp with time zone,
  tentativas_emissao integer DEFAULT 0,
  ultima_tentativa timestamp with time zone,
  proximo_retry timestamp with time zone,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT documentos_fiscais_pkey PRIMARY KEY (id),
  CONSTRAINT documentos_fiscais_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id)
);
CREATE TABLE public.empresa_config (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nome_empresa character varying NOT NULL,
  razao_social character varying,
  cnpj character varying UNIQUE,
  inscricao_estadual character varying,
  inscricao_municipal character varying,
  logo_url text,
  endereco text,
  numero character varying,
  complemento text,
  bairro character varying,
  cidade character varying,
  estado character varying,
  cep character varying,
  telefone character varying,
  email character varying,
  website character varying,
  regime_tributario character varying,
  cnae character varying,
  codigo_municipio character varying,
  logradouro character varying,
  nfe_ambiente character varying DEFAULT '2'::character varying,
  nfe_token text,
  nfce_serie integer DEFAULT 1,
  nfe_serie integer DEFAULT 1,
  nfce_numero integer DEFAULT 1,
  nfe_numero integer DEFAULT 1,
  pdv_emitir_nfce boolean DEFAULT false,
  pdv_imprimir_cupom boolean DEFAULT true,
  pdv_permitir_venda_zerado boolean DEFAULT false,
  pdv_desconto_maximo boolean DEFAULT false,
  pdv_desconto_limite numeric DEFAULT 10.00,
  pdv_mensagem_cupom text,
  whatsapp_api_provider character varying,
  whatsapp_numero_origem character varying,
  whatsapp_api_url text,
  whatsapp_api_key text,
  whatsapp_instance_id character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  certificado_digital text,
  senha_certificado character varying,
  regime_tributario_codigo character varying,
  natureza_operacao_padrao character varying DEFAULT 'VENDA'::character varying,
  sincronizar_numero_nfce boolean DEFAULT true,
  ultimo_numero_nfce_sincronizado integer DEFAULT 0,
  endereco_numero character varying,
  csc_id character varying,
  csc_token character varying,
  ambiente_nfe character varying DEFAULT '2'::character varying,
  serie_nfe character varying DEFAULT '1'::character varying,
  proximo_numero_nfe integer DEFAULT 1,
  cor_primaria character varying DEFAULT '#3B82F6'::character varying,
  cor_secundaria character varying DEFAULT '#10B981'::character varying,
  habilitar_cupom_fiscal boolean DEFAULT false,
  habilitar_nfce boolean DEFAULT false,
  alerta_estoque_minimo boolean DEFAULT true,
  dias_alerta_validade integer DEFAULT 30,
  focusnfe_token text,
  focusnfe_ambiente integer DEFAULT 2,
  certificado_validade date,
  pdv_emitir_nfce_automatico boolean DEFAULT false,
  CONSTRAINT empresa_config_pkey PRIMARY KEY (id)
);
CREATE TABLE public.estoque_movimentacoes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  produto_id uuid NOT NULL,
  lote_id uuid,
  tipo_movimento character varying NOT NULL,
  quantidade numeric NOT NULL,
  unidade_medida USER-DEFINED NOT NULL,
  preco_unitario numeric,
  motivo text,
  referencia_id uuid,
  referencia_tipo character varying,
  usuario_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT estoque_movimentacoes_pkey PRIMARY KEY (id),
  CONSTRAINT estoque_movimentacoes_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id),
  CONSTRAINT estoque_movimentacoes_lote_id_fkey FOREIGN KEY (lote_id) REFERENCES public.produto_lotes(id),
  CONSTRAINT estoque_movimentacoes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id)
);
CREATE TABLE public.fornecedores (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nome character varying NOT NULL,
  cnpj character varying UNIQUE,
  inscricao_estadual character varying,
  endereco text,
  numero character varying,
  bairro character varying,
  cidade character varying,
  estado character varying,
  cep character varying,
  telefone character varying,
  email character varying,
  contato_nome character varying,
  contato_telefone character varying,
  ativo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  razao_social character varying NOT NULL,
  nome_fantasia character varying,
  complemento character varying,
  usuario_id uuid,
  site character varying,
  banco character varying,
  agencia character varying,
  conta character varying,
  pix character varying,
  observacoes text,
  CONSTRAINT fornecedores_pkey PRIMARY KEY (id)
);
CREATE TABLE public.importacao_xml_log (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  arquivo_nome character varying NOT NULL,
  chave_nfe character varying,
  numero_nfe character varying,
  fornecedor_id uuid,
  fornecedor_cnpj character varying,
  fornecedor_nome character varying,
  pedido_id uuid,
  total_produtos integer DEFAULT 0,
  valor_total numeric DEFAULT 0,
  status character varying DEFAULT 'PROCESSANDO'::character varying CHECK (status::text = ANY (ARRAY['PROCESSANDO'::character varying, 'SUCESSO'::character varying, 'ERRO'::character varying, 'PARCIAL'::character varying]::text[])),
  erro_mensagem text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT importacao_xml_log_pkey PRIMARY KEY (id),
  CONSTRAINT fk_importacao_xml_fornecedor FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id),
  CONSTRAINT fk_importacao_xml_user FOREIGN KEY (created_by) REFERENCES public.users(id)
);
CREATE TABLE public.marcas (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nome character varying NOT NULL UNIQUE,
  ativo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  descricao text,
  CONSTRAINT marcas_pkey PRIMARY KEY (id)
);
CREATE TABLE public.movimentacoes_caixa (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  caixa_id uuid NOT NULL,
  data_abertura timestamp with time zone NOT NULL DEFAULT now(),
  data_fechamento timestamp with time zone,
  operador_id uuid NOT NULL,
  saldo_inicial numeric NOT NULL DEFAULT 0.00,
  total_vendas numeric DEFAULT 0.00,
  total_dinheiro numeric DEFAULT 0.00,
  total_sangria numeric DEFAULT 0.00,
  total_suprimento numeric DEFAULT 0.00,
  saldo_final numeric,
  status character varying DEFAULT 'ABERTA'::character varying,
  observacoes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT movimentacoes_caixa_pkey PRIMARY KEY (id),
  CONSTRAINT movimentacoes_caixa_caixa_id_fkey FOREIGN KEY (caixa_id) REFERENCES public.caixas(id),
  CONSTRAINT movimentacoes_caixa_operador_id_fkey FOREIGN KEY (operador_id) REFERENCES public.users(id)
);
CREATE TABLE public.movimentacoes_financeiras (
  id uuid NOT NULL,
  tipo character varying NOT NULL CHECK (tipo::text = ANY (ARRAY['PAGAMENTO'::character varying, 'RECEBIMENTO'::character varying]::text[])),
  conta_pagar_id uuid,
  conta_receber_id uuid,
  valor numeric NOT NULL,
  data_movimento date DEFAULT CURRENT_DATE,
  forma character varying,
  conta_bancaria character varying,
  comprovante character varying,
  observacoes text,
  usuario_id uuid,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT movimentacoes_financeiras_pkey PRIMARY KEY (id),
  CONSTRAINT movimentacoes_financeiras_conta_pagar_id_fkey FOREIGN KEY (conta_pagar_id) REFERENCES public.contas_pagar(id)
);
CREATE TABLE public.pagamentos_venda (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  venda_id uuid NOT NULL,
  forma USER-DEFINED NOT NULL,
  valor numeric NOT NULL,
  numero_parcela integer DEFAULT 1,
  total_parcelas integer DEFAULT 1,
  data_vencimento date,
  status_pagamento character varying DEFAULT 'RECEBIDO'::character varying,
  observacoes text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pagamentos_venda_pkey PRIMARY KEY (id),
  CONSTRAINT pagamentos_venda_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id)
);
CREATE TABLE public.pedido_compra_itens (
  id uuid NOT NULL,
  pedido_id uuid NOT NULL,
  produto_id uuid NOT NULL,
  quantidade numeric NOT NULL,
  quantidade_recebida numeric DEFAULT 0,
  preco_unitario numeric NOT NULL,
  subtotal numeric NOT NULL,
  numero_lote character varying,
  data_validade date,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pedido_compra_itens_pkey PRIMARY KEY (id),
  CONSTRAINT pedido_compra_itens_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos_compra(id)
);
CREATE TABLE public.pedidos_compra (
  id uuid NOT NULL,
  numero character varying NOT NULL UNIQUE,
  fornecedor_id uuid NOT NULL,
  usuario_id uuid NOT NULL,
  subtotal numeric DEFAULT 0,
  desconto numeric DEFAULT 0,
  frete numeric DEFAULT 0,
  outras_despesas numeric DEFAULT 0,
  total numeric DEFAULT 0,
  data_pedido date DEFAULT CURRENT_DATE,
  data_previsao date,
  data_recebimento date,
  nf_numero character varying,
  nf_serie character varying,
  nf_chave character varying,
  status character varying DEFAULT 'PENDENTE'::character varying CHECK (status::text = ANY (ARRAY['PENDENTE'::character varying, 'APROVADO'::character varying, 'RECEBIDO'::character varying, 'CANCELADO'::character varying]::text[])),
  observacoes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT pedidos_compra_pkey PRIMARY KEY (id)
);
CREATE TABLE public.produto_lotes (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  produto_id uuid NOT NULL,
  numero_lote character varying NOT NULL,
  data_fabricacao date,
  data_vencimento date,
  quantidade numeric NOT NULL DEFAULT 0.00,
  localizacao text,
  ativo boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  data_validade date,
  quantidade_inicial numeric DEFAULT 0,
  quantidade_atual numeric DEFAULT 0,
  preco_custo numeric DEFAULT 0,
  fornecedor_id uuid,
  nota_fiscal character varying,
  observacoes text,
  status character varying DEFAULT 'ATIVO'::character varying,
  CONSTRAINT produto_lotes_pkey PRIMARY KEY (id),
  CONSTRAINT produto_lotes_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id)
);
CREATE TABLE public.produtos (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  codigo_barras character varying UNIQUE,
  nome character varying NOT NULL,
  descricao text,
  categoria_id uuid,
  marca_id uuid,
  preco_custo numeric NOT NULL DEFAULT 0.00,
  preco_venda numeric NOT NULL DEFAULT 0.00,
  preco_atacado numeric,
  margem_lucro numeric DEFAULT 0.00,
  unidade_medida_padrao USER-DEFINED DEFAULT 'UN'::unidade_medida,
  unidade_venda USER-DEFINED DEFAULT 'UN'::unidade_medida,
  quantidade_por_embalagem numeric DEFAULT 1.00,
  estoque_minimo numeric DEFAULT 0.00,
  estoque_maximo numeric DEFAULT 0.00,
  estoque_atual numeric DEFAULT 0.00,
  ativo boolean DEFAULT true,
  requer_lote boolean DEFAULT false,
  controla_serie boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  ncm character varying DEFAULT '22021000'::character varying,
  cfop character varying DEFAULT '5102'::character varying,
  origem_produto character varying DEFAULT '0'::character varying,
  descricao_nfe text,
  aliquota_icms numeric DEFAULT 0.00,
  aliquota_pis numeric DEFAULT 0.00,
  aliquota_cofins numeric DEFAULT 0.00,
  aliquota_ipi numeric DEFAULT 0.00,
  cst_icms character varying DEFAULT '00'::character varying,
  codigo character varying,
  marca character varying,
  unidade character varying DEFAULT 'UN'::character varying,
  fornecedor_id uuid,
  imagem_url text,
  volume_ml integer,
  controla_validade boolean DEFAULT true,
  cfop_compra character varying DEFAULT '1102'::character varying,
  cest character varying,
  cfop_venda character varying DEFAULT '5102'::character varying,
  cst_pis character varying,
  cst_cofins character varying,
  cst_ipi character varying,
  origem character varying DEFAULT '0'::character varying,
  embalagem character varying,
  quantidade_embalagem integer DEFAULT 1,
  dias_alerta_validade integer DEFAULT 30,
  localizacao character varying,
  peso_kg numeric,
  sku character varying,
  CONSTRAINT produtos_pkey PRIMARY KEY (id),
  CONSTRAINT produtos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id),
  CONSTRAINT produtos_marca_id_fkey FOREIGN KEY (marca_id) REFERENCES public.marcas(id)
);
CREATE TABLE public.users (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  email character varying NOT NULL UNIQUE,
  nome_completo character varying NOT NULL,
  cpf character varying UNIQUE,
  role USER-DEFINED NOT NULL DEFAULT 'VENDEDOR'::user_role,
  telefone character varying,
  whatsapp character varying,
  ativo boolean DEFAULT true,
  email_confirmado boolean DEFAULT false,
  ultimo_login timestamp with time zone,
  senha_hash character varying,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  full_name character varying,
  approved boolean DEFAULT false,
  approved_by uuid,
  approved_at timestamp with time zone,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
CREATE TABLE public.venda_itens (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  venda_id uuid NOT NULL,
  produto_id uuid NOT NULL,
  lote_id uuid,
  quantidade numeric NOT NULL,
  preco_unitario numeric NOT NULL,
  desconto_percentual numeric DEFAULT 0,
  desconto_valor numeric DEFAULT 0,
  subtotal numeric NOT NULL,
  cfop character varying,
  ncm character varying,
  cst_icms character varying,
  valor_icms numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  preco_custo numeric,
  CONSTRAINT venda_itens_pkey PRIMARY KEY (id)
);
CREATE TABLE public.venda_pagamentos (
  id uuid NOT NULL,
  venda_id uuid NOT NULL,
  forma_pagamento character varying NOT NULL,
  valor numeric NOT NULL,
  bandeira character varying,
  nsu character varying,
  autorizacao character varying,
  parcelas integer DEFAULT 1,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT venda_pagamentos_pkey PRIMARY KEY (id)
);
CREATE TABLE public.vendas (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  numero_nf character varying UNIQUE,
  caixa_id uuid NOT NULL,
  movimentacao_caixa_id uuid NOT NULL,
  operador_id uuid NOT NULL,
  cliente_id uuid,
  subtotal numeric NOT NULL DEFAULT 0.00,
  desconto numeric DEFAULT 0.00,
  desconto_percentual numeric DEFAULT 0.00,
  acrescimo numeric DEFAULT 0.00,
  impostos numeric DEFAULT 0.00,
  total numeric NOT NULL DEFAULT 0.00,
  forma_pagamento USER-DEFINED NOT NULL,
  valor_pago numeric NOT NULL,
  valor_troco numeric DEFAULT 0.00,
  status_venda USER-DEFINED DEFAULT 'FINALIZADA'::venda_status,
  status_fiscal USER-DEFINED DEFAULT 'SEM_DOCUMENTO_FISCAL'::documento_fiscal_status,
  numero_nfce character varying,
  numero_nfe character varying,
  chave_acesso_nfce character varying,
  chave_acesso_nfe character varying,
  protocolo_nfce character varying,
  protocolo_nfe character varying,
  xml_nfce text,
  xml_nfe text,
  mensagem_erro_fiscal text,
  observacoes text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  numero character varying,
  status character varying DEFAULT 'FINALIZADA'::character varying,
  data_venda timestamp with time zone DEFAULT now(),
  sessao_id uuid,
  vendedor_id uuid,
  desconto_valor numeric DEFAULT 0,
  troco numeric DEFAULT 0,
  CONSTRAINT vendas_pkey PRIMARY KEY (id),
  CONSTRAINT vendas_movimentacao_caixa_id_fkey FOREIGN KEY (movimentacao_caixa_id) REFERENCES public.caixa_sessoes(id),
  CONSTRAINT vendas_caixa_id_fkey FOREIGN KEY (caixa_id) REFERENCES public.caixas(id),
  CONSTRAINT vendas_operador_id_fkey FOREIGN KEY (operador_id) REFERENCES public.users(id),
  CONSTRAINT vendas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id)
);
CREATE TABLE public.vendas_itens (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  venda_id uuid NOT NULL,
  produto_id uuid NOT NULL,
  lote_id uuid,
  quantidade numeric NOT NULL,
  unidade_medida USER-DEFINED NOT NULL,
  preco_unitario numeric NOT NULL,
  subtotal numeric NOT NULL,
  desconto numeric DEFAULT 0.00,
  desconto_percentual numeric DEFAULT 0.00,
  acrescimo numeric DEFAULT 0.00,
  total numeric NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  preco_custo numeric,
  CONSTRAINT vendas_itens_pkey PRIMARY KEY (id),
  CONSTRAINT vendas_itens_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id),
  CONSTRAINT vendas_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id),
  CONSTRAINT vendas_itens_lote_id_fkey FOREIGN KEY (lote_id) REFERENCES public.produto_lotes(id)
);

-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE auth.audit_log_entries (
  instance_id uuid,
  id uuid NOT NULL,
  payload json,
  created_at timestamp with time zone,
  ip_address character varying NOT NULL DEFAULT ''::character varying,
  CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.flow_state (
  id uuid NOT NULL,
  user_id uuid,
  auth_code text NOT NULL,
  code_challenge_method USER-DEFINED NOT NULL,
  code_challenge text NOT NULL,
  provider_type text NOT NULL,
  provider_access_token text,
  provider_refresh_token text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  authentication_method text NOT NULL,
  auth_code_issued_at timestamp with time zone,
  CONSTRAINT flow_state_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.identities (
  provider_id text NOT NULL,
  user_id uuid NOT NULL,
  identity_data jsonb NOT NULL,
  provider text NOT NULL,
  last_sign_in_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  email text DEFAULT lower((identity_data ->> 'email'::text)),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT identities_pkey PRIMARY KEY (id),
  CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.instances (
  id uuid NOT NULL,
  uuid uuid,
  raw_base_config text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  CONSTRAINT instances_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.mfa_amr_claims (
  session_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL,
  updated_at timestamp with time zone NOT NULL,
  authentication_method text NOT NULL,
  id uuid NOT NULL,
  CONSTRAINT mfa_amr_claims_pkey PRIMARY KEY (id),
  CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id)
);
CREATE TABLE auth.mfa_challenges (
  id uuid NOT NULL,
  factor_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL,
  verified_at timestamp with time zone,
  ip_address inet NOT NULL,
  otp_code text,
  web_authn_session_data jsonb,
  CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id),
  CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id)
);
CREATE TABLE auth.mfa_factors (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  friendly_name text,
  factor_type USER-DEFINED NOT NULL,
  status USER-DEFINED NOT NULL,
  created_at timestamp with time zone NOT NULL,
  updated_at timestamp with time zone NOT NULL,
  secret text,
  phone text,
  last_challenged_at timestamp with time zone UNIQUE,
  web_authn_credential jsonb,
  web_authn_aaguid uuid,
  last_webauthn_challenge_data jsonb,
  CONSTRAINT mfa_factors_pkey PRIMARY KEY (id),
  CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.oauth_authorizations (
  id uuid NOT NULL,
  authorization_id text NOT NULL UNIQUE,
  client_id uuid NOT NULL,
  user_id uuid,
  redirect_uri text NOT NULL CHECK (char_length(redirect_uri) <= 2048),
  scope text NOT NULL CHECK (char_length(scope) <= 4096),
  state text CHECK (char_length(state) <= 4096),
  resource text CHECK (char_length(resource) <= 2048),
  code_challenge text CHECK (char_length(code_challenge) <= 128),
  code_challenge_method USER-DEFINED,
  response_type USER-DEFINED NOT NULL DEFAULT 'code'::auth.oauth_response_type,
  status USER-DEFINED NOT NULL DEFAULT 'pending'::auth.oauth_authorization_status,
  authorization_code text UNIQUE CHECK (char_length(authorization_code) <= 255),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + '00:03:00'::interval),
  approved_at timestamp with time zone,
  nonce text CHECK (char_length(nonce) <= 255),
  CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id),
  CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id),
  CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.oauth_client_states (
  id uuid NOT NULL,
  provider_type text NOT NULL,
  code_verifier text,
  created_at timestamp with time zone NOT NULL,
  CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.oauth_clients (
  id uuid NOT NULL,
  client_secret_hash text,
  registration_type USER-DEFINED NOT NULL,
  redirect_uris text NOT NULL,
  grant_types text NOT NULL,
  client_name text CHECK (char_length(client_name) <= 1024),
  client_uri text CHECK (char_length(client_uri) <= 2048),
  logo_uri text CHECK (char_length(logo_uri) <= 2048),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  client_type USER-DEFINED NOT NULL DEFAULT 'confidential'::auth.oauth_client_type,
  CONSTRAINT oauth_clients_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.oauth_consents (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  client_id uuid NOT NULL,
  scopes text NOT NULL CHECK (char_length(scopes) <= 2048),
  granted_at timestamp with time zone NOT NULL DEFAULT now(),
  revoked_at timestamp with time zone,
  CONSTRAINT oauth_consents_pkey PRIMARY KEY (id),
  CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id)
);
CREATE TABLE auth.one_time_tokens (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  token_type USER-DEFINED NOT NULL,
  token_hash text NOT NULL CHECK (char_length(token_hash) > 0),
  relates_to text NOT NULL,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  updated_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.refresh_tokens (
  instance_id uuid,
  id bigint NOT NULL DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass),
  token character varying UNIQUE,
  user_id character varying,
  revoked boolean,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  parent character varying,
  session_id uuid,
  CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id)
);
CREATE TABLE auth.saml_providers (
  id uuid NOT NULL,
  sso_provider_id uuid NOT NULL,
  entity_id text NOT NULL UNIQUE CHECK (char_length(entity_id) > 0),
  metadata_xml text NOT NULL CHECK (char_length(metadata_xml) > 0),
  metadata_url text CHECK (metadata_url = NULL::text OR char_length(metadata_url) > 0),
  attribute_mapping jsonb,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  name_id_format text,
  CONSTRAINT saml_providers_pkey PRIMARY KEY (id),
  CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id)
);
CREATE TABLE auth.saml_relay_states (
  id uuid NOT NULL,
  sso_provider_id uuid NOT NULL,
  request_id text NOT NULL CHECK (char_length(request_id) > 0),
  for_email text,
  redirect_to text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  flow_state_id uuid,
  CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id),
  CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id),
  CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id)
);
CREATE TABLE auth.schema_migrations (
  version character varying NOT NULL,
  CONSTRAINT schema_migrations_pkey PRIMARY KEY (version)
);
CREATE TABLE auth.sessions (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  factor_id uuid,
  aal USER-DEFINED,
  not_after timestamp with time zone,
  refreshed_at timestamp without time zone,
  user_agent text,
  ip inet,
  tag text,
  oauth_client_id uuid,
  refresh_token_hmac_key text,
  refresh_token_counter bigint,
  scopes text CHECK (char_length(scopes) <= 4096),
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id)
);
CREATE TABLE auth.sso_domains (
  id uuid NOT NULL,
  sso_provider_id uuid NOT NULL,
  domain text NOT NULL CHECK (char_length(domain) > 0),
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  CONSTRAINT sso_domains_pkey PRIMARY KEY (id),
  CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id)
);
CREATE TABLE auth.sso_providers (
  id uuid NOT NULL,
  resource_id text CHECK (resource_id = NULL::text OR char_length(resource_id) > 0),
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  disabled boolean,
  CONSTRAINT sso_providers_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.users (
  instance_id uuid,
  id uuid NOT NULL,
  aud character varying,
  role character varying,
  email character varying,
  encrypted_password character varying,
  email_confirmed_at timestamp with time zone,
  invited_at timestamp with time zone,
  confirmation_token character varying,
  confirmation_sent_at timestamp with time zone,
  recovery_token character varying,
  recovery_sent_at timestamp with time zone,
  email_change_token_new character varying,
  email_change character varying,
  email_change_sent_at timestamp with time zone,
  last_sign_in_at timestamp with time zone,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  is_super_admin boolean,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  phone text DEFAULT NULL::character varying UNIQUE,
  phone_confirmed_at timestamp with time zone,
  phone_change text DEFAULT ''::character varying,
  phone_change_token character varying DEFAULT ''::character varying,
  phone_change_sent_at timestamp with time zone,
  confirmed_at timestamp with time zone DEFAULT LEAST(email_confirmed_at, phone_confirmed_at),
  email_change_token_current character varying DEFAULT ''::character varying,
  email_change_confirm_status smallint DEFAULT 0 CHECK (email_change_confirm_status >= 0 AND email_change_confirm_status <= 2),
  banned_until timestamp with time zone,
  reauthentication_token character varying DEFAULT ''::character varying,
  reauthentication_sent_at timestamp with time zone,
  is_sso_user boolean NOT NULL DEFAULT false,
  deleted_at timestamp with time zone,
  is_anonymous boolean NOT NULL DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);
-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE auth.audit_log_entries (
  instance_id uuid,
  id uuid NOT NULL,
  payload json,
  created_at timestamp with time zone,
  ip_address character varying NOT NULL DEFAULT ''::character varying,
  CONSTRAINT audit_log_entries_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.flow_state (
  id uuid NOT NULL,
  user_id uuid,
  auth_code text NOT NULL,
  code_challenge_method USER-DEFINED NOT NULL,
  code_challenge text NOT NULL,
  provider_type text NOT NULL,
  provider_access_token text,
  provider_refresh_token text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  authentication_method text NOT NULL,
  auth_code_issued_at timestamp with time zone,
  CONSTRAINT flow_state_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.identities (
  provider_id text NOT NULL,
  user_id uuid NOT NULL,
  identity_data jsonb NOT NULL,
  provider text NOT NULL,
  last_sign_in_at timestamp with time zone,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  email text DEFAULT lower((identity_data ->> 'email'::text)),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT identities_pkey PRIMARY KEY (id),
  CONSTRAINT identities_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.instances (
  id uuid NOT NULL,
  uuid uuid,
  raw_base_config text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  CONSTRAINT instances_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.mfa_amr_claims (
  session_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL,
  updated_at timestamp with time zone NOT NULL,
  authentication_method text NOT NULL,
  id uuid NOT NULL,
  CONSTRAINT mfa_amr_claims_pkey PRIMARY KEY (id),
  CONSTRAINT mfa_amr_claims_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id)
);
CREATE TABLE auth.mfa_challenges (
  id uuid NOT NULL,
  factor_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL,
  verified_at timestamp with time zone,
  ip_address inet NOT NULL,
  otp_code text,
  web_authn_session_data jsonb,
  CONSTRAINT mfa_challenges_pkey PRIMARY KEY (id),
  CONSTRAINT mfa_challenges_auth_factor_id_fkey FOREIGN KEY (factor_id) REFERENCES auth.mfa_factors(id)
);
CREATE TABLE auth.mfa_factors (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  friendly_name text,
  factor_type USER-DEFINED NOT NULL,
  status USER-DEFINED NOT NULL,
  created_at timestamp with time zone NOT NULL,
  updated_at timestamp with time zone NOT NULL,
  secret text,
  phone text,
  last_challenged_at timestamp with time zone UNIQUE,
  web_authn_credential jsonb,
  web_authn_aaguid uuid,
  last_webauthn_challenge_data jsonb,
  CONSTRAINT mfa_factors_pkey PRIMARY KEY (id),
  CONSTRAINT mfa_factors_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.oauth_authorizations (
  id uuid NOT NULL,
  authorization_id text NOT NULL UNIQUE,
  client_id uuid NOT NULL,
  user_id uuid,
  redirect_uri text NOT NULL CHECK (char_length(redirect_uri) <= 2048),
  scope text NOT NULL CHECK (char_length(scope) <= 4096),
  state text CHECK (char_length(state) <= 4096),
  resource text CHECK (char_length(resource) <= 2048),
  code_challenge text CHECK (char_length(code_challenge) <= 128),
  code_challenge_method USER-DEFINED,
  response_type USER-DEFINED NOT NULL DEFAULT 'code'::auth.oauth_response_type,
  status USER-DEFINED NOT NULL DEFAULT 'pending'::auth.oauth_authorization_status,
  authorization_code text UNIQUE CHECK (char_length(authorization_code) <= 255),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  expires_at timestamp with time zone NOT NULL DEFAULT (now() + '00:03:00'::interval),
  approved_at timestamp with time zone,
  nonce text CHECK (char_length(nonce) <= 255),
  CONSTRAINT oauth_authorizations_pkey PRIMARY KEY (id),
  CONSTRAINT oauth_authorizations_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id),
  CONSTRAINT oauth_authorizations_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.oauth_client_states (
  id uuid NOT NULL,
  provider_type text NOT NULL,
  code_verifier text,
  created_at timestamp with time zone NOT NULL,
  CONSTRAINT oauth_client_states_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.oauth_clients (
  id uuid NOT NULL,
  client_secret_hash text,
  registration_type USER-DEFINED NOT NULL,
  redirect_uris text NOT NULL,
  grant_types text NOT NULL,
  client_name text CHECK (char_length(client_name) <= 1024),
  client_uri text CHECK (char_length(client_uri) <= 2048),
  logo_uri text CHECK (char_length(logo_uri) <= 2048),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  deleted_at timestamp with time zone,
  client_type USER-DEFINED NOT NULL DEFAULT 'confidential'::auth.oauth_client_type,
  CONSTRAINT oauth_clients_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.oauth_consents (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  client_id uuid NOT NULL,
  scopes text NOT NULL CHECK (char_length(scopes) <= 2048),
  granted_at timestamp with time zone NOT NULL DEFAULT now(),
  revoked_at timestamp with time zone,
  CONSTRAINT oauth_consents_pkey PRIMARY KEY (id),
  CONSTRAINT oauth_consents_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT oauth_consents_client_id_fkey FOREIGN KEY (client_id) REFERENCES auth.oauth_clients(id)
);
CREATE TABLE auth.one_time_tokens (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  token_type USER-DEFINED NOT NULL,
  token_hash text NOT NULL CHECK (char_length(token_hash) > 0),
  relates_to text NOT NULL,
  created_at timestamp without time zone NOT NULL DEFAULT now(),
  updated_at timestamp without time zone NOT NULL DEFAULT now(),
  CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE auth.refresh_tokens (
  instance_id uuid,
  id bigint NOT NULL DEFAULT nextval('auth.refresh_tokens_id_seq'::regclass),
  token character varying UNIQUE,
  user_id character varying,
  revoked boolean,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  parent character varying,
  session_id uuid,
  CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT refresh_tokens_session_id_fkey FOREIGN KEY (session_id) REFERENCES auth.sessions(id)
);
CREATE TABLE auth.saml_providers (
  id uuid NOT NULL,
  sso_provider_id uuid NOT NULL,
  entity_id text NOT NULL UNIQUE CHECK (char_length(entity_id) > 0),
  metadata_xml text NOT NULL CHECK (char_length(metadata_xml) > 0),
  metadata_url text CHECK (metadata_url = NULL::text OR char_length(metadata_url) > 0),
  attribute_mapping jsonb,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  name_id_format text,
  CONSTRAINT saml_providers_pkey PRIMARY KEY (id),
  CONSTRAINT saml_providers_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id)
);
CREATE TABLE auth.saml_relay_states (
  id uuid NOT NULL,
  sso_provider_id uuid NOT NULL,
  request_id text NOT NULL CHECK (char_length(request_id) > 0),
  for_email text,
  redirect_to text,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  flow_state_id uuid,
  CONSTRAINT saml_relay_states_pkey PRIMARY KEY (id),
  CONSTRAINT saml_relay_states_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id),
  CONSTRAINT saml_relay_states_flow_state_id_fkey FOREIGN KEY (flow_state_id) REFERENCES auth.flow_state(id)
);
CREATE TABLE auth.schema_migrations (
  version character varying NOT NULL,
  CONSTRAINT schema_migrations_pkey PRIMARY KEY (version)
);
CREATE TABLE auth.sessions (
  id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  factor_id uuid,
  aal USER-DEFINED,
  not_after timestamp with time zone,
  refreshed_at timestamp without time zone,
  user_agent text,
  ip inet,
  tag text,
  oauth_client_id uuid,
  refresh_token_hmac_key text,
  refresh_token_counter bigint,
  scopes text CHECK (char_length(scopes) <= 4096),
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT sessions_oauth_client_id_fkey FOREIGN KEY (oauth_client_id) REFERENCES auth.oauth_clients(id)
);
CREATE TABLE auth.sso_domains (
  id uuid NOT NULL,
  sso_provider_id uuid NOT NULL,
  domain text NOT NULL CHECK (char_length(domain) > 0),
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  CONSTRAINT sso_domains_pkey PRIMARY KEY (id),
  CONSTRAINT sso_domains_sso_provider_id_fkey FOREIGN KEY (sso_provider_id) REFERENCES auth.sso_providers(id)
);
CREATE TABLE auth.sso_providers (
  id uuid NOT NULL,
  resource_id text CHECK (resource_id = NULL::text OR char_length(resource_id) > 0),
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  disabled boolean,
  CONSTRAINT sso_providers_pkey PRIMARY KEY (id)
);
CREATE TABLE auth.users (
  instance_id uuid,
  id uuid NOT NULL,
  aud character varying,
  role character varying,
  email character varying,
  encrypted_password character varying,
  email_confirmed_at timestamp with time zone,
  invited_at timestamp with time zone,
  confirmation_token character varying,
  confirmation_sent_at timestamp with time zone,
  recovery_token character varying,
  recovery_sent_at timestamp with time zone,
  email_change_token_new character varying,
  email_change character varying,
  email_change_sent_at timestamp with time zone,
  last_sign_in_at timestamp with time zone,
  raw_app_meta_data jsonb,
  raw_user_meta_data jsonb,
  is_super_admin boolean,
  created_at timestamp with time zone,
  updated_at timestamp with time zone,
  phone text DEFAULT NULL::character varying UNIQUE,
  phone_confirmed_at timestamp with time zone,
  phone_change text DEFAULT ''::character varying,
  phone_change_token character varying DEFAULT ''::character varying,
  phone_change_sent_at timestamp with time zone,
  confirmed_at timestamp with time zone DEFAULT LEAST(email_confirmed_at, phone_confirmed_at),
  email_change_token_current character varying DEFAULT ''::character varying,
  email_change_confirm_status smallint DEFAULT 0 CHECK (email_change_confirm_status >= 0 AND email_change_confirm_status <= 2),
  banned_until timestamp with time zone,
  reauthentication_token character varying DEFAULT ''::character varying,
  reauthentication_sent_at timestamp with time zone,
  is_sso_user boolean NOT NULL DEFAULT false,
  deleted_at timestamp with time zone,
  is_anonymous boolean NOT NULL DEFAULT false,
  CONSTRAINT users_pkey PRIMARY KEY (id)
);

-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE realtime.messages (
  topic text NOT NULL,
  extension text NOT NULL,
  payload jsonb,
  event text,
  private boolean DEFAULT false,
  updated_at timestamp without time zone NOT NULL DEFAULT now(),
  inserted_at timestamp without time zone NOT NULL DEFAULT now(),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  CONSTRAINT messages_pkey PRIMARY KEY (id, inserted_at)
);
CREATE TABLE realtime.schema_migrations (
  version bigint NOT NULL,
  inserted_at timestamp without time zone,
  CONSTRAINT schema_migrations_pkey PRIMARY KEY (version)
);
CREATE TABLE realtime.subscription (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  subscription_id uuid NOT NULL,
  entity regclass NOT NULL,
  filters ARRAY NOT NULL DEFAULT '{}'::realtime.user_defined_filter[],
  claims jsonb NOT NULL,
  claims_role regrole NOT NULL DEFAULT realtime.to_regrole((claims ->> 'role'::text)),
  created_at timestamp without time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  action_filter text DEFAULT '*'::text CHECK (action_filter = ANY (ARRAY['*'::text, 'INSERT'::text, 'UPDATE'::text, 'DELETE'::text])),
  CONSTRAINT subscription_pkey PRIMARY KEY (id)
);

-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE storage.buckets (
  id text NOT NULL,
  name text NOT NULL,
  owner uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  public boolean DEFAULT false,
  avif_autodetection boolean DEFAULT false,
  file_size_limit bigint,
  allowed_mime_types ARRAY,
  owner_id text,
  type USER-DEFINED NOT NULL DEFAULT 'STANDARD'::storage.buckettype,
  CONSTRAINT buckets_pkey PRIMARY KEY (id)
);
CREATE TABLE storage.buckets_analytics (
  name text NOT NULL,
  type USER-DEFINED NOT NULL DEFAULT 'ANALYTICS'::storage.buckettype,
  format text NOT NULL DEFAULT 'ICEBERG'::text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  deleted_at timestamp with time zone,
  CONSTRAINT buckets_analytics_pkey PRIMARY KEY (id)
);
CREATE TABLE storage.buckets_vectors (
  id text NOT NULL,
  type USER-DEFINED NOT NULL DEFAULT 'VECTOR'::storage.buckettype,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT buckets_vectors_pkey PRIMARY KEY (id)
);
CREATE TABLE storage.migrations (
  id integer NOT NULL,
  name character varying NOT NULL UNIQUE,
  hash character varying NOT NULL,
  executed_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT migrations_pkey PRIMARY KEY (id)
);
CREATE TABLE storage.objects (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  bucket_id text,
  name text,
  owner uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  last_accessed_at timestamp with time zone DEFAULT now(),
  metadata jsonb,
  path_tokens ARRAY DEFAULT string_to_array(name, '/'::text),
  version text,
  owner_id text,
  user_metadata jsonb,
  level integer,
  CONSTRAINT objects_pkey PRIMARY KEY (id),
  CONSTRAINT objects_bucketId_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id)
);
CREATE TABLE storage.prefixes (
  bucket_id text NOT NULL,
  name text NOT NULL,
  level integer NOT NULL DEFAULT storage.get_level(name),
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT prefixes_pkey PRIMARY KEY (bucket_id, level, name),
  CONSTRAINT prefixes_bucketId_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id)
);
CREATE TABLE storage.s3_multipart_uploads (
  id text NOT NULL,
  in_progress_size bigint NOT NULL DEFAULT 0,
  upload_signature text NOT NULL,
  bucket_id text NOT NULL,
  key text NOT NULL,
  version text NOT NULL,
  owner_id text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  user_metadata jsonb,
  CONSTRAINT s3_multipart_uploads_pkey PRIMARY KEY (id),
  CONSTRAINT s3_multipart_uploads_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id)
);
CREATE TABLE storage.s3_multipart_uploads_parts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  upload_id text NOT NULL,
  size bigint NOT NULL DEFAULT 0,
  part_number integer NOT NULL,
  bucket_id text NOT NULL,
  key text NOT NULL,
  etag text NOT NULL,
  owner_id text,
  version text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT s3_multipart_uploads_parts_pkey PRIMARY KEY (id),
  CONSTRAINT s3_multipart_uploads_parts_upload_id_fkey FOREIGN KEY (upload_id) REFERENCES storage.s3_multipart_uploads(id),
  CONSTRAINT s3_multipart_uploads_parts_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets(id)
);
CREATE TABLE storage.vector_indexes (
  id text NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  bucket_id text NOT NULL,
  data_type text NOT NULL,
  dimension integer NOT NULL,
  distance_metric text NOT NULL,
  metadata_configuration jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT vector_indexes_pkey PRIMARY KEY (id),
  CONSTRAINT vector_indexes_bucket_id_fkey FOREIGN KEY (bucket_id) REFERENCES storage.buckets_vectors(id)
);
-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE vault.secrets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text,
  description text NOT NULL DEFAULT ''::text,
  secret text NOT NULL,
  key_id uuid,
  nonce bytea DEFAULT vault._crypto_aead_det_noncegen(),
  created_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT secrets_pkey PRIMARY KEY (id)
);

