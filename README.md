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

## 2\. Configuração do Ambiente e Dados de Origem

Este repositório contém os **scripts** (`src/`), mas não os **dados** brutos, que são muito grandes para o Git.

Para que os scripts de ingestão funcionem, os dados de origem devem ser baixados e colocados nos caminhos exatos que os scripts esperam. A pasta `data/` deste repositório contém `README`s que descrevem as fontes e os caminhos esperados para cada conjunto de dados.

**Resumo das Fontes de Dados e Caminhos Esperados:**

| Fonte de Dados | Link de Download | Comando de Extração (Exemplo) | Caminho Esperado |
| :--- | :--- | :--- | :--- |
| Polígonos CEP | [SharePoint do Thierry](https://addressforall-my.sharepoint.com/personal/thierry_addressforall_org/_layouts/15/onedrive.aspx?id=%2Fpersonal%2Fthierry%5Faddressforall%5Forg%2FDocuments%2FA4A%5FOperacao%5F20%2FImput%5FDados%2FMexico%2FCorreos%2F2022%2D12%2D13%5Fportal&ga=1) | `unzip -o "*.zip" -d /mnt/dados/download/mexico/poligonos/` | `/mnt/dados/download/mexico/poligonos/` |
| Geoaddress | [Digital Guard](https://dl.digital-guard.org/d0b51cdba97f9c04eb7e8e4c17695770d66730b895308543781729851e0bd67e.zip) | `unzip [arquivo.zip] -d /mnt/dados/download/mexico/direccion` | `/mnt/dados/download/mexico/direccion` |
| INEGI (CSV) | [Digital Guard](https://dl.digital-guard.org/ef59d60a53d2e96f6ffc13e07af908277b8e554549274ddbbac23eef15550d07.zip) | `unzip [arquivo.zip]` (Gera `inegi-20240621.csv`) | `/mnt/dados/download/mexico/` |
| INEGI (SHPs) | (Fornecido por Carlos) | (N/A) | `/mnt/dados/MX/download-final` |
| Banco `newgrid` | (Acesso de rede) | (N/A) | (Acesso de rede) |

**Para reproduzir este projeto:**

1.  Baixe todas as fontes de dados originais.
2.  Extraia-as para os caminhos exatos listados acima.
3.  **OU** edite os scripts em `src/` para apontar para os novos locais onde você salvou os dados.

-----

## 3\. Fase de Carga (ETL) - Ingestão das Fontes de Dados

### 3.1. `public.poligono` (Polígonos de Códigos Postais)

Estes dados representam os polígonos de códigos postais (Fonte: Thierry). Os arquivos SHP de origem são esperados em `/mnt/dados/download/mexico/poligonos/` (ver `data/poligono/README.md`).

  * **Script de Ingestão:** `src/ingestion/poligono/loop_pol.sh`
      * Um script `bash` executado dentro da pasta de dados (`/mnt/dados/download/mexico/poligonos/`) que itera sobre todos os arquivos `.shp`.
      * O utilitário `shp2pgsql` é usado para carregar os dados.
      * O primeiro shapefile cria a tabela `poligono`, e os demais são anexados (`-a`).

### 3.2. `public.direccion` (Geoaddress)

Dados de geo-endereçamento (Fonte: Claiton). Os arquivos SHP de origem são esperados em `/mnt/dados/download/mexico/direccion` (ver `data/direccion/README.md`).

  * **Script de Ingestão:** `src/ingestion/direccion/loop.sh`
      * Mesmo método da tabela `poligono`: `shp2pgsql` em um loop `bash` executado na pasta de dados para criar e anexar dados na tabela `direccion`.

### 3.3. `optim.jurisdiction` e `optim.jurisdiction_geom` (Limites Administrativos)

Estas tabelas foram migradas de um banco de dados (`newgrid`) para o banco `mexico`.

  * **Script de Migração:** `src/migration/migrate_jurisdiction.sh`
  * **Processo:** O script executa um processo de 3 etapas para copiar a estrutura, copiar os dados filtrados (`WHERE isolabel_ext LIKE 'MX%'`) e, por fim, aplicar os índices e chaves.

*(Ver script para detalhes dos comandos `pg_dump` e `psql \copy`)*

### 3.4. `public.inegi` (Endereços INEGI - Fonte CSV)

Dados de endereço em formato CSV (Fonte: Carlos/OpenAddresses). O arquivo `inegi-20240621.csv` é esperado em `/mnt/dados/download/mexico/` (ver `data/inegi_csv/README.md`).

  * **Script de Ingestão:** `src/ingestion/inegi/inegi_load.sql`
  * **Pipeline de ETL:** O script SQL contém os seguintes passos:
    1.  **Criação da Tabela:** (`CREATE TABLE inegi (...)`)
    2.  **Ingestão dos Dados (CSV):**
        ```sql
        -- ATENÇÃO: O caminho abaixo é absoluto e esperado pelo script.
        \COPY inegi(...)
        FROM '/mnt/dados/download/mexico/inegi-20240621.csv'
        DELIMITER ',' CSV HEADER;
        ```
    3.  **Pós-processamento:** Criação de geometrias (`geom` em 6362, `geom_wgs` em 4326) e indexação espacial.
    4.  **Enriquecimento:** Preenchimento da coluna `postcode` via `ST_Within` com a tabela `poligono`.

### 3.5. `public.new_inegi` (Endereços INEGI - Fonte Shapefiles)

Esta é a fonte principal de dados de endereço, ingerida a partir de um conjunto complexo de shapefiles brutos (Fonte: Carlos, esperado em `/mnt/dados/MX/download-final`).

  * **Fase 1: Staging (Extração e Organização)**

      * (Documentação dos procedimentos manuais/scripts de `chmod`, `unzip` recursivo e `find` para catalogar os SHPs na pasta `direccion`).

  * **Fase 2: Carga (GDAL/OGR via Docker)**

      * O processo de carga foi focado na pasta `direccion`, que continha os shapefiles de endereço (`*ne.shp`).
      * **Script Principal:** `src/ingestion/new_inegi/ingest.sh`
          * Script `bash` que usa `ogr2ogr` (via Docker) em loop. O primeiro SHP cria a tabela `public.new_inegi` (EPSG:6362), e os demais são anexados (`-append`).
      * **Script de Contingência:** `src/ingestion/new_inegi/re_ingest.sh`
          * Script de retomada que continua o `ogr2ogr -append` a partir de um ponto de parada (`LAST_STARTED=...`).

### 2.6. `public.overture_add` e `public.overture3` (Overture Maps)

Dois métodos foram usados para ingerir e comparar os mesmos dados de endereço da Overture Maps (Release `2025-08-20.1`).

**Pré-requisito: Instalação do DuckDB**

Ambos os métodos (`overture_add` e `overture3`) exigem o `duckdb` (CLI) instalado no sistema Linux.

  * **Comando de Instalação (Linux):**
    ```bash
    curl -s https://install.duckdb.org | sh
    ```

#### 2.6.1. Método 1: `overture_add` (DuckDB + GDAL + FDW)

  * **Fase 1 (DuckDB):** O script `src/ingestion/overture/overture_add.sql` é executado com `duckdb < src/ingestion/overture/overture_add.sql`. Ele lê Parquets do S3 da Overture, filtra por `country = 'MX'` e salva localmente.
  * **Fase 2 (GDAL):** `ogr2ogr` é usado para transformar o Parquet (com JSON aninhado) em GeoJSON e de volta para Parquet, corrigindo problemas de tipo.
  * **Fase 3 (PostGIS FDW):** A extensão `parquet_fdw` é usada para criar uma `FOREIGN TABLE` (`overture_add`) que lê o arquivo Parquet.

#### 2.6.2. Método 2: `overture3` (DuckDB-Postgres Connector)

  * **Método:** Este pipeline usou o DuckDB para se conectar diretamente ao PostGIS.
  * **Script:** `src/ingestion/overture/overture_to_postgres.sql`
  * **Processo (Executado com `duckdb < src/ingestion/overture/overture_to_postgres.sql`):**
    1.  O script instala as extensões `spatial` e `postgres` *dentro* do DuckDB.
    2.  Conecta-se ao banco `mexico` via `ATTACH 'dbname=mexico...' AS pg`.
    3.  `CREATE TABLE pg.public.overture3 AS SELECT ...` é usado para ler do S3 da Overture, transformar dados (ex: `TO_JSON()`, `ST_AsText()`) e criar uma **tabela física** (`overture3`) no PostGIS.

-----

## 3. Fase de Análise e Enriquecimento

Após a ingestão de todas as fontes de dados, a próxima fase foi enriquecer os dados de `poligono` (códigos postais) com os atributos hierárquicos dos limites administrativos (`optim.jurisdiction`).

### 3.1. Pré-requisito: Limpeza de Geometrias Inválidas

As análises espaciais (como `ST_Within` e `ST_Intersection`) falham ou geram erros se as geometrias forem inválidas (ex: auto-interseções).

* **Problema:** Durante a análise, foram encontrados `NOTICE: Ring Self-intersection...`. Uma tentativa de correção com `ST_MakeValid()` falhou com o erro `ERROR: Geometry type (GeometryCollection) does not match column type (MultiPolygon)`.
* **Solução:** Um script de limpeza foi executado para corrigir as geometrias usando uma combinação de `ST_MakeValid()` e `ST_CollectionExtract()` para garantir que o tipo de geometria fosse preservado.
* **Script:** `src/analysis/01_clean_geometries.sql`

### 3.2. Enriquecimento dos Polígonos (CEP) com Dados de Jurisdição

O objetivo era preencher as colunas `name` e `parent_abbrev` na tabela `poligono` com base nos dados da tabela `optim.jurisdiction`.

* **Desafio:** Um polígono de CEP (`poligono`) pode estar perfeitamente contido em uma jurisdição (ex: um município) ou pode estar em uma borda, cruzando duas ou mais jurisdições.
* **Solução (Lógica Híbrida):** Foi desenvolvido um script `UPDATE` que utiliza Common Table Expressions (CTEs) para tratar ambos os casos:
    1.  **CTE `matches_within_unicos`:** Resolve os "casos fáceis", onde o `poligono` está 100% contido (`ST_Within`) em *exatamente uma* jurisdição.
    2.  **CTE `matches_sobreposicao`:** Resolve os "casos difíceis" (polígonos de borda) calculando a interseção (`ST_Intersection`) com todas as jurisdições que tocam (`ST_Intersects`) e selecionando aquela com a **maior área de sobreposição** (`ST_Area`).
    3.  **`UNION ALL`:** Junta os resultados dos "fáceis" e "difíceis".
    4.  **`UPDATE`:** Atualiza a tabela `poligono`.

* **Descoberta e Correção de Bug (MX-CMX):**
    * A primeira versão da consulta usava um filtro (`Length(isolabel_ext) > 6`) para remover jurisdições de nível superior.
    * **Problema:** Isso excluiu incorretamente a jurisdição da Cidade do México (`MX-CMX`), que tem 6 caracteres.
    * **Sintomas:** 1.114 polígonos que pertenciam a `MX-CMX` ficaram com valores `NULL`, e polígonos na borda foram atribuídos incorretamente a jurisdições vizinhas.
    * **Correção:** O script final foi corrigido para re-processar todos os polígonos (sobrescrevendo os erros) com uma lógica de filtro ajustada: `(Length(jd.isolabel_ext) > 6 OR jd.isolabel_ext = 'MX-CMX')`.

* **Script Final:** `src/analysis/02_enrich_poligono_jurisdiction.sql`

---

