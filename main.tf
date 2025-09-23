provider "google" {
  project = "daas-mvp-472103"
  region  = "us-central1"
}

# Bucket para dados brutos (bronze)
resource "google_storage_bucket" "bronze" {
  name          = "daas-bronze-mvp"
  location      = "US"
  force_destroy = true
  versioning {
    enabled = true
  }
}

# BigQuery Dataset (bronze -> raw)
resource "google_bigquery_dataset" "mvp_bronze" {
  dataset_id                 = "mvp_bronze"
  location                   = "US"
  delete_contents_on_destroy = true
}

# BigQuery Dataset (silver -> Tratados)
resource "google_bigquery_dataset" "mvp_silver" {
  dataset_id                 = "mvp_silver"
  location                   = "US"
  delete_contents_on_destroy = true
}

# Carregamento Big Query Raw Bronze
resource "google_bigquery_table" "raw_olist_customers" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_customers_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_customers_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""   # precisa definir, mesmo que seja o padrão
    }
  }
}

resource "google_bigquery_table" "raw_olist_geolocation" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_geolocation_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_geolocation_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""  
    }
  }
}

resource "google_bigquery_table" "raw_olist_order_items" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_order_items_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_order_items_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""  
    }
  }
}

resource "google_bigquery_table" "raw_olist_order_payments" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_order_payments_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_order_payments_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""  
    }
  }
}

resource "google_bigquery_table" "raw_olist_order_reviews" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_order_reviews_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_order_reviews_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""  
      allow_quoted_newlines = true
    }
  }
}

resource "google_bigquery_table" "raw_olist_orders" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_orders_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_orders_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""  
    }
  }
}

resource "google_bigquery_table" "raw_olist_products" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_products_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_products_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""  
    }
  }
}

resource "google_bigquery_table" "raw_olist_sellers" {
  dataset_id          = google_bigquery_dataset.mvp_bronze.dataset_id
  table_id            = "olist_sellers_raw"
  deletion_protection = false

  external_data_configuration {
    source_format = "CSV"
    autodetect    = true
    source_uris   = ["gs://${google_storage_bucket.bronze.name}/olist/olist_sellers_dataset.csv"]
    csv_options {
      skip_leading_rows = 1
      quote             = "\""  
    }
  }
}

# Olist Customer Table
resource "google_bigquery_table" "olist_customer" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_customer"

  schema = <<EOF
[
  {"name":"customer_id", "type":"STRING", "mode":"REQUIRED", "description":"Customer ID"},
  {"name":"customer_unique_id", "type":"STRING", "mode":"REQUIRED", "description":"Customer Unique ID"},
  {"name":"customer_zip_code_prefix", "type":"STRING", "mode":"NULLABLE", "description":"Customer zip code prefix"},
  {"name":"customer_city", "type":"STRING", "mode":"NULLABLE", "description":"Customer City"},
  {"name":"customer_state", "type":"STRING", "mode":"NULLABLE", "description":"Customer State"}
]
EOF
}

# Olist Geolocation Table
resource "google_bigquery_table" "olist_geolocation" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_geolocation"

  schema = <<EOF
[
  {"name":"geolocation_zip_code_prefix", "type":"STRING", "mode":"REQUIRED", "description":"Geolocation zip code prefix"},
  {"name":"geolocation_lat", "type":"FLOAT", "mode":"NULLABLE", "description":"Geolocation latitude"},
  {"name":"geolocation_lng", "type":"FLOAT", "mode":"NULLABLE", "description":"Geolocation longitude"},
  {"name":"geolocation_city", "type":"STRING", "mode":"NULLABLE", "description":"Geolocation City"},
  {"name":"geolocation_state", "type":"STRING", "mode":"NULLABLE", "description":"Geolocation State"}
]
EOF
}

# Olist Order Items Table
resource "google_bigquery_table" "olist_order_items" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_order_items"

  schema = <<EOF
[
  {"name":"order_id", "type":"STRING", "mode":"REQUIRED", "description":"Order ID"},
  {"name":"order_item_id", "type":"STRING", "mode":"REQUIRED", "description":"Order Item ID"},
  {"name":"seller_id", "type":"STRING", "mode":"REQUIRED", "description":"Seller ID"},
  {"name":"shipping_limit_date", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Shipping Limit Date"},
  {"name":"price", "type":"FLOAT", "mode":"NULLABLE", "description":"Item price"}
]
EOF
}

# Olist Order Payments Table
resource "google_bigquery_table" "olist_order_payments" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_order_payments"

  schema = <<EOF
[
  {"name":"order_id", "type":"STRING", "mode":"REQUIRED", "description":"Order ID"},
  {"name":"payment_sequential", "type":"INTEGER", "mode":"NULLABLE", "description":"Payment Sequential Number"},
  {"name":"payment_type", "type":"STRING", "mode":"NULLABLE", "description":"Payment Type"},
  {"name":"payment_installments", "type":"INTEGER", "mode":"NULLABLE", "description":"Payment Installments"},
  {"name":"payment_value", "type":"FLOAT", "mode":"NULLABLE", "description":"Payment Value"}
]
EOF
}

# Olist Order Reviews Table
resource "google_bigquery_table" "olist_order_reviews" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_order_reviews"

  schema = <<EOF
