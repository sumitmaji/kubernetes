FROM python:3.11-slim

WORKDIR /app

COPY app.py requirements.txt vault_credentials.py __init__.py ./

# Install nsenter (util-linux)
RUN apt-get update && apt-get install -y util-linux

RUN pip install --no-cache-dir -r requirements.txt

CMD ["python", "app.py"]