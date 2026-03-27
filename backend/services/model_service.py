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
            
            # Load the trained model
            if os.path.exists(model_path):
                self.model = joblib.load(model_path)
                print("✅ Model loaded successfully")
            else:
                print("⚠️ Model file not found")
            
            # Load BSSIDs from MongoDB instead of CSV
            try:
                records = list(db.training_data_records.find({'source': 'train'}, {'bssid': 1}))
                if records:
                    bssids = [str(record['bssid']).strip().lower() for record in records if 'bssid' in record]
                    self.all_bssids = sorted(set(bssids))
                    print(f"✅ Loaded {len(self.all_bssids)} unique BSSIDs from MongoDB")
                else:
                    print("⚠️ No training data found in MongoDB")
            except Exception as e:
                print(f"⚠️ Could not load BSSIDs from MongoDB: {e}")
                # Fallback to CSV if MongoDB fails
                train_path = "train.csv"
                if os.path.exists(train_path):
                    df_train = pd.read_csv(train_path)
                    df_train['BSSID'] = df_train['BSSID'].astype(str).str.strip().str.lower()
                    self.all_bssids = sorted(df_train['BSSID'].unique())
                    print(f"✅ Loaded {len(self.all_bssids)} unique BSSIDs from CSV (fallback)")
            
        except Exception as e:
            print(f"⚠️ Could not load model or training data: {e}")

    def predict(self, bssid_to_signal):
        if self.model is None or not self.all_bssids:
            return None
        
        feature_vector = [bssid_to_signal.get(bssid, -100) for bssid in self.all_bssids]
        prediction = self.model.predict([feature_vector])[0]
        return str(prediction)

model_service = ModelService()
