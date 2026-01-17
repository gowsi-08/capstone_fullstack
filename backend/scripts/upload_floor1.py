from pymongo import MongoClient
import gridfs
import os

mongo_url = "mongodb+srv://gowsalyaanantharaj:gowsimongodb@cluster1.zh9gr.mongodb.net/?retryWrites=true&w=majority&appName=Cluster1"
client = MongoClient(mongo_url)
db = client['findmyway']
fs = gridfs.GridFS(db)

floor = "1"
image_path = "../floor1.png"

if os.path.exists(image_path):
    with open(image_path, 'rb') as f:
        # Remove old map for this floor
        db.maps.delete_many({'floor': floor})
        # Save image to GridFS
        file_id = fs.put(f, filename=f'map_{floor}.png')
        db.maps.insert_one({'floor': floor, 'file_id': file_id})
        print(f"✅ Uploaded {image_path} to floor {floor}")
else:
    print(f"❌ {image_path} not found")
