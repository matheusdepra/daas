import os
import logging
from datetime import datetime
from typing import List

import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from google.cloud import storage, bigquery

logging.basicConfig(level=logging.INFO)

app = FastAPI()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "daas-mvp-472103")
BRONZE_BUCKET = os.environ["BRONZE_BUCKET"]
BQ_DATASET = os.environ["BQ_SILVER_DATASET"]

storage_client = storage.Client(project=PROJECT_ID)
bq_client = bigquery.Client(project=PROJECT_ID)

class SilverRequest(BaseModel):
    company: str
    domain: str
    date: str  # yyyy-mm-dd


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