[
  {"name":"review_id", "type":"STRING", "mode":"REQUIRED", "description":"Review ID"},
  {"name":"order_id", "type":"STRING", "mode":"REQUIRED", "description":"Order ID"},
  {"name":"review_score", "type":"INTEGER", "mode":"NULLABLE", "description":"Review Score"},
  {"name":"review_comment_title", "type":"STRING", "mode":"NULLABLE", "description":"Review Comment Title"},
  {"name":"review_comment_message", "type":"STRING", "mode":"NULLABLE", "description":"Review Comment Message"},
  {"name":"review_creation_date", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Review Creation Date"},
  {"name":"review_answer_timestamp", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Review Answer Timestamp"}
]
EOF
}

# Olist Orders Table
resource "google_bigquery_table" "olist_orders" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_orders"

  schema = <<EOF
[
  {"name":"order_id", "type":"STRING", "mode":"REQUIRED", "description":"Order ID"},
  {"name":"customer_id", "type":"STRING", "mode":"REQUIRED", "description":"Customer ID"},
  {"name":"order_status", "type":"STRING", "mode":"REQUIRED", "description":"Order Status"},
  {"name":"order_purchase_timestamp", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Purchase Timestamp"},
  {"name":"order_approved_at", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Approved At"},
  {"name":"order_delivered_carrier_date", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Delivered Carrier Date"},
  {"name":"order_delivered_customer_date", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Delivered Customer Date"},
  {"name":"order_estimated_delivery_date", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Estimated Delivery Date"}
]
EOF
}

# Olist Products Table
resource "google_bigquery_table" "olist_products" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_products"

  schema = <<EOF
[
  {"name":"product_id", "type":"STRING", "mode":"REQUIRED", "description":"Product ID"},
  {"name":"product_category_name", "type":"STRING", "mode":"REQUIRED", "description":"Product Category Name"},
  {"name":"product_name_lenght", "type":"INTEGER", "mode":"REQUIRED", "description":"Product Name Lenght"},
  {"name":"product_description_lenght", "type":"INTEGER", "mode":"NULLABLE", "description":"Product Description Lenght"},
  {"name":"product_photos_qty", "type":"INTEGER", "mode":"NULLABLE", "description":"Product Photos Quantity"},
  {"name":"product_weight_g", "type":"INTEGER", "mode":"NULLABLE", "description":"Product Weight Grams"},
  {"name":"product_length_cm", "type":"INTEGER", "mode":"NULLABLE", "description":"Product Length Centimeters"},
  {"name":"product_height_cm", "type":"INTEGER", "mode":"NULLABLE", "description":"Product Height Centimeters"},
  {"name":"product_width_cm", "type":"INTEGER", "mode":"NULLABLE", "description":"Product Width Centimeters"}
]
EOF
}

# Olist Sellers Table
resource "google_bigquery_table" "olist_sellers" {
  dataset_id = google_bigquery_dataset.mvp_silver.dataset_id
  table_id   = "olist_sellers"

  schema = <<EOF
[
  {"name":"seller_id", "type":"STRING", "mode":"REQUIRED", "description":"Seller ID"},
  {"name":"seller_zip_code_prefix", "type":"STRING", "mode":"REQUIRED", "description":"Seller ZIP Code Prefix"},
  {"name":"seller_city", "type":"STRING", "mode":"REQUIRED", "description":"Seller City"},
  {"name":"seller_state", "type":"STRING", "mode":"NULLABLE", "description":"Seller State"}
]
EOF
}


# BigQuery Dataset Gold
resource "google_bigquery_dataset" "mvp_gold" {
  dataset_id = "mvp_gold"
  location   = "US"
  delete_contents_on_destroy = false
}

# Fato de Pedidos (Gold)
resource "google_bigquery_table" "f_orders" {
  dataset_id = google_bigquery_dataset.mvp_gold.dataset_id
  table_id   = "f_orders"
  deletion_protection = false

  schema = <<EOF
[
  {"name":"order_id", "type":"STRING", "mode":"REQUIRED", "description":"Order ID"},
  {"name":"customer_id", "type":"STRING", "mode":"REQUIRED", "description":"Customer ID"},
  {"name":"customer_unique_id", "type":"STRING", "mode":"NULLABLE", "description":"Customer Unique ID"},
  {"name":"customer_city", "type":"STRING", "mode":"NULLABLE", "description":"Customer City"},
  {"name":"customer_state", "type":"STRING", "mode":"NULLABLE", "description":"Customer State"},
  {"name":"order_status", "type":"STRING", "mode":"REQUIRED", "description":"Order Status"},
  {"name":"order_purchase_ts", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Purchase Timestamp"},
  {"name":"order_approved_ts", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Approved Timestamp"},
  {"name":"order_delivered_customer_ts", "type":"TIMESTAMP", "mode":"NULLABLE", "description":"Order Delivered Customer Timestamp"},
  {"name":"order_estimated_delivery_date", "type":"DATE", "mode":"NULLABLE", "description":"Order Estimated Delivery Date"},
  {"name":"total_items", "type":"INTEGER", "mode":"NULLABLE", "description":"Total items in order"},
  {"name":"total_order_value", "type":"FLOAT", "mode":"NULLABLE", "description":"Sum of item prices"},
  {"name":"total_payment_value", "type":"FLOAT", "mode":"NULLABLE", "description":"Sum of payments"},
  {"name":"max_installments", "type":"INTEGER", "mode":"NULLABLE", "description":"Max number of installments"},
  {"name":"delivered_on_time", "type":"INTEGER", "mode":"NULLABLE", "description":"1 if delivered on or before estimated date, else 0"}
]
EOF
}

