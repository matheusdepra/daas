#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

# Tabela origem (RAW no Bronze)
BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_orders_raw"

# Tabela destino (Silver já criada no Terraform)
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_orders"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  CAST(order_id AS STRING)           AS order_id,               -- obrigatório
  CAST(customer_id AS STRING)        AS customer_id,            -- obrigatório
  CAST(order_status AS STRING)        AS order_status,          -- obrigatório
  SAFE_CAST(order_purchase_timestamp AS TIMESTAMP)   AS order_purchase_timestamp,           
  SAFE_CAST(order_approved_at AS STRING)   AS order_approved_at,
  SAFE_CAST(order_delivered_carrier_date AS TIMESTAMP) AS order_delivered_carrier_date,
  SAFE_CAST(order_delivered_customer_date AS TIMESTAMP)    AS order_delivered_customer_date,
  SAFE_CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_date
FROM \`$BRONZE_TABLE\`
WHERE order_id IS NOT NULL
  AND customer_id IS NOT NULL
  AND order_status IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
