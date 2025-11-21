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

Esta é a fonte principal de dados de endereço. Os dados brutos (fornecidos por Carlos) chegaram em uma estrutura complexa de arquivos `.zip` aninhados contendo diversas camadas geográficas misturadas.

* **Localização Esperada:** `/mnt/dados/MX/download-final`
* **Fase 1: Staging (Extração e Organização)**
    * **Script de Referência:** `src/ingestion/new_inegi/prepare_staging.sh`
    * **Desafio:** Os dados continham múltiplos níveis de compactação (zips dentro de zips).
    * **Processo:**
        1.  **Permissões:** Ajuste de permissões (`chmod`) para garantir acesso.
        2.  **Extração Recursiva:** Execução de múltiplos comandos `unzip` em cascata, movendo o conteúdo para pastas temporárias (`extract1` a `extract5`) para garantir que nenhum arquivo fosse perdido.
        3.  **Catalogação:** Criação de pastas temáticas (`direccion`, `vial`, `manzana`, etc.) e uso do comando `find` para mover os Shapefiles corretos para cada pasta baseando-se no sufixo do arquivo (ex: `*ne.shp` -> `direccion`).

* **Fase 2: Carga (GDAL/OGR via Docker)**
    * O processo de carga foi focado na pasta resultante `direccion`, que continha os shapefiles de nós de endereço.
    * **Script Principal:** `src/ingestion/new_inegi/ingest.sh`
        * Script `bash` que usa `ogr2ogr` (via Docker) em loop. O primeiro SHP cria a tabela `public.new_inegi` (EPSG:6362), e os demais são anexados (`-append`).
    * **Script de Contingência:** `src/ingestion/new_inegi/re_ingest.sh`
        * Script de retomada que continua o `ogr2ogr -append` a partir de um ponto de parada (`LAST_STARTED=...`).### 3.5. `public.new_inegi` (Endereços INEGI - Fonte Shapefiles)

Esta é a fonte principal de dados de endereço. Os dados brutos (fornecidos por Carlos) chegaram em uma estrutura complexa de arquivos `.zip` aninhados contendo diversas camadas geográficas misturadas.

* **Localização Esperada:** `/mnt/dados/MX/download-final`
* **Fase 1: Staging (Extração e Organização)**
    * **Script de Referência:** `src/ingestion/new_inegi/prepare_staging.sh`
    * **Desafio:** Os dados continham múltiplos níveis de compactação (zips dentro de zips).
    * **Processo:**
        1.  **Permissões:** Ajuste de permissões (`chmod`) para garantir acesso.
        2.  **Extração Recursiva:** Execução de múltiplos comandos `unzip` em cascata, movendo o conteúdo para pastas temporárias (`extract1` a `extract5`) para garantir que nenhum arquivo fosse perdido.
        3.  **Catalogação:** Criação de pastas temáticas (`direccion`, `vial`, `manzana`, etc.) e uso do comando `find` para mover os Shapefiles corretos para cada pasta baseando-se no sufixo do arquivo (ex: `*ne.shp` -> `direccion`).

* **Fase 2: Carga (GDAL/OGR via Docker)**
    * O processo de carga foi focado na pasta resultante `direccion`, que continha os shapefiles de nós de endereço.
    * **Script Principal:** `src/ingestion/new_inegi/ingest.sh`
        * Script `bash` que usa `ogr2ogr` (via Docker) em loop. O primeiro SHP cria a tabela `public.new_inegi` (EPSG:6362), e os demais são anexados (`-append`).
    * **Script de Contingência:** `src/ingestion/new_inegi/re_ingest.sh`
        * Script de retomada que continua o `ogr2ogr -append` a partir de um ponto de parada (`LAST_STARTED=...`).

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

### 3.7. `optim.estado` e `optim.municipio` (Limites Oficiais INEGI)

Estas são as geometrias "limpas" de estados e municípios usadas como fonte da verdade para o enriquecimento (ver Seção 4.3).

* **Fonte de Download:** [INEGI Marco Geoestadístico 2024](https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/marcogeo/794551132173_s.zip)
* **Processo de Extração:**
    1.  O arquivo `...794551132173_s.zip` é baixado.
    2.  Dentro dele, o arquivo `mg_2024_integrado.zip` é extraído.
    3.  Este, por sua vez, contém o subdiretório `conjunto_de_datos`.
