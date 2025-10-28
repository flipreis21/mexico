#!/bin/bash
# ==========================================================
# Migra as tabelas optim.jurisdiction e optim.jurisdiction_geom
# do banco 'newgrid' para 'mexico', filtrando por 'MX%'.
# ==========================================================
set -e

DB_SOURCE="newgrid"
DB_TARGET="mexico"
DB_USER="postgres"
SCHEMA="optim"
TABLE1="jurisdiction"
TABLE2="jurisdiction_geom"

echo "Passo 1: Criando schema  (se não existir)..."
psql -U  -d  -c "CREATE SCHEMA IF NOT EXISTS ;"

echo "Passo 2: Copiando estrutura (pre-data)..."
pg_dump -U  -d  --schema-only --section=pre-data -t . -t . | psql -U  -d 

echo "Passo 3: Copiando dados de ...."
psql -U  -d  -c "\copy (SELECT * FROM . WHERE isolabel_ext LIKE 'MX%') TO STDOUT" | psql -U  -d  -c "\copy . FROM STDIN"

echo "Passo 4: Copiando dados de ...."
psql -U  -d  -c "\copy (SELECT * FROM . WHERE isolabel_ext LIKE 'MX%') TO STDOUT" | psql -U  -d  -c "\copy . FROM STDIN"

echo "Passo 5: Copiando índices e chaves (post-data)..."
pg_dump -U  -d  --schema-only --section=post-data -t . -t . | psql -U  -d 

echo "✅ Migração de  concluída."
