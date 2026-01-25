FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir \
    fastapi \
    uvicorn \
    google-cloud-storage \
    google-cloud-firestore \
    google-cloud-logging

COPY main.py .

ENV PORT=8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
