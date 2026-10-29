#!/bin/sh
# Entrypoint du conteneur MinIO.
#
#   1. démarrer le serveur MinIO en arrière-plan
#   2. attendre que son API S3 réponde (lancer un processus ne veut pas dire qu'il est prêt)
#   3. créer les buckets utilisés par DVC et MLflow (idempotent : sans risque à chaque redémarrage)
#   4. écrire un fichier-témoin, que docker-compose utilise comme health check :
#      « healthy » signifie donc « serveur up ET buckets créés »
#   5. rester attaché au processus serveur, pour que le conteneur vive aussi longtemps que MinIO
#
# Les identifiants viennent de MINIO_ROOT_USER / MINIO_ROOT_PASSWORD (définis dans docker-compose.yaml).
set -eu

DATA_DIR="${MINIO_DATA_DIR:-/data}"
API_URL="http://127.0.0.1:9000"
# Les noms sont imposés par les tests : dvc-storage (remote DVC), mlflow-artifacts (stockage d'artefacts MLflow)
BUCKETS="${MINIO_BUCKETS:-dvc-storage mlflow-artifacts}"
READY_FLAG="${MINIO_READY_FLAG:-/tmp/.minio-init-done}"
MAX_WAIT_SECONDS=60

rm -f "$READY_FLAG"

minio server "$DATA_DIR" --console-address ":9001" &
SERVER_PID=$!

# `docker stop` envoie SIGTERM au PID 1, donc à ce script : on le relaie à MinIO pour un arrêt propre.
trap 'kill -TERM "$SERVER_PID" 2>/dev/null || true; wait "$SERVER_PID" || true; exit 0' TERM INT

echo "[init_minio] waiting for the MinIO API on ${API_URL} ..."
waited=0
until curl -fsS "${API_URL}/minio/health/ready" >/dev/null 2>&1; do
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        echo "[init_minio] ERROR: the MinIO server exited during startup" >&2
        exit 1
    fi
    waited=$((waited + 1))
    if [ "$waited" -ge "$MAX_WAIT_SECONDS" ]; then
        echo "[init_minio] ERROR: MinIO not ready after ${MAX_WAIT_SECONDS}s" >&2
        kill -TERM "$SERVER_PID" 2>/dev/null || true
        exit 1
    fi
    sleep 1
done

mc alias set local "$API_URL" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null

for bucket in $BUCKETS; do
    # --ignore-existing : pas d'erreur si le bucket existe déjà (volume persistant, redémarrage)
    mc mb --ignore-existing "local/${bucket}"
done

touch "$READY_FLAG"
echo "[init_minio] ready - buckets: ${BUCKETS}"

# Bloquer sur le serveur ; le code de sortie du conteneur est celui de MinIO.
wait "$SERVER_PID"