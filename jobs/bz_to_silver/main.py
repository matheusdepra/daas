import os
import logging
from datetime import datetime
from typing import List

import pandas as pd
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import yaml
import re
from google.cloud import storage, bigquery
from google.cloud import firestore

logging.basicConfig(level=logging.INFO)

# Bucket onde estao os buckets
SCHEMA_BUCKET = os.getenv("SCHEMA_BUCKET")

app = FastAPI()

PROJECT_ID = os.getenv("GOOGLE_CLOUD_PROJECT", "daas-mvp-472103")
BRONZE_BUCKET = os.getenv("BRONZE_BUCKET")
BQ_DATASET = os.getenv("BQ_SILVER_DATASET")

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
def mark_processed(company: str, domain: str, bronze_object: str, schema_version: int):
    
    doc_id = make_doc_id(company, domain, bronze_object)
    
    firestore_client.collection("silver_runs").document(doc_id).set({
        "company": company,
        "domain": domain,
        "bronze_object": bronze_object,
        "status": "PROCESSED",
        "schema_bucket": SCHEMA_BUCKET,
        "schema_version": schema_version,
        "schema_path": f"{company}/{domain}/v{schema_version}.yaml",
        "processed_at": datetime.now()
    })
  
# Cria doc id basedo no bronze object  
def make_doc_id(company: str, domain: str, bronze_object: str) -> str:
    safe_path = bronze_object.replace("/", "__")
    return f"{company}__{domain}__{safe_path}"

# Criacao e validacao de contratos

# Busca ultima versao de contrato
def get_latest_contract_version(bucket, company, domain):
    blobs = bucket.list_blobs(prefix=f"{company}/{domain}/v")
    versions = [int(b.name.split("v")[1].split(".")[0]) for b in blobs]
    return max(versions) if versions else None

# Carrega contraato
def load_contract(bucket, company, domain, version):
    blob = bucket.blob(f"{company}/{domain}/v{version}.yaml")
    return yaml.safe_load(blob.download_as_text())

# Detectar se ha mudanca e precisa novo contrato
def is_breaking_change(contract, bq_schema):
    for col, typ in contract["types"].items():
        if col not in bq_schema:
            return True
        if bq_schema[col] != typ:
            return True
    return False



def generate_contract(domain, table):
    return {
        "table": domain,
        "mode": "soft",
        "required": [f.name for f in table.schema if f.mode == "REQUIRED"],
        "types": {f.name: f.field_type for f in table.schema}
    }


# Salva contrato
def save_contract(contract, company, domain, version):
    bucket = storage_client.bucket(SCHEMA_BUCKET)
    blob = bucket.blob(f"{company}/{domain}/v{version}.yaml")
    blob.upload_from_string(yaml.dump(contract))

def get_bq_schema(table):
    return {f.name: f.field_type for f in table.schema}

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
    
    # Como ja esta processado podemos cuidar do schema
    schema_bucket = storage_client.bucket(SCHEMA_BUCKET)
    table = bq_client.get_table(table_id)

    latest = get_latest_contract_version(schema_bucket, company, domain)
    used_version = None

    # Gera primeira versao
    if latest is None:
        used_version = 1
        contract = generate_contract(domain, table)
        save_contract(contract, company, domain, 1)
        
    else:
        used_version = latest
        # Busca contrato e schema
        contract = load_contract(schema_bucket, company, domain, latest)
        bq_schema = get_bq_schema(table)

        # Verifica se tem diferenca no contrato e no schema e gera nova versao
        if is_breaking_change(contract, bq_schema):
            
            new_version = latest + 1
            used_version = latest
            new_contract = generate_contract(domain, table)
            save_contract(new_contract, company, domain, new_version)
    
    # Marca processado
    mark_processed(company, domain, bronze_object, used_version)
    
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
