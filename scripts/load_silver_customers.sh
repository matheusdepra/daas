#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_customers_raw"
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_customer"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  CAST(customer_id AS STRING) AS customer_id,
  CAST(customer_unique_id AS STRING) AS customer_unique_id,
  LPAD(CAST(customer_zip_code_prefix AS STRING), 4, '0') AS customer_zip_code_prefix,
  INITCAP(SAFE_CAST(customer_city AS STRING))  AS customer_city,
  SAFE_CAST(customer_state AS STRING)          AS customer_state
FROM \`$BRONZE_TABLE\`
WHERE customer_id IS NOT NULL
  AND customer_unique_id IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
