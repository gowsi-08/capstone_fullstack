import joblib
import pandas as pd
import os
from services.database import db

class ModelService:
    def __init__(self):
        self.model = None
        self.all_bssids = []
        self.load_model()

    def load_model(self):
        try:
            model_path = "wifi_model.pkl"

            if os.path.exists(model_path):
                self.model = joblib.load(model_path)

            train_data = list(db.wifi_training_data.find({}, {'_id': 0, 'BSSID': 1}))
            if train_data:
                df_train = pd.DataFrame(train_data)
                df_train['BSSID'] = df_train['BSSID'].astype(str).str.strip().str.lower()
                self.all_bssids = sorted(df_train['BSSID'].unique())
            
            print("✅ Model and training BSSIDs loaded successfully")
        except Exception as e:
            print(f"⚠️ Could not load model or training data: {e}")

    def predict(self, bssid_to_signal):
        if self.model is None or not self.all_bssids:
            return None
        
        feature_vector = [bssid_to_signal.get(bssid, -100) for bssid in self.all_bssids]
        prediction = self.model.predict([feature_vector])[0]
        return str(prediction)

model_service = ModelService()
