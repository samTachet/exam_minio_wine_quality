# Serveur de tracking MLflow (backend : fichier SQLite, artefacts : bucket MinIO).
# La vraie commande du serveur, le backend store et la racine des artefacts sont définis dans docker-compose.yaml.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install -r requirements.txt

EXPOSE 5000

# Commande par défaut seulement ; docker-compose la remplace par la ligne complète `mlflow server ...`.
CMD ["mlflow", "server", "--host", "0.0.0.0", "--port", "5000"]