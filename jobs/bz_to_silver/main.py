import os
import logging
from datetime import datetime
from typing import List

import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.cloud import storage, bigquery
from google.cloud import firestore

logging.basicConfig(level=logging.INFO)

app = FastAPI()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "daas-mvp-472103")
BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]
BQ_DATASET = os.environ["BQ_SILVER_DATASET"]

storage_client = storage.Client(project=PROJECT_ID)
bq_client = bigquery.Client(project=PROJECT_ID)

# Inicia Firestore client
PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "daas-mvp-472103")
firestore_client = firestore.Client(
    project=PROJECT_ID,
    database="daas-metadata"
)

class SilverRequest(BaseModel):
    company: str
    domain: str
    date: str  # yyyy-mm-dd


# Verifica se doc ja processado
def already_processed(company:str, domain: str, bronze_object: str) -> bool:
    doc_id = make_doc_id(company, domain, bronze_object)
    
    doc = firestore_client.collection("silver_runs").document(doc_id).get()
    return doc.exists

# Marca documentos ja processados
def mark_processed(company: str, domain: str, bronze_object: str):
    
    doc_id = make_doc_id(company, domain, bronze_object)
    
    firestore_client.collection("silver_runs").document(doc_id).set({
        "company": company,
        "domain": domain,
        "bronze_object": bronze_object,
        "status": "PROCESSED",
        "processed_at": datetime.utcnow()
    })
  
# Cria doc id basedo no bronze object  
def make_doc_id(company: str, domain: str, bronze_object: str) -> str:
    safe_path = bronze_object.replace("/", "__")
    return f"{company}__{domain}__{safe_path}"



def list_bronze_files(company:str, domain: str, date: str) -> List[str]:
    dt = datetime.strptime(date, "%Y-%m-%d")
    prefix = f"{company}/{domain}/{dt:%Y/%m/%d}/"

    bucket = storage_client.bucket(BRONZE_BUCKET)
    blobs = bucket.list_blobs(prefix=prefix)

    files = [f"gs://{BRONZE_BUCKET}/{b.name}" for b in blobs if b.name.endswith(".csv")]
    return files

def infer_and_load(files: List[str], company:str, domain: str):
    if not files:
        raise ValueError("Nenhum arquivo encontrado")

    dfs = []
    for path in files:
        
        logging.info(f"Lendo {path}")
        
        bronze_object = path.replace(f"gs://{BRONZE_BUCKET}/", "")
        
        if already_processed(company, domain, bronze_object):
            logging.info(f"Ignorado (já processado): {bronze_object}")
            continue
        
        df = pd.read_csv(path)
        df['company'] = company
        df["domain"] = domain
        df["source_file"] = path
        df["ingestion_ts"] = datetime.utcnow()
        dfs.append(df)

    final_df = pd.concat(dfs, ignore_index=True)

    table_id = f"{PROJECT_ID}.{BQ_DATASET}.{domain}"

    job_config = bigquery.LoadJobConfig(
        autodetect=True,
        write_disposition="WRITE_APPEND"
    )

    load_job = bq_client.load_table_from_dataframe(
        final_df,
        table_id,
        job_config=job_config
    )

    load_job.result()
    
    # Marca processado
    mark_processed(company, domain, bronze_object)
    
    logging.info(f"Dados carregados em {table_id}")

@app.post("/run")
def run_silver(req: SilverRequest):
    try:
        files = list_bronze_files(req.company, req.domain, req.date)
        infer_and_load(files, req.company, req.domain)

        return {
            "status": "ok",
            "company": req.company,
            "domain": req.domain,
            "date": req.date,
            "files_processed": len(files)
        }

    except Exception as e:
        logging.exception("Erro no Silver job")
        raise HTTPException(status_code=500, detail=str(e))
