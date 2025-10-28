/*
==========================================================
Script 04: Enriquecimento e Validação da Tabela de Staging
Usa a tabela 'poligono' para:
1. Adicionar o postcode validado espacialmente.
2. Adicionar 'cidade' e 'estado_abbrev'.
3. "Confrontar" o postcode original com o validado.
==========================================================
*/

-- Adiciona as colunas que receberão os dados
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS postcode_validado text;
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS cidade text;
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS estado_abbrev text;
ALTER TABLE public.produto_final_staging ADD COLUMN IF NOT EXISTS flag_postcode_match boolean;

-- Executa o JOIN espacial (ST_Within) para validar
UPDATE public.produto_final_staging s
SET
    postcode_validado = p.cp,
    cidade = p.name,
    estado_abbrev = p.parent_abbrev,
    -- O "Confronto":
    -- Compara o 'postcode_original' (de new_inegi) com o 'cp' (de poligono)
    flag_postcode_match = (s.postcode_original = p.cp)
FROM
    poligono p
WHERE
    ST_Within(s.geom, p.geom);

