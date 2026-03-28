#!/usr/bin/env python3
"""
Quick test script to check if the backend server is running and responding
"""
import requests
import json

# Test production server
PROD_URL = "https://capstone-server-yadf.onrender.com"

print("=" * 60)
print("TESTING BACKEND SERVER CONNECTION")
print("=" * 60)

# Test 1: Health check
print("\n1. Testing health endpoint...")
try:
    resp = requests.get(f"{PROD_URL}/health", timeout=10)
    print(f"   Status: {resp.status_code}")
    print(f"   Response: {resp.text}")
    if resp.status_code == 200:
        print("   ✅ Health check passed")
    else:
        print("   ❌ Health check failed")
except Exception as e:
    print(f"   ❌ Connection failed: {e}")

# Test 2: Prediction endpoint with sample data
print("\n2. Testing /getlocation endpoint...")
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
    print(f"   Response: {resp.text}")
    if resp.status_code == 200:
        data = resp.json()
        if isinstance(data, list) and len(data) > 0:
            print("   ✅ Prediction endpoint working")
            print(f"   Predicted: {data[0].get('predicted')}")
        else:
            print("   ⚠️ Unexpected response format")
    else:
        print("   ❌ Prediction endpoint failed")
except Exception as e:
    print(f"   ❌ Connection failed: {e}")

# Test 3: Check if model is loaded
print("\n3. Checking model status...")
try:
    # Try to get training stats which will tell us if DB is connected
    resp = requests.get(f"{PROD_URL}/admin/training-stats", timeout=10)
    print(f"   Status: {resp.status_code}")
    if resp.status_code == 200:
        stats = resp.json()
        print(f"   Training records: {stats.get('total_records', 0)}")
        print("   ✅ Database connected")
    else:
        print("   ⚠️ Could not get training stats")
except Exception as e:
    print(f"   ❌ Connection failed: {e}")

print("\n" + "=" * 60)
print("TEST COMPLETE")
print("=" * 60)
