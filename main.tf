provider "google" {
  project = "daas-mvp-472103"
  region  = "us-central1"
}

##############################################
# Criação de Buckets
##############################################

# Bucket para dados brutos do cliente (landing)
# Arquivos de entrada do cliente
# Pode conter dados incorretos e lixos
# Deleção após 7 dias
resource "google_storage_bucket" "landing" {
  name          = "daas-landing-mvp"
  location      = "US"
  force_destroy = false
  storage_class = "STANDARD"
    
  uniform_bucket_level_access = true
  versioning {
    enabled = false
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 7
    }
  }
  labels = {
    product = "daas"
    env     = "mvp"
    layer   = "landing"
  }
}

# Bucket para dados brutos (bronze)
# Deleção - 365 dias
resource "google_storage_bucket" "bronze" {
  name          = "daas-bronze-mvp"
  location      = "US"
  force_destroy = false
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 365
    }
  }

  labels = {
    product = "daas"
    env     = "mvp"
    layer   = "bronze"
  }
}

# Bucket para dados limpos e tratados - Silver
# Deleção - 180 dias
resource "google_storage_bucket" "silver" {
  name          = "daas-silver-mvp"
  location      = "US"
  force_destroy = false
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 180
    }
  }

  labels = {
    product = "daas"
    env     = "mvp"
    layer   = "silver"
  }
}

# Bucket para dados com erro, sem schema  - quarantine
# Deleção - 30 dias
resource "google_storage_bucket" "quarantine" {
  name          = "daas-quarantine-mvp"
  location      = "US"
  force_destroy = false
  storage_class = "STANDARD"

  uniform_bucket_level_access = true

  versioning {
    enabled = true
  }
  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30
    }
  }

  labels = {
    product = "daas"
    env     = "mvp"
    layer   = "quarantine"
  }
}


##############################################
# Criação das Tabelas Big Query
##############################################
# Nesse ponto suportamos apenas a criação de 
# datasets
# Tabelas devem ser criadas no pipeline de dados


resource "google_bigquery_dataset" "silver" {
  dataset_id = "silver"
  location   = "US"

  labels = {
    product = "daas"
    env     = "mvp"
    layer   = "silver"
  }
}

resource "google_bigquery_dataset" "gold" {
  dataset_id = "gold"
  location   = "US"

  labels = {
    product = "daas"
    env     = "mvp"
    layer   = "gold"
  }
}

resource "google_bigquery_dataset" "quarantine" {
  dataset_id = "quarantine"
  location   = "US"

  labels = {
    product = "daas"
    env     = "mvp"
    layer   = "quarantine"
  }
}


##############################################
# Criação das service accounts
##############################################

# Ingestão do cloud run
resource "google_service_account" "cloud_run_ingest" {
  account_id   = "sa-daas-ingest"
  display_name = "DaaS Cloud Run Ingest Service"
}

resource "google_service_account" "eventarc" {
  account_id   = "sa-daas-eventarc"
  display_name = "DaaS Eventarc Trigger"
}

resource "google_service_account" "cloud_run_silver" {
  account_id   = "sa-daas-silver"
  display_name = "DaaS Silver Job Service"
}

##############################################
# IAM
##############################################
resource "google_project_iam_member" "ingest_gcs" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloud_run_ingest.email}"
}

# BIG Query
resource "google_project_iam_member" "ingest_bq" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.cloud_run_ingest.email}"
}

# Firestore
resource "google_project_iam_member" "ingest_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_run_ingest.email}"
}

# Logs
resource "google_project_iam_member" "ingest_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_ingest.email}"
}

# Event
resource "google_project_iam_member" "eventarc_receiver" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.eventarc.email}"
}

# Acessor reader landing bucket
resource "google_storage_bucket_iam_member" "eventarc_landing_reader" {
  bucket = google_storage_bucket.landing.name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.eventarc.email}"
}

# acesso pub sub apara event arc
resource "google_project_iam_member" "gcs_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

# Acesso a images
resource "google_project_iam_member" "ingest_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.cloud_run_ingest.email}"
}

#------------------------------------
# IAM para Silver Jobs
#------------------------------------
# Ler Bronze
resource "google_project_iam_member" "silver_gcs" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.cloud_run_silver.email}"
}

# Escrever BigQuery Silver
resource "google_project_iam_member" "silver_bq" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = "serviceAccount:${google_service_account.cloud_run_silver.email}"
}

# Logs
resource "google_project_iam_member" "silver_logs" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_silver.email}"
}

# Big query load
resource "google_project_iam_member" "silver_bq_jobuser" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cloud_run_silver.email}"
}

# Firestore
resource "google_project_iam_member" "silver_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.cloud_run_silver.email}"
}


##############################################
# Criação do Cloud Run Service 
# Ingest
##############################################

resource "google_cloud_run_service" "daas_ingest" {
  name     = "daas-ingest-worker"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run_ingest.email
      timeout_seconds      = 300
      container_concurrency = 1

      containers {
        image = var.ingest_image

        resources {
          limits = {
            cpu    = "1"
            memory = "1Gi"
          }
        }

        env {
          name  = "LANDING_BUCKET"
          value = google_storage_bucket.landing.name
        }

        env {
          name  = "BRONZE_BUCKET"
          value = google_storage_bucket.bronze.name
        }

        env {
          name  = "SILVER_BUCKET"
          value = google_storage_bucket.silver.name
        }

        env {
          name  = "QUARANTINE_BUCKET"
          value = google_storage_bucket.quarantine.name
        }

        env {
          name  = "BQ_SILVER_DATASET"
          value = "silver"
        }

        env {
          name  = "BQ_QUARANTINE_DATASET"
          value = "quarantine"
        }
      }
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

##############################################
# Criação do Cloud Run Service 
# Bronze -> Silver
##############################################

resource "google_cloud_run_service" "daas_silver" {
  name     = "daas-silver-job"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.cloud_run_silver.email
      timeout_seconds      = 900

      containers {
        image = var.silver_image

        resources {
          limits = {
            cpu    = "2"
            memory = "2Gi"
          }
        }

        env {
          name  = "BRONZE_BUCKET"
          value = google_storage_bucket.bronze.name
        }

        env {
          name  = "BQ_SILVER_DATASET"
          value = "silver"
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}



##############################################
# Firestore para Metadados
##############################################
resource "google_firestore_database" "metadata" {
  name        = "daas-metadata"
  location_id = "us-central1"
  type        = "FIRESTORE_NATIVE"
}

##############################################
# Cria Event Arc
##############################################
resource "google_cloud_run_service_iam_member" "eventarc_invoker" {
  location = google_cloud_run_service.daas_ingest.location
  service  = google_cloud_run_service.daas_ingest.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.eventarc.email}"
}



##############################################
# Cria Event Arc - Trigger
##############################################
resource "google_eventarc_trigger" "gcs_to_cloud_run" {
  name     = "gcs-finalize-to-daas-ingest"
  location = "us"

  matching_criteria {
    attribute = "type"
    value     = "google.cloud.storage.object.v1.finalized"
  }

  matching_criteria {
    attribute = "bucket"
    value     = google_storage_bucket.landing.name
  }

  destination {
    cloud_run_service {
      service = google_cloud_run_service.daas_ingest.name
      region  = var.region
    }
  }

  service_account = google_service_account.eventarc.email
}

##############################################
# Output
##############################################
output "cloud_run_service" {
  value = google_cloud_run_service.daas_ingest.name
}

