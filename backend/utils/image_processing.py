import cv2
import numpy as np
import io
from PIL import Image

def process_map_image(file_bytes, floor):
    nparr = np.frombuffer(file_bytes, np.uint8)
    img_cv = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

    if img_cv is None:
        return None, None, []

    # Optimize: Resize if too huge
    height, width = img_cv.shape[:2]
    max_dim = 2000
    if max(height, width) > max_dim:
        scale = max_dim / max(height, width)
        width = int(width * scale)
        height = int(height * scale)
        img_cv = cv2.resize(img_cv, (width, height), interpolation=cv2.INTER_AREA)

    # Analyze: Detect Contours (Rooms)
    gray = cv2.cvtColor(img_cv, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 200, 255, cv2.THRESH_BINARY_INV) 
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    new_locations = []
    room_count = 1
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if area > 500: 
            M = cv2.moments(cnt)
            if M["m00"] != 0:
                cX = int(M["m10"] / M["m00"])
                cY = int(M["m01"] / M["m00"])
                new_locations.append({
                    'id': f"{floor}_{room_count}",
                    'name': f"Room {room_count}",
                    'x': cX,
                    'y': cY,
                    'floor': floor
                })
                room_count += 1

    # Save Optimized Image
    img_rgb = cv2.cvtColor(img_cv, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(img_rgb)
    output_io = io.BytesIO()
    pil_img.save(output_io, format='WEBP', quality=80)
    output_io.seek(0)
    
    return output_io, (width, height), new_locations
