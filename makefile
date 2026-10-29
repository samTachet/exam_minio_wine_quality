# Docker Compose v2 s'appelle `docker compose` ; la v1 est le binaire autonome `docker-compose`. On utilise celui qui existe.
COMPOSE := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

.PHONY: build up pipeline tests tests-only all down clean

# Construire les images des trois services (MinIO, MLflow, pipeline DVC)
build:
	$(COMPOSE) build minio mlflow pipeline

# Démarrer MinIO (buckets créés) et MLflow en arrière-plan, une fois « healthy »
up:
	$(COMPOSE) up -d --build minio mlflow

# Exécuter toute la chaîne : démarrer MinIO + MLflow si besoin (depends_on attend leurs health checks),
# puis dvc repro (entraînement journalisé dans MLflow) et dvc push (vers MinIO)
pipeline: build
	$(COMPOSE) run --rm pipeline

# Les 4 tests pytest. Ils inspectent seulement ce que MinIO et MLflow contiennent déjà (d'où --no-deps),
# donc la stack et le pipeline doivent avoir tourné avant : `pipeline` est un prérequis, ce qui fait
# fonctionner `make tests` depuis un démarrage à froid. `make tests-only` rejoue les tests sans relancer le pipeline.
tests: pipeline
	$(COMPOSE) up --no-deps tests

tests-only:
	$(COMPOSE) up --no-deps tests

# Tout, dans l'ordre
all: tests

# Arrêter et supprimer les conteneurs (les volumes, donc les données MinIO et MLflow, sont conservés)
down:
	$(COMPOSE) down --remove-orphans

# Arrêter et supprimer les conteneurs ET les volumes : les objets MinIO et la base MLflow sont effacés
clean:
	$(COMPOSE) down -v --remove-orphans