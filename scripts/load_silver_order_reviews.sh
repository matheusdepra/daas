#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

# Tabela origem (RAW no Bronze)
BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_order_reviews_raw"

# Tabela destino (Silver já criada no Terraform)
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_order_reviews"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  CAST(review_id AS STRING)          AS review_id,              -- obrigatório
  CAST(order_id AS STRING)           AS order_id,               -- obrigatório
  SAFE_CAST(review_score AS INT64)   AS review_score,           -- nota pode faltar
  SAFE_CAST(review_comment_title AS STRING)   AS review_comment_title,
  SAFE_CAST(review_comment_message AS STRING) AS review_comment_message,
  -- datas no dataset Olist geralmente estão como STRING (YYYY-MM-DD HH:MM:SS)
  SAFE_CAST(review_creation_date AS STRING)    AS review_creation_date,
  SAFE_CAST(review_answer_timestamp AS STRING) AS review_answer_timestamp
FROM \`$BRONZE_TABLE\`
WHERE review_id IS NOT NULL
  AND order_id IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
