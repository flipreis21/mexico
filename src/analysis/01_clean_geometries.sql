/*
==========================================================
Script 01: Limpeza de Geometria (Pré-Análise)
Corrige geometrias inválidas (ex: self-intersections) que
impedem a execução de joins espaciais.
==========================================================
*/

-- Limpeza da Tabela 'poligono'
-- (Corrige o erro 'GeometryCollection does not match column type')
UPDATE poligono
SET
  geom = ST_CollectionExtract(ST_MakeValid(geom), 3)
WHERE
  NOT ST_IsValid(geom);

-- Limpeza da Tabela 'jurisdiction_geom'
UPDATE optim.jurisdiction_geom
SET
  geom = ST_CollectionExtract(ST_MakeValid(geom), 3)
WHERE
  NOT ST_IsValid(geom);
