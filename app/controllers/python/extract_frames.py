import sys
import cv2
import tempfile
from pathlib import Path
from ultralytics import YOLO

video_id = sys.argv[1]
video_path = sys.argv[2]

model = YOLO("yolov8n.pt")
cap = cv2.VideoCapture(video_path)

ret, frame = cap.read()
if not ret:
    print("Failed to read first frame", file=sys.stderr)
    exit(1)

results = model(frame, classes=[0], verbose=False)

id_list = []
if results and results[0].boxes is not None:
    for j, box in enumerate(results[0].boxes):
        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        if class_id == 0 and confidence > 0.5:
            id_list.append(j + 1)
            x1, y1, x2, y2 = map(int, box.xyxy[0])
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
            cv2.putText(frame, f"Person {j + 1}", (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)

# 一時ファイルに画像を保存
with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp_file:
    cv2.imwrite(tmp_file.name, frame)
    thumbnail_path = tmp_file.name

print("First frame persons:", len(id_list), file=sys.stderr)

# IDリスト出力
print(",".join(str(person_id) for person_id in id_list))
# サムネイルパス出力
print(f"THUMBNAIL_PATH:{thumbnail_path}")