* **Ingestão:** Os arquivos `00ent.shp` (Estados) e `00mun.shp` (Municípios) foram ingeridos no banco de dados (schema `optim`) usando `ogr2ogr` (GDAL).
* **Transformação (SRID):** Durante a ingestão, os dados foram transformados do EPSG:6372 (origem) para **EPSG:6362** (destino), para garantir a compatibilidade com a tabela `poligono`.
* **Tabelas Finais:** `optim.estado` e `optim.municipio`.
-----

## 4\. Fase de Análise e Enriquecimento

Após a ingestão, os dados brutos foram limpos e cruzados para gerar um produto final coeso.

### 4.1. Pré-requisito: Limpeza de Geometrias Inválidas

  * **Problema:** Análises espaciais falham com geometrias inválidas (`NOTICE: Ring Self-intersection...`).
  * **Solução:** Um script de limpeza foi executado para corrigir as geometrias usando `ST_MakeValid()` e `ST_CollectionExtract()` (para evitar o erro `GeometryCollection does not match column type`).
  * **Script:** `src/analysis/01_clean_geometries.sql`

### 4.2. Enriquecimento dos Polígonos (CEP) com Jurisdição

O primeiro método para preencher `estado_name` e `municipio_name` na tabela `poligono` usou a hierarquia da tabela `optim.jurisdiction` baseada no `isolabel_ext`.

* **Scripts:** `src/analysis/02_enrich_poligono_state_municipality.sql` e `src/analysis/02b_patch_orphan_poligonos.sql`
* **Lógica (Híbrida):**
    1.  **Estado:** Encontrava a jurisdição de `length(isolabel_ext) = 6` com maior sobreposição.
    2.  **Município:** Encontrava a jurisdição de `length(isolabel_ext) > 6` com maior sobreposição (exceto para 'MX-CMX').
    3.  **Patch:** Um script (`02b`) corrigia 13 polígonos órfãos usando uma lógica "bottom-up" (do município para o estado via `parent_id`).

### 4.3. Enriquecimento dos Polígonos (Método 2: Fontes Limpas) [RECOMENDADO]

Devido à complexidade do Método 1, uma abordagem mais robusta foi desenvolvida usando fontes de geometria limpas e dedicadas(`optim.estado` e `optim.municipio`) ingeridas na **Seção 3.7**.

* **Script:** `src/analysis/enrich_poligono_mx.sql`
* **Lógica (Baseada em Fontes Limpas):** Este script é mais rápido e robusto. Ele ignora a lógica `isolabel_ext` e usa tabelas de geometria separadas (ambas em SRID 6362, eliminando a necessidade de `ST_Transform`):
    1.  **Etapa 1 (Estado):** Encontra o `NOMGEO` da tabela `optim.estado` com a maior sobreposição (`ST_Area(ST_Intersection(...))`) e preenche `poligono.estado_name`.
    2.  **Etapa 2 (Município):** Encontra o `NOMGEO` da tabela `optim.municipio` com a maior sobreposição e preenche `poligono.municipio_name`.

### 4.4. Criação da Tabela de Staging (Produto Final)

*(Esta etapa depende do `poligono` ter `estado_name` e `municipio_name`, fornecidos pelo Método 1 ou 2)*

Para otimizar o pipeline final, uma tabela de *staging* (`produto_final_staging`) foi criada, contendo apenas as colunas necessárias da massiva tabela `new_inegi`.

  * **Script:** `src/analysis/03_create_staging_table.sql`
  * **Processo:** Cria a tabela selecionando `gid`, `geom` e formatando as colunas de endereço (`concat_ws(' ', tipovial, nomvial) AS via`, `numext AS hnum`, `nomasen AS nsvia`). A coluna `cp` original é mantida como `postcode_original`.

### 4.5. Enriquecimento e Validação da Tabela de Staging

A tabela de staging (pontos de endereço) foi enriquecida com os dados da tabela `poligono` (áreas de CEP, agora com dados de estado/município).

  * **Script:** `src/analysis/04_enrich_staging_table.sql`
  * **Processo:** Um `UPDATE` com `ST_Within` é usado para transferir os atributos (`cp`, `estado_name`, `municipio_name`) do polígono para o ponto contido nele.
  * **Validação (Confronto):** O `postcode_original` (do ponto) é comparado com o `cp` do polígono (`postcode_validado`), e o resultado salvo na coluna `flag_postcode_match`.

-----

## 5\. Fase de Exportação do Produto Final

