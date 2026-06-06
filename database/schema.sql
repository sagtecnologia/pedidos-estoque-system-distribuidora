-- DROP SCHEMA public;

CREATE SCHEMA public AUTHORIZATION postgres;

-- DROP TYPE public."documento_fiscal_status";

CREATE TYPE public."documento_fiscal_status" AS ENUM (
	'SEM_DOCUMENTO_FISCAL',
	'PENDENTE_EMISSAO',
	'EMITIDA_NFCE',
	'EMITIDA_NFE',
	'REJEITADA_SEFAZ',
	'CANCELADA');

-- DROP TYPE public."pagamento_forma";

CREATE TYPE public."pagamento_forma" AS ENUM (
	'DINHEIRO',
	'CARTAO_CREDITO',
	'CARTAO_DEBITO',
	'PIX',
	'CHEQUE',
	'VALE',
	'PRAZO');

-- DROP TYPE public."unidade_medida";

CREATE TYPE public."unidade_medida" AS ENUM (
	'UN',
	'CX',
	'FD',
	'DZ',
	'L',
	'KG',
	'PCT');

-- DROP TYPE public."user_role";

CREATE TYPE public."user_role" AS ENUM (
	'ADMIN',
	'GERENTE',
	'VENDEDOR',
	'OPERADOR_CAIXA',
	'ESTOQUISTA',
	'COMPRADOR',
	'APROVADOR');

-- DROP TYPE public."venda_status";

CREATE TYPE public."venda_status" AS ENUM (
	'ABERTA',
	'FINALIZADA',
	'CANCELADA',
	'DEVOLVIDA');

-- DROP SEQUENCE public.vendas_numero_seq;

CREATE SEQUENCE public.vendas_numero_seq
	INCREMENT BY 1
	MINVALUE 1
	MAXVALUE 9223372036854775807
	START 1001
	CACHE 1
	NO CYCLE;

-- Permissions

ALTER SEQUENCE public.vendas_numero_seq OWNER TO postgres;
GRANT ALL ON SEQUENCE public.vendas_numero_seq TO postgres;
GRANT USAGE ON SEQUENCE public.vendas_numero_seq TO anon;
GRANT USAGE ON SEQUENCE public.vendas_numero_seq TO authenticated;
GRANT USAGE ON SEQUENCE public.vendas_numero_seq TO service_role;
-- public.caixas definição

-- Drop table

-- DROP TABLE public.caixas;

CREATE TABLE public.caixas ( id uuid DEFAULT uuid_generate_v4() NOT NULL, numero int4 NOT NULL, descricao varchar(100) NULL, serie_pdv varchar(20) NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, nome varchar(100) NULL, impressora_nfce varchar(100) NULL, impressora_cupom varchar(100) NULL, terminal varchar(100) NULL, CONSTRAINT caixas_numero_key UNIQUE (numero), CONSTRAINT caixas_pkey PRIMARY KEY (id));
CREATE INDEX idx_caixas_ativo ON public.caixas USING btree (ativo);
CREATE INDEX idx_caixas_numero ON public.caixas USING btree (numero);

-- Permissions

ALTER TABLE public.caixas OWNER TO postgres;
GRANT ALL ON TABLE public.caixas TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixas TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixas TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixas TO service_role;


-- public.categorias definição

-- Drop table

-- DROP TABLE public.categorias;

CREATE TABLE public.categorias ( id uuid DEFAULT uuid_generate_v4() NOT NULL, nome varchar(100) NOT NULL, descricao text NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT categorias_nome_key UNIQUE (nome), CONSTRAINT categorias_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE public.categorias OWNER TO postgres;
GRANT ALL ON TABLE public.categorias TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.categorias TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.categorias TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.categorias TO service_role;


-- public.clientes definição

-- Drop table

-- DROP TABLE public.clientes;

CREATE TABLE public.clientes ( id uuid DEFAULT uuid_generate_v4() NOT NULL, nome varchar(255) NOT NULL, tipo varchar(10) NULL, cpf_cnpj varchar(18) NULL, inscricao_estadual varchar(20) NULL, endereco text NULL, numero varchar(10) NULL, complemento text NULL, bairro varchar(100) NULL, cidade varchar(100) NULL, estado varchar(2) NULL, cep varchar(10) NULL, telefone varchar(20) NULL, whatsapp varchar(20) NULL, email varchar(100) NULL, limite_credito numeric(12, 2) DEFAULT 0.00 NULL, saldo_devedor numeric(12, 2) DEFAULT 0.00 NULL, tabela_preco_custom bool DEFAULT false NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT clientes_cpf_cnpj_key UNIQUE (cpf_cnpj), CONSTRAINT clientes_pkey PRIMARY KEY (id));
CREATE INDEX idx_clientes_ativo ON public.clientes USING btree (ativo);

-- Table Triggers

create trigger update_clientes_updated_at before
update
    on
    public.clientes for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.clientes OWNER TO postgres;
GRANT ALL ON TABLE public.clientes TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.clientes TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.clientes TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.clientes TO service_role;


-- public.empresa_config definição

-- Drop table

-- DROP TABLE public.empresa_config;

CREATE TABLE public.empresa_config ( id uuid DEFAULT uuid_generate_v4() NOT NULL, nome_empresa varchar(200) NOT NULL, razao_social varchar(200) NULL, cnpj varchar(18) NULL, inscricao_estadual varchar(20) NULL, inscricao_municipal varchar(20) NULL, logo_url text NULL, endereco text NULL, numero varchar(10) NULL, complemento text NULL, bairro varchar(100) NULL, cidade varchar(100) NULL, estado varchar(2) NULL, cep varchar(10) NULL, telefone varchar(20) NULL, email varchar(100) NULL, website varchar(200) NULL, regime_tributario varchar(1) NULL, cnae varchar(10) NULL, codigo_municipio varchar(7) NULL, logradouro varchar(255) NULL, nfe_ambiente varchar(1) DEFAULT '2'::character varying NULL, nfe_token text NULL, nfce_serie int4 DEFAULT 1 NULL, nfe_serie int4 DEFAULT 1 NULL, nfce_numero int4 DEFAULT 1 NULL, nfe_numero int4 DEFAULT 1 NULL, pdv_emitir_nfce bool DEFAULT false NULL, pdv_imprimir_cupom bool DEFAULT true NULL, pdv_permitir_venda_zerado bool DEFAULT false NULL, pdv_desconto_maximo bool DEFAULT false NULL, pdv_desconto_limite numeric(5, 2) DEFAULT 10.00 NULL, pdv_mensagem_cupom text NULL, whatsapp_api_provider varchar(50) NULL, whatsapp_numero_origem varchar(20) NULL, whatsapp_api_url text NULL, whatsapp_api_key text NULL, whatsapp_instance_id varchar(100) NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, certificado_digital text NULL, senha_certificado varchar(255) NULL, regime_tributario_codigo varchar(1) NULL, natureza_operacao_padrao varchar(150) DEFAULT 'VENDA'::character varying NULL, sincronizar_numero_nfce bool DEFAULT true NULL, ultimo_numero_nfce_sincronizado int4 DEFAULT 0 NULL, endereco_numero varchar(20) NULL, csc_id varchar(50) NULL, csc_token varchar(100) NULL, ambiente_nfe varchar(1) DEFAULT '2'::character varying NULL, serie_nfe varchar(5) DEFAULT '1'::character varying NULL, proximo_numero_nfe int4 DEFAULT 1 NULL, cor_primaria varchar(7) DEFAULT '#3B82F6'::character varying NULL, cor_secundaria varchar(7) DEFAULT '#10B981'::character varying NULL, habilitar_cupom_fiscal bool DEFAULT false NULL, habilitar_nfce bool DEFAULT false NULL, alerta_estoque_minimo bool DEFAULT true NULL, dias_alerta_validade int4 DEFAULT 30 NULL, focusnfe_token text NULL, focusnfe_ambiente int4 DEFAULT 2 NULL, certificado_validade date NULL, pdv_emitir_nfce_automatico bool DEFAULT false NULL, focusnfe_token_homologacao text NULL, api_fiscal_provider varchar(20) DEFAULT 'focus_nfe'::character varying NULL, nuvemfiscal_client_id text NULL, nuvemfiscal_client_secret text NULL, nuvemfiscal_access_token text NULL, nuvemfiscal_token_expiry timestamp NULL, impressora_nfce_padrao varchar NULL, impressora_cupom_padrao varchar NULL, CONSTRAINT empresa_config_api_fiscal_provider_check CHECK (((api_fiscal_provider)::text = ANY ((ARRAY['focus_nfe'::character varying, 'nuvem_fiscal'::character varying, 'sefaz_direta'::character varying])::text[]))), CONSTRAINT empresa_config_cnpj_key UNIQUE (cnpj), CONSTRAINT empresa_config_pkey PRIMARY KEY (id));
CREATE INDEX idx_empresa_config_api_provider ON public.empresa_config USING btree (api_fiscal_provider);

-- Column comments

COMMENT ON COLUMN public.empresa_config.nfce_serie IS 'Série utilizada para emissão de NFC-e';
COMMENT ON COLUMN public.empresa_config.nfe_serie IS 'Série utilizada para emissão de NF-e';
COMMENT ON COLUMN public.empresa_config.nfce_numero IS 'Próximo número sequencial de NFC-e';
COMMENT ON COLUMN public.empresa_config.nfe_numero IS 'Próximo número sequencial de NF-e';
COMMENT ON COLUMN public.empresa_config.csc_id IS 'ID do Código de Segurança do Contribuinte (NFC-e)';
COMMENT ON COLUMN public.empresa_config.csc_token IS 'Token do Código de Segurança do Contribuinte (NFC-e)';
COMMENT ON COLUMN public.empresa_config.focusnfe_token IS 'Token Focus NFe para ambiente de PRODUÇÃO';
COMMENT ON COLUMN public.empresa_config.focusnfe_ambiente IS '1=Produção, 2=Homologação';
COMMENT ON COLUMN public.empresa_config.certificado_validade IS 'Data de validade do certificado digital A1';
COMMENT ON COLUMN public.empresa_config.pdv_emitir_nfce_automatico IS 'Se true, emite NFC-e automaticamente ao finalizar venda no PDV';
COMMENT ON COLUMN public.empresa_config.focusnfe_token_homologacao IS 'Token Focus NFe para ambiente de HOMOLOGAÇÃO';
COMMENT ON COLUMN public.empresa_config.api_fiscal_provider IS 'Provedor de API fiscal a ser utilizado: focus_nfe, nuvem_fiscal ou sefaz_direta';
COMMENT ON COLUMN public.empresa_config.nuvemfiscal_client_id IS 'Client ID da API Nuvem Fiscal (OAuth2)';
COMMENT ON COLUMN public.empresa_config.nuvemfiscal_client_secret IS 'Client Secret da API Nuvem Fiscal (OAuth2)';
COMMENT ON COLUMN public.empresa_config.nuvemfiscal_access_token IS 'Access Token OAuth2 em cache';
COMMENT ON COLUMN public.empresa_config.nuvemfiscal_token_expiry IS 'Data/hora de expiração do access token';
COMMENT ON COLUMN public.empresa_config.impressora_nfce_padrao IS 'Nome da impressora fiscal padrão para NFC-e. Usado quando o caixa não tem impressora específica configurada.';
COMMENT ON COLUMN public.empresa_config.impressora_cupom_padrao IS 'Nome da impressora térmica padrão para cupons. Usado quando o caixa não tem impressora específica configurada.';

-- Table Triggers

create trigger update_empresa_config_updated_at before
update
    on
    public.empresa_config for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.empresa_config OWNER TO postgres;
GRANT ALL ON TABLE public.empresa_config TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.empresa_config TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.empresa_config TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.empresa_config TO service_role;


-- public.estoque_backups definição

-- Drop table

-- DROP TABLE public.estoque_backups;

CREATE TABLE public.estoque_backups ( id uuid DEFAULT gen_random_uuid() NOT NULL, data_backup timestamptz DEFAULT now() NULL, total_produtos int4 NULL, total_unidades numeric NULL, dados_backup jsonb NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT estoque_backups_pkey PRIMARY KEY (id));
CREATE INDEX idx_estoque_backups_data_backup ON public.estoque_backups USING btree (data_backup DESC);
COMMENT ON TABLE public.estoque_backups IS 'Backup de estoque antes de reprocessamento - contém snapshot JSON dos produtos e suas quantidades';

-- Permissions

ALTER TABLE public.estoque_backups OWNER TO postgres;
GRANT ALL ON TABLE public.estoque_backups TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.estoque_backups TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.estoque_backups TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.estoque_backups TO service_role;


-- public.fornecedores definição

-- Drop table

-- DROP TABLE public.fornecedores;

CREATE TABLE public.fornecedores ( id uuid DEFAULT uuid_generate_v4() NOT NULL, nome varchar(255) NOT NULL, cnpj varchar(18) NULL, inscricao_estadual varchar(20) NULL, endereco text NULL, numero varchar(10) NULL, bairro varchar(100) NULL, cidade varchar(100) NULL, estado varchar(2) NULL, cep varchar(10) NULL, telefone varchar(20) NULL, email varchar(100) NULL, contato_nome varchar(255) NULL, contato_telefone varchar(20) NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, razao_social varchar(150) NOT NULL, nome_fantasia varchar(150) NULL, complemento varchar(100) NULL, usuario_id uuid NULL, site varchar(200) NULL, banco varchar(100) NULL, agencia varchar(20) NULL, conta varchar(30) NULL, pix varchar(100) NULL, observacoes text NULL, CONSTRAINT fornecedores_cnpj_key UNIQUE (cnpj), CONSTRAINT fornecedores_pkey PRIMARY KEY (id));
CREATE INDEX idx_fornecedores_ativo ON public.fornecedores USING btree (ativo);
CREATE INDEX idx_fornecedores_cnpj ON public.fornecedores USING btree (cnpj);
CREATE INDEX idx_fornecedores_razao_social ON public.fornecedores USING btree (razao_social);

-- Permissions

ALTER TABLE public.fornecedores OWNER TO postgres;
GRANT ALL ON TABLE public.fornecedores TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.fornecedores TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.fornecedores TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.fornecedores TO service_role;


-- public.marcas definição

-- Drop table

-- DROP TABLE public.marcas;

CREATE TABLE public.marcas ( id uuid DEFAULT uuid_generate_v4() NOT NULL, nome varchar(100) NOT NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, descricao text NULL, CONSTRAINT marcas_nome_key UNIQUE (nome), CONSTRAINT marcas_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE public.marcas OWNER TO postgres;
GRANT ALL ON TABLE public.marcas TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.marcas TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.marcas TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.marcas TO service_role;


-- public.pedidos_compra definição

-- Drop table

-- DROP TABLE public.pedidos_compra;

CREATE TABLE public.pedidos_compra ( id uuid NOT NULL, numero varchar(20) NOT NULL, fornecedor_id uuid NOT NULL, usuario_id uuid NOT NULL, subtotal numeric(12, 2) DEFAULT 0 NULL, desconto numeric(12, 2) DEFAULT 0 NULL, frete numeric(12, 2) DEFAULT 0 NULL, outras_despesas numeric(12, 2) DEFAULT 0 NULL, total numeric(12, 2) DEFAULT 0 NULL, data_pedido date DEFAULT CURRENT_DATE NULL, data_previsao date NULL, data_recebimento date NULL, nf_numero varchar(50) NULL, nf_serie varchar(10) NULL, nf_chave varchar(50) NULL, status varchar(20) DEFAULT 'PENDENTE'::character varying NULL, observacoes text NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT pedidos_compra_numero_key UNIQUE (numero), CONSTRAINT pedidos_compra_pkey PRIMARY KEY (id), CONSTRAINT pedidos_compra_status_check CHECK (((status)::text = ANY ((ARRAY['PENDENTE'::character varying, 'APROVADO'::character varying, 'RECEBIDO'::character varying, 'CANCELADO'::character varying])::text[]))));
CREATE INDEX idx_pedidos_compra_data ON public.pedidos_compra USING btree (data_pedido);
CREATE INDEX idx_pedidos_compra_fornecedor ON public.pedidos_compra USING btree (fornecedor_id);
CREATE INDEX idx_pedidos_compra_status ON public.pedidos_compra USING btree (status);

-- Permissions

ALTER TABLE public.pedidos_compra OWNER TO postgres;
GRANT ALL ON TABLE public.pedidos_compra TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pedidos_compra TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pedidos_compra TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pedidos_compra TO service_role;


-- public.users definição

-- Drop table

-- DROP TABLE public.users;

CREATE TABLE public.users ( id uuid DEFAULT uuid_generate_v4() NOT NULL, email varchar(255) NOT NULL, nome_completo varchar(255) NOT NULL, cpf varchar(14) NULL, "role" public."user_role" DEFAULT 'VENDEDOR'::user_role NOT NULL, telefone varchar(20) NULL, whatsapp varchar(20) NULL, ativo bool DEFAULT true NULL, email_confirmado bool DEFAULT false NULL, ultimo_login timestamptz NULL, senha_hash varchar(255) NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, full_name varchar(255) NULL, approved bool DEFAULT false NULL, approved_by uuid NULL, approved_at timestamptz NULL, CONSTRAINT users_cpf_key UNIQUE (cpf), CONSTRAINT users_email_key UNIQUE (email), CONSTRAINT users_pkey PRIMARY KEY (id));
CREATE INDEX idx_users_ativo ON public.users USING btree (ativo);
CREATE INDEX idx_users_email ON public.users USING btree (email);
CREATE INDEX idx_users_role ON public.users USING btree (role);

-- Table Triggers

create trigger update_users_updated_at before
update
    on
    public.users for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.users OWNER TO postgres;
GRANT ALL ON TABLE public.users TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.users TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.users TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.users TO service_role;


-- public.venda_itens definição

-- Drop table

-- DROP TABLE public.venda_itens;

CREATE TABLE public.venda_itens ( id uuid DEFAULT uuid_generate_v4() NOT NULL, venda_id uuid NOT NULL, produto_id uuid NOT NULL, lote_id uuid NULL, quantidade numeric(12, 3) NOT NULL, preco_unitario numeric(12, 2) NOT NULL, desconto_percentual numeric(5, 2) DEFAULT 0 NULL, desconto_valor numeric(12, 2) DEFAULT 0 NULL, subtotal numeric(12, 2) NOT NULL, cfop varchar(10) NULL, ncm varchar(10) NULL, cst_icms varchar(5) NULL, valor_icms numeric(12, 2) DEFAULT 0 NULL, created_at timestamptz DEFAULT now() NULL, preco_custo numeric(12, 2) NULL, CONSTRAINT venda_itens_pkey PRIMARY KEY (id));
CREATE INDEX idx_venda_itens_lote ON public.venda_itens USING btree (lote_id);
CREATE INDEX idx_venda_itens_produto ON public.venda_itens USING btree (produto_id);
CREATE INDEX idx_venda_itens_venda ON public.venda_itens USING btree (venda_id);

-- Column comments

COMMENT ON COLUMN public.venda_itens.preco_custo IS 'Preço de custo no momento da venda - usado para análise de lucro';

-- Table Triggers

create trigger trg_before_insert_venda_item_custo before
insert
    on
    public.venda_itens for each row execute function trg_venda_item_set_preco_custo();

-- Permissions

ALTER TABLE public.venda_itens OWNER TO postgres;
GRANT ALL ON TABLE public.venda_itens TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.venda_itens TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.venda_itens TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.venda_itens TO service_role;


-- public.venda_pagamentos definição

-- Drop table

-- DROP TABLE public.venda_pagamentos;

CREATE TABLE public.venda_pagamentos ( id uuid NOT NULL, venda_id uuid NOT NULL, forma_pagamento varchar(30) NOT NULL, valor numeric(12, 2) NOT NULL, bandeira varchar(50) NULL, nsu varchar(50) NULL, autorizacao varchar(50) NULL, parcelas int4 DEFAULT 1 NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT venda_pagamentos_pkey PRIMARY KEY (id));

-- Permissions

ALTER TABLE public.venda_pagamentos OWNER TO postgres;
GRANT ALL ON TABLE public.venda_pagamentos TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.venda_pagamentos TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.venda_pagamentos TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.venda_pagamentos TO service_role;


-- public.aliquotas_estaduais definição

-- Drop table

-- DROP TABLE public.aliquotas_estaduais;

CREATE TABLE public.aliquotas_estaduais ( id uuid DEFAULT uuid_generate_v4() NOT NULL, estado_origem varchar(2) NOT NULL, estado_destino varchar(2) NOT NULL, categoria_id uuid NULL, aliquota_icms numeric(5, 2) DEFAULT 0.00 NULL, aliquota_pis numeric(5, 2) DEFAULT 0.00 NULL, aliquota_cofins numeric(5, 2) DEFAULT 0.00 NULL, vigencia_inicio date NOT NULL, vigencia_fim date NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT aliquotas_estaduais_estado_origem_estado_destino_categoria__key UNIQUE (estado_origem, estado_destino, categoria_id, vigencia_inicio), CONSTRAINT aliquotas_estaduais_pkey PRIMARY KEY (id), CONSTRAINT aliquotas_estaduais_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id));

-- Permissions

ALTER TABLE public.aliquotas_estaduais OWNER TO postgres;
GRANT ALL ON TABLE public.aliquotas_estaduais TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.aliquotas_estaduais TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.aliquotas_estaduais TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.aliquotas_estaduais TO service_role;


-- public.auditoria_log definição

-- Drop table

-- DROP TABLE public.auditoria_log;

CREATE TABLE public.auditoria_log ( id uuid DEFAULT uuid_generate_v4() NOT NULL, tabela_nome varchar(100) NOT NULL, operacao varchar(10) NOT NULL, registro_id uuid NULL, dados_antigos jsonb NULL, dados_novos jsonb NULL, usuario_id uuid NULL, ip_address varchar(45) NULL, user_agent text NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT auditoria_log_pkey PRIMARY KEY (id), CONSTRAINT auditoria_log_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id));
CREATE INDEX idx_auditoria_data ON public.auditoria_log USING btree (created_at DESC);
CREATE INDEX idx_auditoria_tabela ON public.auditoria_log USING btree (tabela_nome);
CREATE INDEX idx_auditoria_usuario ON public.auditoria_log USING btree (usuario_id);

