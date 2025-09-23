#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

# Tabela origem (RAW no Bronze)
BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_order_items_raw"

# Tabela destino (Silver já criada no Terraform)
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_order_items"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  CAST(order_id AS STRING)        AS order_id,
  CAST(order_item_id AS STRING)   AS order_item_id,
  CAST(seller_id AS STRING)       AS seller_id,
  -- shipping_limit_date pode ser datetime, mas está como texto no CSV
  SAFE_CAST(shipping_limit_date AS STRING) AS shipping_limit_date,
  SAFE_CAST(price AS FLOAT64)     AS price
FROM \`$BRONZE_TABLE\`
WHERE order_id IS NOT NULL
  AND order_item_id IS NOT NULL
  AND seller_id IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
