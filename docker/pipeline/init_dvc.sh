#!/bin/sh
# Commande de démarrage du conteneur pipeline :
#   1. initialiser le projet DVC et pointer son remote vers le bucket MinIO
#   2. exécuter le pipeline existant (dvc.yaml) : ingestion -> validation -> transformation -> entraînement -> évaluation
#   3. pousser les fichiers suivis par DVC vers MinIO
#
# Environnement attendu (défini dans docker-compose.yaml) :
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY  identifiants lus par la couche S3 de DVC (= utilisateur/mot de passe root de MinIO)
#   MINIO_ENDPOINT_URL                         endpoint S3 dans le réseau compose, p. ex. http://minio:9000
#   MLFLOW_TRACKING_URI, MLFLOW_S3_ENDPOINT_URL utilisés par les étapes d'entraînement/évaluation (client MLflow)
set -eu

cd "${PROJECT_DIR:-/app}"

DVC_BUCKET="${MINIO_DVC_BUCKET:-dvc-storage}"
: "${MINIO_ENDPOINT_URL:?MINIO_ENDPOINT_URL must be set}"

# --no-scm : pas de Git dans le conteneur. Le dépôt monté est un dépôt Git dont les
#   fichiers de données sont suivis par Git, ce que DVC refuserait de gérer aussi comme sorties ;
#   cela évite aussi les erreurs « dubious ownership » sur un .git monté en bind-mount.
# -f : le dépôt contient déjà un dossier .dvc/ (config vide) ; on le (re)crée proprement.
dvc init --no-scm -f

# L'URL du remote doit être la RACINE du bucket : DVC 3 range alors les objets sous files/md5/<xx>/<hash>,
# l'arborescence que cherchent les tests. Les identifiants ne sont PAS écrits dans .dvc/config (il est versionné) :
# ils viennent des variables d'environnement AWS_*.
dvc remote add -f -d minio "s3://${DVC_BUCKET}"
dvc remote modify minio endpointurl "${MINIO_ENDPOINT_URL}"

# --force : l'état du serveur MLflow est hors du graphe de dépendances de DVC. Mesuré : après
# `make clean` (volumes effacés) avec l'état DVC du dépôt conservé, un `dvc repro` simple saute model_trainer
# (entrées inchangées, aucune sortie déclarée), donc l'expérience « Wine Quality Prediction » n'est jamais
# recréée dans le serveur MLflow neuf - et les 4 tests officiels passent quand même, ils ne peuvent pas le voir.
dvc repro --force

dvc push
dvc status --cloud