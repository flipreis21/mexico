# Projeto de Banco de Dados Geoespacial - México

Este repositório documenta o processo de criação, ingestão, enriquecimento e exportação de um banco de dados PostGIS (`mexico`) focado em dados geoespaciais do México. O objetivo é consolidar múltiplas fontes de dados em uma única base coesa para análise.

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
| `produto_final_staging` | `public` | Tabela `new_inegi` | `CREATE TABLE AS SELECT ...` | `src/analysis/03_create_staging_table.sql`|

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

Estes dados representam os polígonos de códigos postais (Fonte: Thierry). Os arquivos SHP de origem são esperados em `/mnt/dados/download/mexico/poligonos/`.

  * **Script de Ingestão:** `src/ingestion/poligono/loop_pol.sh`
  * **Processo:** Um loop `bash` (`shp2pgsql`) cria a tabela `poligono` com o primeiro SHP e anexa (`-a`) os demais.

### 3.2. `public.direccion` (Geoaddress)

Dados de geo-endereçamento (Fonte: Claiton). Os arquivos SHP de origem são esperados em `/mnt/dados/download/mexico/direccion`.

  * **Script de Ingestão:** `src/ingestion/direccion/loop.sh`
  * **Processo:** Mesmo método da tabela `poligono`, criando e anexando dados na tabela `direccion`.

### 3.3. `optim.jurisdiction` e `optim.jurisdiction_geom` (Limites Administrativos)

Estas tabelas foram migradas do banco `newgrid` para o banco `mexico`.

  * **Script de Migração:** `src/migration/migrate_jurisdiction.sh`
  * **Processo:** O script executa um processo de 3 etapas para copiar a estrutura, copiar os dados filtrados (`WHERE isolabel_ext LIKE 'MX%'`) e, por fim, aplicar os índices e chaves.

### 3.4. `public.inegi` (Endereços INEGI - Fonte CSV)

Dados de endereço em formato CSV (Fonte: Carlos/OpenAddresses). O arquivo `inegi-20240621.csv` é esperado em `/mnt/dados/download/mexico/`.

  * **Script de Ingestão:** `src/ingestion/inegi/inegi_load.sql`
  * **Pipeline de ETL:** O script SQL cria a tabela, ingere os dados via `\COPY`, cria as geometrias (`geom` em 6362, `geom_wgs` em 4326) e enriquece o `postcode` usando `ST_Within` com a tabela `poligono`.

### 3.5. `public.new_inegi` (Endereços INEGI - Fonte Shapefiles)

Esta é a fonte principal de dados de endereço, ingerida a partir de um conjunto complexo de shapefiles brutos (Fonte: Carlos, esperado em `/mnt/dados/MX/download-final`).

  * **Fase 1: Staging (Extração e Organização):** `chmod`, `unzip` recursivo e `find` para catalogar os SHPs na pasta `direccion`.
  * **Fase 2: Carga (GDAL/OGR via Docker):**
      * **Script Principal:** `src/ingestion/new_inegi/ingest.sh` (cria a tabela `new_inegi` com o primeiro SHP e anexa os demais via `ogr2ogr -append`).
      * **Script de Contingência:** `src/ingestion/new_inegi/re_ingest.sh` (retoma a ingestão a partir de um ponto de parada).

### 3.6. `public.overture_add` e `public.overture3` (Overture Maps)

Dois métodos foram usados para ingerir e comparar os mesmos dados de endereço da Overture Maps.

**Pré-requisito: Instalação do DuckDB**
Ambos os métodos exigem o `duckdb` (CLI) instalado no sistema Linux.

  * **Comando de Instalação (Linux):** `curl -s https://install.duckdb.org | sh`

#### 3.6.1. Método 1: `overture_add` (DuckDB + GDAL + FDW)

  * **Script:** `src/ingestion/overture/overture_add.sql`
  * **Processo:** O DuckDB baixa os Parquets do S3 da Overture. `ogr2ogr` é usado para converter/corrigir os tipos. A extensão `parquet_fdw` é usada no PostGIS para criar uma `FOREIGN TABLE`.

#### 3.6.2. Método 2: `overture3` (DuckDB-Postgres Connector)

  * **Script:** `src/ingestion/overture/overture_to_postgres.sql`
  * **Processo:** O DuckDB (com as extensões `spatial` e `postgres`) conecta-se diretamente ao PostGIS (`ATTACH 'dbname=mexico...'`) e executa um `CREATE TABLE pg.public.overture3 AS SELECT ...` para ler do S3 e escrever uma tabela física no PostGIS.

-----

## 4\. Fase de Análise e Enriquecimento

Após a ingestão, os dados brutos foram limpos e cruzados para gerar um produto final coeso.

