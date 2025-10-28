/*
==========================================================
Script 02b: Patch para 'poligono' (Correção de Órfãos)
Complementa o script 02, corrigindo os polígonos
onde 'estado_name' ficou nulo devido a falhas no
polígono de estado (length=6).

Lógica "Bottom-Up":
1. Encontra o MUNICÍPIO (length>6) com maior sobreposição.
2. Usa o 'parent_id' desse município para encontrar o ESTADO.
==========================================================
*/

WITH
-- 1. Encontra o melhor MUNICÍPIO (length>6) para cada polígono órfão
municipality_patch AS (
  SELECT
    DISTINCT ON (p.cp) p.cp,
    jd.name AS best_municipio_name,
    jd.parent_id AS state_osm_id -- A chave para o estado
  FROM
    poligono AS p
  JOIN
    optim.jurisdiction_geom AS jg ON ST_Intersects(p.geom, ST_Transform(jg.geom, 6362))
  JOIN
    optim.jurisdiction AS jd ON jg.osm_id = jd.osm_id
  WHERE
    -- Alvo: Apenas os polígonos que falharam no script 02
    p.estado_name IS NULL
    AND p.geom IS NOT NULL -- Ignora geometrias nulas
    -- Lógica de busca: Apenas municípios
    AND length(jd.isolabel_ext) > 6
    AND ST_IsValid(p.geom) AND ST_IsValid(jg.geom)
  ORDER BY
    -- Lógica de "Maior Sobreposição"
    p.cp,
    ST_Area(ST_Intersection(p.geom, ST_Transform(jg.geom, 6362))) DESC
)
-- 2. Atualiza 'poligono' usando o 'parent_id' para buscar o nome do estado
UPDATE poligono p
SET
  municipio_name = mp.best_municipio_name,
  -- Busca o nome do estado (state.name)
  estado_name = state.name
FROM
  municipality_patch AS mp
JOIN
  -- Segunda 'JOIN' para buscar o estado pelo 'parent_id'
  optim.jurisdiction AS state ON state.osm_id = mp.state_osm_id
WHERE
  p.cp = mp.cp;
