/*
==========================================================
Script 04: Enriquecimento e Validação da Tabela de Staging
Usa a tabela 'poligono' (agora com 'estado_name' e 'municipio_name'
limpos) para enriquecer a tabela 'produto_final_staging'.
==========================================================
*/

-- Limpa colunas antigas (se existirem)
ALTER TABLE public.produto_final_staging DROP COLUMN IF EXISTS cidade;
ALTER TABLE public.produto_final_staging DROP COLUMN IF EXISTS estado_abbrev;

-- Adiciona as colunas que receberão os dados
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS postcode_validado text;
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS estado_name text;
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS municipio_name text;
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS flag_postcode_match boolean;

-- Executa o JOIN espacial (ST_Within) para validar
UPDATE public.produto_final_staging s
SET
    postcode_validado = p.cp,
    estado_name = p.estado_name,       -- (Nova lógica)
    municipio_name = p.municipio_name, -- (Nova lógica)
    -- O "Confronto":
    flag_postcode_match = (s.postcode_original = p.cp)
FROM
    poligono p
WHERE
    ST_Within(s.geom, p.geom);

