import os
import joblib
import mlflow
import mlflow.sklearn
from mlflow.models import infer_signature
import numpy as np
import pandas as pd

from sklearn.linear_model import ElasticNet
from pipeline.entity import ModelTrainerConfig
from sklearn.metrics import mean_squared_error, mean_absolute_error, r2_score

class ModelTrainer:
    def __init__(self, config: ModelTrainerConfig):
        self.config = config
        mlflow_tracking_uri = os.getenv("MLFLOW_TRACKING_URI", "http://mlflow:5000")
        mlflow.set_tracking_uri(mlflow_tracking_uri)
        mlflow.set_experiment("Wine Quality Prediction")
    
    def eval_metrics(self, actual, pred):
        rmse = np.sqrt(mean_squared_error(actual, pred))
        mae = mean_absolute_error(actual, pred)
        r2 = r2_score(actual, pred)
        return rmse, mae, r2

    def train(self):
        X_train = pd.read_csv(self.config.X_train_path)
        y_train = pd.read_csv(self.config.y_train_path)
        X_test = pd.read_csv(self.config.X_test_path)
        y_test = pd.read_csv(self.config.y_test_path)

        with mlflow.start_run():
            # Journaliser les paramètres du modèle
            mlflow.log_param("alpha", self.config.alpha)
            mlflow.log_param("l1_ratio", self.config.l1_ratio)

            lr = ElasticNet(alpha = self.config.alpha, l1_ratio = self.config.l1_ratio, random_state=42)
            lr.fit(X_train, y_train)

            (rmse, mae, r2) = self.eval_metrics(y_test, lr.predict(X_test))

            # Suivre les métriques et le modèle avec mlflow
            mlflow.log_metric("rmse", rmse)
            mlflow.log_metric("mae", mae)
            mlflow.log_metric("r2", r2)

            # La signature enregistre le schéma d'entrée/sortie attendu avec l'artefact du modèle
            signature = infer_signature(X_train, lr.predict(X_train))
            mlflow.sklearn.log_model(lr, "model", signature=signature)

            joblib.dump(lr, os.path.join(self.config.root_dir, self.config.model_name))