-- Permissions

ALTER TABLE public.auditoria_log OWNER TO postgres;
GRANT ALL ON TABLE public.auditoria_log TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.auditoria_log TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.auditoria_log TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.auditoria_log TO service_role;


-- public.caixa_sessoes definição

-- Drop table

-- DROP TABLE public.caixa_sessoes;

CREATE TABLE public.caixa_sessoes ( caixa_id uuid NULL, operador_id uuid NULL, data_abertura timestamptz DEFAULT now() NULL, data_fechamento timestamptz NULL, valor_abertura numeric(12, 2) DEFAULT 0 NULL, valor_fechamento numeric(12, 2) NULL, valor_vendas numeric(12, 2) DEFAULT 0 NULL, valor_sangrias numeric(12, 2) DEFAULT 0 NULL, valor_suprimentos numeric(12, 2) DEFAULT 0 NULL, diferenca numeric(12, 2) NULL, status varchar(20) DEFAULT 'ABERTO'::character varying NULL, observacoes text NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, id uuid DEFAULT uuid_generate_v4() NOT NULL, CONSTRAINT caixa_sessoes_pkey PRIMARY KEY (id), CONSTRAINT caixa_sessoes_status_check CHECK (((status)::text = ANY ((ARRAY['ABERTO'::character varying, 'FECHADO'::character varying, 'CONFERIDO'::character varying])::text[]))), CONSTRAINT fk_caixa_sessoes_caixa FOREIGN KEY (caixa_id) REFERENCES public.caixas(id), CONSTRAINT fk_caixa_sessoes_operador FOREIGN KEY (operador_id) REFERENCES public.users(id));
CREATE INDEX idx_caixa_sessoes_caixa_id ON public.caixa_sessoes USING btree (caixa_id);
CREATE INDEX idx_caixa_sessoes_data ON public.caixa_sessoes USING btree (data_abertura DESC);
CREATE INDEX idx_caixa_sessoes_data_abertura ON public.caixa_sessoes USING btree (data_abertura);
CREATE INDEX idx_caixa_sessoes_operador_id ON public.caixa_sessoes USING btree (operador_id);
CREATE INDEX idx_sessoes_caixa ON public.caixa_sessoes USING btree (caixa_id);
CREATE INDEX idx_sessoes_operador ON public.caixa_sessoes USING btree (operador_id);
CREATE INDEX idx_sessoes_status ON public.caixa_sessoes USING btree (status);

-- Permissions

ALTER TABLE public.caixa_sessoes OWNER TO postgres;
GRANT ALL ON TABLE public.caixa_sessoes TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixa_sessoes TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixa_sessoes TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixa_sessoes TO service_role;


-- public.categoria_impostos definição

-- Drop table

-- DROP TABLE public.categoria_impostos;

CREATE TABLE public.categoria_impostos ( id uuid DEFAULT uuid_generate_v4() NOT NULL, categoria_id uuid NOT NULL, aliquota_icms numeric(5, 2) DEFAULT 0.00 NULL, aliquota_pis numeric(5, 2) DEFAULT 0.00 NULL, aliquota_cofins numeric(5, 2) DEFAULT 0.00 NULL, aliquota_ipi numeric(5, 2) DEFAULT 0.00 NULL, cst_icms varchar(3) DEFAULT '00'::character varying NULL, ncm_padrao varchar(8) NULL, cfop_padrao varchar(4) DEFAULT '5102'::character varying NULL, origem_padrao varchar(1) DEFAULT '0'::character varying NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT categoria_impostos_categoria_id_key UNIQUE (categoria_id), CONSTRAINT categoria_impostos_pkey PRIMARY KEY (id), CONSTRAINT categoria_impostos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.categoria_impostos OWNER TO postgres;
GRANT ALL ON TABLE public.categoria_impostos TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.categoria_impostos TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.categoria_impostos TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.categoria_impostos TO service_role;


-- public.contas_pagar definição

-- Drop table

-- DROP TABLE public.contas_pagar;

CREATE TABLE public.contas_pagar ( id uuid NOT NULL, numero_documento varchar(50) NULL, descricao varchar(255) NOT NULL, fornecedor_id uuid NULL, pedido_compra_id uuid NULL, valor_original numeric(12, 2) NOT NULL, valor_desconto numeric(12, 2) DEFAULT 0 NULL, valor_juros numeric(12, 2) DEFAULT 0 NULL, valor_multa numeric(12, 2) DEFAULT 0 NULL, valor_pago numeric(12, 2) DEFAULT 0 NULL, valor_total numeric(12, 2) GENERATED ALWAYS AS ((valor_original - valor_desconto + valor_juros + valor_multa)) STORED NULL, data_emissao date DEFAULT CURRENT_DATE NULL, data_vencimento date NOT NULL, data_pagamento date NULL, forma_pagamento varchar(30) NULL, conta_bancaria varchar(100) NULL, status varchar(20) DEFAULT 'PENDENTE'::character varying NULL, categoria varchar(50) DEFAULT 'FORNECEDOR'::character varying NULL, centro_custo varchar(50) NULL, parcela_atual int4 DEFAULT 1 NULL, total_parcelas int4 DEFAULT 1 NULL, observacoes text NULL, usuario_id uuid NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT contas_pagar_pkey PRIMARY KEY (id), CONSTRAINT contas_pagar_status_check CHECK (((status)::text = ANY ((ARRAY['PENDENTE'::character varying, 'PAGO'::character varying, 'PAGO_PARCIAL'::character varying, 'VENCIDO'::character varying, 'CANCELADO'::character varying])::text[]))), CONSTRAINT contas_pagar_fornecedor_id_fkey FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id), CONSTRAINT contas_pagar_pedido_compra_id_fkey FOREIGN KEY (pedido_compra_id) REFERENCES public.pedidos_compra(id));
CREATE INDEX idx_contas_pagar_categoria ON public.contas_pagar USING btree (categoria);
CREATE INDEX idx_contas_pagar_fornecedor ON public.contas_pagar USING btree (fornecedor_id);
CREATE INDEX idx_contas_pagar_status ON public.contas_pagar USING btree (status);
CREATE INDEX idx_contas_pagar_vencimento ON public.contas_pagar USING btree (data_vencimento);

-- Permissions

ALTER TABLE public.contas_pagar OWNER TO postgres;
GRANT ALL ON TABLE public.contas_pagar TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.contas_pagar TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.contas_pagar TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.contas_pagar TO service_role;


-- public.importacao_xml_log definição

-- Drop table

-- DROP TABLE public.importacao_xml_log;

CREATE TABLE public.importacao_xml_log ( id uuid DEFAULT uuid_generate_v4() NOT NULL, arquivo_nome varchar(255) NOT NULL, chave_nfe varchar(44) NULL, numero_nfe varchar(20) NULL, fornecedor_id uuid NULL, fornecedor_cnpj varchar(18) NULL, fornecedor_nome varchar(255) NULL, pedido_id uuid NULL, total_produtos int4 DEFAULT 0 NULL, valor_total numeric(10, 2) DEFAULT 0 NULL, status varchar(20) DEFAULT 'PROCESSANDO'::character varying NULL, erro_mensagem text NULL, created_by uuid NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT importacao_xml_log_pkey PRIMARY KEY (id), CONSTRAINT importacao_xml_log_status_check CHECK (((status)::text = ANY ((ARRAY['PROCESSANDO'::character varying, 'SUCESSO'::character varying, 'ERRO'::character varying, 'PARCIAL'::character varying])::text[]))), CONSTRAINT fk_importacao_xml_fornecedor FOREIGN KEY (fornecedor_id) REFERENCES public.fornecedores(id), CONSTRAINT fk_importacao_xml_user FOREIGN KEY (created_by) REFERENCES public.users(id));
CREATE INDEX idx_importacao_xml_log_chave ON public.importacao_xml_log USING btree (chave_nfe);
CREATE INDEX idx_importacao_xml_log_created ON public.importacao_xml_log USING btree (created_at DESC);
CREATE INDEX idx_importacao_xml_log_fornecedor ON public.importacao_xml_log USING btree (fornecedor_id);
CREATE INDEX idx_importacao_xml_log_pedido ON public.importacao_xml_log USING btree (pedido_id);
CREATE INDEX idx_importacao_xml_log_status ON public.importacao_xml_log USING btree (status);

