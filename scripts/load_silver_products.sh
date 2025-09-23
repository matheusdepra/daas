#!/bin/bash
set -e

PROJECT_ID="daas-mvp-472103"
DATASET_BRONZE="mvp_bronze"
DATASET_SILVER="mvp_silver"

# Tabela origem (RAW no Bronze)
BRONZE_TABLE="$PROJECT_ID.$DATASET_BRONZE.olist_products_raw"

# Tabela destino (Silver já criada no Terraform)
SILVER_TABLE="$PROJECT_ID.$DATASET_SILVER.olist_products"

echo "🚀 Carregando dados de $BRONZE_TABLE para $SILVER_TABLE ..."

bq query --use_legacy_sql=false "
CREATE OR REPLACE TABLE \`$SILVER_TABLE\` AS
SELECT
  CAST(product_id AS STRING)        AS product_id,            -- obrigatório
  CAST(product_category_name AS STRING)        AS product_category_name,          -- obrigatório
  CAST(product_name_lenght AS INTEGER)        AS product_name_lenght,          -- obrigatório
  SAFE_CAST(product_description_lenght AS INTEGER)   AS product_description_lenght,           
  SAFE_CAST(product_photos_qty AS INTEGER)   AS product_photos_qty,           
  SAFE_CAST(product_weight_g AS INTEGER)   AS product_weight_g,           
  SAFE_CAST(product_length_cm AS INTEGER)   AS product_length_cm,           
  SAFE_CAST(product_height_cm AS INTEGER)   AS product_height_cm,           
  SAFE_CAST(product_width_cm AS INTEGER)   AS product_width_cm         
FROM \`$BRONZE_TABLE\`
WHERE product_id IS NOT NULL
  AND product_category_name IS NOT NULL
  AND product_name_lenght IS NOT NULL;
"

echo "✅ Tabela Silver ($SILVER_TABLE) atualizada com sucesso!"
