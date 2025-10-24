import chainlit as cl
import httpx
import os
import datetime

# URL da sua API FastAPI que deve estar rodando separadamente
API_URL = "http://localhost:8080/ask"

@cl.on_chat_start
def on_chat_start():
    """
    Chamado quando uma nova sessão de chat é iniciada.
    Cria um ID de sessão único para a conversa e o armazena na sessão do usuário.
    """
    session_id = f"chainlit-ui-session-{datetime.datetime.now().strftime('%Y-%m-%d-%H%M%S')}-{os.urandom(4).hex()}"
    cl.user_session.set("session_id", session_id)
    cl.Message(content="Olá! Sou a interface de teste do seu agente. Como posso ajudar hoje?").send()

@cl.on_message
async def on_message(message: cl.Message):
    """
    Chamado a cada nova mensagem do usuário.
    Envia a pergunta para o backend FastAPI e exibe a resposta.
    """
    session_id = cl.user_session.get("session_id")
    question = message.content

    request_body = {
        "session_id": session_id,
        "question": question
    }

    loading_msg = cl.Message(content="Processando...")
    await loading_msg.send()

    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(API_URL, json=request_body)
            response.raise_for_status()

        api_response = response.json()
        answer = api_response.get("answer", "Não recebi uma resposta válida da API.")
        sql_query = api_response.get("sql_query")

        await loading_msg.remove()

        await cl.Message(content=answer).send()
        if sql_query:
            await cl.Message(content=f"**Consulta SQL executada:**\n```sql\n{sql_query}\n```").send()

    except httpx.HTTPStatusError as e:
        await loading_msg.remove()
        # Corrigido: Acessa o texto da resposta através de e.response.text
        error_detail = e.response.json().get("detail", e.response.text)
        await cl.Message(content=f"Erro ao comunicar com a API: {error_detail}").send()
    except Exception as e:
        await loading_msg.remove()
        await cl.Message(content=f"Ocorreu um erro inesperado: {str(e)}").send()
