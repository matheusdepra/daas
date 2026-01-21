import os
from google.cloud import bigquery

# --- Configuração --- 
# Lê o ID do projeto de uma variável de ambiente ou usa um valor padrão.
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "daas-mvp-472103")
DATASET_BRONZE = "mvp_bronze"
DATASET_SILVER = "mvp_silver"
DATASET_GOLD = "mvp_gold"

# Inicializa o cliente BigQuery que será usado para executar as queries
client = bigquery.Client(project=PROJECT_ID)

# --- Definição das Queries SQL --- 
# Cada query é uma transformação de uma camada para outra (Bronze -> Silver, Silver -> Gold)

# Query para carregar a tabela de clientes na camada Silver
LOAD_SILVER_CUSTOMERS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_customer` AS
SELECT
  CAST(customer_id AS STRING) AS customer_id,
  CAST(customer_unique_id AS STRING) AS customer_unique_id,
  LPAD(CAST(customer_zip_code_prefix AS STRING), 5, '0') AS customer_zip_code_prefix,
  INITCAP(SAFE_CAST(customer_city AS STRING))  AS customer_city,
  SAFE_CAST(customer_state AS STRING)          AS customer_state
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_customers_raw`
WHERE customer_id IS NOT NULL
  AND customer_unique_id IS NOT NULL;
"""

# Query para carregar a tabela de geolocalização na camada Silver
LOAD_SILVER_GEOLOCATION_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_geolocation` AS
SELECT
  LPAD(CAST(geolocation_zip_code_prefix AS STRING), 5, '0') AS geolocation_zip_code_prefix,
  SAFE_CAST(geolocation_lat AS FLOAT64)  AS geolocation_lat,
  SAFE_CAST(geolocation_lng AS FLOAT64)  AS geolocation_lng,
  INITCAP(SAFE_CAST(geolocation_city AS STRING)) AS geolocation_city,
  SAFE_CAST(geolocation_state AS STRING) AS geolocation_state
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_geolocation_raw`
WHERE geolocation_zip_code_prefix IS NOT NULL;
"""

# Adicione aqui as outras queries para a camada Silver...
LOAD_SILVER_ORDER_ITEMS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_order_items` AS
SELECT
  CAST(order_id AS STRING) AS order_id,
  CAST(order_item_id AS STRING) AS order_item_id,
  CAST(product_id AS STRING) AS product_id,
  CAST(seller_id AS STRING) AS seller_id,
  SAFE_CAST(shipping_limit_date AS TIMESTAMP) AS shipping_limit_date,
  SAFE_CAST(price AS FLOAT64) AS price,
  SAFE_CAST(freight_value AS FLOAT64) AS freight_value
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_order_items_raw`
WHERE order_id IS NOT NULL;
"""

LOAD_SILVER_ORDER_PAYMENTS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_order_payments` AS
SELECT
  CAST(order_id AS STRING) AS order_id,
  SAFE_CAST(payment_sequential AS INT64) AS payment_sequential,
  SAFE_CAST(payment_type AS STRING) AS payment_type,
  SAFE_CAST(payment_installments AS INT64) AS payment_installments,
  SAFE_CAST(payment_value AS FLOAT64) AS payment_value
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_order_payments_raw`
WHERE order_id IS NOT NULL;
"""

LOAD_SILVER_ORDER_REVIEWS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_order_reviews` AS
SELECT
  CAST(review_id AS STRING) AS review_id,
  CAST(order_id AS STRING) AS order_id,
  SAFE_CAST(review_score AS INT64) AS review_score,
  CAST(review_comment_title AS STRING) AS review_comment_title,
  CAST(review_comment_message AS STRING) AS review_comment_message,
  SAFE_CAST(review_creation_date AS TIMESTAMP) AS review_creation_date,
  SAFE_CAST(review_answer_timestamp AS TIMESTAMP) AS review_answer_timestamp
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_order_reviews_raw`
WHERE review_id IS NOT NULL AND order_id IS NOT NULL;
"""

LOAD_SILVER_ORDERS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_orders` AS
SELECT
  CAST(order_id AS STRING) AS order_id,
  CAST(customer_id AS STRING) AS customer_id,
  CAST(order_status AS STRING) AS order_status,
  SAFE_CAST(order_purchase_timestamp AS TIMESTAMP) AS order_purchase_timestamp,
  SAFE_CAST(order_approved_at AS TIMESTAMP) AS order_approved_at,
  SAFE_CAST(order_delivered_carrier_date AS TIMESTAMP) AS order_delivered_carrier_date,
  SAFE_CAST(order_delivered_customer_date AS TIMESTAMP) AS order_delivered_customer_date,
  SAFE_CAST(order_estimated_delivery_date AS TIMESTAMP) AS order_estimated_delivery_date
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_orders_raw`
WHERE order_id IS NOT NULL;
"""