-- Permissions

ALTER TABLE public.importacao_xml_log OWNER TO postgres;
GRANT ALL ON TABLE public.importacao_xml_log TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.importacao_xml_log TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.importacao_xml_log TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.importacao_xml_log TO service_role;


-- public.movimentacoes_caixa definição

-- Drop table

-- DROP TABLE public.movimentacoes_caixa;

CREATE TABLE public.movimentacoes_caixa ( id uuid DEFAULT uuid_generate_v4() NOT NULL, caixa_id uuid NOT NULL, data_abertura timestamptz DEFAULT now() NOT NULL, data_fechamento timestamptz NULL, operador_id uuid NOT NULL, saldo_inicial numeric(12, 2) DEFAULT 0.00 NOT NULL, total_vendas numeric(12, 2) DEFAULT 0.00 NULL, total_dinheiro numeric(12, 2) DEFAULT 0.00 NULL, total_sangria numeric(12, 2) DEFAULT 0.00 NULL, total_suprimento numeric(12, 2) DEFAULT 0.00 NULL, saldo_final numeric(12, 2) NULL, status varchar(20) DEFAULT 'ABERTA'::character varying NULL, observacoes text NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, CONSTRAINT movimentacoes_caixa_pkey PRIMARY KEY (id), CONSTRAINT movimentacoes_caixa_caixa_id_fkey FOREIGN KEY (caixa_id) REFERENCES public.caixas(id), CONSTRAINT movimentacoes_caixa_operador_id_fkey FOREIGN KEY (operador_id) REFERENCES public.users(id));

-- Permissions

ALTER TABLE public.movimentacoes_caixa OWNER TO postgres;
GRANT ALL ON TABLE public.movimentacoes_caixa TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.movimentacoes_caixa TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.movimentacoes_caixa TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.movimentacoes_caixa TO service_role;


-- public.movimentacoes_financeiras definição

-- Drop table

-- DROP TABLE public.movimentacoes_financeiras;

CREATE TABLE public.movimentacoes_financeiras ( id uuid NOT NULL, tipo varchar(20) NOT NULL, conta_pagar_id uuid NULL, conta_receber_id uuid NULL, valor numeric(12, 2) NOT NULL, data_movimento date DEFAULT CURRENT_DATE NULL, forma varchar(30) NULL, conta_bancaria varchar(100) NULL, comprovante varchar(255) NULL, observacoes text NULL, usuario_id uuid NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT movimentacoes_financeiras_pkey PRIMARY KEY (id), CONSTRAINT movimentacoes_financeiras_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['PAGAMENTO'::character varying, 'RECEBIMENTO'::character varying])::text[]))), CONSTRAINT movimentacoes_financeiras_conta_pagar_id_fkey FOREIGN KEY (conta_pagar_id) REFERENCES public.contas_pagar(id));

-- Permissions

ALTER TABLE public.movimentacoes_financeiras OWNER TO postgres;
GRANT ALL ON TABLE public.movimentacoes_financeiras TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.movimentacoes_financeiras TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.movimentacoes_financeiras TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.movimentacoes_financeiras TO service_role;


-- public.pedido_compra_itens definição

-- Drop table

-- DROP TABLE public.pedido_compra_itens;

CREATE TABLE public.pedido_compra_itens ( id uuid NOT NULL, pedido_id uuid NOT NULL, produto_id uuid NOT NULL, quantidade numeric(12, 3) NOT NULL, quantidade_recebida numeric(12, 3) DEFAULT 0 NULL, preco_unitario numeric(12, 2) NOT NULL, subtotal numeric(12, 2) NOT NULL, numero_lote varchar(50) NULL, data_validade date NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT pedido_compra_itens_pkey PRIMARY KEY (id), CONSTRAINT pedido_compra_itens_pedido_id_fkey FOREIGN KEY (pedido_id) REFERENCES public.pedidos_compra(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.pedido_compra_itens OWNER TO postgres;
GRANT ALL ON TABLE public.pedido_compra_itens TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pedido_compra_itens TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pedido_compra_itens TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pedido_compra_itens TO service_role;


-- public.produtos definição

-- Drop table

-- DROP TABLE public.produtos;

CREATE TABLE public.produtos ( id uuid DEFAULT uuid_generate_v4() NOT NULL, codigo_barras varchar(20) NULL, nome varchar(255) NOT NULL, descricao text NULL, categoria_id uuid NULL, marca_id uuid NULL, preco_custo numeric(12, 2) DEFAULT 0.00 NOT NULL, preco_venda numeric(12, 2) DEFAULT 0.00 NOT NULL, preco_atacado numeric(12, 2) NULL, margem_lucro numeric(5, 2) DEFAULT 0.00 NULL, unidade_medida_padrao public."unidade_medida" DEFAULT 'UN'::unidade_medida NULL, unidade_venda public."unidade_medida" DEFAULT 'UN'::unidade_medida NULL, quantidade_por_embalagem numeric(10, 2) DEFAULT 1.00 NULL, estoque_minimo numeric(10, 2) DEFAULT 0.00 NULL, estoque_maximo numeric(10, 2) DEFAULT 0.00 NULL, estoque_atual numeric(10, 2) DEFAULT 0.00 NULL, ativo bool DEFAULT true NULL, requer_lote bool DEFAULT false NULL, controla_serie bool DEFAULT false NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, ncm varchar(10) DEFAULT '22021000'::character varying NULL, cfop varchar(4) DEFAULT '5102'::character varying NULL, origem_produto varchar(1) DEFAULT '0'::character varying NULL, descricao_nfe text NULL, aliquota_icms numeric(5, 2) DEFAULT 0.00 NULL, aliquota_pis numeric(5, 2) DEFAULT 0.00 NULL, aliquota_cofins numeric(5, 2) DEFAULT 0.00 NULL, aliquota_ipi numeric(5, 2) DEFAULT 0.00 NULL, cst_icms varchar(10) DEFAULT '00'::character varying NULL, codigo varchar(50) NULL, marca varchar(100) NULL, unidade varchar(20) DEFAULT 'UN'::character varying NULL, fornecedor_id uuid NULL, imagem_url text NULL, volume_ml int4 NULL, controla_validade bool DEFAULT true NULL, cfop_compra varchar(10) DEFAULT '1102'::character varying NULL, cest varchar(10) NULL, cfop_venda varchar(10) DEFAULT '5102'::character varying NULL, cst_pis varchar(10) NULL, cst_cofins varchar(10) NULL, cst_ipi varchar(10) NULL, origem varchar(5) DEFAULT '0'::character varying NULL, embalagem varchar(50) NULL, quantidade_embalagem int4 DEFAULT 1 NULL, dias_alerta_validade int4 DEFAULT 30 NULL, localizacao varchar(50) NULL, peso_kg numeric(10, 3) NULL, sku varchar(50) NULL, CONSTRAINT produtos_codigo_barras_key UNIQUE (codigo_barras), CONSTRAINT produtos_pkey PRIMARY KEY (id), CONSTRAINT produtos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES public.categorias(id), CONSTRAINT produtos_marca_id_fkey FOREIGN KEY (marca_id) REFERENCES public.marcas(id));
CREATE INDEX idx_produtos_ativo ON public.produtos USING btree (ativo);
CREATE INDEX idx_produtos_categoria ON public.produtos USING btree (categoria_id);
CREATE INDEX idx_produtos_categoria_id ON public.produtos USING btree (categoria_id);
CREATE INDEX idx_produtos_cest ON public.produtos USING btree (cest);
CREATE INDEX idx_produtos_cfop_compra ON public.produtos USING btree (cfop_compra);
CREATE INDEX idx_produtos_cfop_venda ON public.produtos USING btree (cfop_venda);
CREATE INDEX idx_produtos_codigo ON public.produtos USING btree (codigo);
CREATE INDEX idx_produtos_codigo_barras ON public.produtos USING btree (codigo_barras);
CREATE INDEX idx_produtos_cst_icms ON public.produtos USING btree (cst_icms);
CREATE INDEX idx_produtos_fornecedor ON public.produtos USING btree (fornecedor_id);
CREATE INDEX idx_produtos_marca ON public.produtos USING btree (marca);
CREATE INDEX idx_produtos_marca_id ON public.produtos USING btree (marca_id);
CREATE INDEX idx_produtos_ncm ON public.produtos USING btree (ncm);
CREATE INDEX idx_produtos_nome ON public.produtos USING gin (to_tsvector('portuguese'::regconfig, (nome)::text));
COMMENT ON TABLE public.produtos IS 'Cadastro de produtos - estoque_atual é calculado, NÃO editar manualmente';

-- Column comments

COMMENT ON COLUMN public.produtos.preco_custo IS 'Preço de custo - atualizado automaticamente na entrada de compra';
COMMENT ON COLUMN public.produtos.estoque_atual IS 'Estoque atual - NUNCA editar manualmente, apenas via movimentações';

-- Table Triggers

create trigger tr_validar_sku_insert before
insert
    on
    public.produtos for each row execute function validar_sku_unico();
create trigger tr_validar_sku_update before
update
    on
    public.produtos for each row execute function validar_sku_unico();
create trigger trigger_validar_estoque before
update
    on
    public.produtos for each row execute function validar_estoque_positivo();
create trigger update_produtos_updated_at before
update
    on
    public.produtos for each row execute function update_updated_at_column();

-- Permissions

ALTER TABLE public.produtos OWNER TO postgres;
GRANT ALL ON TABLE public.produtos TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.produtos TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.produtos TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.produtos TO service_role;


-- public.vendas definição

-- Drop table

-- DROP TABLE public.vendas;

CREATE TABLE public.vendas ( id uuid DEFAULT uuid_generate_v4() NOT NULL, numero_nf varchar(20) NULL, caixa_id uuid NOT NULL, movimentacao_caixa_id uuid NOT NULL, operador_id uuid NOT NULL, cliente_id uuid NULL, subtotal numeric(12, 2) DEFAULT 0.00 NOT NULL, desconto numeric(12, 2) DEFAULT 0.00 NULL, desconto_percentual numeric(5, 2) DEFAULT 0.00 NULL, acrescimo numeric(12, 2) DEFAULT 0.00 NULL, impostos numeric(12, 2) DEFAULT 0.00 NULL, total numeric(12, 2) DEFAULT 0.00 NOT NULL, forma_pagamento public."pagamento_forma" NOT NULL, valor_pago numeric(12, 2) NOT NULL, valor_troco numeric(12, 2) DEFAULT 0.00 NULL, status_venda public."venda_status" DEFAULT 'FINALIZADA'::venda_status NULL, status_fiscal public."documento_fiscal_status" DEFAULT 'SEM_DOCUMENTO_FISCAL'::documento_fiscal_status NULL, numero_nfce varchar(50) NULL, numero_nfe varchar(50) NULL, chave_acesso_nfce varchar(50) NULL, chave_acesso_nfe varchar(50) NULL, protocolo_nfce varchar(50) NULL, protocolo_nfe varchar(50) NULL, xml_nfce text NULL, xml_nfe text NULL, mensagem_erro_fiscal text NULL, observacoes text NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, numero varchar(20) NULL, status varchar(20) DEFAULT 'FINALIZADA'::character varying NULL, data_venda timestamptz DEFAULT now() NULL, sessao_id uuid NULL, vendedor_id uuid NULL, desconto_valor numeric(12, 2) DEFAULT 0 NULL, troco numeric(12, 2) DEFAULT 0 NULL, nfce_id varchar NULL, CONSTRAINT vendas_numero_nf_key UNIQUE (numero_nf), CONSTRAINT vendas_pkey PRIMARY KEY (id), CONSTRAINT vendas_caixa_id_fkey FOREIGN KEY (caixa_id) REFERENCES public.caixas(id), CONSTRAINT vendas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id), CONSTRAINT vendas_movimentacao_caixa_id_fkey FOREIGN KEY (movimentacao_caixa_id) REFERENCES public.caixa_sessoes(id), CONSTRAINT vendas_operador_id_fkey FOREIGN KEY (operador_id) REFERENCES public.users(id));
CREATE INDEX idx_vendas_caixa ON public.vendas USING btree (caixa_id);
CREATE INDEX idx_vendas_cliente ON public.vendas USING btree (cliente_id);
CREATE INDEX idx_vendas_created ON public.vendas USING btree (created_at DESC);
CREATE INDEX idx_vendas_data ON public.vendas USING btree (data_venda);
CREATE INDEX idx_vendas_fiscal_status ON public.vendas USING btree (status_fiscal);
CREATE INDEX idx_vendas_nfce_id ON public.vendas USING btree (nfce_id);
CREATE INDEX idx_vendas_numero ON public.vendas USING btree (numero);
CREATE INDEX idx_vendas_operador ON public.vendas USING btree (operador_id);
CREATE INDEX idx_vendas_sessao ON public.vendas USING btree (sessao_id);
CREATE INDEX idx_vendas_troco ON public.vendas USING btree (troco);

-- Table Triggers

create trigger update_vendas_estoque after
update
    on
    public.vendas for each row execute function atualizar_estoque_venda();

-- Permissions

ALTER TABLE public.vendas OWNER TO postgres;
GRANT ALL ON TABLE public.vendas TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vendas TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vendas TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vendas TO service_role;


-- public.caixa_movimentacoes definição

-- Drop table

-- DROP TABLE public.caixa_movimentacoes;

CREATE TABLE public.caixa_movimentacoes ( id uuid NOT NULL, sessao_id uuid NOT NULL, tipo varchar(20) NOT NULL, valor numeric(12, 2) NOT NULL, motivo text NULL, responsavel_id uuid NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT caixa_movimentacoes_pkey PRIMARY KEY (id), CONSTRAINT caixa_movimentacoes_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['SANGRIA'::character varying, 'SUPRIMENTO'::character varying])::text[]))), CONSTRAINT caixa_movimentacoes_sessao_id_fkey FOREIGN KEY (sessao_id) REFERENCES public.caixa_sessoes(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.caixa_movimentacoes OWNER TO postgres;
GRANT ALL ON TABLE public.caixa_movimentacoes TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixa_movimentacoes TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixa_movimentacoes TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.caixa_movimentacoes TO service_role;


-- public.comandas definição

-- Drop table

-- DROP TABLE public.comandas;

CREATE TABLE public.comandas ( id uuid DEFAULT uuid_generate_v4() NOT NULL, numero_comanda varchar(20) NOT NULL, numero_mesa varchar(10) NULL, tipo varchar(20) DEFAULT 'mesa'::character varying NULL, cliente_id uuid NULL, cliente_nome varchar(255) NULL, status varchar(20) DEFAULT 'aberta'::character varying NULL, data_abertura timestamp DEFAULT now() NULL, data_fechamento timestamp NULL, usuario_abertura_id uuid NULL, usuario_fechamento_id uuid NULL, subtotal numeric(10, 2) DEFAULT 0 NULL, desconto numeric(10, 2) DEFAULT 0 NULL, acrescimo numeric(10, 2) DEFAULT 0 NULL, valor_total numeric(10, 2) DEFAULT 0 NULL, observacoes text NULL, venda_id uuid NULL, created_at timestamp DEFAULT now() NULL, updated_at timestamp DEFAULT now() NULL, CONSTRAINT comandas_numero_comanda_key UNIQUE (numero_comanda), CONSTRAINT comandas_pkey PRIMARY KEY (id), CONSTRAINT comandas_status_check CHECK (((status)::text = ANY ((ARRAY['aberta'::character varying, 'fechada'::character varying, 'cancelada'::character varying])::text[]))), CONSTRAINT comandas_tipo_check CHECK (((tipo)::text = ANY ((ARRAY['mesa'::character varying, 'balcao'::character varying, 'delivery'::character varying])::text[]))), CONSTRAINT comandas_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id), CONSTRAINT comandas_usuario_abertura_id_fkey FOREIGN KEY (usuario_abertura_id) REFERENCES public.users(id), CONSTRAINT comandas_usuario_fechamento_id_fkey FOREIGN KEY (usuario_fechamento_id) REFERENCES public.users(id), CONSTRAINT comandas_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id));
CREATE INDEX idx_comandas_data_abertura ON public.comandas USING btree (data_abertura);
CREATE INDEX idx_comandas_mesa ON public.comandas USING btree (numero_mesa);
CREATE INDEX idx_comandas_numero ON public.comandas USING btree (numero_comanda);
CREATE INDEX idx_comandas_status ON public.comandas USING btree (status);
CREATE UNIQUE INDEX idx_comandas_venda_id_unica ON public.comandas USING btree (venda_id) WHERE (venda_id IS NOT NULL);
COMMENT ON INDEX public.idx_comandas_venda_id_unica IS 'Garante que cada venda está ligada a no máximo uma comanda. O índice ignora linhas com venda_id NULL.';
COMMENT ON TABLE public.comandas IS 'Comandas/vendas em aberto para consumo no local';

