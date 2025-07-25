import sys
import cv2
from pathlib import Path
from ultralytics import YOLO

video_id = sys.argv[1]
video_path = sys.argv[2]
output_dir = Path(f"./public/face_thumbs/{video_id}")
output_dir.mkdir(parents=True, exist_ok=True)

model = YOLO("yolov8n.pt")
cap = cv2.VideoCapture(video_path)

ret, frame = cap.read()
if not ret:
    print("Failed to read video")
    exit(1)

results = model(frame)
for i, box in enumerate(results[0].boxes.xyxy):
    x1, y1, x2, y2 = map(int, box)
    face = frame[y1:y2, x1:x2]
    cv2.imwrite(str(output_dir / f"person_{i}.jpg"), face)
