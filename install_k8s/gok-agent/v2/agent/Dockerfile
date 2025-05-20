FROM python:3.11-slim

WORKDIR /app

COPY agent_backend.py requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "agent_backend.py"]