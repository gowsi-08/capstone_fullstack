import csv
import os
import threading
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.preprocessing import LabelEncoder

TRAIN_CSV = 'train.csv'
MODEL_PATH = 'wifi_model.pkl'

class TrainingService:
    """Handles appending training data and retraining the ML model."""

    def __init__(self):
        self._lock = threading.Lock()

    def append_training_data(self, rows):
        """
        Append rows to train.csv.
        Each row is a dict with keys: SSID, Location, Landmark, Floor, BSSID,
        Frequency (MHz), Bandwidth (MHz), Signal Strength dBm,
        Estimated Distance m, Capabilities
        Returns the number of rows appended.
        """
        if not rows:
            return 0

        fieldnames = [
            'SSID', 'Location', 'Landmark', 'Floor', 'BSSID',
            'Frequency (MHz)', 'Bandwidth (MHz)', 'Signal Strength dBm',
            'Estimated Distance m', 'Capabilities'
        ]

        with self._lock:
            file_exists = os.path.exists(TRAIN_CSV) and os.path.getsize(TRAIN_CSV) > 0

            with open(TRAIN_CSV, 'a', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=fieldnames)

                if not file_exists:
                    writer.writeheader()

                count = 0
                for row in rows:
                    clean_row = {}
                    for key in fieldnames:
                        clean_row[key] = row.get(key, '')
                    writer.writerow(clean_row)
                    count += 1

            return count

    def retrain_model(self):
        """
        Retrain the ML model from train.csv and save it.
        This is run in a background thread after new data is appended.
        Returns (success, message).
        """
        try:
            if not os.path.exists(TRAIN_CSV):
                return False, 'train.csv not found'

            print("🔄 RETRAINING: Loading training data...", flush=True)
            df = pd.read_csv(TRAIN_CSV)

            if df.empty or 'BSSID' not in df.columns or 'Location' not in df.columns:
                return False, 'Invalid training data format'

            # Normalize BSSIDs
            df['BSSID'] = df['BSSID'].astype(str).str.strip().str.lower()
            df['Location'] = df['Location'].astype(str).str.strip()

            # Build the feature matrix: pivot BSSID signal strengths per location sample
            # Group rows by (Location, Landmark, Floor) to form samples
            # Each unique BSSID becomes a feature column

            all_bssids = sorted(df['BSSID'].unique())
            print(f"🔄 RETRAINING: {len(all_bssids)} unique BSSIDs, {len(df)} total rows", flush=True)

            # Group by location + landmark to create individual scan samples
            # Each group of consecutive rows with same Location is one scan
            groups = []
            current_group = []
            current_loc = None

            for _, row in df.iterrows():
                loc = row['Location']
                if loc != current_loc:
                    if current_group:
                        groups.append(current_group)
                    current_group = [row]
                    current_loc = loc
                else:
                    current_group.append(row)

            if current_group:
                groups.append(current_group)

            # Build feature vectors
            X = []
            y = []

            for group in groups:
                bssid_to_signal = {}
                location = group[0]['Location']

                for row in group:
                    bssid = str(row['BSSID']).strip().lower()
                    try:
                        signal = int(float(row['Signal Strength dBm']))
                    except (ValueError, TypeError):
                        signal = -100
                    bssid_to_signal[bssid] = signal

                feature_vector = [bssid_to_signal.get(b, -100) for b in all_bssids]
                X.append(feature_vector)
                y.append(location)

            if len(X) < 2:
                return False, 'Not enough training samples'

            print(f"🔄 RETRAINING: Training with {len(X)} samples, {len(all_bssids)} features...", flush=True)

            # Train RandomForest
            clf = RandomForestClassifier(n_estimators=100, random_state=42, n_jobs=-1)
            clf.fit(X, y)

            # Save model
            joblib.dump(clf, MODEL_PATH)
            print(f"✅ RETRAINING COMPLETE: Model saved to {MODEL_PATH}", flush=True)

            return True, f'Model retrained with {len(X)} samples and {len(all_bssids)} BSSIDs'

        except Exception as e:
            print(f"❌ RETRAINING ERROR: {e}", flush=True)
            return False, str(e)

    def retrain_async(self):
        """Start retraining in a background thread."""
        thread = threading.Thread(target=self._retrain_and_reload, daemon=True)
        thread.start()
        return True

    def _retrain_and_reload(self):
        """Retrain and then reload the model in model_service."""
        success, msg = self.retrain_model()
        if success:
            # Reload the model in the model service
            try:
                from services.model_service import model_service
                model_service.load_model()
                print("✅ Model reloaded in model_service after retraining", flush=True)
            except Exception as e:
                print(f"⚠️ Model retrained but failed to reload: {e}", flush=True)

training_service = TrainingService()
