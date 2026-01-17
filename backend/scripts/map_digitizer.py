import cv2
import numpy as np
import json
import sys

def digitize_map(image_path):
    img = cv2.imread(image_path)
    if img is None:
        print(f"Error: Could not read {image_path}")
        return None

    # Resize for consistent processing
    target_width = 1000
    h, w = img.shape[:2]
    scale = target_width / w
    img_resized = cv2.resize(img, (target_width, int(h * scale)))
    
    gray = cv2.cvtColor(img_resized, cv2.COLOR_BGR2GRAY)
    
    # 1. Detect Walls (Lines)
    edges = cv2.Canny(gray, 50, 150, apertureSize=3)
    lines = cv2.HoughLinesP(edges, 1, np.pi/180, threshold=50, minLineLength=30, maxLineGap=10)
    
    walls = []
    if lines is not None:
        for line in lines:
            x1, y1, x2, y2 = line[0]
            walls.append({
                'x1': float(x1) / scale, 
                'y1': float(y1) / scale, 
                'x2': float(x2) / scale, 
                'y2': float(y2) / scale
            })

    # 2. Detect Rooms (Contours/Rectangles)
    # Thresholding
    _, thresh = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    rooms = []
    idx = 1
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area > 1000: # Filter small noise
            x, y, w, h = cv2.boundingRect(cnt)
            rooms.append({
                'id': idx,
                'name': f"Room {idx}",
                'rect': {
                    'x': float(x) / scale, 
                    'y': float(y) / scale, 
                    'w': float(w) / scale, 
                    'h': float(h) / scale
                }
            })
            idx += 1

    structure = {
        'width': w,
        'height': h,
        'walls': walls,
        'rooms': rooms
    }
    
    return structure

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python map_digitizer.py <image_path> <output_json>")
        sys.exit(1)
        
    img_path = sys.argv[1]
    output_path = sys.argv[2]
    
    data = digitize_map(img_path)
    if data:
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        print(f"Map structure saved to {output_path}")
