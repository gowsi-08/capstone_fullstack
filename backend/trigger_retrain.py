#!/usr/bin/env python3
"""
Script to trigger model retraining on the production server
"""
import requests
import time

PROD_URL = "https://capstone-server-yadf.onrender.com"

print("=" * 60)
print("TRIGGERING MODEL RETRAIN")
print("=" * 60)

# Step 1: Check current training stats
print("\n1. Checking current training data...")
try:
    resp = requests.get(f"{PROD_URL}/admin/training-stats", timeout=10)
    if resp.status_code == 200:
        stats = resp.json()
        print(f"   Total records: {stats.get('total_rows', 0)}")
        print(f"   Unique locations: {stats.get('total_locations', 0)}")
        print(f"   Unique BSSIDs: {stats.get('total_bssids', 0)}")
        print("   ✅ Training data available")
    else:
        print(f"   ⚠️ Could not get stats: {resp.status_code}")
except Exception as e:
    print(f"   ❌ Error: {e}")

# Step 2: Trigger retrain
print("\n2. Triggering model retrain...")
try:
    resp = requests.post(f"{PROD_URL}/admin/retrain", timeout=30)
    print(f"   Status: {resp.status_code}")
    print(f"   Response: {resp.text}")
    if resp.status_code == 200:
        print("   ✅ Retrain triggered successfully")
        print("\n   ⏳ Waiting for retrain to complete (this may take a minute)...")
        time.sleep(5)
    else:
        print("   ❌ Retrain failed")
except Exception as e:
    print(f"   ❌ Error: {e}")

# Step 3: Test prediction after retrain
print("\n3. Testing prediction after retrain...")
sample_payload = [
    {"BSSID": "00:11:22:33:44:55", "Signal Strength dBm": -50},
    {"BSSID": "aa:bb:cc:dd:ee:ff", "Signal Strength dBm": -60},
]

try:
    resp = requests.post(
        f"{PROD_URL}/getlocation",
        json=sample_payload,
        headers={"Content-Type": "application/json"},
        timeout=10
    )
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        data = resp.json()
        if isinstance(data, list) and len(data) > 0:
            print("   ✅ Prediction working after retrain")
            print(f"   Predicted: {data[0].get('predicted')}")
        else:
            print("   ⚠️ Unexpected response format")
    else:
        print(f"   ❌ Prediction failed: {resp.text}")
except Exception as e:
    print(f"   ❌ Error: {e}")

print("\n" + "=" * 60)
print("RETRAIN COMPLETE")
print("=" * 60)
print("\nNOTE: If prediction still fails, the model may need more time to retrain.")
print("Wait 1-2 minutes and try the app again.")