A etapa final é exportar a tabela de staging enriquecida para um CSV limpo.

  * **Script:** `src/export/export_final.sql`
  * **Local de Saída:** O script está configurado para salvar o arquivo em `/mnt/dados/MX/mexico/produto_final.csv` (a raiz do repositório).
  * **Lógica da Consulta:**
    1.  Seleciona os dados da `produto_final_staging` (gid, via, hnum, nsvia, estado\_name, municipio\_name).
    2.  Converte a geometria (`geom` SRID 6362) para `latitude` e `longitude` (WGS84) usando `ST_Transform`, `ST_Y` e `ST_X`.
    3.  Aplica uma lógica de *fallback* (plano B) para o código postal: `COALESCE(s.postcode_validado, s.postcode_original) AS postcode`.
    4.  Exporta o resultado para CSV usando `\copy`.



-----

## 6\. Guia de Execução (Pipeline Completo)

Após a ingestão de dados (Fase 3), o fluxo de trabalho de análise e exportação é o seguinte:

**1. Executar Análise no `psql`:**
Conecte-se ao banco (`psql -U postgres -d mexico`) e execute os scripts de análise em ordem:

```sql
-- 1. Limpa geometrias (Obrigatório)
\i src/analysis/01_clean_geometries.sql

-- 2. Enriquece 'poligono' (Método 2 - Fontes Limpas)
\i src/analysis/enrich_poligono_mx.sql

-- 3. CORRIGE os 13 órfãos
\i src/analysis/02b_patch_orphan_poligonos.sql

-- 4. Cria tabela 'produto_final_staging'
\i src/analysis/03_create_staging_table.sql

-- 5. Enriquece 'produto_final_staging' (Validação)
\i src/analysis/04_enrich_staging_table.sql

-- 6. Exportação de produto final com estrutura idêntica aos dados da OpenAddress
\i src/export/export_final.sql
```
-----

## 7\. Resumo do Produto Final (produto\_final.csv)

Esta seção resume a origem, transformação e estado dos dados contidos no arquivo de saída `produto_final.csv` (e no arquivo de amostra `amostra_produto_final.csv`).

### 7.1. Origem e Transformação dos Dados

O produto final é um conjunto de dados de pontos de endereço derivado da tabela `public.new_inegi` do banco de dados `mexico`.

1.  **Fonte:** Os dados brutos foram baixados pelo colaborador Carlos do site do INEGI.
2.  **Ingestão:** A fonte consistia em múltiplos arquivos `.zip`, que foram descompactados em um grande conjunto de arquivos `.shp`. Estes shapefiles foram ingeridos em lote (usando os scripts `src/ingestion/new_inegi/`) para criar a tabela única `public.new_inegi`.
3.  **Filtragem de Atributos:** Para a criação do produto final, foi criada uma tabela de staging (`produto_final_staging`) que aproveitou apenas os atributos essenciais da `new_inegi`. Esta seleção foi baseada nas estruturas de dados de projetos como OpenAddresses e Overture Maps.
4.  **Enriquecimento Espacial:** A tabela de staging foi enriquecida espacialmente (`ST_Within`) usando os dados da tabela `public.poligono` (que, por sua vez, foi enriquecida pela `optim.jurisdiction`).
5.  **Validação de Postcode:** O `postcode` original da `new_inegi` foi "confrontado" (validado) com o `postcode` do polígono onde o ponto estava contido.

### 7.2. Mapeamento de Atributos (Produto Final)

A tabela a seguir descreve a origem de cada coluna no arquivo `produto_final.csv`:

| Coluna no CSV Final | Origem (Tabela.Coluna) | Transformação / Lógica |
| :--- | :--- | :--- |
| `gid` | `new_inegi.gid` | ID primário original. |
| `estado` | `poligono.estado_name` | Nome do estado (Ex: 'Jalisco') obtido via `ST_Within`. |
| `cidade` | `poligono.municipio_name` | Nome do município (Ex: 'Guadalajara') obtido via `ST_Within`. |
| `via` | `new_inegi.tipovial`, `new_inegi.nomvial` | **Explicação:** O nome da rua é composto pela junção de duas colunas: `tipovial` (ex: 'Avenida', 'Calle') e `nomvial` (ex: 'Vallarta'). Elas são unidas por um espaço para formar um nome completo (ex: 'Avenida Vallarta'). |
| `hnum` | `new_inegi.numext` | Número externo da porta. |
| `nsvia` | `new_inegi.nomasen` | Nome do assentamento (bairro/colônia). |
| `latitude` | `new_inegi.geom` | `ST_Y(ST_Transform(geom, 4326))` (WGS84). |
| `longitude` | `new_inegi.geom` | `ST_X(ST_Transform(geom, 4326))` (WGS84). |
| `postcode` | `poligono.cp` (Primário), `new_inegi.cp` (Fallback) | **Explicação:** O código postal final é determinado por um processo de validação espacial. O `postcode` do ponto (`new_inegi.cp`) foi comparado com o `postcode` do polígono (`poligono.cp`) onde o ponto está localizado. **A versão final prioriza o `postcode` do polígono (validado)**. Se o ponto não caiu dentro de nenhum polígono (um "ponto órfão"), o `postcode` original do ponto é usado como um *fallback* (plano B). |

