ALTER TABLE public.empresa_config
DROP CONSTRAINT IF EXISTS empresa_config_api_fiscal_provider_check;

ALTER TABLE public.empresa_config
ADD CONSTRAINT empresa_config_api_fiscal_provider_check
CHECK (
    (api_fiscal_provider)::text = ANY (
        ARRAY[
            'focus_nfe'::character varying,
            'nuvem_fiscal'::character varying,
            'sefaz_direta'::character varying
        ]::text[]
    )
);

ALTER TABLE public.documentos_fiscais
DROP CONSTRAINT IF EXISTS documentos_fiscais_api_provider_check;

ALTER TABLE public.documentos_fiscais
ADD CONSTRAINT documentos_fiscais_api_provider_check
CHECK (
    (api_provider)::text = ANY (
        ARRAY[
            'focus_nfe'::character varying,
            'nuvem_fiscal'::character varying,
            'sefaz_direta'::character varying
        ]::text[]
    )
);

COMMENT ON COLUMN public.empresa_config.api_fiscal_provider IS
'Provedor de API fiscal a ser utilizado: focus_nfe, nuvem_fiscal ou sefaz_direta';

COMMENT ON COLUMN public.documentos_fiscais.api_provider IS
'Provedor da API fiscal: focus_nfe, nuvem_fiscal ou sefaz_direta';
