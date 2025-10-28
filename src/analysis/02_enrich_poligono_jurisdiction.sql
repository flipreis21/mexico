/*
==========================================================
Script 02: Enriquecimento da Tabela 'poligono'
Usa os limites de 'optim.jurisdiction' para preencher
'name' e 'parent_abbrev' nos polígonos de CEP.

Lógica Híbrida:
1. (matches_within_unicos): Resolve CPs 100% contidos em UMA jurisdição.
2. (matches_sobreposicao): Resolve CPs de borda/ambíguos
   usando o critério de MAIOR ÁREA DE SOBREPOSIÇÃO.

Correção Crítica:
O filtro WHERE inclui a exceção '(Length > 6 OR isolabel_ext = 'MX-CMX')'
para incluir a Cidade do México (MX-CMX), que era
filtrada incorretamente pela regra de Length > 6.
==========================================================
*/

-- Passo 1: Adicionar as colunas de destino (se ainda não existirem)
ALTER TABLE poligono ADD COLUMN IF NOT EXISTS parent_abbrev TEXT;
ALTER TABLE poligono ADD COLUMN IF NOT EXISTS name TEXT;

-- Passo 2: Executar o UPDATE de enriquecimento
UPDATE poligono
SET
  parent_abbrev = final_matches.parent_abbrev,
  name = final_matches.name
FROM (
  -- Início da subconsulta com a lógica de CTEs
  WITH
  -- CTE 1: Encontra CPs que estão COMPLETAMENTE DENTRO (ST_Within)
  --        e filtra por jurisdições válidas (AGORA COM A EXCEÇÃO).
  matches_within AS (
    SELECT
      p.cp,
      COUNT(j.osm_id) AS contagem_within,
      MIN(j.osm_id) AS unico_osm_id
    FROM
      poligono AS p
    JOIN
      optim.jurisdiction_geom AS j ON ST_Within(p.geom, ST_Transform(j.geom, 6362))
    JOIN
      optim.jurisdiction AS jd ON j.osm_id = jd.osm_id
    WHERE
      ST_IsValid(p.geom) AND ST_IsValid(j.geom) AND
      -- ######### FILTRO CORRIGIDO AQUI #########
      (Length(jd.isolabel_ext) > 6 OR jd.isolabel_ext = 'MX-CMX')
      -- ##########################################
    GROUP BY
      p.cp
  ),

  -- CTE 2: Filtra apenas os CPs que estão dentro de EXATAMENTE UMA jurisdição
  --        e busca os atributos (name, parent_abbrev).
  matches_within_unicos AS (
    SELECT
      m.cp,
      jd.parent_abbrev,
      jd.name
    FROM
      matches_within AS m
    JOIN
      optim.jurisdiction AS jd ON m.unico_osm_id = jd.osm_id
    WHERE
      m.contagem_within = 1
  ),

  -- CTE 3: Para o "RESTANTE", faz a análise de MAIOR SOBREPOSIÇÃO
  --        (AGORA COM A EXCEÇÃO).
  matches_sobreposicao AS (
    SELECT
      DISTINCT ON (p.cp) p.cp,
      jd.parent_abbrev,
      jd.name,
      ST_Area(
        ST_Intersection(p.geom, ST_Transform(j.geom, 6362))
      ) AS area_sobreposicao
    FROM
      poligono AS p
    JOIN
      optim.jurisdiction_geom AS j ON ST_Intersects(p.geom, ST_Transform(j.geom, 6362))
    JOIN
      optim.jurisdiction AS jd ON j.osm_id = jd.osm_id
    WHERE
      -- Exclui CPs que já resolvemos no CTE 2
      p.cp NOT IN (SELECT cp FROM matches_within_unicos)
      AND ST_IsValid(p.geom) AND ST_IsValid(j.geom) AND ST_Area(p.geom) > 0
      -- ######### FILTRO CORRIGIDO AQUI #########
      AND (Length(jd.isolabel_ext) > 6 OR jd.isolabel_ext = 'MX-CMX')
      -- ##########################################
    ORDER BY
      p.cp,
      area_sobreposicao DESC
  )

  -- Resultado Final: Junta os dois conjuntos de resultados
  (SELECT cp, parent_abbrev, name FROM matches_within_unicos)
  UNION ALL
  (SELECT cp, parent_abbrev, name FROM matches_sobreposicao)
  -- Fim da subconsulta

) AS final_matches
WHERE
  -- A condição que liga a tabela 'poligono' aos resultados da consulta
  poligono.cp = final_matches.cp;
