#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

# Tabela origem (RAW no Bronze)
BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_geolocation_raw"

# Tabela destino (Silver já criada no Terraform)
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_geolocation"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  -- zip_code como STRING com 5 dígitos (o dataset Olist tem prefixos de CEP de 5 dígitos)
  LPAD(CAST(geolocation_zip_code_prefix AS STRING), 5, '0') AS geolocation_zip_code_prefix,
  SAFE_CAST(geolocation_lat AS FLOAT64)  AS geolocation_lat,
  SAFE_CAST(geolocation_lng AS FLOAT64)  AS geolocation_lng,
  INITCAP(SAFE_CAST(geolocation_city AS STRING)) AS geolocation_city,
  SAFE_CAST(geolocation_state AS STRING) AS geolocation_state
FROM \`$BRONZE_TABLE\`
WHERE geolocation_zip_code_prefix IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