-- Column comments

COMMENT ON COLUMN public.comandas.numero_comanda IS 'Identificador único da comanda (Mesa 1, Comanda 001, etc)';
COMMENT ON COLUMN public.comandas.tipo IS 'Tipo de atendimento: mesa, balcao ou delivery';
COMMENT ON COLUMN public.comandas.status IS 'Status da comanda: aberta, fechada ou cancelada';

-- Permissions

ALTER TABLE public.comandas OWNER TO postgres;
GRANT ALL ON TABLE public.comandas TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.comandas TO anon;
GRANT ALL ON TABLE public.comandas TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.comandas TO service_role;


-- public.contas_receber definição

-- Drop table

-- DROP TABLE public.contas_receber;

CREATE TABLE public.contas_receber ( id uuid DEFAULT uuid_generate_v4() NOT NULL, venda_id uuid NULL, cliente_id uuid NOT NULL, valor_original numeric(12, 2) NOT NULL, valor_pago numeric(12, 2) DEFAULT 0.00 NULL, valor_pendente numeric(12, 2) NOT NULL, data_vencimento date NOT NULL, data_pagamento date NULL, juros numeric(12, 2) DEFAULT 0.00 NULL, multa numeric(12, 2) DEFAULT 0.00 NULL, desconto numeric(12, 2) DEFAULT 0.00 NULL, observacoes text NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, valor_recebido numeric(12, 2) DEFAULT 0 NULL, status varchar(20) DEFAULT 'PENDENTE'::character varying NULL, valor_desconto numeric(12, 2) DEFAULT 0 NULL, valor_juros numeric(12, 2) DEFAULT 0 NULL, valor_multa numeric(12, 2) DEFAULT 0 NULL, data_recebimento date NULL, numero_documento varchar(50) NULL, descricao varchar(255) NULL, data_emissao date DEFAULT CURRENT_DATE NULL, forma_recebimento varchar(30) NULL, conta_bancaria varchar(100) NULL, categoria varchar(50) DEFAULT 'VENDA'::character varying NULL, parcela_atual int4 DEFAULT 1 NULL, total_parcelas int4 DEFAULT 1 NULL, usuario_id uuid NULL, CONSTRAINT contas_receber_pkey PRIMARY KEY (id), CONSTRAINT contas_receber_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES public.clientes(id), CONSTRAINT contas_receber_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id));
CREATE INDEX idx_contas_receber_cliente ON public.contas_receber USING btree (cliente_id);
CREATE INDEX idx_contas_receber_status ON public.contas_receber USING btree (status);
CREATE INDEX idx_contas_receber_vencimento ON public.contas_receber USING btree (data_vencimento);

-- Table Triggers

create trigger update_contas_saldo_cliente after
insert
    or
update
    on
    public.contas_receber for each row execute function atualizar_saldo_cliente();

-- Permissions

ALTER TABLE public.contas_receber OWNER TO postgres;
GRANT ALL ON TABLE public.contas_receber TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.contas_receber TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.contas_receber TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.contas_receber TO service_role;


-- public.documentos_fiscais definição

-- Drop table

-- DROP TABLE public.documentos_fiscais;

CREATE TABLE public.documentos_fiscais ( id uuid DEFAULT uuid_generate_v4() NOT NULL, venda_id uuid NOT NULL, tipo_documento varchar(20) NOT NULL, numero_documento varchar(50) NULL, serie int4 NULL, chave_acesso varchar(50) NULL, protocolo_autorizacao varchar(50) NULL, status_sefaz varchar(50) NULL, mensagem_sefaz text NULL, xml_nota text NULL, xml_retorno text NULL, valor_total numeric(12, 2) NULL, natureza_operacao varchar(100) NULL, data_emissao timestamptz NULL, data_autorizacao timestamptz NULL, tentativas_emissao int4 DEFAULT 0 NULL, ultima_tentativa timestamptz NULL, proximo_retry timestamptz NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, api_provider varchar DEFAULT 'focus_nfe'::character varying NULL, CONSTRAINT documentos_fiscais_api_provider_check CHECK (((api_provider)::text = ANY ((ARRAY['focus_nfe'::character varying, 'nuvem_fiscal'::character varying, 'sefaz_direta'::character varying])::text[]))), CONSTRAINT documentos_fiscais_pkey PRIMARY KEY (id), CONSTRAINT documentos_fiscais_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id) ON DELETE CASCADE);
CREATE INDEX idx_docs_fiscais_status ON public.documentos_fiscais USING btree (status_sefaz);
CREATE INDEX idx_docs_fiscais_venda ON public.documentos_fiscais USING btree (venda_id);
CREATE INDEX idx_documentos_fiscais_api_provider ON public.documentos_fiscais USING btree (api_provider);

-- Column comments

COMMENT ON COLUMN public.documentos_fiscais.api_provider IS 'Provedor da API fiscal: focus_nfe, nuvem_fiscal ou sefaz_direta';

-- Permissions

ALTER TABLE public.documentos_fiscais OWNER TO postgres;
GRANT ALL ON TABLE public.documentos_fiscais TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.documentos_fiscais TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.documentos_fiscais TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.documentos_fiscais TO service_role;


-- public.pagamentos_venda definição

-- Drop table

-- DROP TABLE public.pagamentos_venda;

CREATE TABLE public.pagamentos_venda ( id uuid DEFAULT uuid_generate_v4() NOT NULL, venda_id uuid NOT NULL, forma public."pagamento_forma" NOT NULL, valor numeric(12, 2) NOT NULL, numero_parcela int4 DEFAULT 1 NULL, total_parcelas int4 DEFAULT 1 NULL, data_vencimento date NULL, status_pagamento varchar(20) DEFAULT 'RECEBIDO'::character varying NULL, observacoes text NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT pagamentos_venda_pkey PRIMARY KEY (id), CONSTRAINT pagamentos_venda_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id) ON DELETE CASCADE);

-- Permissions

ALTER TABLE public.pagamentos_venda OWNER TO postgres;
GRANT ALL ON TABLE public.pagamentos_venda TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pagamentos_venda TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pagamentos_venda TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.pagamentos_venda TO service_role;


-- public.produto_lotes definição

-- Drop table

-- DROP TABLE public.produto_lotes;

CREATE TABLE public.produto_lotes ( id uuid DEFAULT uuid_generate_v4() NOT NULL, produto_id uuid NOT NULL, numero_lote varchar(50) NOT NULL, data_fabricacao date NULL, data_vencimento date NULL, quantidade numeric(10, 2) DEFAULT 0.00 NOT NULL, localizacao text NULL, ativo bool DEFAULT true NULL, created_at timestamptz DEFAULT now() NULL, updated_at timestamptz DEFAULT now() NULL, data_validade date NULL, quantidade_inicial numeric(12, 3) DEFAULT 0 NULL, quantidade_atual numeric(12, 3) DEFAULT 0 NULL, preco_custo numeric(12, 2) DEFAULT 0 NULL, fornecedor_id uuid NULL, nota_fiscal varchar(50) NULL, observacoes text NULL, status varchar(20) DEFAULT 'ATIVO'::character varying NULL, CONSTRAINT produto_lotes_pkey PRIMARY KEY (id), CONSTRAINT produto_lotes_produto_id_numero_lote_key UNIQUE (produto_id, numero_lote), CONSTRAINT produto_lotes_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id) ON DELETE CASCADE);
CREATE INDEX idx_lotes_produto ON public.produto_lotes USING btree (produto_id);
CREATE INDEX idx_lotes_status ON public.produto_lotes USING btree (status);
CREATE INDEX idx_lotes_validade ON public.produto_lotes USING btree (data_validade);

-- Permissions

ALTER TABLE public.produto_lotes OWNER TO postgres;
GRANT ALL ON TABLE public.produto_lotes TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.produto_lotes TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.produto_lotes TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.produto_lotes TO service_role;


-- public.vendas_itens definição

-- Drop table

-- DROP TABLE public.vendas_itens;

CREATE TABLE public.vendas_itens ( id uuid DEFAULT uuid_generate_v4() NOT NULL, venda_id uuid NOT NULL, produto_id uuid NOT NULL, lote_id uuid NULL, quantidade numeric(10, 2) NOT NULL, "unidade_medida" public."unidade_medida" NOT NULL, preco_unitario numeric(12, 2) NOT NULL, subtotal numeric(12, 2) NOT NULL, desconto numeric(12, 2) DEFAULT 0.00 NULL, desconto_percentual numeric(5, 2) DEFAULT 0.00 NULL, acrescimo numeric(12, 2) DEFAULT 0.00 NULL, total numeric(12, 2) NOT NULL, created_at timestamptz DEFAULT now() NULL, preco_custo numeric(12, 2) NULL, CONSTRAINT vendas_itens_pkey PRIMARY KEY (id), CONSTRAINT vendas_itens_lote_id_fkey FOREIGN KEY (lote_id) REFERENCES public.produto_lotes(id), CONSTRAINT vendas_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id), CONSTRAINT vendas_itens_venda_id_fkey FOREIGN KEY (venda_id) REFERENCES public.vendas(id) ON DELETE CASCADE);
CREATE INDEX idx_vendas_itens_lote ON public.vendas_itens USING btree (lote_id);
CREATE INDEX idx_vendas_itens_produto ON public.vendas_itens USING btree (produto_id);
CREATE INDEX idx_vendas_itens_venda ON public.vendas_itens USING btree (venda_id);

-- Column comments

COMMENT ON COLUMN public.vendas_itens.preco_custo IS 'Preço de custo no momento da venda - usado para análise de lucro';

-- Table Triggers

create trigger trg_before_insert_venda_item_custo before
insert
    on
    public.vendas_itens for each row execute function trg_venda_item_set_preco_custo();

-- Permissions

ALTER TABLE public.vendas_itens OWNER TO postgres;
GRANT ALL ON TABLE public.vendas_itens TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vendas_itens TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vendas_itens TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vendas_itens TO service_role;


-- public.comanda_itens definição

-- Drop table

-- DROP TABLE public.comanda_itens;

CREATE TABLE public.comanda_itens ( id uuid DEFAULT uuid_generate_v4() NOT NULL, comanda_id uuid NOT NULL, produto_id uuid NOT NULL, nome_produto varchar(255) NOT NULL, quantidade numeric(10, 3) DEFAULT 1 NOT NULL, preco_unitario numeric(10, 2) NOT NULL, subtotal numeric(10, 2) NOT NULL, desconto numeric(10, 2) DEFAULT 0 NULL, status varchar(20) DEFAULT 'pendente'::character varying NULL, observacoes text NULL, usuario_id uuid NULL, created_at timestamp DEFAULT now() NULL, updated_at timestamp DEFAULT now() NULL, CONSTRAINT comanda_itens_pkey PRIMARY KEY (id), CONSTRAINT comanda_itens_status_check CHECK (((status)::text = ANY ((ARRAY['pendente'::character varying, 'preparando'::character varying, 'entregue'::character varying, 'cancelado'::character varying])::text[]))), CONSTRAINT comanda_itens_comanda_id_fkey FOREIGN KEY (comanda_id) REFERENCES public.comandas(id) ON DELETE CASCADE, CONSTRAINT comanda_itens_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id), CONSTRAINT comanda_itens_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id));
CREATE INDEX idx_comanda_itens_comanda ON public.comanda_itens USING btree (comanda_id);
CREATE INDEX idx_comanda_itens_produto ON public.comanda_itens USING btree (produto_id);
CREATE INDEX idx_comanda_itens_status ON public.comanda_itens USING btree (status);
COMMENT ON TABLE public.comanda_itens IS 'Itens adicionados às comandas abertas';

-- Column comments

COMMENT ON COLUMN public.comanda_itens.status IS 'Status do item: pendente, preparando, entregue, cancelado';

-- Table Triggers

create trigger trigger_atualizar_totais_comanda_delete after
delete
    on
    public.comanda_itens for each row execute function atualizar_totais_comanda();
create trigger trigger_atualizar_totais_comanda_insert after
insert
    on
    public.comanda_itens for each row execute function atualizar_totais_comanda();
create trigger trigger_atualizar_totais_comanda_update after
update
    on
    public.comanda_itens for each row execute function atualizar_totais_comanda();

-- Permissions

ALTER TABLE public.comanda_itens OWNER TO postgres;
GRANT ALL ON TABLE public.comanda_itens TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.comanda_itens TO anon;
GRANT ALL ON TABLE public.comanda_itens TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.comanda_itens TO service_role;


-- public.estoque_movimentacoes definição

-- Drop table

-- DROP TABLE public.estoque_movimentacoes;

CREATE TABLE public.estoque_movimentacoes ( id uuid DEFAULT uuid_generate_v4() NOT NULL, produto_id uuid NOT NULL, lote_id uuid NULL, tipo_movimento varchar(20) NOT NULL, quantidade numeric(10, 2) NOT NULL, "unidade_medida" public."unidade_medida" NOT NULL, preco_unitario numeric(12, 2) NULL, motivo text NULL, referencia_id uuid NULL, referencia_tipo varchar(50) NULL, usuario_id uuid NOT NULL, created_at timestamptz DEFAULT now() NULL, CONSTRAINT estoque_movimentacoes_pkey PRIMARY KEY (id), CONSTRAINT estoque_movimentacoes_lote_id_fkey FOREIGN KEY (lote_id) REFERENCES public.produto_lotes(id), CONSTRAINT estoque_movimentacoes_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id), CONSTRAINT estoque_movimentacoes_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id));
CREATE INDEX idx_estoque_mov_created ON public.estoque_movimentacoes USING btree (created_at DESC);
CREATE INDEX idx_estoque_mov_data ON public.estoque_movimentacoes USING btree (created_at DESC);
CREATE INDEX idx_estoque_mov_produto ON public.estoque_movimentacoes USING btree (produto_id);
CREATE INDEX idx_estoque_mov_referencia ON public.estoque_movimentacoes USING btree (referencia_id, referencia_tipo);
CREATE INDEX idx_estoque_mov_tipo ON public.estoque_movimentacoes USING btree (tipo_movimento);
COMMENT ON TABLE public.estoque_movimentacoes IS 'Registro de TODAS as movimentações de estoque - entrada, saída, ajustes';

