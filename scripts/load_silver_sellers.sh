#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

# Tabela origem (RAW no Bronze)
BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_sellers_raw"

# Tabela destino (Silver já criada no Terraform)
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_sellers"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  CAST(seller_id AS STRING)        AS seller_id,            -- obrigatório
  LPAD(CAST(seller_zip_code_prefix AS STRING), 5, '0') AS seller_zip_code_prefix,
  SAFE_CAST(seller_city AS STRING)   AS seller_city,
  SAFE_CAST(seller_state AS STRING)   AS seller_state
FROM \`$BRONZE_TABLE\`
WHERE seller_id IS NOT NULL
  AND seller_zip_code_prefix IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
