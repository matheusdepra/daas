#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

# Tabela origem (RAW no Bronze)
BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_order_payments_raw"

# Tabela destino (Silver já criada no Terraform)
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_order_payments"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  CAST(order_id AS STRING)                  AS order_id,               -- obrigatório
  SAFE_CAST(payment_sequential AS INT64)    AS payment_sequential,     -- número sequencial (pode ser NULL)
  SAFE_CAST(payment_type AS STRING)         AS payment_type,           -- tipo de pagamento
  SAFE_CAST(payment_installments AS INT64)  AS payment_installments,   -- número de parcelas
  SAFE_CAST(payment_value AS FLOAT64)       AS payment_value           -- valor do pagamento
FROM \`$BRONZE_TABLE\`
WHERE order_id IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