### 7.3. Métricas de Qualidade e Resultados da Análise

A análise foi executada na tabela `produto_final_staging`, que contém um total de **31.236.822** pontos de endereço. A validação espacial (confrontando o `postcode_original` do ponto com o `postcode_validado` do polígono) revelou as seguintes métricas:

#### 1\. Qualidade dos Dados Originais (O "Problema")

  * **Pontos com `postcode` "Zero":** 15.646.607 pontos (**50,09%** do total) tinham um `postcode` original consistindo apenas de zeros (ex: '0', '00000').
  * **Pontos com `postcode` Nulo:** Apenas 4 pontos (insignificante).
  * *Esta alta contagem de postcodes "zeros" foi a principal motivação para realizar a validação espacial contra a camada de polígonos.*

#### 2\. Resultados da Validação Espacial (A "Solução")

  * **Correspondência Perfeita:** 13.656.144 pontos (**43,72%** do total) tinham um `postcode` original que bateu perfeitamente com o `postcode` do polígono (`flag_postcode_match = 't'`).
  * **Pontos Órfãos:** 70.505 pontos (**0,23%** do total) não caíram dentro de nenhum polígono de CEP (`postcode_validado is null`). Para estes, o `postcode` original foi mantido no arquivo final (lógica de *fallback*).
  * **Total de Conflitos (Corrigidos):** 17.510.171 pontos (**56,06%** do total) tiveram seu `postcode` original **corrigido** pela análise espacial (`flag_postcode_match = 'f'`).

#### 3\. Análise Detalhada dos Conflitos

O dado mais importante é a composição desses 17,5 milhões de conflitos:

  * **Correção de Zeros (Maioria):** 15.619.830 conflitos (**89,2%** dos conflitos) foram casos em que o `postcode_original` era '00000' e foi **corrigido** para um valor real (ex: '41000').
  * **Correção de Postcodes Reais (Minoria):** 1.890.341 conflitos (**10,8%** dos conflitos) foram casos em que o `postcode_original` *parecia* válido (ex: '41000'), mas a análise espacial provou que estava **errado** e o **corrigiu** para o valor do polígono (ex: '41001').

### 7.4. Consultas de Verificação (QA)

As métricas da seção 7.3 foram derivadas das seguintes consultas SQL, executadas na tabela `produto_final_staging` após a conclusão do script `04_enrich_staging_table.sql`.

```sql
-- Total de pontos na tabela final
select count(*) from produto_final_staging;
-- Resultado: 31236822

-- 1. QUALIDADE DOS DADOS ORIGINAIS

-- Postcodes nulos na origem
select count(*) from produto_final_staging where postcode_original is null;
-- Resultado: 4

-- Postcodes '00000' na origem
select count(*) from produto_final_staging where postcode_original ~ '^[0]+$';
-- Resultado: 15646607

-- 2. RESULTADOS DA VALIDAÇÃO

-- Pontos Órfãos (não caíram em nenhum polígono)
select count(*) from produto_final_staging where postcode_validado is null;
-- Resultado: 70505

-- Correspondências Perfeitas (Original = Validado)
select count(*) from produto_final_staging where flag_postcode_match ='t';
-- Resultado: 13656144

-- Total de Conflitos (Original != Validado)
select count(*) from produto_final_staging where flag_postcode_match ='f';
-- Resultado: 17510171

-- 3. DETALHAMENTO DOS CONFLITOS

-- Conflitos que eram '00000' (Zeros Corrigidos)
select count(*) from produto_final_staging where postcode_original ~ '^[0]+$' and flag_postcode_match = 'f';
-- Resultado: 15619830 
-- (Nota: 15.646.607 (Total Zeros) - 26.777 (Zeros Órfãos) = 15.619.830)

-- Conflitos que eram postcodes "reais" (Não-Zeros Corrigidos)
select count(*) from produto_final_staging where postcode_original !~ '^[0]+$' and flag_postcode_match ='f';
-- Resultado: 1890341
```
