import os
import datetime
import json
import re
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# --- Bibliotecas Google Cloud ---
import vertexai
from vertexai.generative_models import GenerativeModel
from google.cloud import bigquery, firestore

# --- Configuração Inicial ---
PROJECT_ID = os.getenv("GCP_PROJECT_ID", "daas-mvp-472103")
LOCATION = os.getenv("GCP_REGION", "us-central1")
BIGQUERY_TABLE_ID = f"{PROJECT_ID}.mvp_gold.f_orders"

# Inicializa os clientes GCP
vertexai.init(project=PROJECT_ID, location=LOCATION)
fs_client = firestore.Client(project=PROJECT_ID, database="daas-mvp-chat-history")
bq_client = bigquery.Client(project=PROJECT_ID)

# Carrega o modelo generativo
llm = GenerativeModel("gemini-2.5-pro")

# --- Modelos de Dados (Pydantic) ---
class AskRequest(BaseModel):
    session_id: str
    question: str

class AskResponse(BaseModel):
    session_id: str
    answer: str
    sql_query: str | None = None

# --- Lógica de Memória (Firestore) ---

def get_conversation_history(session_id: str, limit: int = 5) -> list[dict]:
    """Busca o histórico da conversa do Firestore."""
    docs = fs_client.collection("conversations").document(session_id).collection("messages").order_by("timestamp", direction=firestore.Query.DESCENDING).limit(limit).stream()
    history = [doc.to_dict() for doc in docs]
    return list(reversed(history))

def save_conversation(session_id: str, question: str, answer: str):
    """Salva a troca de mensagens no Firestore."""
    convo_ref = fs_client.collection("conversations").document(session_id).collection("messages")
    timestamp = datetime.datetime.now(datetime.timezone.utc)
    convo_ref.add({"role": "user", "content": question, "timestamp": timestamp})
    convo_ref.add({"role": "agent", "content": answer, "timestamp": timestamp})

# --- Lógica do Agente (LLM) ---

def route_intent(question: str, history: list[dict]) -> str:
    """Decide qual ferramenta usar: chat ou busca no banco de dados."""
    prompt = f"""
    Você é um roteador de intenções. Sua tarefa é decidir se a pergunta do usuário requer uma busca em um banco de dados ou se é uma conversa geral.
    As ferramentas são: `query_database` ou `general_chat`.

    `query_database`: Use para perguntas sobre vendas, clientes, pedidos, performance, etc.
    `general_chat`: Use para saudações, despedidas, ou perguntas que não podem ser respondidas pelos dados.

    Histórico da conversa:
    {history}

    Pergunta do usuário: "{question}"

    Responda APENAS com o nome da ferramenta.
    """
    response = llm.generate_content(prompt)
    return response.text.strip()

def get_table_schema() -> str:
    """Busca o esquema da tabela do BigQuery e o retorna como uma string JSON."""
    try:
        table = bq_client.get_table(BIGQUERY_TABLE_ID)
        schema = [{"name": field.name, "type": field.field_type, "mode": field.mode} for field in table.schema]
        return json.dumps(schema)
    except Exception as e:
        print(f"Alerta: Não foi possível buscar o esquema do BigQuery dinamicamente: {e}")
        return """[            {"name":"order_id", "type":"STRING", "mode":"REQUIRED"},            {"name":"customer_id", "type":"STRING", "mode":"REQUIRED"},            {"name":"customer_unique_id", "type":"STRING", "mode":"NULLABLE"},            {"name":"customer_city", "type":"STRING", "mode":"NULLABLE"},            {"name":"customer_state", "type":"STRING", "mode":"NULLABLE"},            {"name":"order_status", "type":"STRING", "mode":"REQUIRED"},            {"name":"order_purchase_ts", "type":"TIMESTAMP", "mode":"NULLABLE"},            {"name":"total_items", "type":"INTEGER", "mode":"NULLABLE"},            {"name":"total_order_value", "type":"FLOAT", "mode":"NULLABLE"}        ]"""

def generate_sql_from_question(question: str, history: list[dict]) -> str:
    """Gera uma query SQL a partir da pergunta e do histórico, com maior robustez."""
    schema = get_table_schema()
    prompt = f"""
    Sua tarefa é converter uma pergunta em uma query SQL para BigQuery.
    Você deve responder APENAS com o código SQL e nada mais. Não adicione explicações, saudações ou qualquer outro texto.
    Se a pergunta não puder ser respondida com o esquema fornecido, ou se for ambígua, retorne a palavra 'UNSURE' e nada mais.

    Use o esquema da tabela `{BIGQUERY_TABLE_ID}`: {schema}

    Histórico da conversa anterior: {history}
    Pergunta do usuário: "{question}"

    Query SQL:
    """
    response = llm.generate_content(prompt)
    sql_query = response.text.replace("```sql", "").replace("```", "").strip()

    if 'UNSURE' in sql_query:
        raise ValueError("Não tenho certeza de como responder a essa pergunta. Por favor, tente ser mais específico.")

    if not sql_query.lower().startswith("select"):
        # Tenta extrair o SQL se o modelo ainda adicionar texto extra
        match = re.search(r"select\s.*", sql_query, re.IGNORECASE | re.DOTALL)
        if match:
            sql_query = match.group(0)
        else:
            raise ValueError("A resposta do LLM não é uma query SQL válida.")
            
    return sql_query

def execute_bigquery_query(sql_query: str) -> list:
    """Executa a query no BigQuery."""
    query_job = bq_client.query(sql_query)
    results = query_job.result()
    return [dict(row) for row in results]

def summarize_result(question: str, data: list) -> str:
    """Usa o LLM para criar uma resposta em linguagem natural a partir dos dados."""
    prompt = f"""
    A pergunta do usuário foi: "{question}"
    Os seguintes dados foram retornados do banco de dados: {data}

    Sua tarefa é formular uma resposta clara e concisa em linguagem natural para o usuário.
    """
    response = llm.generate_content(prompt)
    return response.text.strip()

def generate_chat_response(question: str, history: list[dict]) -> str:
    """Gera uma resposta para conversas gerais."""
    prompt = f"Histórico: {history}\nPergunta: {question}\nResponda de forma amigável."
    response = llm.generate_content(prompt)
    return response.text.strip()

# --- Endpoint Principal da API ---

app = FastAPI(
    title="Agente Conversacional Inteligente",
    description="Um agente com memória e capacidade de decisão para conversar sobre dados.",
    version="1.0.0",
)

@app.post("/ask", response_model=AskResponse)
def ask_question(request: AskRequest):
    """Ponto de entrada principal do agente conversacional."""
    session_id = request.session_id
    question = request.question
    sql_query = None

    history = get_conversation_history(session_id)

    try:
        intent = route_intent(question, history)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro no roteador de intenção: {e}")

    if "query_database" in intent:
        try:
            sql_query = generate_sql_from_question(question, history)
            data = execute_bigquery_query(sql_query)
            answer = summarize_result(question, data)
        except Exception as e:
            answer = f"Desculpe, ocorreu um erro ao processar sua pergunta de dados: {e}"
    else: # general_chat
        try:
            answer = generate_chat_response(question, history)
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Erro ao gerar resposta de chat: {e}")

    save_conversation(session_id, question, answer)

    return AskResponse(session_id=session_id, answer=answer, sql_query=sql_query)
