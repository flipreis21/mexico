/*
==========================================================
Script 02: Enriquecimento da Tabela 'poligono' (Nova Lógica)
Preenche os dados de Estado e Município usando a hierarquia
da 'optim.jurisdiction' com base na maior sobreposição.

Substitui os scripts 02, 05 e 06 anteriores.
==========================================================
*/

-- Passo 1: Adicionar as novas colunas (se não existirem)
-- (Vamos remover as colunas 'parent_abbrev' e 'name' antigas)
ALTER TABLE poligono DROP COLUMN IF EXISTS parent_abbrev;
ALTER TABLE poligono DROP COLUMN IF EXISTS name;

ALTER TABLE poligono ADD COLUMN IF NOT EXISTS estado_isolabel text;
ALTER TABLE poligono ADD COLUMN IF NOT EXISTS estado_name text;
ALTER TABLE poligono ADD COLUMN IF NOT EXISTS municipio_name text;

-- Passo 2: Limpar dados de execuções anteriores (se houver)
UPDATE poligono SET estado_isolabel=NULL, estado_name=NULL, municipio_name=NULL;

----------------------------------------------------------
-- ETAPA 1: ATRIBUIR O ESTADO (Length = 6)
----------------------------------------------------------
WITH state_matches AS (
  SELECT
    DISTINCT ON (p.cp) p.cp, -- Para cada 'cp'
    jd.isolabel_ext,
    jd.name,
    ST_Area(
      ST_Intersection(p.geom, ST_Transform(jg.geom, 6362))
    ) AS area_sobreposicao
  FROM
    poligono AS p
  JOIN
    optim.jurisdiction_geom AS jg ON ST_Intersects(p.geom, ST_Transform(jg.geom, 6362))
  JOIN
    optim.jurisdiction AS jd ON jg.osm_id = jd.osm_id
  WHERE
    -- Regra de ESTADO: isolabel_ext tem 6 caracteres (ex: 'MX-CMX')
    length(jd.isolabel_ext) = 6
    AND ST_IsValid(p.geom) AND ST_IsValid(jg.geom)
  ORDER BY
    -- Lógica de "Maior Sobreposição": Pega o que tiver mais área
    p.cp, area_sobreposicao DESC
)
-- Atualiza a tabela 'poligono' com os resultados
UPDATE poligono p
SET
  estado_isolabel = sm.isolabel_ext,
  estado_name = sm.name
FROM
  state_matches sm
WHERE
  p.cp = sm.cp;

----------------------------------------------------------
-- ETAPA 2: ATRIBUIR O MUNICÍPIO (Length > 6)
----------------------------------------------------------
WITH municipality_matches AS (
  SELECT
    DISTINCT ON (p.cp) p.cp,
    jd.name,
    ST_Area(
      ST_Intersection(p.geom, ST_Transform(jg.geom, 6362))
    ) AS area_sobreposicao
  FROM
    poligono AS p
  JOIN
    optim.jurisdiction_geom AS jg ON ST_Intersects(p.geom, ST_Transform(jg.geom, 6362))
  JOIN
    optim.jurisdiction AS jd ON jg.osm_id = jd.osm_id
  WHERE
    -- Regra de MUNICÍPIO: isolabel_ext tem mais de 6 caracteres
    length(jd.isolabel_ext) > 6
    -- Regra de EXCEÇÃO: Não fazer isso para 'Ciudad de México'
    AND p.estado_isolabel != 'MX-CMX'
    AND ST_IsValid(p.geom) AND ST_IsValid(jg.geom)
  ORDER BY
    -- Lógica de "Maior Sobreposição"
    p.cp, area_sobreposicao DESC
)
-- Atualiza a tabela 'poligono' com os resultados
UPDATE poligono p
SET
  municipio_name = mm.name
FROM
  municipality_matches mm
WHERE
  p.cp = mm.cp;
