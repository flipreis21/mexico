# Projeto de Banco de Dados Geoespacial - México

Este repositório documenta o processo de criação, ingestão e enriquecimento de um banco de dados PostGIS (`mexico`) focado em dados geoespaciais do México. O objetivo é consolidar múltiplas fontes de dados (limites administrativos, códigos postais, endereços) em uma única base coesa para análise.

Os scripts de ingestão e análise referenciados neste documento estão localizados no diretório `src/`.

## 1\. Visão Geral da Arquitetura de Dados

O banco de dados `mexico` é composto por dados de diversas fontes, ingeridos através de diferentes pipelines de ETL.

| Tabela | Schema | Fonte de Dados Primária | Método de Ingestão | Script de Referência |
| :--- | :--- | :--- | :--- | :--- |
| `poligono` | `public` | Thierry (Polígonos de CEP) | `shp2pgsql` (loop `bash`) | `src/ingestion/poligono/loop_pol.sh` |
| `direccion` | `public` | Claiton (Geoaddress / preserv-MX) | `shp2pgsql` (loop `bash`) | `src/ingestion/direccion/loop.sh` |
| `inegi` | `public` | Carlos (OpenAddresses / CSV) | `\COPY` (CSV) | `src/ingestion/inegi/inegi_load.sql` |
| `new_inegi` | `public` | Carlos (INEGI / Shapefiles) | `ogr2ogr` (loop `bash` + Docker) | `src/ingestion/new_inegi/ingest.sh` |
| `jurisdiction` | `optim` | Banco `newgrid` (Limites Adm.) | `pg_dump` + `psql \copy` | `src/migration/migrate_jurisdiction.sh` |
| `jurisdiction_geom` | `optim` | Banco `newgrid` (Limites Adm.) | `pg_dump` + `psql \copy` | `src/migration/migrate_jurisdiction.sh` |
| `overture_add` | `public` | Overture Maps (Endereços) | DuckDB + GDAL + `parquet_fdw` | `src/ingestion/overture/overture_add.sql` |
| `overture3` | `public` | Overture Maps (Endereços) | DuckDB + `postgres` connector | `src/ingestion/overture/overture_to_postgres.sql` |

-----

## 2\. Fase de Carga (ETL) - Ingestão das Fontes de Dados

A seguir, é detalhado o pipeline de ETL para cada fonte de dados principal.

### 2.1. `public.poligono` (Polígonos de Códigos Postais)

Estes dados representam os polígonos de códigos postais, fornecidos por Thierry. Os arquivos SHP de origem foram obtidos de `/mnt/dados/download/mexico/2022-12-13_portal`.

  * **Script de Ingestão:** `src/ingestion/poligono/loop_pol.sh`
      * Um script `bash` foi usado para iterar sobre todos os arquivos `.shp` na pasta de origem. O utilitário `shp2pgsql` foi usado para carregar os dados.
      * O primeiro shapefile cria a tabela `poligono`.
      * Os shapefiles subsequentes são anexados (`-a`) à tabela existente.

<!-- end list -->

```bash
#!/bin/bash
# Script: src/ingestion/poligono/loop_pol.sh

primeiro=1
for file in *.shp ; do
        if [ $primeiro -eq 1 ] ; then
                # (Assumindo que $file aponta para o local dos SHPs)
                shp2pgsql $file poligono | psql -U postgres -d mexico
                primeiro=0
        else
                shp2pgsql -a $file poligono | psql -U postgres -d mexico
        fi
done 2>&1 | tee log_pol.txt # Gera log no diretório de execução
```

### 2.2. `public.direccion` (Geoaddress)

