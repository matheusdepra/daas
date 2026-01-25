import os
import logging
from datetime import datetime

from fastapi import FastAPI, Request
from google.cloud import storage
from google.cloud import firestore
from google.cloud import logging as cloud_logging

# Cloud Logging
cloud_logging.Client().setup_logging()
logging.basicConfig(level=logging.INFO)

app = FastAPI()

# Env vars
LANDING_BUCKET = os.environ["LANDING_BUCKET"]
BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "daas-mvp-472103")


storage_client = storage.Client()
firestore_client = firestore.Client(
    project=PROJECT_ID,
    database="daas-metadata"
)

@app.post("/")
async def handle_event(request: Request):
    logging.info("Recebido evento")
    event = await request.json()
    
    if not event:
        logging.warning("Evento vazio")
        return {"status": "ignored"}
    
    logging.info(f"Evento: {event}")

    try:
        bucket_name = event.get("bucket")
        object_name = event.get("name")

        if not bucket_name or not object_name:
            logging.warning("Evento incompleto")
            return {"status": "ignored"}

        if bucket_name != LANDING_BUCKET:
            logging.info(f"Ignorado bucket {bucket_name}")
            return {"status": "ignored"}

        logging.info(f"Processando gs://{bucket_name}/{object_name}")
        process_file(bucket_name, object_name)

        return {"status": "ok"}

    except Exception as e:
        logging.exception("Erro ao processar evento")
        return {"status": "error", "message": str(e)}


def process_file(bucket_name: str, object_name: str):
    logging.info(f"Copiando para bronze: {bucket_name}/{object_name}")
    
    source_bucket = storage_client.bucket(bucket_name)
    source_blob = source_bucket.blob(object_name)
    
    # Ex: vendas/pedidos.csv
    path_parts = object_name.split("/", 2)

    if len(path_parts) < 2:
        logging.warning("Arquivo sem domínio (subpasta)")
        raise ValueError("Arquivo deve estar dentro de um domínio (ex: vendas/arquivo.csv)")

    company = path_parts[0]             # empresa
    domain = path_parts[1]              # vendas
    original_file = path_parts[2]       # pedidos.csv

    date_path = datetime.now().strftime("%Y/%m/%d")

    bronze_path = f"{company}/{domain}/{date_path}/{original_file}"

    dest_bucket = storage_client.bucket(BRONZE_BUCKET)
    source_bucket.copy_blob(source_blob, dest_bucket, bronze_path)

    firestore_client.collection("ingestions").add({
        "source_bucket": bucket_name,
        "source_object": object_name,
        "bronze_object": bronze_path,
        "status": "BRONZE_CREATED",
        "ingestion_ts": datetime.now()
    })

    logging.info(f"Copiado para bronze: {bronze_path}")
