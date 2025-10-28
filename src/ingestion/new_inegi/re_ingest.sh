# ==========================================================
# Script de RETOMADA de importação (assume que a tabela JÁ EXISTE)
# Autor: Felipe Reis da Cruz (Modificado por IA)
# Descrição: Retoma a importação a partir de um ponto de parada.
# ==========================================================

# --- Configurações (Verifique se estão iguais ao original) ---
DB="mexico"
USER="postgres"
TABLE="new_inegi"
SRID="6362"
LOG="/mnt/dados/MX/download-final/direccion/log_ogr.txt"
ERROR_LOG="/mnt/dados/MX/download-final/direccion/erros_import_ogr.txt"
BASE_DIR="/mnt/dados/MX/download-final/direccion"

# --- PONTO DE RETOMADA ---
# Coloque o NOME DO ARQUIVO que estava sendo inserido quando o terminal fechou.
# (Baseado no seu log, é este)
LAST_STARTED="110200001ne.shp"

# ----------------------------------------------------------------

# Função para rodar ogr2ogr dentro do Docker GDAL
ogr2ogr_docker() {
  docker run --rm --network host \
    -v "$BASE_DIR":"$BASE_DIR" \
    ghcr.io/osgeo/gdal \
    ogr2ogr "$@"
}

echo "🚀 RETOMANDO importação GDAL (Docker) para tabela $TABLE"
echo "-----------------------------------------------------------" | tee -a "$LOG"

cd "$BASE_DIR"

# Flag para controlar o início do processamento
process=false

# Itera por todos os arquivos na ordem correta (ls -v)
for f in $(ls -v *.shp); do
  
  # Procura o arquivo onde a importação parou
  if [ "$f" == "$LAST_STARTED" ]; then
    echo "🏁 Ponto de retomada encontrado: $f" | tee -a "$LOG"
    process=true
  fi

  # Se a flag 'process' for verdadeira, importa o arquivo
  # A tabela já existe, então SÓ usamos -append
  if [ "$process" = true ]; then
    echo "📥 (Retomada) Inserindo: $f" | tee -a "$LOG"
    
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

if [ "$process" = false ]; then
    echo "⚠️ ATENÇÃO: O arquivo de retomada '$LAST_STARTED' não foi encontrado." | tee -a "$LOG"
    echo "Nenhum arquivo novo foi importado. Verifique o nome do arquivo."
fi

echo "✅ Importação (Retomada) concluída!"
echo "📜 Log: $LOG"
echo "⚠️  Erros: $ERROR_LOG"
