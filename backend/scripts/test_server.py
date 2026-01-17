import requests
import json

def test_api():
    url = "https://capstone-server-yadf.onrender.com/getlocation"
    payload = [{"BSSID": "test_bssid", "Signal Strength dBm": -50}]
    try:
        response = requests.post(url, json=payload, timeout=5)
        print(f"Status: {response.status_code}")
        print(f"Response: {response.json()}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    test_api()
