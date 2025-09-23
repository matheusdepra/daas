#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_SILVER="mvp_silver"
DATASET_GOLD="mvp_gold"

# Tabelas de origem (Silver)
SILVER_ORDERS="$PROJECT_ID.$DATASET_SILVER.olist_orders"
SILVER_CUSTOMERS="$PROJECT_ID.$DATASET_SILVER.olist_customer"
SILVER_ITEMS="$PROJECT_ID.$DATASET_SILVER.olist_order_items"
SILVER_PAYMENTS="$PROJECT_ID.$DATASET_SILVER.olist_order_payments"

# Tabela de destino (Gold)
GOLD_TABLE="$PROJECT_ID.$DATASET_GOLD.f_orders"

echo "🚀 Carregando dados de Silver para $GOLD_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$GOLD_TABLE\` AS
SELECT
  CAST(o.order_id AS STRING) AS order_id,
  CAST(o.customer_id AS STRING) AS customer_id,
  c.customer_unique_id,
  c.customer_city,
  c.customer_state,
  o.order_status,
  SAFE_CAST(o.order_purchase_timestamp AS TIMESTAMP)       AS order_purchase_ts,
  SAFE_CAST(o.order_approved_at AS TIMESTAMP)              AS order_approved_ts,
  SAFE_CAST(o.order_delivered_customer_date AS TIMESTAMP)  AS order_delivered_customer_ts,
  SAFE_CAST(o.order_estimated_delivery_date AS DATE)       AS order_estimated_delivery_date,
  COUNT(oi.order_item_id)                                  AS total_items,
  SUM(SAFE_CAST(oi.price AS FLOAT64))                      AS total_order_value,
  SUM(SAFE_CAST(op.payment_value AS FLOAT64))              AS total_payment_value,
  MAX(SAFE_CAST(op.payment_installments AS INT64))         AS max_installments,
  CASE 
    WHEN DATE(SAFE_CAST(o.order_delivered_customer_date AS TIMESTAMP)) 
         <= SAFE_CAST(o.order_estimated_delivery_date AS DATE) THEN 1
    ELSE 0
  END AS delivered_on_time
FROM \`$SILVER_ORDERS\` o
LEFT JOIN \`$SILVER_CUSTOMERS\` c
  ON o.customer_id = c.customer_id
LEFT JOIN \`$SILVER_ITEMS\` oi
  ON o.order_id = oi.order_id
LEFT JOIN \`$SILVER_PAYMENTS\` op
  ON o.order_id = op.order_id
WHERE o.order_id IS NOT NULL
GROUP BY
  o.order_id, o.customer_id, c.customer_unique_id, c.customer_city, c.customer_state,
  o.order_status, o.order_purchase_timestamp, o.order_approved_at,
  o.order_delivered_customer_date, o.order_estimated_delivery_date;
"

echo "✅ Tabela Gold ($GOLD_TABLE) atualizada com sucesso!"
