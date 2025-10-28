/*
==========================================================
Pipeline de Carga: overture_add (Método 1: DuckDB -> Parquet)
Executar com: duckdb < overture_add.sql
==========================================================
*/

INSTALL httpfs;
LOAD httpfs;

INSTALL spatial;
LOAD spatial;

-- Define região para S3 público da Overture
SET s3_region='us-west-2';

COPY (
  SELECT *
  FROM read_parquet(
    's3://overturemaps-us-west-2/release/2025-08-20.1/theme=addresses/type=address/*',
    filename=true, hive_partitioning=true
  )
  WHERE country = 'MX'
) TO 'enderecos_mexico.parquet';

/*
NOTA PÓS-DUCKDB:
Após rodar este script, os seguintes comandos GDAL (Docker)
foram usados para transformar o Parquet e achatar atributos:

# Parquet -> GeoJSON
docker run --rm --network host -v $(pwd):$(pwd) ghcr.io/osgeo/gdal ogr2ogr enderecos_mexico.geojson enderecos_mexico.parquet

# GeoJSON -> Parquet (Corrige tipos)
docker run --rm --network host -v $(pwd):$(pwd) ghcr.io/osgeo/gdal ogr2ogr enderecos_mexico1.parquet enderecos_mexico.geojson

# (Opcional) Achatando atributos aninhados
docker run --rm -v $(pwd):$(pwd)   ghcr.io/osgeo/gdal ogr2ogr   -f Parquet enderecos_mexico_flat.parquet   enderecos_mexico1.parquet   -lco FLATTEN_NESTED_ATTRIBUTES=YES
*/