-- Permissions

ALTER TABLE public.estoque_movimentacoes OWNER TO postgres;
GRANT ALL ON TABLE public.estoque_movimentacoes TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.estoque_movimentacoes TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.estoque_movimentacoes TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.estoque_movimentacoes TO service_role;


-- public.v_contas_pagar_vencidas fonte

CREATE OR REPLACE VIEW public.v_contas_pagar_vencidas
AS SELECT cp.id,
    cp.numero_documento,
    cp.descricao,
    cp.fornecedor_id,
    cp.pedido_compra_id,
    cp.valor_original,
    cp.valor_desconto,
    cp.valor_juros,
    cp.valor_multa,
    cp.valor_pago,
    cp.valor_total,
    cp.data_emissao,
    cp.data_vencimento,
    cp.data_pagamento,
    cp.forma_pagamento,
    cp.conta_bancaria,
    cp.status,
    cp.categoria,
    cp.centro_custo,
    cp.parcela_atual,
    cp.total_parcelas,
    cp.observacoes,
    cp.usuario_id,
    cp.created_at,
    cp.updated_at,
    f.nome AS fornecedor_nome,
    f.razao_social AS fornecedor_razao_social,
    f.cnpj AS fornecedor_cnpj,
    CURRENT_DATE - cp.data_vencimento AS dias_atraso
   FROM contas_pagar cp
     LEFT JOIN fornecedores f ON f.id = cp.fornecedor_id
  WHERE (cp.status::text = ANY (ARRAY['PENDENTE'::character varying, 'PAGO_PARCIAL'::character varying]::text[])) AND cp.data_vencimento < CURRENT_DATE
  ORDER BY cp.data_vencimento;

-- Permissions

ALTER TABLE public.v_contas_pagar_vencidas OWNER TO postgres;
GRANT ALL ON TABLE public.v_contas_pagar_vencidas TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_contas_pagar_vencidas TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_contas_pagar_vencidas TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_contas_pagar_vencidas TO service_role;


-- public.v_contas_receber_vencidas fonte

CREATE OR REPLACE VIEW public.v_contas_receber_vencidas
AS SELECT cr.id,
    cr.venda_id,
    cr.cliente_id,
    cr.valor_original,
    cr.valor_pago,
    cr.valor_pendente,
    cr.data_vencimento,
    cr.data_pagamento,
    cr.juros,
    cr.multa,
    cr.desconto,
    cr.observacoes,
    cr.created_at,
    cr.updated_at,
    cr.valor_recebido,
    cr.status,
    cr.valor_desconto,
    cr.valor_juros,
    cr.valor_multa,
    cr.data_recebimento,
    cr.numero_documento,
    cr.descricao,
    cr.data_emissao,
    cr.forma_recebimento,
    cr.conta_bancaria,
    cr.categoria,
    cr.parcela_atual,
    cr.total_parcelas,
    cr.usuario_id,
    c.nome AS cliente_nome,
    c.cpf_cnpj AS cliente_documento,
    c.telefone AS cliente_telefone,
    CURRENT_DATE - cr.data_vencimento AS dias_atraso
   FROM contas_receber cr
     LEFT JOIN clientes c ON c.id = cr.cliente_id
  WHERE (cr.status::text = ANY (ARRAY['PENDENTE'::character varying, 'PAGO_PARCIAL'::character varying]::text[])) AND cr.data_vencimento < CURRENT_DATE
  ORDER BY cr.data_vencimento;

-- Permissions

ALTER TABLE public.v_contas_receber_vencidas OWNER TO postgres;
GRANT ALL ON TABLE public.v_contas_receber_vencidas TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_contas_receber_vencidas TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_contas_receber_vencidas TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_contas_receber_vencidas TO service_role;


-- public.v_vendas_do_dia fonte

CREATE OR REPLACE VIEW public.v_vendas_do_dia
AS SELECT CURRENT_DATE AS data_venda,
    count(DISTINCT id) AS total_vendas,
    sum(total) AS valor_total,
    count(DISTINCT cliente_id) AS clientes_unicos,
    sum(
        CASE
            WHEN status_venda = 'FINALIZADA'::venda_status THEN total
            ELSE 0::numeric
        END) AS valor_vendas_finalizadas
   FROM vendas
  WHERE date(created_at) = CURRENT_DATE;

-- Permissions

ALTER TABLE public.v_vendas_do_dia OWNER TO postgres;
GRANT ALL ON TABLE public.v_vendas_do_dia TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_vendas_do_dia TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_vendas_do_dia TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.v_vendas_do_dia TO service_role;


-- public.vw_analise_vendas fonte

CREATE OR REPLACE VIEW public.vw_analise_vendas
AS SELECT v.id AS venda_id,
    v.numero,
    v.created_at AS data_venda,
    v.total AS total_venda,
    c.nome AS cliente_nome,
    u.nome_completo AS operador_nome,
    COALESCE(sum(vi.quantidade * vi.preco_custo), 0::numeric) AS custo_total,
    v.total - COALESCE(sum(vi.quantidade * vi.preco_custo), 0::numeric) AS lucro_bruto,
        CASE
            WHEN COALESCE(sum(vi.quantidade * vi.preco_custo), 0::numeric) > 0::numeric THEN (v.total - COALESCE(sum(vi.quantidade * vi.preco_custo), 0::numeric)) / COALESCE(sum(vi.quantidade * vi.preco_custo), 1::numeric) * 100::numeric
            ELSE 0::numeric
        END AS margem_lucro_percentual
   FROM vendas v
     LEFT JOIN venda_itens vi ON vi.venda_id = v.id
     LEFT JOIN clientes c ON c.id = v.cliente_id
     LEFT JOIN users u ON u.id = v.operador_id
  WHERE v.status::text = 'FINALIZADA'::text OR v.status_venda = 'FINALIZADA'::venda_status
  GROUP BY v.id, v.numero, v.created_at, v.total, c.nome, u.nome_completo;

-- Permissions

ALTER TABLE public.vw_analise_vendas OWNER TO postgres;
GRANT ALL ON TABLE public.vw_analise_vendas TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vw_analise_vendas TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vw_analise_vendas TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vw_analise_vendas TO service_role;


-- public.vw_posicao_estoque fonte

CREATE OR REPLACE VIEW public.vw_posicao_estoque
AS SELECT p.id,
    p.codigo,
    p.codigo_barras,
    p.nome,
    p.estoque_atual,
    p.estoque_minimo,
    p.estoque_maximo,
    p.preco_custo,
    p.preco_venda,
    p.unidade,
    c.nome AS categoria,
    m.nome AS marca,
        CASE
            WHEN p.estoque_atual <= 0::numeric THEN 'SEM_ESTOQUE'::text
            WHEN p.estoque_atual <= p.estoque_minimo THEN 'ESTOQUE_BAIXO'::text
            WHEN p.estoque_atual >= p.estoque_maximo THEN 'ESTOQUE_ALTO'::text
            ELSE 'ESTOQUE_NORMAL'::text
        END AS status_estoque,
    p.estoque_atual * p.preco_custo AS valor_estoque,
    p.created_at,
    p.updated_at
   FROM produtos p
     LEFT JOIN categorias c ON c.id = p.categoria_id
     LEFT JOIN marcas m ON m.id = p.marca_id
  WHERE p.ativo = true
  ORDER BY p.nome;

-- Permissions

ALTER TABLE public.vw_posicao_estoque OWNER TO postgres;
GRANT ALL ON TABLE public.vw_posicao_estoque TO postgres;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vw_posicao_estoque TO anon;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vw_posicao_estoque TO authenticated;
GRANT INSERT, UPDATE, SELECT, DELETE ON TABLE public.vw_posicao_estoque TO service_role;



-- DROP FUNCTION public.armor(bytea);

