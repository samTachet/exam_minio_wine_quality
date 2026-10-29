# Conteneur du pipeline DVC : exécute `dvc repro` puis `dvc push` vers MinIO (voir init_dvc.sh).
# Le projet n'est PAS copié dans l'image : docker-compose monte le dépôt sur /app (bind-mount),
# donc le pipeline lit les sources courantes et réécrit data/, models/, metrics/, dvc.lock dans le dépôt.
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DVC_NO_ANALYTICS=1

WORKDIR /app

COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# Garde-fou CRLF : un script extrait avec des fins de ligne Windows ne démarrerait pas.
COPY init_dvc.sh /tmp/init_dvc.sh
RUN sed 's/\r$//' /tmp/init_dvc.sh > /usr/local/bin/init_dvc.sh \
    && chmod +x /usr/local/bin/init_dvc.sh \
    && rm /tmp/init_dvc.sh

CMD ["/usr/local/bin/init_dvc.sh"]