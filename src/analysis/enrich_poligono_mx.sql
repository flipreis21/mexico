/*
==========================================================
Script 02: Enriquecimento da Tabela 'poligono' (Nova Lógica V2)
Preenche os dados de Estado e Município usando as tabelas
'optim.estado' e 'optim.municipio' (fontes limpas).

Esta versão substitui a lógica baseada em 'isolabel_ext'.
SRID 6362 é usado em todas as tabelas (sem ST_Transform).
==========================================================
*/

-- Passo 1: Limpar colunas antigas e garantir que as novas existam
ALTER TABLE poligono DROP COLUMN IF EXISTS parent_abbrev;
ALTER TABLE poligono DROP COLUMN IF EXISTS estado_isolabel;
ALTER TABLE poligono ADD COLUMN IF NOT EXISTS estado_name text;
ALTER TABLE poligono ADD COLUMN IF NOT EXISTS municipio_name text;

-- Limpa execuções anteriores
UPDATE poligono SET estado_name=NULL, municipio_name=NULL;

----------------------------------------------------------
-- ETAPA 1: ATRIBUIR O ESTADO (Usando 'optim.estado')
----------------------------------------------------------
WITH state_matches AS (
  SELECT
    DISTINCT ON (p.cp) p.cp,
    ef.NOMGEO AS best_state_name,
    ST_Area(
      ST_Intersection(p.geom, ef.geom)
    ) AS area_sobreposicao
  FROM
    poligono AS p
  JOIN
    -- JUNTA com a nova tabela de estados (SRID 6362)
    optim.estado AS ef ON ST_Intersects(p.geom, ef.geom)
  WHERE
    ST_IsValid(p.geom) AND ST_IsValid(ef.geom)
  ORDER BY
    -- Lógica de "Maior Sobreposição": Pega o que tiver mais área
    p.cp, area_sobreposicao DESC
)
-- Atualiza 'poligono'
UPDATE poligono p
SET
  estado_name = sm.best_state_name
FROM
  state_matches sm
WHERE
  p.cp = sm.cp;

----------------------------------------------------------
-- ETAPA 2: ATRIBUIR O MUNICÍPIO (Usando 'optim.municipio')
----------------------------------------------------------
WITH municipality_matches AS (
  SELECT
    DISTINCT ON (p.cp) p.cp,
    m.NOMGEO AS best_municipio_name,
    ST_Area(
      ST_Intersection(p.geom, m.geom)
    ) AS area_sobreposicao
  FROM
    poligono AS p
  JOIN
    -- JUNTA com a nova tabela de municípios (SRID 6362)
    optim.municipio AS m ON ST_Intersects(p.geom, m.geom)
  WHERE
    ST_IsValid(p.geom) AND ST_IsValid(m.geom)
  ORDER BY
    -- Lógica de "Maior Sobreposição"
    p.cp, area_sobreposicao DESC
)
-- Atualiza 'poligono'
UPDATE poligono p
SET
  municipio_name = mm.best_municipio_name
FROM
  municipality_matches mm
WHERE
  p.cp = mm.cp;
