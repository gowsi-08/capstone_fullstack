import pandas as pd
import os
from services.database import db

def migrate():
    if os.path.exists('train.csv'):
        try:
            df_train = pd.read_csv('train.csv')
            train_data = df_train.to_dict('records')
            if train_data:
                db.wifi_training_data.drop()
                db.wifi_training_data.insert_many(train_data)
                print(f"Inserted {len(train_data)} records to wifi_training_data")
        except Exception as e:
            print(f"Error migrating train.csv: {e}")
    else:
        print("train.csv not found")

    if os.path.exists('test.csv'):
        try:
            df_test = pd.read_csv('test.csv')
            test_data = df_test.to_dict('records')
            if test_data:
                db.wifi_test_data.drop()
                db.wifi_test_data.insert_many(test_data)
                print(f"Inserted {len(test_data)} records to wifi_test_data")
        except Exception as e:
            print(f"Error migrating test.csv: {e}")
    else:
        print("test.csv not found")

if __name__ == '__main__':
    migrate()
