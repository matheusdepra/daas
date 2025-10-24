# Use uma imagem base oficial do Python
FROM python:3.10-slim

# Defina o diretório de trabalho no container
WORKDIR /app

# Copie o arquivo de dependências para o diretório de trabalho
COPY requirements.txt .

# Instale as dependências
RUN pip install --no-cache-dir -r requirements.txt

# Copie o resto do código da aplicação para o diretório de trabalho
COPY . .

# Exponha a porta em que o app vai rodar
EXPOSE 8080

# Comando para iniciar a aplicação quando o container for executado
# O uvicorn é um servidor ASGI de alta performance.
# O host 0.0.0.0 faz o servidor ser acessível de fora do container.
# A porta 8080 é a porta padrão que o Cloud Run espera.
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
