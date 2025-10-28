# Script de importação automática de shapefiles com GDAL (Docker)
# Autor: Felipe Reis da Cruz
# Descrição: Importa shapefiles da pasta atual para o banco PostGIS,
#             criando a tabela a partir do primeiro shapefile e
#             anexando os demais (schema flexível).
# ==========================================================

# Configurações
DB="mexico"
USER="postgres"
TABLE="new_inegi"
SRID="6362"
LOG="/mnt/dados/MX/download-final/direccion/log_ogr.txt"
ERROR_LOG="/mnt/dados/MX/download-final/direccion/erros_import_ogr.txt"
BASE_DIR="/mnt/dados/MX/download-final/direccion"

# Função para rodar ogr2ogr dentro do Docker GDAL
ogr2ogr_docker() {
  docker run --rm --network host \
    -v "$BASE_DIR":"$BASE_DIR" \
    ghcr.io/osgeo/gdal \
    ogr2ogr "$@"
}

echo "🚀 Iniciando importação GDAL (Docker) para tabela $TABLE no banco $DB"
echo "-----------------------------------------------------------" | tee "$LOG"

cd "$BASE_DIR"

# Captura o primeiro shapefile (ordenação natural)
FIRST=$(ls -v *.shp | head -n 1)
echo "🧩 Criando tabela com o primeiro shapefile: $FIRST" | tee -a "$LOG"

# Cria a tabela no PostGIS
ogr2ogr_docker -f "PostgreSQL" PG:"host=localhost port=5432 dbname=$DB user=$USER password=postgres" "$BASE_DIR/$FIRST" \
  -nln $TABLE \
  -nlt PROMOTE_TO_MULTI \
  -lco GEOMETRY_NAME=geom \
  -lco FID=gid \
  -lco precision=NO \
  -a_srs EPSG:$SRID \
  -progress 2>>"$ERROR_LOG"

# Importa os demais shapefiles
for f in *.shp; do
  if [ "$f" != "$FIRST" ]; then
    echo "📥 Inserindo: $f" | tee -a "$LOG"
    ogr2ogr_docker -f "PostgreSQL" PG:"host=localhost port=5432 dbname=$DB user=$USER password=postgres" "$BASE_DIR/$f" \
      -nln $TABLE \
      -append \
      -nlt PROMOTE_TO_MULTI \
      -lco GEOMETRY_NAME=geom \
      -lco FID=gid \
      -lco precision=NO \
      -a_srs EPSG:$SRID \
      -progress 2>>"$ERROR_LOG" \
      || echo "❌ Erro ao importar $f" >> "$ERROR_LOG"
  fi
done

echo "✅ Importação concluída!"
echo "📜 Log: $LOG"
echo "⚠️  Erros: $ERROR_LOG"
