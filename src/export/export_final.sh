#!/bin/bash
# ==========================================================
# Exporta o produto final para CSV
# (Salva na raiz do repositório Git)
# ==========================================================
set -e

DB="mexico"
USER="postgres"
# --- CAMINHO DE SAÍDA ATUALIZADO ---
# (Este é o caminho da raiz do seu repositório Git)
OUTPUT_FILE="/mnt/dados/MX/mexico/produto_final.csv"

echo "🚀 Iniciando exportação para ..."

psql -U felipe -d  -c "
\copy (
  SELECT
    s.gid,
    s.estado_name AS estado,
    s.municipio_name AS cidade, -- 'cidade' agora é o nome do município
    s.via,
    s.hnum,
    s.nsvia,
    -- Transforma a geometria (SRID 6362) para Lat/Lon (WGS84)
    ST_Y(ST_Transform(s.geom, 4326)) AS latitude,
    ST_X(ST_Transform(s.geom, 4326)) AS longitude,
    
    -- Lógica de Fallback para Postcode:
    COALESCE(s.postcode_validado, s.postcode_original) AS postcode
    
  FROM
    public.produto_final_staging AS s
  ORDER BY
    s.gid
) TO '' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');
"

echo "✅ Exportação concluída."
