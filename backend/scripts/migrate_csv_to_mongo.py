"""
Migration script to move train.csv and test.csv data into MongoDB
Run this once to migrate existing CSV data to the database
"""
import sys
import os
from datetime import datetime
import pandas as pd
from pymongo import MongoClient, ASCENDING
from dotenv import load_dotenv

# Add parent directory to path to import config
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import Config

load_dotenv()

def migrate_csv_to_mongo():
    """Migrate train.csv and test.csv to MongoDB training_data_records collection"""
    
    print("🚀 Starting CSV to MongoDB migration...")
    
    # Connect to MongoDB
    try:
        client = MongoClient(Config.MONGO_URL)
        db = client[Config.DB_NAME]
        collection = db['training_data_records']
        print(f"✅ Connected to MongoDB: {Config.DB_NAME}")
    except Exception as e:
        print(f"❌ Failed to connect to MongoDB: {e}")
        return
    
    # Create indexes for better query performance
    collection.create_index([('location', ASCENDING), ('floor', ASCENDING)])
    collection.create_index([('bssid', ASCENDING)])
    collection.create_index([('source', ASCENDING)])
    collection.create_index([('created_at', ASCENDING)])
    print("✅ Created indexes")
    
    total_inserted = 0
    total_skipped = 0
    stats = {
        'train': {'count': 0, 'locations': set(), 'floors': set()},
        'test': {'count': 0, 'locations': set(), 'floors': set()}
    }
    
    # Migrate train.csv
    train_path = 'train.csv'
    if os.path.exists(train_path):
        print(f"\n📂 Processing {train_path}...")
        try:
            df = pd.read_csv(train_path)
            records = []
            
            for _, row in df.iterrows():
                # Parse floor number from floor string
                floor_str = str(row.get('Floor', 'ground floor')).lower()
                if 'ground' in floor_str or 'first' in floor_str or '1' in floor_str:
                    floor_num = 1
                elif 'second' in floor_str or '2' in floor_str:
                    floor_num = 2
                elif 'third' in floor_str or '3' in floor_str:
                    floor_num = 3
                else:
                    floor_num = 1  # default
                
                location = str(row.get('Location', 'Unknown')).strip()
                bssid = str(row.get('BSSID', '')).strip().lower()
                
                # Create unique identifier to avoid duplicates
                unique_key = f"{bssid}_{location}_{floor_num}_{row.get('Signal Strength dBm', 0)}"
                
                record = {
                    'ssid': str(row.get('SSID', '')).strip(),
                    'bssid': bssid,
                    'signal_strength': int(row.get('Signal Strength dBm', -100)),
                    'location': location,
                    'landmark': str(row.get('Landmark', '')).strip(),
                    'floor': floor_num,
                    'frequency': int(row.get('Frequency (MHz)', 0)),
                    'bandwidth': int(row.get('Bandwidth (MHz)', 20)),
                    'estimated_distance': float(row.get('Estimated Distance m', 0)),
                    'capabilities': str(row.get('Capabilities', '')).strip(),
                    'source': 'train',
                    'unique_key': unique_key,
                    'collected_at': datetime.utcnow(),
                    'created_at': datetime.utcnow()
                }
                
                records.append(record)
                stats['train']['locations'].add(location)
                stats['train']['floors'].add(floor_num)
            
            # Bulk insert with duplicate handling
            if records:
                try:
                    # Try to insert, skip duplicates based on unique_key
                    for record in records:
                        try:
                            existing = collection.find_one({'unique_key': record['unique_key']})
                            if not existing:
                                collection.insert_one(record)
                                total_inserted += 1
                                stats['train']['count'] += 1
                            else:
                                total_skipped += 1
                        except Exception as e:
                            print(f"⚠️  Skipped duplicate: {e}")
                            total_skipped += 1
                    
                    print(f"✅ Processed {len(records)} records from train.csv")
                except Exception as e:
                    print(f"❌ Error inserting train records: {e}")
        except Exception as e:
            print(f"❌ Error reading train.csv: {e}")
    else:
        print(f"⚠️  {train_path} not found")
    
    # Migrate test.csv
    test_path = 'test.csv'
    if os.path.exists(test_path):
        print(f"\n📂 Processing {test_path}...")
        try:
            df = pd.read_csv(test_path)
            records = []
            
            for _, row in df.iterrows():
                # Parse floor number
                floor_str = str(row.get('Floor', 'ground floor')).lower()
                if 'ground' in floor_str or 'first' in floor_str or '1' in floor_str:
                    floor_num = 1
                elif 'second' in floor_str or '2' in floor_str:
                    floor_num = 2
                elif 'third' in floor_str or '3' in floor_str:
                    floor_num = 3
                else:
                    floor_num = 1
                
                location = str(row.get('Location', 'Unknown')).strip()
                bssid = str(row.get('BSSID', '')).strip().lower()
                
                unique_key = f"{bssid}_{location}_{floor_num}_{row.get('Signal Strength dBm', 0)}"
                
                record = {
                    'ssid': str(row.get('SSID', '')).strip(),
                    'bssid': bssid,
                    'signal_strength': int(row.get('Signal Strength dBm', -100)),
                    'location': location,
                    'landmark': str(row.get('Landmark', '')).strip(),
                    'floor': floor_num,
                    'frequency': int(row.get('Frequency (MHz)', 0)),
                    'bandwidth': int(row.get('Bandwidth (MHz)', 20)),
                    'estimated_distance': float(row.get('Estimated Distance m', 0)),
                    'capabilities': str(row.get('Capabilities', '')).strip(),
                    'source': 'test',
                    'unique_key': unique_key,
                    'collected_at': datetime.utcnow(),
                    'created_at': datetime.utcnow()
                }
                
                records.append(record)
                stats['test']['locations'].add(location)
                stats['test']['floors'].add(floor_num)
            
            if records:
                try:
                    for record in records:
                        try:
                            existing = collection.find_one({'unique_key': record['unique_key']})
                            if not existing:
                                collection.insert_one(record)
                                total_inserted += 1
                                stats['test']['count'] += 1
                            else:
                                total_skipped += 1
                        except Exception as e:
                            total_skipped += 1
                    
                    print(f"✅ Processed {len(records)} records from test.csv")
                except Exception as e:
                    print(f"❌ Error inserting test records: {e}")
        except Exception as e:
            print(f"❌ Error reading test.csv: {e}")
    else:
        print(f"⚠️  {test_path} not found")
    
    # Print summary
    print("\n" + "="*60)
    print("📊 MIGRATION SUMMARY")
    print("="*60)
    print(f"✅ Total records inserted: {total_inserted}")
    print(f"⏭️  Total records skipped (duplicates): {total_skipped}")
    print(f"\n📈 Train Data:")
    print(f"   - Records: {stats['train']['count']}")
    print(f"   - Unique locations: {len(stats['train']['locations'])}")
    print(f"   - Floors: {sorted(stats['train']['floors'])}")
    print(f"\n📈 Test Data:")
    print(f"   - Records: {stats['test']['count']}")
    print(f"   - Unique locations: {len(stats['test']['locations'])}")
    print(f"   - Floors: {sorted(stats['test']['floors'])}")
    
    # Per-location breakdown
    print(f"\n📍 Records per location:")
    pipeline = [
        {'$group': {
            '_id': {'location': '$location', 'floor': '$floor'},
            'count': {'$sum': 1}
        }},
        {'$sort': {'_id.floor': 1, '_id.location': 1}}
    ]
    location_counts = list(collection.aggregate(pipeline))
    for item in location_counts:
        loc = item['_id']['location']
        floor = item['_id']['floor']
        count = item['count']
        print(f"   Floor {floor} - {loc}: {count} records")
    
    print("\n✅ Migration completed successfully!")
    client.close()

if __name__ == '__main__':
    migrate_csv_to_mongo()
