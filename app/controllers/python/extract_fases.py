import sys
import cv2
from pathlib import Path
from ultralytics import YOLO

video_id = sys.argv[1]
video_path = sys.argv[2]
output_dir = Path(f"./public/first_frame/{video_id}")
output_dir.mkdir(parents=True, exist_ok=True)

model = YOLO("yolov8n.pt")
cap = cv2.VideoCapture(video_path)

ret, frame = cap.read()
if not ret:
    print("Failed to read video")
    exit(1)

results = model.track(frame, tracker="bytetrack.yaml", classes=[0]) 

id_list = []

for box in results[0].boxes:
    cls = int(box.cls[0])
    if cls == 0:
        x1, y1, x2, y2 = map(int, box.xyxy[0])
        track_id = box.id[0] if box.id is not None else -1
        id_list.append(track_id)
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        # ID表示
        cv2.putText(frame, f"ID: {track_id}", (x1, y1 - 10),
                    cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

cv2.imwrite(str(output_dir / "full_frame_with_boxes_and_ids.jpg"), frame)

print(",".join(str(track_id) for track_id in id_list))