### 4.1. Pré-requisito: Limpeza de Geometrias Inválidas

  * **Problema:** Análises espaciais falham com geometrias inválidas (`NOTICE: Ring Self-intersection...`).
  * **Solução:** Um script de limpeza foi executado para corrigir as geometrias usando `ST_MakeValid()` e `ST_CollectionExtract()` (para evitar o erro `GeometryCollection does not match column type`).
  * **Script:** `src/analysis/01_clean_geometries.sql`

### 4.2. Enriquecimento dos Polígonos (CEP) com Jurisdição

O objetivo foi preencher os dados de Estado e Município na tabela `poligono`, usando `optim.jurisdiction` como fonte da verdade.

  * **Script:** `src/analysis/02_enrich_poligono_state_municipality.sql`
  * **Lógica (Híbrida):** O script atualiza a tabela `poligono` em duas etapas, sempre usando o critério de **maior área de sobreposição** (`ST_Area(ST_Intersection(...))`):
    1.  **Etapa 1 (Estado):** Encontra a jurisdição de `length(isolabel_ext) = 6` (ex: 'MX-JAL') com maior sobreposição e preenche `estado_name`.
    2.  **Etapa 2 (Município):** Encontra a jurisdição de `length(isolabel_ext) > 6` (ex: 'MX-JAL-001') com maior sobreposição e preenche `municipio_name`.
    <!-- end list -->
      * **Exceção:** A Etapa 2 ignora polígonos onde o estado é `MX-CMX` (Ciudad de México).

### 4.3. Criação da Tabela de Staging (Produto Final)

Para otimizar o pipeline final, uma tabela de *staging* (`produto_final_staging`) foi criada, contendo apenas as colunas necessárias da massiva tabela `new_inegi`.

  * **Script:** `src/analysis/03_create_staging_table.sql`
  * **Processo:** Cria a tabela selecionando `gid`, `geom` e formatando as colunas de endereço (`concat_ws(' ', tipovial, nomvial) AS via`, `numext AS hnum`, `nomasen AS nsvia`). A coluna `cp` original é mantida como `postcode_original`.

### 4.4. Enriquecimento e Validação da Tabela de Staging

A tabela de staging (pontos de endereço) foi enriquecida com os dados da tabela `poligono` (áreas de CEP, agora com dados de estado/município).

  * **Script:** `src/analysis/04_enrich_staging_table.sql`
  * **Processo:** Um `UPDATE` com `ST_Within` é usado para transferir os atributos (`cp`, `estado_name`, `municipio_name`) do polígono para o ponto contido nele.
  * **Validação (Confronto):** O `postcode_original` (do ponto) é comparado com o `cp` do polígono (`postcode_validado`), e o resultado salvo na coluna `flag_postcode_match`.

-----

## 5\. Fase de Exportação do Produto Final

A etapa final é exportar a tabela de staging enriquecida para um CSV limpo.

  * **Script:** `src/export/export_final.sh`
  * **Local de Saída:** O script está configurado para salvar o arquivo em `/mnt/dados/MX/mexico/produto_final.csv` (a raiz do repositório).
  * **Lógica da Consulta:**
    1.  Seleciona os dados da `produto_final_staging` (gid, via, hnum, nsvia, estado\_name, municipio\_name).
    2.  Converte a geometria (`geom` SRID 6362) para `latitude` e `longitude` (WGS84) usando `ST_Transform`, `ST_Y` e `ST_X`.
    3.  Aplica uma lógica de *fallback* (plano B) para o código postal: `COALESCE(s.postcode_validado, s.postcode_original) AS postcode`.
    4.  Exporta o resultado para CSV usando `\copy`.

**⚠️ Importante: `.gitignore`**

O arquivo de saída `produto_final.csv` é um produto de dados e **não deve ser rastreado pelo Git**. Um arquivo `.gitignore` foi adicionado ao repositório para garantir que este arquivo seja ignorado.

-----

## 6\. Guia de Execução (Pipeline Completo)

Após a ingestão de dados (Fase 3), o fluxo de trabalho de análise e exportação é o seguinte:

**1. Executar Análise no `psql`:**
Conecte-se ao banco (`psql -U postgres -d mexico`) e execute os scripts de análise em ordem:

```sql
-- 1. Limpa geometrias (Obrigatório)
\i src/analysis/01_clean_geometries.sql

-- 2. Enriquece 'poligono' com Estado/Município
\i src/analysis/02_enrich_poligono_state_municipality.sql

-- 3. Cria tabela 'produto_final_staging' (bruta)
\i src/analysis/03_create_staging_table.sql

-- 4. Enriquece 'produto_final_staging' (Valida o postcode)
\i src/analysis/04_enrich_staging_table.sql

-- Saia do psql
\q
```

**2. Executar Exportação no `bash`:**
No seu terminal, na raiz do repositório, execute o script de exportação:

```bash
bash src/export/export_final.sh
```