LOAD_SILVER_PRODUCTS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_products` AS
SELECT
  CAST(product_id AS STRING) AS product_id,
  CAST(product_category_name AS STRING) AS product_category_name,
  SAFE_CAST(product_name_lenght AS INT64) AS product_name_lenght,
  SAFE_CAST(product_description_lenght AS INT64) AS product_description_lenght,
  SAFE_CAST(product_photos_qty AS INT64) AS product_photos_qty,
  SAFE_CAST(product_weight_g AS INT64) AS product_weight_g,
  SAFE_CAST(product_length_cm AS INT64) AS product_length_cm,
  SAFE_CAST(product_height_cm AS INT64) AS product_height_cm,
  SAFE_CAST(product_width_cm AS INT64) AS product_width_cm
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_products_raw`
WHERE product_id IS NOT NULL;
"""

LOAD_SILVER_SELLERS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_SILVER}.olist_sellers` AS
SELECT
  CAST(seller_id AS STRING) AS seller_id,
  LPAD(CAST(seller_zip_code_prefix AS STRING), 5, '0') AS seller_zip_code_prefix,
  INITCAP(CAST(seller_city AS STRING)) AS seller_city,
  CAST(seller_state AS STRING) AS seller_state
FROM `{PROJECT_ID}.{DATASET_BRONZE}.olist_sellers_raw`
WHERE seller_id IS NOT NULL;
"""


# Query para criar a tabela de fatos (camada Gold)
LOAD_GOLD_F_ORDERS_SQL = f"""
CREATE OR REPLACE TABLE `{PROJECT_ID}.{DATASET_GOLD}.f_orders` AS
SELECT
    o.order_id,
    o.customer_id,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    o.order_status,
    o.order_purchase_timestamp AS order_purchase_ts,
    o.order_approved_at AS order_approved_ts,
    o.order_delivered_customer_date AS order_delivered_customer_ts,
    DATE(o.order_estimated_delivery_date) AS order_estimated_delivery_date,
    (SELECT COUNT(oi.product_id) FROM `{PROJECT_ID}.{DATASET_SILVER}.olist_order_items` oi WHERE oi.order_id = o.order_id) as total_items,
    (SELECT SUM(oi.price) FROM `{PROJECT_ID}.{DATASET_SILVER}.olist_order_items` oi WHERE oi.order_id = o.order_id) as total_order_value,
    (SELECT SUM(p.payment_value) FROM `{PROJECT_ID}.{DATASET_SILVER}.olist_order_payments` p WHERE p.order_id = o.order_id) as total_payment_value,
    (SELECT MAX(p.payment_installments) FROM `{PROJECT_ID}.{DATASET_SILVER}.olist_order_payments` p WHERE p.order_id = o.order_id) as max_installments,
    CASE
        WHEN o.order_delivered_customer_date IS NOT NULL AND o.order_estimated_delivery_date IS NOT NULL
        THEN IF(DATE(o.order_delivered_customer_date) <= DATE(o.order_estimated_delivery_date), 1, 0)
        ELSE NULL
    END as delivered_on_time
FROM `{PROJECT_ID}.{DATASET_SILVER}.olist_orders` o
LEFT JOIN `{PROJECT_ID}.{DATASET_SILVER}.olist_customer` c ON o.customer_id = c.customer_id
"""

def execute_query(sql: str, job_name: str):
    """Função genérica para executar uma query no BigQuery."""
    print(f"🔄 Executando job: {job_name}...")
    try:
        # Inicia a query
        query_job = client.query(sql)
        # Espera a finalização do job
        query_job.result()
        print(f"✅ Job \"{job_name}\" finalizado com sucesso!")
    except Exception as e:
        print(f"❌ Erro no job \"{job_name}\": {e}")
        # Propaga o erro para parar o pipeline se algo falhar
        raise

def run_silver_layer_pipeline():
    """Orquestra a execução de todas as queries da camada Silver."""
    print("🚀 Iniciando carga da Camada Silver...")
    # Dicionário mapeando nome do job e a query SQL correspondente
    silver_jobs = {
        "silver_customers": LOAD_SILVER_CUSTOMERS_SQL,
        "silver_geolocation": LOAD_SILVER_GEOLOCATION_SQL,
        "silver_order_items": LOAD_SILVER_ORDER_ITEMS_SQL,
        "silver_order_payments": LOAD_SILVER_ORDER_PAYMENTS_SQL,
        "silver_order_reviews": LOAD_SILVER_ORDER_REVIEWS_SQL,
        "silver_orders": LOAD_SILVER_ORDERS_SQL,
        "silver_products": LOAD_SILVER_PRODUCTS_SQL,
        "silver_sellers": LOAD_SILVER_SELLERS_SQL,
    }
    
    for job_name, sql in silver_jobs.items():
        execute_query(sql, job_name)
    
    print("✅ Camada Silver carregada com sucesso!")


def run_gold_layer_pipeline():
    """Orquestra a execução da query da camada Gold."""
    print("\n🚀 Iniciando carga da Camada Gold...")
    execute_query(LOAD_GOLD_F_ORDERS_SQL, "gold_f_orders")
    print("✅ Camada Gold carregada com sucesso!")


if __name__ == "__main__":
    print("🎉 Iniciando pipeline de dados completo...\n")
    run_silver_layer_pipeline()
    run_gold_layer_pipeline()
    print("\n🎉 Pipeline de dados finalizado com sucesso!")
