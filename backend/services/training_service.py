import threading
import joblib
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from services.database import db
from datetime import datetime

MODEL_PATH = 'wifi_model.pkl'

class TrainingService:
    """Handles appending training data and retraining the ML model using MongoDB."""

    def __init__(self):
        self._lock = threading.Lock()

    def append_training_data(self, rows):
        """
        Append rows to MongoDB training_data_records collection.
        Each row is a dict with keys: ssid, location, landmark, floor, bssid,
        frequency, bandwidth, signal_strength, estimated_distance, capabilities
        Returns the number of rows appended.
        """
        if not rows:
            return 0

        with self._lock:
            records = []
            for row in rows:
                # Parse floor to integer
                floor_str = str(row.get('floor', row.get('Floor', 'ground floor'))).lower()
                if 'ground' in floor_str or 'first' in floor_str or '1' in floor_str:
                    floor_num = 1
                elif 'second' in floor_str or '2' in floor_str:
                    floor_num = 2
                elif 'third' in floor_str or '3' in floor_str:
                    floor_num = 3
                else:
                    floor_num = 1  # default
                
                # Create unique key to prevent duplicates
                signal_val = row.get('signal_strength', row.get('Signal Strength dBm', -100))
                unique_key = f"{row.get('bssid', row.get('BSSID', ''))}_{row.get('location', row.get('Location', ''))}_{floor_num}_{signal_val}"
                
                record = {
                    'ssid': row.get('ssid', row.get('SSID', '')),
                    'location': row.get('location', row.get('Location', '')),
                    'landmark': row.get('landmark', row.get('Landmark', '')),
                    'floor': floor_num,
                    'bssid': str(row.get('bssid', row.get('BSSID', ''))).strip().lower(),
                    'frequency': int(row.get('frequency', row.get('Frequency (MHz)', 0))),
                    'bandwidth': int(row.get('bandwidth', row.get('Bandwidth (MHz)', 0))),
                    'signal': int(signal_val),
                    'estimated_distance': float(row.get('estimated_distance', row.get('Estimated Distance m', 0))),
                    'capabilities': row.get('capabilities', row.get('Capabilities', '')),
                    'source': 'train',
                    'unique_key': unique_key,
                    'created_at': datetime.utcnow()
                }
                records.append(record)

            # Insert records, skip duplicates
            inserted_count = 0
            for record in records:
                try:
                    db.training_data_records.insert_one(record)
                    inserted_count += 1
                except Exception as e:
                    # Skip duplicates (unique_key constraint)
                    if 'duplicate key error' not in str(e).lower():
                        print(f"⚠️ Error inserting record: {e}")
                    continue

            return inserted_count

    def retrain_model(self):
        """
        Retrain the ML model from MongoDB and save it.
        This is run in a background thread after new data is appended.
        Returns (success, message).
        """
        try:
            print("🔄 RETRAINING: Loading training data from MongoDB...", flush=True)
            
            # Fetch all training records from MongoDB
            records = list(db.training_data_records.find({'source': 'train'}))
            
            if not records:
                return False, 'No training data found in MongoDB'

            # Convert to DataFrame
            df = pd.DataFrame(records)
            
            if df.empty or 'bssid' not in df.columns or 'location' not in df.columns:
                return False, 'Invalid training data format'

            # Normalize BSSIDs and locations
            df['bssid'] = df['bssid'].astype(str).str.strip().str.lower()
            df['location'] = df['location'].astype(str).str.strip()

            # Build the feature matrix: pivot BSSID signal strengths per location sample
            all_bssids = sorted(df['bssid'].unique())
            print(f"🔄 RETRAINING: {len(all_bssids)} unique BSSIDs, {len(df)} total rows", flush=True)

            # Group by location + landmark to create individual scan samples
            groups = []
            current_group = []
            current_loc = None

            for _, row in df.iterrows():
                loc = row['location']
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
                location = group[0]['location']

                for row in group:
                    bssid = str(row['bssid']).strip().lower()
                    try:
                        signal = int(float(row['signal']))
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
