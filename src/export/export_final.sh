#!/bin/bash
# ==========================================================
# Exporta o produto final para CSV
# (Versão corrigida com lógica de fallback)
# ==========================================================
set -e

DB="mexico"
USER="postgres"
OUTPUT_FILE="/mnt/dados/download/mexico/produto_final.csv"

echo "🚀 Iniciando exportação para ..."

psql -U felipe -d  -c "
\copy (
  SELECT
    s.gid,
    m.nome_completo AS estado,
    s.cidade,
    s.via,
    s.hnum,
    s.nsvia,
    -- Transforma a geometria (SRID 6362) para Lat/Lon (WGS84)
    ST_Y(ST_Transform(s.geom, 4326)) AS latitude,
    ST_X(ST_Transform(s.geom, 4326)) AS longitude,
    
    -- Lógica de Fallback para Postcode:
    -- 1. Usa o postcode validado (do polígono), se existir.
    -- 2. Se for NULL (ponto órfão), usa o postcode original (da new_inegi).
    COALESCE(s.postcode_validado, s.postcode_original) AS postcode
    
  FROM
    public.produto_final_staging AS s
  LEFT JOIN
    -- Junta com o mapa de estados para obter o nome completo
    public.mapa_estados AS m ON s.estado_abbrev = m.abbrev
  ORDER BY
    s.gid
) TO '' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');
"

echo "✅ Exportação concluída."