CREATE OR REPLACE FUNCTION public.armor(bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_armor$function$
;

-- Permissions

ALTER FUNCTION public.armor(bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.armor(bytea) TO supabase_admin;

-- DROP FUNCTION public.armor(bytea, _text, _text);

CREATE OR REPLACE FUNCTION public.armor(bytea, text[], text[])
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_armor$function$
;

-- Permissions

ALTER FUNCTION public.armor(bytea, _text, _text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.armor(bytea, _text, _text) TO supabase_admin;

-- DROP FUNCTION public.atualizar_estoque_venda();

CREATE OR REPLACE FUNCTION public.atualizar_estoque_venda()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Reduzir estoque ao finalizar venda
    IF NEW.status_venda = 'FINALIZADA' AND OLD.status_venda != 'FINALIZADA' THEN
        UPDATE produtos SET estoque_atual = estoque_atual - (
            SELECT COALESCE(SUM(quantidade), 0) 
            FROM vendas_itens 
            WHERE venda_id = NEW.id
        )
        WHERE id IN (SELECT produto_id FROM vendas_itens WHERE venda_id = NEW.id);
    END IF;
    
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.atualizar_estoque_venda() OWNER TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda() TO public;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda() TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda() TO anon;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda() TO authenticated;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda() TO service_role;

-- DROP FUNCTION public.atualizar_estoque_venda_com_validacao(uuid);

CREATE OR REPLACE FUNCTION public.atualizar_estoque_venda_com_validacao(p_venda_id uuid)
 RETURNS TABLE(sucesso boolean, mensagem text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_item RECORD;
    v_estoque_disponivel NUMERIC;
BEGIN
    -- Loop em cada item da venda
    FOR v_item IN 
        SELECT produto_id, quantidade FROM vendas_itens WHERE venda_id = p_venda_id
    LOOP
        -- Verificar estoque disponível
        SELECT estoque_atual INTO v_estoque_disponivel
        FROM produtos
        WHERE id = v_item.produto_id;

        IF v_estoque_disponivel < v_item.quantidade THEN
            RETURN QUERY SELECT false, 'Estoque insuficiente para produto: ' || v_item.produto_id::text;
            RETURN;
        END IF;

        -- Atualizar estoque
        UPDATE produtos
        SET estoque_atual = estoque_atual - v_item.quantidade
        WHERE id = v_item.produto_id;

        -- Registrar movimento
        INSERT INTO estoque_movimentacoes (
            produto_id,
            tipo_movimento,
            quantidade,
            unidade_medida,
            motivo,
            referencia_id,
            referencia_tipo,
            usuario_id
        ) VALUES (
            v_item.produto_id,
            'SAIDA',
            v_item.quantidade,
            'UN',
            'Venda PDV',
            p_venda_id,
            'VENDA',
            auth.uid()
        );
    END LOOP;

    RETURN QUERY SELECT true, 'Estoque atualizado com sucesso';
END;
$function$
;

-- Permissions

ALTER FUNCTION public.atualizar_estoque_venda_com_validacao(uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda_com_validacao(uuid) TO public;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda_com_validacao(uuid) TO postgres;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda_com_validacao(uuid) TO anon;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda_com_validacao(uuid) TO authenticated;
GRANT ALL ON FUNCTION public.atualizar_estoque_venda_com_validacao(uuid) TO service_role;

-- DROP FUNCTION public.atualizar_quantidade_lotes();

CREATE OR REPLACE FUNCTION public.atualizar_quantidade_lotes()
 RETURNS TABLE(lote_id uuid, numero_lote character varying, quantidade_atual numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH lote_saidas AS (
        SELECT 
            vi.lote_id,
            pl.numero_lote,
            SUM(vi.quantidade) AS quantidade_saida
        FROM public.vendas_itens vi
        JOIN public.vendas v ON vi.venda_id = v.id
        JOIN public.produto_lotes pl ON vi.lote_id = pl.id
        WHERE v.status = 'FINALIZADA'
        AND vi.lote_id IS NOT NULL
        GROUP BY vi.lote_id, pl.numero_lote
    )
    UPDATE public.produto_lotes pl
    SET quantidade_atual = GREATEST(quantidade_inicial - ls.quantidade_saida, 0)
    FROM lote_saidas ls
    WHERE pl.id = ls.lote_id
    RETURNING 
        pl.id,
        pl.numero_lote,
        pl.quantidade_atual;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.atualizar_quantidade_lotes() OWNER TO postgres;
GRANT ALL ON FUNCTION public.atualizar_quantidade_lotes() TO public;
GRANT ALL ON FUNCTION public.atualizar_quantidade_lotes() TO postgres;
GRANT ALL ON FUNCTION public.atualizar_quantidade_lotes() TO anon;
GRANT ALL ON FUNCTION public.atualizar_quantidade_lotes() TO authenticated;
GRANT ALL ON FUNCTION public.atualizar_quantidade_lotes() TO service_role;

-- DROP FUNCTION public.atualizar_saldo_cliente();

CREATE OR REPLACE FUNCTION public.atualizar_saldo_cliente()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE clientes 
    SET saldo_devedor = (
        SELECT COALESCE(SUM(valor_pendente), 0) 
        FROM contas_receber 
        WHERE cliente_id = NEW.cliente_id 
        AND status IN ('PENDENTE', 'PAGO_PARCIAL', 'VENCIDO')
    )
    WHERE id = NEW.cliente_id;
    
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.atualizar_saldo_cliente() OWNER TO postgres;
GRANT ALL ON FUNCTION public.atualizar_saldo_cliente() TO public;
GRANT ALL ON FUNCTION public.atualizar_saldo_cliente() TO postgres;
GRANT ALL ON FUNCTION public.atualizar_saldo_cliente() TO anon;
GRANT ALL ON FUNCTION public.atualizar_saldo_cliente() TO authenticated;
GRANT ALL ON FUNCTION public.atualizar_saldo_cliente() TO service_role;

-- DROP FUNCTION public.atualizar_totais_comanda();

CREATE OR REPLACE FUNCTION public.atualizar_totais_comanda()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE comandas
    SET 
        subtotal = (
            SELECT COALESCE(SUM(subtotal - desconto), 0)
            FROM comanda_itens
            WHERE comanda_id = NEW.comanda_id
            AND status != 'cancelado'
        ),
        valor_total = (
            SELECT COALESCE(SUM(subtotal - desconto), 0)
            FROM comanda_itens
            WHERE comanda_id = NEW.comanda_id
            AND status != 'cancelado'
        ) - COALESCE((SELECT desconto FROM comandas WHERE id = NEW.comanda_id), 0) 
          + COALESCE((SELECT acrescimo FROM comandas WHERE id = NEW.comanda_id), 0),
        updated_at = NOW()
    WHERE id = NEW.comanda_id;
    
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.atualizar_totais_comanda() OWNER TO postgres;
GRANT ALL ON FUNCTION public.atualizar_totais_comanda() TO public;
GRANT ALL ON FUNCTION public.atualizar_totais_comanda() TO postgres;
GRANT ALL ON FUNCTION public.atualizar_totais_comanda() TO anon;
GRANT ALL ON FUNCTION public.atualizar_totais_comanda() TO authenticated;
GRANT ALL ON FUNCTION public.atualizar_totais_comanda() TO service_role;

-- DROP FUNCTION public.buscar_produtos_disponiveis(text);

CREATE OR REPLACE FUNCTION public.buscar_produtos_disponiveis(p_busca text DEFAULT NULL::text)
 RETURNS TABLE(id uuid, sku character varying, nome character varying, preco_venda numeric, estoque_atual numeric, disponivel boolean)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        p.id,
        p.sku,
        p.nome,
        p.preco_venda,
        p.estoque_atual,
        (p.estoque_atual > 0) as disponivel
    FROM produtos p
    WHERE p.ativo = true
    AND (
        p_busca IS NULL 
        OR p.codigo_barras ILIKE '%' || p_busca || '%'
        OR p.sku ILIKE '%' || p_busca || '%'
        OR p.nome ILIKE '%' || p_busca || '%'
    )
    ORDER BY p.nome;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.buscar_produtos_disponiveis(text) OWNER TO postgres;
GRANT ALL ON FUNCTION public.buscar_produtos_disponiveis(text) TO public;
GRANT ALL ON FUNCTION public.buscar_produtos_disponiveis(text) TO postgres;
GRANT ALL ON FUNCTION public.buscar_produtos_disponiveis(text) TO anon;
GRANT ALL ON FUNCTION public.buscar_produtos_disponiveis(text) TO authenticated;
GRANT ALL ON FUNCTION public.buscar_produtos_disponiveis(text) TO service_role;

-- DROP FUNCTION public.calcular_impostos_produto(uuid, varchar, numeric, numeric);

CREATE OR REPLACE FUNCTION public.calcular_impostos_produto(p_produto_id uuid, p_estado_destino character varying DEFAULT NULL::character varying, p_quantidade numeric DEFAULT 1.00, p_preco_unitario numeric DEFAULT 0.00)
 RETURNS TABLE(aliquota_icms numeric, aliquota_pis numeric, aliquota_cofins numeric, aliquota_ipi numeric, valor_icms numeric, valor_pis numeric, valor_cofins numeric, valor_ipi numeric, valor_total_impostos numeric)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_empresa RECORD;
    v_produto RECORD;
    v_cat_imposto RECORD;
    v_aliq_icms NUMERIC;
    v_aliq_pis NUMERIC;
    v_aliq_cofins NUMERIC;
    v_aliq_ipi NUMERIC;
    v_base_calculo NUMERIC;
BEGIN
    -- Obter empresa
    SELECT * INTO v_empresa FROM empresa_config LIMIT 1;
    
    -- Obter produto
    SELECT * INTO v_produto FROM produtos WHERE id = p_produto_id;
    
    IF v_produto IS NULL THEN
        RAISE EXCEPTION 'Produto não encontrado';
    END IF;
    
    -- Obter alíquotas da categoria
    SELECT * INTO v_cat_imposto 
    FROM categoria_impostos 
    WHERE categoria_id = v_produto.categoria_id;
    
    -- Se não tiver alíquota da categoria, usar do produto
    IF v_cat_imposto IS NULL THEN
        v_aliq_icms := v_produto.aliquota_icms;
        v_aliq_pis := v_produto.aliquota_pis;
        v_aliq_cofins := v_produto.aliquota_cofins;
        v_aliq_ipi := v_produto.aliquota_ipi;
    ELSE
        v_aliq_icms := v_cat_imposto.aliquota_icms;
        v_aliq_pis := v_cat_imposto.aliquota_pis;
        v_aliq_cofins := v_cat_imposto.aliquota_cofins;
        v_aliq_ipi := v_cat_imposto.aliquota_ipi;
    END IF;
    
    -- Calcular base
    v_base_calculo := p_quantidade * p_preco_unitario;
    
    -- Retornar
    RETURN QUERY
    SELECT 
        v_aliq_icms,
        v_aliq_pis,
        v_aliq_cofins,
        v_aliq_ipi,
        ROUND((v_base_calculo * v_aliq_icms / 100), 2),
        ROUND((v_base_calculo * v_aliq_pis / 100), 2),
        ROUND((v_base_calculo * v_aliq_cofins / 100), 2),
        ROUND((v_base_calculo * v_aliq_ipi / 100), 2),
        ROUND((v_base_calculo * (v_aliq_icms + v_aliq_pis + v_aliq_cofins + v_aliq_ipi) / 100), 2);
END;
$function$
;

-- Permissions

ALTER FUNCTION public.calcular_impostos_produto(uuid, varchar, numeric, numeric) OWNER TO postgres;
GRANT ALL ON FUNCTION public.calcular_impostos_produto(uuid, varchar, numeric, numeric) TO public;
GRANT ALL ON FUNCTION public.calcular_impostos_produto(uuid, varchar, numeric, numeric) TO postgres;
GRANT ALL ON FUNCTION public.calcular_impostos_produto(uuid, varchar, numeric, numeric) TO anon;
GRANT ALL ON FUNCTION public.calcular_impostos_produto(uuid, varchar, numeric, numeric) TO authenticated;
GRANT ALL ON FUNCTION public.calcular_impostos_produto(uuid, varchar, numeric, numeric) TO service_role;

-- DROP FUNCTION public.converter_unidade(numeric, unidade_medida, unidade_medida);

CREATE OR REPLACE FUNCTION public.converter_unidade(p_valor numeric, p_de_unidade unidade_medida, p_para_unidade unidade_medida)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN CASE 
        WHEN p_de_unidade = 'CX' AND p_para_unidade = 'UN' THEN p_valor * 12
        WHEN p_de_unidade = 'UN' AND p_para_unidade = 'CX' THEN p_valor / 12
        WHEN p_de_unidade = 'FD' AND p_para_unidade = 'UN' THEN p_valor * 6
        WHEN p_de_unidade = 'UN' AND p_para_unidade = 'FD' THEN p_valor / 6
        WHEN p_de_unidade = 'DZ' AND p_para_unidade = 'UN' THEN p_valor * 12
        WHEN p_de_unidade = 'UN' AND p_para_unidade = 'DZ' THEN p_valor / 12
        ELSE p_valor
    END;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.converter_unidade(numeric, unidade_medida, unidade_medida) OWNER TO postgres;
GRANT ALL ON FUNCTION public.converter_unidade(numeric, unidade_medida, unidade_medida) TO public;
GRANT ALL ON FUNCTION public.converter_unidade(numeric, unidade_medida, unidade_medida) TO postgres;
GRANT ALL ON FUNCTION public.converter_unidade(numeric, unidade_medida, unidade_medida) TO anon;
GRANT ALL ON FUNCTION public.converter_unidade(numeric, unidade_medida, unidade_medida) TO authenticated;
GRANT ALL ON FUNCTION public.converter_unidade(numeric, unidade_medida, unidade_medida) TO service_role;

-- DROP FUNCTION public.crypt(text, text);

CREATE OR REPLACE FUNCTION public.crypt(text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_crypt$function$
;

-- Permissions

ALTER FUNCTION public.crypt(text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.crypt(text, text) TO supabase_admin;

-- DROP FUNCTION public.dearmor(text);

CREATE OR REPLACE FUNCTION public.dearmor(text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_dearmor$function$
;

-- Permissions

ALTER FUNCTION public.dearmor(text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.dearmor(text) TO supabase_admin;

-- DROP FUNCTION public.decrypt(bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.decrypt(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_decrypt$function$
;

-- Permissions

ALTER FUNCTION public.decrypt(bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.decrypt(bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.decrypt_iv(bytea, bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.decrypt_iv(bytea, bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_decrypt_iv$function$
;

-- Permissions

ALTER FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.decrypt_iv(bytea, bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.digest(bytea, text);

CREATE OR REPLACE FUNCTION public.digest(bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_digest$function$
;

-- Permissions

ALTER FUNCTION public.digest(bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.digest(bytea, text) TO supabase_admin;

-- DROP FUNCTION public.digest(text, text);

CREATE OR REPLACE FUNCTION public.digest(text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_digest$function$
;

-- Permissions

ALTER FUNCTION public.digest(text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.digest(text, text) TO supabase_admin;

-- DROP FUNCTION public.encrypt(bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.encrypt(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_encrypt$function$
;

-- Permissions

ALTER FUNCTION public.encrypt(bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.encrypt(bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.encrypt_iv(bytea, bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.encrypt_iv(bytea, bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_encrypt_iv$function$
;

-- Permissions

ALTER FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.encrypt_iv(bytea, bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.fechar_caixa(uuid, numeric);

CREATE OR REPLACE FUNCTION public.fechar_caixa(p_movimentacao_id uuid, p_saldo_final numeric)
 RETURNS TABLE(sucesso boolean, mensagem text, diferenca numeric)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_total_vendas NUMERIC;
    v_diferenca NUMERIC;
BEGIN
    -- Calcular total de vendas
    SELECT COALESCE(SUM(total), 0) INTO v_total_vendas
    FROM vendas
    WHERE movimentacao_caixa_id = p_movimentacao_id
    AND status_venda = 'FINALIZADA';

    -- Calcular diferença
    v_diferenca := p_saldo_final - (
        (SELECT saldo_inicial FROM movimentacoes_caixa WHERE id = p_movimentacao_id) + 
        v_total_vendas
    );

    -- Atualizar movimentação
    UPDATE movimentacoes_caixa
    SET 
        data_fechamento = NOW(),
        total_vendas = v_total_vendas,
        saldo_final = p_saldo_final,
        status = 'FECHADA'
    WHERE id = p_movimentacao_id;

    RETURN QUERY SELECT 
        true,
        CASE 
            WHEN v_diferenca = 0 THEN 'Caixa fechado com precisão'
            WHEN v_diferenca > 0 THEN 'Caixa com excesso de: ' || v_diferenca::text
            ELSE 'Caixa com falta de: ' || (v_diferenca * -1)::text
        END,
        v_diferenca;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.fechar_caixa(uuid, numeric) OWNER TO postgres;
GRANT ALL ON FUNCTION public.fechar_caixa(uuid, numeric) TO public;
GRANT ALL ON FUNCTION public.fechar_caixa(uuid, numeric) TO postgres;
GRANT ALL ON FUNCTION public.fechar_caixa(uuid, numeric) TO anon;
GRANT ALL ON FUNCTION public.fechar_caixa(uuid, numeric) TO authenticated;
GRANT ALL ON FUNCTION public.fechar_caixa(uuid, numeric) TO service_role;

-- DROP FUNCTION public.finalizar_venda_segura(varchar, uuid, uuid, uuid, numeric, numeric, numeric, numeric, pagamento_forma, numeric, numeric);

CREATE OR REPLACE FUNCTION public.finalizar_venda_segura(p_numero_nf character varying, p_caixa_id uuid, p_movimentacao_caixa_id uuid, p_operador_id uuid, p_subtotal numeric, p_desconto numeric, p_acrescimo numeric, p_total numeric, p_forma_pagamento pagamento_forma, p_valor_pago numeric, p_valor_troco numeric)
 RETURNS uuid
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_venda_id UUID;
BEGIN
    -- Usar transação implícita do PL/pgSQL
    -- Buscar com lock (FOR UPDATE) para evitar race condition
    
    INSERT INTO vendas (
        numero_nf,
        caixa_id,
        movimentacao_caixa_id,
        operador_id,
        subtotal,
        desconto,
        desconto_percentual,
        acrescimo,
        total,
        forma_pagamento,
        valor_pago,
        valor_troco,
        status_venda,
        status_fiscal
    ) VALUES (
        p_numero_nf,
        p_caixa_id,
        p_movimentacao_caixa_id,
        p_operador_id,
        p_subtotal,
        p_desconto,
        (p_desconto / p_subtotal * 100),
        p_acrescimo,
        p_total,
        p_forma_pagamento,
        p_valor_pago,
        p_valor_troco,
        'FINALIZADA',
        'SEM_DOCUMENTO_FISCAL'
    )
    RETURNING id INTO v_venda_id;

    -- Registrar pagamento
    INSERT INTO pagamentos_venda (
        venda_id,
        forma,
        valor,
        status_pagamento
    ) VALUES (
        v_venda_id,
        p_forma_pagamento,
        p_valor_pago,
        'RECEBIDO'
    );

    RETURN v_venda_id;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.finalizar_venda_segura(varchar, uuid, uuid, uuid, numeric, numeric, numeric, numeric, pagamento_forma, numeric, numeric) OWNER TO postgres;
GRANT ALL ON FUNCTION public.finalizar_venda_segura(varchar, uuid, uuid, uuid, numeric, numeric, numeric, numeric, pagamento_forma, numeric, numeric) TO public;
GRANT ALL ON FUNCTION public.finalizar_venda_segura(varchar, uuid, uuid, uuid, numeric, numeric, numeric, numeric, pagamento_forma, numeric, numeric) TO postgres;
GRANT ALL ON FUNCTION public.finalizar_venda_segura(varchar, uuid, uuid, uuid, numeric, numeric, numeric, numeric, pagamento_forma, numeric, numeric) TO anon;
GRANT ALL ON FUNCTION public.finalizar_venda_segura(varchar, uuid, uuid, uuid, numeric, numeric, numeric, numeric, pagamento_forma, numeric, numeric) TO authenticated;
GRANT ALL ON FUNCTION public.finalizar_venda_segura(varchar, uuid, uuid, uuid, numeric, numeric, numeric, numeric, pagamento_forma, numeric, numeric) TO service_role;

-- DROP FUNCTION public.gen_random_bytes(int4);

CREATE OR REPLACE FUNCTION public.gen_random_bytes(integer)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_random_bytes$function$
;

-- Permissions

ALTER FUNCTION public.gen_random_bytes(int4) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.gen_random_bytes(int4) TO supabase_admin;

-- DROP FUNCTION public.gen_random_uuid();

CREATE OR REPLACE FUNCTION public.gen_random_uuid()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/pgcrypto', $function$pg_random_uuid$function$
;

-- Permissions

ALTER FUNCTION public.gen_random_uuid() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.gen_random_uuid() TO supabase_admin;

-- DROP FUNCTION public.gen_salt(text);

CREATE OR REPLACE FUNCTION public.gen_salt(text)
 RETURNS text
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_gen_salt$function$
;

-- Permissions

ALTER FUNCTION public.gen_salt(text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.gen_salt(text) TO supabase_admin;

-- DROP FUNCTION public.gen_salt(text, int4);

CREATE OR REPLACE FUNCTION public.gen_salt(text, integer)
 RETURNS text
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_gen_salt_rounds$function$
;

-- Permissions

ALTER FUNCTION public.gen_salt(text, int4) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.gen_salt(text, int4) TO supabase_admin;

-- DROP FUNCTION public.gerar_numero_nfce();

CREATE OR REPLACE FUNCTION public.gerar_numero_nfce()
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_numero INTEGER;
    v_empresa_id UUID;
BEGIN
    -- Buscar ID da empresa (primeira config)
    SELECT id INTO v_empresa_id FROM empresa_config LIMIT 1;

    -- Incrementar número
    UPDATE empresa_config
    SET nfce_numero = nfce_numero + 1
    WHERE id = v_empresa_id;

    -- Retornar número formatado
    SELECT nfce_numero INTO v_numero FROM empresa_config WHERE id = v_empresa_id;
    
    RETURN LPAD(v_numero::text, 6, '0');
END;
$function$
;

-- Permissions

ALTER FUNCTION public.gerar_numero_nfce() OWNER TO postgres;
GRANT ALL ON FUNCTION public.gerar_numero_nfce() TO public;
GRANT ALL ON FUNCTION public.gerar_numero_nfce() TO postgres;
GRANT ALL ON FUNCTION public.gerar_numero_nfce() TO anon;
GRANT ALL ON FUNCTION public.gerar_numero_nfce() TO authenticated;
GRANT ALL ON FUNCTION public.gerar_numero_nfce() TO service_role;

-- DROP FUNCTION public.gerar_numero_venda();

CREATE OR REPLACE FUNCTION public.gerar_numero_venda()
 RETURNS character varying
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN 'PED-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(nextval('vendas_numero_seq')::TEXT, 6, '0');
END;
$function$
;

-- Permissions

ALTER FUNCTION public.gerar_numero_venda() OWNER TO postgres;
GRANT ALL ON FUNCTION public.gerar_numero_venda() TO public;
GRANT ALL ON FUNCTION public.gerar_numero_venda() TO postgres;
GRANT ALL ON FUNCTION public.gerar_numero_venda() TO anon;
GRANT ALL ON FUNCTION public.gerar_numero_venda() TO authenticated;
GRANT ALL ON FUNCTION public.gerar_numero_venda() TO service_role;

-- DROP FUNCTION public.get_preco_custo_para_venda(uuid, uuid);

CREATE OR REPLACE FUNCTION public.get_preco_custo_para_venda(p_produto_id uuid, p_lote_id uuid DEFAULT NULL::uuid)
 RETURNS numeric
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_preco_custo DECIMAL(12,2);
BEGIN
    -- 1. Tentar buscar do lote específico
    IF p_lote_id IS NOT NULL THEN
        SELECT preco_custo INTO v_preco_custo
        FROM produto_lotes
        WHERE id = p_lote_id;
        
        IF v_preco_custo IS NOT NULL AND v_preco_custo > 0 THEN
            RETURN v_preco_custo;
        END IF;
    END IF;
    
    -- 2. Buscar do último pedido de compra recebido
    SELECT pci.preco_unitario INTO v_preco_custo
    FROM pedido_compra_itens pci
    JOIN pedidos_compra pc ON pci.pedido_id = pc.id
    WHERE pci.produto_id = p_produto_id
    AND pc.status = 'RECEBIDO'
    AND pci.quantidade_recebida > 0
    ORDER BY pc.data_recebimento DESC, pc.created_at DESC
    LIMIT 1;
    
    IF v_preco_custo IS NOT NULL AND v_preco_custo > 0 THEN
        RETURN v_preco_custo;
    END IF;
    
    -- 3. Fallback: usar preco_custo do cadastro do produto
    SELECT preco_custo INTO v_preco_custo
    FROM produtos
    WHERE id = p_produto_id;
    
    RETURN COALESCE(v_preco_custo, 0);
END;
$function$
;

-- Permissions

ALTER FUNCTION public.get_preco_custo_para_venda(uuid, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.get_preco_custo_para_venda(uuid, uuid) TO public;
GRANT ALL ON FUNCTION public.get_preco_custo_para_venda(uuid, uuid) TO postgres;
GRANT ALL ON FUNCTION public.get_preco_custo_para_venda(uuid, uuid) TO anon;
GRANT ALL ON FUNCTION public.get_preco_custo_para_venda(uuid, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.get_preco_custo_para_venda(uuid, uuid) TO service_role;

-- DROP FUNCTION public.hmac(bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.hmac(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_hmac$function$
;

-- Permissions

ALTER FUNCTION public.hmac(bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.hmac(bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.hmac(text, text, text);

CREATE OR REPLACE FUNCTION public.hmac(text, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pg_hmac$function$
;

-- Permissions

ALTER FUNCTION public.hmac(text, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.hmac(text, text, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_armor_headers(in text, out text, out text);

CREATE OR REPLACE FUNCTION public.pgp_armor_headers(text, OUT key text, OUT value text)
 RETURNS SETOF record
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_armor_headers$function$
;

-- Permissions

ALTER FUNCTION public.pgp_armor_headers(in text, out text, out text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_armor_headers(in text, out text, out text) TO supabase_admin;

-- DROP FUNCTION public.pgp_key_id(bytea);

CREATE OR REPLACE FUNCTION public.pgp_key_id(bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_key_id_w$function$
;

-- Permissions

ALTER FUNCTION public.pgp_key_id(bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_key_id(bytea) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_decrypt(bytea, bytea);

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt(bytea, bytea)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_decrypt(bytea, bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_decrypt(bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt(bytea, bytea, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text);

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_decrypt(bytea, bytea, text, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea);

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text);

CREATE OR REPLACE FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_decrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_decrypt_bytea(bytea, bytea, text, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_encrypt(text, bytea);

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt(text, bytea)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_encrypt(text, bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_encrypt(text, bytea, text);

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt(text, bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_encrypt(text, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_encrypt(text, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea);

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea) TO supabase_admin;

-- DROP FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text);

CREATE OR REPLACE FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_pub_encrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_pub_encrypt_bytea(bytea, bytea, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_decrypt(bytea, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt(bytea, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_decrypt(bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_decrypt(bytea, text, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt(bytea, text, text)
 RETURNS text
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_decrypt(bytea, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_decrypt(bytea, text, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_decrypt_bytea(bytea, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt_bytea(bytea, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_decrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_decrypt_bytea(bytea, text, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_encrypt(text, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt(text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_encrypt(text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_encrypt(text, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_encrypt(text, text, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt(text, text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_text$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_encrypt(text, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_encrypt(text, text, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_encrypt_bytea(bytea, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt_bytea(bytea, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text) TO supabase_admin;

-- DROP FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text);

CREATE OR REPLACE FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text)
 RETURNS bytea
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/pgcrypto', $function$pgp_sym_encrypt_bytea$function$
;

-- Permissions

ALTER FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.pgp_sym_encrypt_bytea(bytea, text, text) TO supabase_admin;

-- DROP FUNCTION public.processar_entradas_compras();

CREATE OR REPLACE FUNCTION public.processar_entradas_compras()
 RETURNS TABLE(produto_id uuid, produto_nome character varying, quantidade_total numeric, preco_custo numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH entradas AS (
        SELECT 
            pci.produto_id,
            p.nome AS produto_nome,
            SUM(pci.quantidade) AS quantidade_total,
            pci.preco_unitario AS preco_custo
        FROM public.pedido_compra_itens pci
        JOIN public.pedidos_compra pc ON pci.pedido_id = pc.id
        JOIN public.produtos p ON pci.produto_id = p.id
        WHERE pc.status = 'RECEBIDO'  -- Apenas pedidos recebidos
        GROUP BY pci.produto_id, p.nome, pci.preco_unitario
    )
    UPDATE public.produtos p
    SET estoque_atual = estoque_atual + e.quantidade_total
    FROM entradas e
    WHERE p.id = e.produto_id
    RETURNING 
        e.produto_id,
        e.produto_nome,
        e.quantidade_total,
        e.preco_custo;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.processar_entradas_compras() OWNER TO postgres;
GRANT ALL ON FUNCTION public.processar_entradas_compras() TO public;
GRANT ALL ON FUNCTION public.processar_entradas_compras() TO postgres;
GRANT ALL ON FUNCTION public.processar_entradas_compras() TO anon;
GRANT ALL ON FUNCTION public.processar_entradas_compras() TO authenticated;
GRANT ALL ON FUNCTION public.processar_entradas_compras() TO service_role;

-- DROP FUNCTION public.processar_saidas_vendas();

CREATE OR REPLACE FUNCTION public.processar_saidas_vendas()
 RETURNS TABLE(produto_id uuid, produto_nome character varying, quantidade_total numeric, preco_venda numeric)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH saidas AS (
        SELECT 
            vi.produto_id,
            p.nome AS produto_nome,
            SUM(vi.quantidade) AS quantidade_total,
            vi.preco_unitario AS preco_venda
        FROM public.vendas_itens vi
        JOIN public.vendas v ON vi.venda_id = v.id
        JOIN public.produtos p ON vi.produto_id = p.id
        WHERE v.status = 'FINALIZADA'  -- Apenas vendas finalizadas
        GROUP BY vi.produto_id, p.nome, vi.preco_unitario
    )
    UPDATE public.produtos p
    SET estoque_atual = estoque_atual - s.quantidade_total
    FROM saidas s
    WHERE p.id = s.produto_id
    AND estoque_atual >= s.quantidade_total  -- Validação!
    RETURNING 
        s.produto_id,
        s.produto_nome,
        s.quantidade_total,
        s.preco_venda;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.processar_saidas_vendas() OWNER TO postgres;
GRANT ALL ON FUNCTION public.processar_saidas_vendas() TO public;
GRANT ALL ON FUNCTION public.processar_saidas_vendas() TO postgres;
GRANT ALL ON FUNCTION public.processar_saidas_vendas() TO anon;
GRANT ALL ON FUNCTION public.processar_saidas_vendas() TO authenticated;
GRANT ALL ON FUNCTION public.processar_saidas_vendas() TO service_role;

-- DROP FUNCTION public.reprocessar_estoque_novo();

CREATE OR REPLACE FUNCTION public.reprocessar_estoque_novo()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Log de início
    RAISE NOTICE '========================================';
    RAISE NOTICE 'INICIANDO REPROCESSAMENTO DE ESTOQUE';
    RAISE NOTICE '========================================';
    
    -- ETAPA 1: Zerar
    RAISE NOTICE '1️⃣  Zerando estoque...';
    PERFORM zerar_estoque_completo();
    RAISE NOTICE '   ✅ Estoque zerado com sucesso';
    
    -- ETAPA 2: Processar Entradas
    RAISE NOTICE '2️⃣  Processando entradas de compras...';
    PERFORM processar_entradas_compras();
    RAISE NOTICE '   ✅ Entradas processadas com sucesso';
    
    -- ETAPA 3: Processar Saídas
    RAISE NOTICE '3️⃣  Processando saídas de vendas...';
    PERFORM processar_saidas_vendas();
    RAISE NOTICE '   ✅ Saídas processadas com sucesso';
    
    -- ETAPA 4: Atualizar Lotes
    RAISE NOTICE '4️⃣  Atualizando quantidade de lotes...';
    PERFORM atualizar_quantidade_lotes();
    RAISE NOTICE '   ✅ Lotes atualizados com sucesso';
    
    -- ETAPA 5: Validar
    RAISE NOTICE '5️⃣  Validando consistência...';
    PERFORM validar_consistencia_estoque();
    RAISE NOTICE '   ✅ Validação concluída com sucesso';
    
    RAISE NOTICE '========================================';
    RAISE NOTICE 'REPROCESSAMENTO CONCLUÍDO!';
    RAISE NOTICE '========================================';
END;
$function$
;

-- Permissions

ALTER FUNCTION public.reprocessar_estoque_novo() OWNER TO postgres;
GRANT ALL ON FUNCTION public.reprocessar_estoque_novo() TO public;
GRANT ALL ON FUNCTION public.reprocessar_estoque_novo() TO postgres;
GRANT ALL ON FUNCTION public.reprocessar_estoque_novo() TO anon;
GRANT ALL ON FUNCTION public.reprocessar_estoque_novo() TO authenticated;
GRANT ALL ON FUNCTION public.reprocessar_estoque_novo() TO service_role;

-- DROP FUNCTION public.stats_vendas_dia(out numeric, out int4, out numeric);

CREATE OR REPLACE FUNCTION public.stats_vendas_dia(OUT total_vendas numeric, OUT quantidade_itens integer, OUT media_venda numeric)
 RETURNS record
 LANGUAGE plpgsql
AS $function$
BEGIN
    SELECT 
        COALESCE(SUM(v.total), 0),
        COALESCE(COUNT(DISTINCT vi.id), 0),
        COALESCE(AVG(v.total), 0)
    INTO total_vendas, quantidade_itens, media_venda
    FROM vendas v
    LEFT JOIN vendas_itens vi ON v.id = vi.venda_id
    WHERE DATE(v.created_at) = CURRENT_DATE
    AND v.status_venda = 'FINALIZADA';
END;
$function$
;

-- Permissions

ALTER FUNCTION public.stats_vendas_dia(out numeric, out int4, out numeric) OWNER TO postgres;
GRANT ALL ON FUNCTION public.stats_vendas_dia(out numeric, out int4, out numeric) TO public;
GRANT ALL ON FUNCTION public.stats_vendas_dia(out numeric, out int4, out numeric) TO postgres;
GRANT ALL ON FUNCTION public.stats_vendas_dia(out numeric, out int4, out numeric) TO anon;
GRANT ALL ON FUNCTION public.stats_vendas_dia(out numeric, out int4, out numeric) TO authenticated;
GRANT ALL ON FUNCTION public.stats_vendas_dia(out numeric, out int4, out numeric) TO service_role;

-- DROP FUNCTION public.trg_venda_item_set_preco_custo();

CREATE OR REPLACE FUNCTION public.trg_venda_item_set_preco_custo()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Se preco_custo não foi informado, buscar automaticamente
    IF NEW.preco_custo IS NULL OR NEW.preco_custo = 0 THEN
        NEW.preco_custo := get_preco_custo_para_venda(NEW.produto_id, NEW.lote_id);
    END IF;
    
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.trg_venda_item_set_preco_custo() OWNER TO postgres;
GRANT ALL ON FUNCTION public.trg_venda_item_set_preco_custo() TO public;
GRANT ALL ON FUNCTION public.trg_venda_item_set_preco_custo() TO postgres;
GRANT ALL ON FUNCTION public.trg_venda_item_set_preco_custo() TO anon;
GRANT ALL ON FUNCTION public.trg_venda_item_set_preco_custo() TO authenticated;
GRANT ALL ON FUNCTION public.trg_venda_item_set_preco_custo() TO service_role;

-- DROP FUNCTION public.update_updated_at_column();

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.update_updated_at_column() OWNER TO postgres;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO public;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO postgres;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO anon;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_updated_at_column() TO service_role;

-- DROP FUNCTION public.uuid_generate_v1();

CREATE OR REPLACE FUNCTION public.uuid_generate_v1()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v1$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v1() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_generate_v1() TO supabase_admin;

-- DROP FUNCTION public.uuid_generate_v1mc();

CREATE OR REPLACE FUNCTION public.uuid_generate_v1mc()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v1mc$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v1mc() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_generate_v1mc() TO supabase_admin;

-- DROP FUNCTION public.uuid_generate_v3(uuid, text);

CREATE OR REPLACE FUNCTION public.uuid_generate_v3(namespace uuid, name text)
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v3$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v3(uuid, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_generate_v3(uuid, text) TO supabase_admin;

-- DROP FUNCTION public.uuid_generate_v4();

CREATE OR REPLACE FUNCTION public.uuid_generate_v4()
 RETURNS uuid
 LANGUAGE c
 PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v4$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v4() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_generate_v4() TO supabase_admin;

-- DROP FUNCTION public.uuid_generate_v5(uuid, text);

CREATE OR REPLACE FUNCTION public.uuid_generate_v5(namespace uuid, name text)
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_generate_v5$function$
;

-- Permissions

ALTER FUNCTION public.uuid_generate_v5(uuid, text) OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_generate_v5(uuid, text) TO supabase_admin;

-- DROP FUNCTION public.uuid_nil();

CREATE OR REPLACE FUNCTION public.uuid_nil()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_nil$function$
;

-- Permissions

ALTER FUNCTION public.uuid_nil() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_nil() TO supabase_admin;

-- DROP FUNCTION public.uuid_ns_dns();

CREATE OR REPLACE FUNCTION public.uuid_ns_dns()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_dns$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_dns() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_ns_dns() TO supabase_admin;

-- DROP FUNCTION public.uuid_ns_oid();

CREATE OR REPLACE FUNCTION public.uuid_ns_oid()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_oid$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_oid() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_ns_oid() TO supabase_admin;

-- DROP FUNCTION public.uuid_ns_url();

CREATE OR REPLACE FUNCTION public.uuid_ns_url()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_url$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_url() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_ns_url() TO supabase_admin;

-- DROP FUNCTION public.uuid_ns_x500();

CREATE OR REPLACE FUNCTION public.uuid_ns_x500()
 RETURNS uuid
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/uuid-ossp', $function$uuid_ns_x500$function$
;

-- Permissions

ALTER FUNCTION public.uuid_ns_x500() OWNER TO supabase_admin;
GRANT ALL ON FUNCTION public.uuid_ns_x500() TO supabase_admin;

-- DROP FUNCTION public.validar_consistencia_estoque();

CREATE OR REPLACE FUNCTION public.validar_consistencia_estoque()
 RETURNS TABLE(produto_id uuid, produto_nome character varying, estoque_atual numeric, entradas_total numeric, saidas_total numeric, estoque_calculado numeric, status character varying)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH movimentacao AS (
        -- Entradas de compras
        SELECT 
            pci.produto_id,
            'ENTRADA'::VARCHAR AS tipo,
            SUM(pci.quantidade) AS quantidade
        FROM public.pedido_compra_itens pci
        JOIN public.pedidos_compra pc ON pci.pedido_id = pc.id
        WHERE pc.status = 'RECEBIDO'
        GROUP BY pci.produto_id
        
        UNION ALL
        
        -- Saídas de vendas
        SELECT 
            vi.produto_id,
            'SAIDA'::VARCHAR,
            -SUM(vi.quantidade)
        FROM public.vendas_itens vi
        JOIN public.vendas v ON vi.venda_id = v.id
        WHERE v.status = 'FINALIZADA'
        GROUP BY vi.produto_id
    ),
    resumo AS (
        SELECT 
            p.id AS produto_id,
            p.nome AS produto_nome,
            p.estoque_atual,
            COALESCE(
                SUM(CASE WHEN m.tipo = 'ENTRADA' THEN m.quantidade ELSE 0 END), 0
            ) AS entradas_total,
            COALESCE(
                SUM(CASE WHEN m.tipo = 'SAIDA' THEN -m.quantidade ELSE 0 END), 0
            ) AS saidas_total
        FROM public.produtos p
        LEFT JOIN movimentacao m ON p.id = m.produto_id
        GROUP BY p.id, p.nome, p.estoque_atual
    )
    SELECT 
        r.produto_id,
        r.produto_nome,
        r.estoque_atual,
        r.entradas_total,
        r.saidas_total,
        (r.entradas_total - r.saidas_total)::NUMERIC AS estoque_calculado,
        CASE 
            WHEN r.estoque_atual = (r.entradas_total - r.saidas_total) THEN 'OK'::VARCHAR
            ELSE 'DIVERGÊNCIA'::VARCHAR
        END AS status
    FROM resumo r
    WHERE r.estoque_atual > 0 OR r.entradas_total > 0 OR r.saidas_total > 0
    ORDER BY r.produto_nome;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.validar_consistencia_estoque() OWNER TO postgres;
GRANT ALL ON FUNCTION public.validar_consistencia_estoque() TO public;
GRANT ALL ON FUNCTION public.validar_consistencia_estoque() TO postgres;
GRANT ALL ON FUNCTION public.validar_consistencia_estoque() TO anon;
GRANT ALL ON FUNCTION public.validar_consistencia_estoque() TO authenticated;
GRANT ALL ON FUNCTION public.validar_consistencia_estoque() TO service_role;

-- DROP FUNCTION public.validar_cpf_cnpj(varchar);

CREATE OR REPLACE FUNCTION public.validar_cpf_cnpj(p_documento character varying)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_doc VARCHAR;
    v_sum INTEGER;
    v_resto INTEGER;
    i INTEGER;
BEGIN
    -- Remover caracteres especiais
    v_doc := regexp_replace(p_documento, '[^0-9]', '', 'g');

    -- Validar tamanho
    IF length(v_doc) NOT IN (11, 14) THEN
        RETURN false;
    END IF;

    -- Validar CPF (11 dígitos)
    IF length(v_doc) = 11 THEN
        -- Validação simplificada
        IF v_doc ~ '^[0-9]{11}$' THEN
            RETURN true;
        END IF;
    END IF;

    -- Validar CNPJ (14 dígitos)
    IF length(v_doc) = 14 THEN
        IF v_doc ~ '^[0-9]{14}$' THEN
            RETURN true;
        END IF;
    END IF;

    RETURN false;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.validar_cpf_cnpj(varchar) OWNER TO postgres;
GRANT ALL ON FUNCTION public.validar_cpf_cnpj(varchar) TO public;
GRANT ALL ON FUNCTION public.validar_cpf_cnpj(varchar) TO postgres;
GRANT ALL ON FUNCTION public.validar_cpf_cnpj(varchar) TO anon;
GRANT ALL ON FUNCTION public.validar_cpf_cnpj(varchar) TO authenticated;
GRANT ALL ON FUNCTION public.validar_cpf_cnpj(varchar) TO service_role;

-- DROP FUNCTION public.validar_dados_emissao_fiscal();

CREATE OR REPLACE FUNCTION public.validar_dados_emissao_fiscal()
 RETURNS TABLE(campo character varying, status character varying, mensagem text)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_empresa RECORD;
    v_problemas INT := 0;
BEGIN
    SELECT * INTO v_empresa FROM empresa_config LIMIT 1;
    
    -- Verificar empresa
    IF v_empresa IS NULL THEN
        RETURN QUERY SELECT 'empresa_config'::VARCHAR, 'ERRO'::VARCHAR, 'Nenhuma empresa configurada'::TEXT;
        v_problemas := v_problemas + 1;
    END IF;
    
    -- Verificar campos obrigatórios
    IF v_empresa.cnpj IS NULL OR v_empresa.cnpj = '' THEN
        RETURN QUERY SELECT 'empresa.cnpj'::VARCHAR, 'ERRO'::VARCHAR, 'CNPJ não preenchido'::TEXT;
        v_problemas := v_problemas + 1;
    END IF;
    
    IF v_empresa.inscricao_estadual IS NULL OR v_empresa.inscricao_estadual = '' THEN
        RETURN QUERY SELECT 'empresa.inscricao_estadual'::VARCHAR, 'ERRO'::VARCHAR, 'IE não preenchida'::TEXT;
        v_problemas := v_problemas + 1;
    END IF;
    
    IF v_empresa.logradouro IS NULL OR v_empresa.logradouro = '' THEN
        RETURN QUERY SELECT 'empresa.logradouro'::VARCHAR, 'ERRO'::VARCHAR, 'Logradouro não preenchido'::TEXT;
        v_problemas := v_problemas + 1;
    END IF;
    
    IF v_empresa.codigo_municipio IS NULL OR v_empresa.codigo_municipio = '' THEN
        RETURN QUERY SELECT 'empresa.codigo_municipio'::VARCHAR, 'ERRO'::VARCHAR, 'Código município IBGE não preenchido'::TEXT;
        v_problemas := v_problemas + 1;
    END IF;
    
    IF v_empresa.nfe_token IS NULL OR v_empresa.nfe_token = '' THEN
        RETURN QUERY SELECT 'empresa.nfe_token'::VARCHAR, 'AVISO'::VARCHAR, 'Token Focus NFe não configurado (emissão não funcionará)'::TEXT;
        v_problemas := v_problemas + 1;
    END IF;
    
    IF v_empresa.certificado_digital IS NULL OR v_empresa.certificado_digital = '' THEN
        RETURN QUERY SELECT 'empresa.certificado_digital'::VARCHAR, 'AVISO'::VARCHAR, 'Certificado digital não carregado'::TEXT;
        v_problemas := v_problemas + 1;
    END IF;
    
    -- Verificar produtos
    IF (SELECT COUNT(*) FROM produtos WHERE ncm IS NULL OR ncm = '') > 0 THEN
        RETURN QUERY SELECT 'produtos.ncm'::VARCHAR, 'AVISO'::VARCHAR, CONCAT((SELECT COUNT(*) FROM produtos WHERE ncm IS NULL OR ncm = ''), ' produtos sem NCM'::TEXT);
        v_problemas := v_problemas + 1;
    END IF;
    
    IF (SELECT COUNT(*) FROM produtos WHERE cfop IS NULL OR cfop = '') > 0 THEN
        RETURN QUERY SELECT 'produtos.cfop'::VARCHAR, 'AVISO'::VARCHAR, CONCAT((SELECT COUNT(*) FROM produtos WHERE cfop IS NULL OR cfop = ''), ' produtos sem CFOP'::TEXT);
        v_problemas := v_problemas + 1;
    END IF;
    
    -- Resultado final
    IF v_problemas = 0 THEN
        RETURN QUERY SELECT 'GERAL'::VARCHAR, 'OK'::VARCHAR, 'Sistema pronto para emissão fiscal'::TEXT;
    ELSE
        RETURN QUERY SELECT 'GERAL'::VARCHAR, 'CRÍTICO'::VARCHAR, CONCAT(v_problemas, ' problemas encontrados'::TEXT);
    END IF;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.validar_dados_emissao_fiscal() OWNER TO postgres;
GRANT ALL ON FUNCTION public.validar_dados_emissao_fiscal() TO public;
GRANT ALL ON FUNCTION public.validar_dados_emissao_fiscal() TO postgres;
GRANT ALL ON FUNCTION public.validar_dados_emissao_fiscal() TO anon;
GRANT ALL ON FUNCTION public.validar_dados_emissao_fiscal() TO authenticated;
GRANT ALL ON FUNCTION public.validar_dados_emissao_fiscal() TO service_role;

-- DROP FUNCTION public.validar_estoque_positivo();

CREATE OR REPLACE FUNCTION public.validar_estoque_positivo()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.estoque_atual < 0 THEN
        RAISE EXCEPTION 'Estoque não pode ser negativo para o produto %', NEW.nome;
    END IF;
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.validar_estoque_positivo() OWNER TO postgres;
GRANT ALL ON FUNCTION public.validar_estoque_positivo() TO public;
GRANT ALL ON FUNCTION public.validar_estoque_positivo() TO postgres;
GRANT ALL ON FUNCTION public.validar_estoque_positivo() TO anon;
GRANT ALL ON FUNCTION public.validar_estoque_positivo() TO authenticated;
GRANT ALL ON FUNCTION public.validar_estoque_positivo() TO service_role;

-- DROP FUNCTION public.validar_sku_unico();

CREATE OR REPLACE FUNCTION public.validar_sku_unico()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Valida apenas se SKU não é NULL e não é vazio
    IF NEW.sku IS NOT NULL AND NEW.sku != '' THEN
        -- Verifica se já existe outro produto com este SKU
        IF EXISTS (
            SELECT 1 FROM produtos 
            WHERE sku = NEW.sku 
            AND id != NEW.id  -- Ignora o próprio registro em UPDATE
        ) THEN
            RAISE EXCEPTION 'Erro: SKU "%" já existe em outro produto!', NEW.sku;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$function$
;

-- Permissions

ALTER FUNCTION public.validar_sku_unico() OWNER TO postgres;
GRANT ALL ON FUNCTION public.validar_sku_unico() TO public;
GRANT ALL ON FUNCTION public.validar_sku_unico() TO postgres;
GRANT ALL ON FUNCTION public.validar_sku_unico() TO anon;
GRANT ALL ON FUNCTION public.validar_sku_unico() TO authenticated;
GRANT ALL ON FUNCTION public.validar_sku_unico() TO service_role;

-- DROP FUNCTION public.verificar_acesso_role(uuid, user_role);

CREATE OR REPLACE FUNCTION public.verificar_acesso_role(p_usuario_id uuid, p_role user_role)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_user_role user_role;
BEGIN
    SELECT role INTO v_user_role FROM users WHERE id = p_usuario_id;
    RETURN v_user_role = p_role OR v_user_role = 'ADMIN';
END;
$function$
;

-- Permissions

ALTER FUNCTION public.verificar_acesso_role(uuid, user_role) OWNER TO postgres;
GRANT ALL ON FUNCTION public.verificar_acesso_role(uuid, user_role) TO public;
GRANT ALL ON FUNCTION public.verificar_acesso_role(uuid, user_role) TO postgres;
GRANT ALL ON FUNCTION public.verificar_acesso_role(uuid, user_role) TO anon;
GRANT ALL ON FUNCTION public.verificar_acesso_role(uuid, user_role) TO authenticated;
GRANT ALL ON FUNCTION public.verificar_acesso_role(uuid, user_role) TO service_role;

-- DROP FUNCTION public.zerar_estoque_completo();

CREATE OR REPLACE FUNCTION public.zerar_estoque_completo()
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
    -- Zerar estoque dos produtos (WHERE garante segurança)
    UPDATE public.produtos SET estoque_atual = 0 WHERE estoque_atual <> 0;
    
    -- Zerar quantidade dos lotes (WHERE garante segurança)
    UPDATE public.produto_lotes SET quantidade_atual = 0 WHERE quantidade_atual <> 0;
    
    RAISE NOTICE '✅ Estoque zerado com sucesso';
END;
$function$
;

-- Permissions

ALTER FUNCTION public.zerar_estoque_completo() OWNER TO postgres;
GRANT ALL ON FUNCTION public.zerar_estoque_completo() TO public;
GRANT ALL ON FUNCTION public.zerar_estoque_completo() TO postgres;
GRANT ALL ON FUNCTION public.zerar_estoque_completo() TO anon;
GRANT ALL ON FUNCTION public.zerar_estoque_completo() TO authenticated;
GRANT ALL ON FUNCTION public.zerar_estoque_completo() TO service_role;


-- Permissions

GRANT ALL ON SCHEMA public TO postgres;
GRANT ALL ON SCHEMA public TO public;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT INSERT, UPDATE, SELECT, DELETE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT INSERT, UPDATE, SELECT, DELETE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT INSERT, UPDATE, SELECT, DELETE ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT USAGE ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT USAGE ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT USAGE ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO service_role;
