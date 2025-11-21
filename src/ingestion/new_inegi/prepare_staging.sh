#!/bin/bash
# ==========================================================
# Script de Preparação e Staging (Dados INEGI Brutos)
# Descrição: Realiza a descompactação recursiva e organização
#            temática dos dados brutos do INEGI.
#
# NOTA: Este script documenta os passos manuais executados
#       na pasta /mnt/dados/MX/download-final
# ==========================================================

# 1. Ajuste de Permissões (Para garantir leitura/escrita)
# sudo find . -type d -exec chmod 0777 {} \;
# sudo find . -type f -exec chmod 0644 {} \;

# 2. Extração Recusiva (Zips dentro de Zips)
mkdir -p extract1
# Extrai o primeiro nível
for z in *_s.zip; do unzip -o "$z" -d extract1; done

# Cria pastas para níveis aninhados
mkdir -p extract{2,3,4,5}

cd extract1
# Extração em cascata para capturar todos os arquivos aninhados
find . -type f -name '*.zip' -exec unzip -o {} -d ../extract2 \;
find ../extract2 -type f -name '*.zip' -exec unzip -o {} -d ../extract3 \;
find ./conjunto_de_datos -type f -name '*.zip' -exec unzip -o {} -d ../extract4 \;
find ../extract4 -type f -name '*.zip' -exec unzip -o {} -d ../extract5 \;
cd ..

# 3. Organização Temática (Staging)
# Cria as pastas de destino
mkdir -p {area_geoestadistica,asentamiento,frente_manzana,area_urbana,manzana,direccion,servicio_publico,poi,vial}

# Move os arquivos para suas respectivas pastas baseado no sufixo
# (Ex: *ne.shp vai para 'direccion')
find . -type f \( -name '*ne.shp' -o -name '*ne.dbf' -o -name '*ne.prj' -o -name '*ne.shx' -o -name '*ne.shp.xml' \) -exec mv -f -t direccion {} +
find . -type f \( -name '*v.shp'  -o -name '*v.dbf'  -o -name '*v.prj'  -o -name '*v.shx'  -o -name '*v.shp.xml'  \) -exec mv -f -t vial {} +
find . -type f \( -name '*m.shp'  -o -name '*m.dbf'  -o -name '*m.prj'  -o -name '*m.shx'  -o -name '*m.shp.xml'  \) -exec mv -f -t manzana {} +
find . -type f \( -name '*as.shp' -o -name '*as.dbf' -o -name '*as.prj' -o -name '*as.shx' -o -name '*as.shp.xml' \) -exec mv -f -t asentamiento {} +
# ... (demais arquivos movidos conforme padrão) ...

echo "✅ Preparação e Staging concluídos. Os dados de endereço estão na pasta 'direccion'."
