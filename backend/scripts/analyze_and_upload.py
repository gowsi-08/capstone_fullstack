import cv2
import numpy as np
from pymongo import MongoClient
import gridfs
import os
from bson import ObjectId

# --- Setup ---
mongo_url = "mongodb+srv://gowsalyaanantharaj:gowsimongodb@cluster1.zh9gr.mongodb.net/?retryWrites=true&w=majority&appName=Cluster1"
client = MongoClient(mongo_url)
db = client['findmyway']
fs = gridfs.GridFS(db)

FLOOR = "1"
IMAGE_PATH = "../floor1.png"

def upload_map():
    if not os.path.exists(IMAGE_PATH):
        print(f"❌ {IMAGE_PATH} not found")
        return False
    
    print(f"Uploading {IMAGE_PATH}...")
    with open(IMAGE_PATH, 'rb') as f:
        # Remove old map
        db.maps.delete_many({'floor': FLOOR})
        # Upload new
        file_id = fs.put(f, filename=f'map_{FLOOR}.png')
        db.maps.insert_one({'floor': FLOOR, 'file_id': file_id})
    print("✅ Map uploaded successfully.")
    return True

def analyze_rooms():
    print("Analyzing rooms...")
    img = cv2.imread(IMAGE_PATH)
    if img is None:
        print("❌ Could not read image for analysis.")
        return

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Thresholding to get black rooms on white background or vice versa.
    # Assuming map is white background with black lines.
    # Invert so lines are white, background is black for contour detection
    _, thresh = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)
    
    # Find contours
    contours, hierarchy = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Filter and create locations
    locations = []
    
    # Clear existing locations for this floor
    db.locations.delete_many({'floor': FLOOR})
    
    room_count = 1
    
    # Sort contours by area (largest first) to maybe capture main rooms
    contours = sorted(contours, key=cv2.contourArea, reverse=True)
    
    for cnt in contours:
        area = cv2.contourArea(cnt)
        # Filter small noise. Adjust threshold as needed based on image resolution.
        if area > 1000: 
            # Get bounding box
            x, y, w, h = cv2.boundingRect(cnt)
            
            # Get centroid
            M = cv2.moments(cnt)
            if M["m00"] != 0:
                cX = int(M["m10"] / M["m00"])
                cY = int(M["m01"] / M["m00"])
            else:
                cX, cY = x + w//2, y + h//2
            
            # Simple assumption: A large contour is a room
            loc_name = f"Room {room_count}"
            
            location = {
                'floor': FLOOR,
                'name': loc_name,
                'x': float(cX),
                'y': float(cY)
            }
            
            db.locations.insert_one(location)
            print(f"  Found {loc_name} at ({cX}, {cY}) - Area: {area}")
            
            # Prepare for next
            room_count += 1
            
            # Optional: Visualize (for debug, not saving)
            # cv2.drawContours(img, [cnt], -1, (0, 255, 0), 2)
            # cv2.circle(img, (cX, cY), 7, (255, 0, 0), -1)

    print(f"✅ Analysis complete. {room_count - 1} rooms identified and saved to DB.")

if __name__ == "__main__":
    if upload_map():
        analyze_rooms()
