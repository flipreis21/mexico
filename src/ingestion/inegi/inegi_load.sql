/*
==========================================================
Pipeline de Carga e Enriquecimento: public.inegi (CSV)
==========================================================
*/

-- Passo 1: Criação da Tabela
CREATE TABLE inegi (
    gid serial PRIMARY KEY,
    estado text,
    cidade text,
    via text,
    hnum text,
    nsvia text,
    latitude double precision,
    longitude double precision,
    geom geometry(point, 6362),
    postcode text
);

-- Passo 2: Ingestão dos Dados (CSV)
-- ATENÇÃO: O caminho abaixo é absoluto e deve estar acessível
-- ao servidor PostgreSQL.
\COPY inegi(gid, estado, cidade, via, hnum, nsvia, latitude, longitude)
FROM '/mnt/dados/download/mexico/inegi-20240621.csv'
DELIMITER ','
CSV HEADER;

-- Passo 3: Pós-processamento (Criação de Geometrias)
UPDATE inegi
SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 6362);

ALTER TABLE inegi ADD COLUMN geom_wgs geometry(point, 4326);
UPDATE inegi
SET geom_wgs = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);

CREATE INDEX inegi_idx ON inegi USING GIST(geom);

-- Passo 4: Enriquecimento (Spatial Join com 'poligono')
UPDATE inegi i
SET postcode = p.cp
FROM poligono p
WHERE ST_Within(i.geom, p.geom);
