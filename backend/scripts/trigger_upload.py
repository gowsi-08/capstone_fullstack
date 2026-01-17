import requests
import os

url = 'https://capstone-server-yadf.onrender.com/admin/upload_map/1'
file_path = '../floor1.png'

if os.path.exists(file_path):
    print(f"Uploading {file_path} to {url}...")
    with open(file_path, 'rb') as f:
        files = {'file': f}
        try:
            r = requests.post(url, files=files)
            print(f"Status Code: {r.status_code}")
            print(f"Response: {r.text}")
        except Exception as e:
            print(f"Failed to upload: {e}")
else:
    print(f"File {file_path} not found.")
