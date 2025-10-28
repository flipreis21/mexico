/*
==========================================================
Script 05: Cria Tabela de Mapeamento de Estados
Cria uma tabela 'mapa_estados' para traduzir a abreviação
do estado (ex: 'MX-CMX') para o nome completo (ex: 'Ciudad de México'),
usando a tabela 'inegi' como fonte.
==========================================================
*/

-- (Opcional) Limpar tabela antiga se estiver re-executando
DROP TABLE IF EXISTS public.mapa_estados;

-- Cria a tabela de-para (lookup table)
CREATE TABLE public.mapa_estados AS
SELECT DISTINCT
  p.parent_abbrev AS abbrev,
  i.estado AS nome_completo
FROM
  poligono p
JOIN
  inegi i ON p.cp = i.postcode
WHERE
  p.parent_abbrev IS NOT NULL
  AND i.estado IS NOT NULL AND i.estado != '';

-- Criar um índice para acelerar o join final
CREATE INDEX IF NOT EXISTS idx_mapa_estados_abbrev ON public.mapa_estados(abbrev);