Dados de geo-endereçamento obtidos a partir dos procedimentos de Claiton. Os arquivos SHP de origem estavam em `/mnt/dados/download/mexico/direccion`.

  * **Referência:** [digital-guard/preserv-MX (Geoaddress)](https://github.com/digital-guard/preserv-MX/tree/main/data/_pk0002.01)
  * **Script de Ingestão:** `src/ingestion/direccion/loop.sh`
      * O mesmo método da tabela `poligono` foi aplicado: `shp2pgsql` em um loop `bash` para criar e anexar dados na tabela `direccion`.

<!-- end list -->

```bash
#!/bin/bash
# Script: src/ingestion/direccion/loop.sh

primeiro=1
for file in *.shp ; do
        if [ $primeiro -eq 1 ] ; then
                shp2pgsql $file direccion | psql -U postgres -d mexico
                primeiro=0
        else
                shp2pgsql -a $file direccion | psql -U postgres -d mexico
        fi
done 2>&1 | tee log.txt # Gera log no diretório de execução
```

### 2.3. `optim.jurisdiction` e `optim.jurisdiction_geom` (Limites Administrativos)

Estas tabelas foram migradas de um banco de dados (`newgrid`) para o banco `mexico`.

  * **Script de Migração:** `src/migration/migrate_jurisdiction.sh`
  * **Processo:** O script executa um processo de 3 etapas:
    1.  **Copiar Estrutura:** A estrutura das tabelas (sem dados) é copiada usando `pg_dump`.
    2.  **Copiar Dados (Filtrados):** Os dados são exportados do `newgrid` (`\copy (SELECT ... WHERE isolabel_ext LIKE 'MX%') TO STDOUT`) e importados no `mexico` (`\copy ... FROM STDIN`), usando um "pipe" (`|`).
    3.  **Aplicar Índices:** Os índices e chaves estrangeiras são aplicados usando `pg_dump --section=post-data`.

*(Você pode colocar os comandos `pg_dump` e `psql` dentro do arquivo .sh referenciado acima)*

### 2.4. `public.inegi` (Endereços INEGI - Fonte CSV)

Dados de endereço em formato CSV, obtidos dos procedimentos de Carlos (OpenAddresses). O arquivo CSV (`inegi-20240621.csv`) foi baixado de `dl.digital-guard.org/...`

  * **Script de Ingestão:** `src/ingestion/inegi/inegi_load.sql`
  * **Pipeline de ETL:** O script SQL contém os seguintes passos:
    1.  **Criação da Tabela:**
        ```sql
        CREATE TABLE inegi (
            gid serial PRIMARY KEY,
            -- ... (outras colunas) ...
            geom geometry(point, 6362),
            postcode text
        );
        ```
    2.  **Ingestão dos Dados (CSV):**
        ```sql
        -- (Caminho do CSV precisa ser acessível pelo servidor Postgres)
        \COPY inegi(gid, estado, ...)
        FROM '/mnt/dados/download/mexico/inegi-20240621.csv'
        DELIMITER ',' CSV HEADER;
        ```
    3.  **Pós-processamento (Criação de Geometrias):**
        ```sql
        UPDATE inegi
        SET geom = ST_Transform(ST_SetSRID(ST_MakePoint(longitude, latitude), 4326), 6362);

        ALTER TABLE inegi ADD COLUMN geom_wgs geometry(point, 4326);
        UPDATE inegi
        SET geom_wgs = ST_SetSRID(ST_MakePoint(longitude, latitude), 4326);

        CREATE INDEX inegi_idx ON inegi USING GIST(geom);
        ```
    4.  **Enriquecimento (Primeiro Spatial Join):**
          * O `postcode` foi preenchido usando os polígonos da tabela `poligono`.
        <!-- end list -->
        ```sql
        UPDATE inegi i
        SET postcode = p.cp
        FROM poligono p
        WHERE ST_Within(i.geom, p.geom);
        ```

### 2.5. `public.new_inegi` (Endereços INEGI - Fonte Shapefiles)

Esta é a fonte principal de dados de endereço, ingerida a partir de um conjunto complexo de shapefiles brutos (Fonte: Carlos, `/mnt/dados/MX/download-final`).

  * **Fase 1: Staging (Extração e Organização)**

      * (Documentação dos procedimentos manuais/scripts de `chmod`, `unzip` recursivo e `find` para catalogar os SHPs na pasta `direccion`).

  * **Fase 2: Carga (GDAL/OGR via Docker)**

      * O processo de carga foi focado na pasta `direccion`, que continha os shapefiles de endereço (`*ne.shp`).

      * **Script Principal:** `src/ingestion/new_inegi/ingest.sh`

          * Um script `bash` que usa `ogr2ogr` (via Docker `ghcr.io/osgeo/gdal`) em loop.
          * O primeiro shapefile **cria** a tabela `public.new_inegi` (EPSG:6362, `-nlt PROMOTE_TO_MULTI`).
          * Os demais shapefiles são **anexados** (`-append`).
          * *Obs: Este processo é o que cria o schema `ogr_system_tables`.*

      * **Script de Contingência:** `src/ingestion/new_inegi/re_ingest.sh`

          * Caso a ingestão inicial seja interrompida.
          * O script define um ponto de partida (`LAST_STARTED=...`) e continua o `ogr2ogr -append` a partir daquele arquivo, garantindo que não haja duplicatas.

### 2.6. `public.overture_add` e `public.overture3` (Overture Maps)

Dois métodos foram usados para ingerir e comparar os mesmos dados de endereço da Overture Maps (Release `2025-08-20.1`).

#### 2.6.1. Método 1: `overture_add` (DuckDB + GDAL + FDW)

  * **Fase 1 (DuckDB):** O script `src/ingestion/overture/overture_add.sql` foi usado no DuckDB para ler os Parquets do S3 da Overture, filtrar (`country = 'MX'`) e salvar localmente.
  * **Fase 2 (GDAL):** `ogr2ogr` foi usado para transformar o Parquet (com JSON aninhado) em GeoJSON e de volta para Parquet, corrigindo problemas de tipo.
  * **Fase 3 (PostGIS FDW):** A extensão `parquet_fdw` foi usada para criar uma `FOREIGN TABLE` (`overture_add`) que lê o arquivo Parquet transformado.

#### 2.6.2. Método 2: `overture3` (DuckDB-Postgres Connector)

  * **Método:** Este pipeline usou o DuckDB para se conectar diretamente ao PostGIS.
  * **Script:** `src/ingestion/overture/overture_to_postgres.sql`
  * **Processo (Executado no DuckDB):**
    1.  `INSTALL spatial;` e `INSTALL postgres;`
    2.  `ATTACH 'dbname=mexico...' AS pg (TYPE POSTGRES);`
    3.  `CREATE TABLE pg.public.overture3 AS SELECT ...` é usado para ler do S3 da Overture, transformar dados (ex: `TO_JSON()`, `ST_AsText()`) e criar uma **tabela física** (`overture3`) no PostGIS.

-----

## 3\. Fase de Análise e Enriquecimento

(Aguardando os próximos procedimentos...)
