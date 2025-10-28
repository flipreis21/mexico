/*
==========================================================
Script de Exportação Final (SQL Puro)
Exporta a tabela 'produto_final_staging' para CSV.
Executar com: \i src/export/export_final.sql
==========================================================
*/

-- \echo '🚀 Iniciando exportação para /mnt/dados/MX/mexico/produto_final.csv...'

\copy (SELECT s.gid, s.estado_name AS estado, s.municipio_name AS cidade, s.via, s.hnum, s.nsvia, ST_Y(ST_Transform(s.geom, 4326)) AS latitude, ST_X(ST_Transform(s.geom, 4326)) AS longitude, COALESCE(s.postcode_validado, s.postcode_original) AS postcode FROM public.produto_final_staging AS s ORDER BY s.gid) TO '/mnt/dados/MX/mexico/produto_final.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',');
-- --- CORRIGIDO: DELIMTLER -> DELIMITER ---

-- \echo '✅ Exportação concluída.'

