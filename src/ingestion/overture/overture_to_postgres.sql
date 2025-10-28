/*
==========================================================
Pipeline de Carga: overture3 (Método 2: DuckDB -> Postgres)
Executar com: duckdb < overture_to_postgres.sql
==========================================================
*/

-- 1. Instala e carrega as extensões
INSTALL spatial;
INSTALL postgres;
LOAD spatial;
LOAD postgres;

-- 2. Conecta ao seu banco de dados PostgreSQL
-- (Ajuste a string de conexão conforme necessário)
ATTACH 'dbname=mexico user=postgres host=localhost password=postgres' AS pg (TYPE POSTGRES);

-- 3. Cria a tabela no PostgreSQL lendo diretamente do S3
CREATE TABLE pg.public.overture3 AS
SELECT
    -- Colunas com tipos simples
    id,
    country,
    postcode,
    street,
    number,
    unit,
    postal_city,
    version,
    filename,
    theme,
    type,

    -- Colunas complexas (STRUCT) convertidas para JSON
    TO_JSON(bbox) AS bbox,
    TO_JSON(address_levels) AS address_levels,
    TO_JSON(sources) AS sources,
    
    -- Geometria convertida para TEXTO (WKT)
    ST_AsText(geometry) AS geometry_wkt

FROM read_parquet(
    's3://overturemaps-us-west-2/release/2025-08-20.1/theme=addresses/type=address/*',
    filename:=true, hive_partitioning:=true
)
WHERE country = 'MX';

/*
NOTA PÓS-DUCKDB:
Após rodar este script, a tabela 'overture3' existirá no PostGIS,
mas com a geometria em formato WKT (texto).
Execute o SQL abaixo no PostGIS para criar a geometria espacial:

ALTER TABLE overture3 ADD COLUMN geom geometry(Geometry, 4326);
UPDATE overture3 SET geom = ST_GeomFromText(geometry_wkt, 4326);
CREATE INDEX overture3_geom_idx ON overture3 USING GIST(geom);
*/
