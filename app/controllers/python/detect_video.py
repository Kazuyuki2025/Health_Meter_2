import cv2
from ultralytics import YOLO
import numpy as np
import argparse
import csv
import datetime
from argparse import RawTextHelpFormatter
import math
import json


COLOR = (0, 255, 0)
VAR_THICKNESS = 20
FONT_SCALE = 2.0
TEXT_THICKNESS = 2
FINISH_COMMAND = "q"
OUTLIER = 1000

# set now_time
dt_now = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
# set deta_type
tp = lambda x: list(map(int, x.split(',')))

# Format argument
parser = argparse.ArgumentParser(formatter_class=RawTextHelpFormatter)
parser.add_argument('--type', help='Set demo_type', default=1)
parser.add_argument('--limit', help='Set number of detected people', default=100000)
parser.add_argument('--fps', help='Set FPS', default=20)
parser.add_argument('--model', help='Set model_data', default='model/yolov8n.pt')
parser.add_argument('--framesize', type=tp, help='Set width and height of framesize', default='1920,1080')
parser.add_argument('--start', help='Set start of frame', type=int, default=2)
parser.add_argument('--end', help='Set end of frame', type=int, default=0)
parser.add_argument('input', help='Input video data', default=f'input_data/{dt_now}.mp4')

parser.usage = parser.format_help()

# Set argument
args = parser.parse_args()
fps = args.fps
frame_width = args.framesize[0]
frame_height = args.framesize[1]
detect_limit = args.limit
detect_type = int(args.type)
input_file = args.input
model_data = args.model
start_frame = args.start
end_frame = args.end
validation = OUTLIER

# Load learning model
model = YOLO(model_data)

cap = cv2.VideoCapture(input_file)

totalframe = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
if end_frame == 0:
    end_frame = totalframe
if end_frame > totalframe:
    print("Error: end_frame is over totalframe")
    exit()
if start_frame < 2:
    print("Error: start_frame is over 2")
    exit()

cap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)
frame_width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
frame_height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

print("---start---")

# Initialize detected_data array
coordinate = np.array(np.zeros((4, detect_limit), dtype=int)).T.tolist()
velocity = np.array(np.zeros((4, detect_limit), dtype=int)).T.tolist()
pre_velocity = np.array(np.zeros((4, detect_limit), dtype=int)).T.tolist()
activity_average = np.zeros(detect_limit, dtype=int)

# Analysis results storage
analysis_results = {}
# Track baseline IDs from the first 10 frames
baseline_ids = set()

# Store coordinates of the previous frame
previous_coordinates = {}

frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

frame_baseline_limit = 10
frame_skip = 1000  # ここで何フレームごとに処理するか指定

for i in range(frame_count):
    ret, frame = cap.read()
    played_frame = int(cap.get(cv2.CAP_PROP_POS_FRAMES))
    if not ret:
        break

    # フレームを間引く
    if i % frame_skip != 0:
        continue

    # ここから下は元の処理
    results = model.track(frame, verbose=False, persist=True, classes=[0], tracker="bytetrack.yaml")
    names = results[0].names
    classes = results[0].boxes.cls
    boxes = results[0].boxes
    annotatedFrame = results[0].plot()

    current_ids = set()
    current_coordinates = {}
    for box, cls in zip(boxes, classes):
        x1, x2, y1, y2 = [int(i) for i in box.xyxy[0]]
        name = names[int(cls)]
        if box.id is not None:
            ids = int(box.id[0])
        else:
            continue

        # During the first 10 frames, establish baseline IDs
        if played_frame - start_frame < frame_baseline_limit:
            baseline_ids.add(ids)

        # If new ID appears after the baseline frames
        if ids not in baseline_ids:
            closest_id = None
            closest_distance = float('inf')
            for prev_id, prev_coords in previous_coordinates.items():
                distance = math.sqrt((x1 - prev_coords[0])**2 + (y1 - prev_coords[2])**2)
                if distance < closest_distance and prev_id not in current_ids:
                    closest_id = prev_id
                    closest_distance = distance

            if closest_id is not None:
                ids = closest_id
            else:
                print(f"Frame {played_frame}: Over-detection, skipping ID {ids}")
                continue

        current_ids.add(ids)
        current_coordinates[ids] = (x1, x2, y1, y2)

        velocity[ids][0], velocity[ids][1], velocity[ids][2], velocity[ids][3] = \
            abs(x1-coordinate[ids][0]), abs(x2-coordinate[ids][1]), abs(y1-coordinate[ids][2]), abs(y2-coordinate[ids][3])

        match detect_type:
            case 1:
                evaluation = abs(velocity[ids][0] - pre_velocity[ids][0]) + abs(velocity[ids][1] - pre_velocity[ids][1]) + abs(velocity[ids][2] \
                             - pre_velocity[ids][2]) + abs(velocity[ids][3] - pre_velocity[ids][3])
            case 2:
                evaluation = abs(velocity[ids][0] - pre_velocity[ids][0]) + abs(velocity[ids][1] - pre_velocity[ids][1]) + abs(velocity[ids][2] \
                             - pre_velocity[ids][2]) + abs(velocity[ids][3] - pre_velocity[ids][3])
            case _:
                print("Please select a specific type")

        # Mark outlier if evaluation exceeds 30
        if evaluation > 100:
            evaluation = 0.00

        coordinate[ids] = box.xyxy[0]
        activity_average[ids] = activity_average[ids] + evaluation

        # Store results for averaging
        if played_frame >= 415:
            if ids not in analysis_results:
                analysis_results[ids] = []
            analysis_results[ids].append(evaluation)

        if played_frame >= start_frame+2:
            print(f"Frame {played_frame-2}: Evaluation = {'{:.2f}'.format(evaluation)}, ID = {ids}")

    # Update previous coordinates
    for id in baseline_ids:
        if id not in current_ids:
            # Retain the last known position of IDs not detected in the current frame
            current_coordinates[id] = previous_coordinates.get(id, (0, 0, 0, 0))
    previous_coordinates = current_coordinates

# Calculate averages for the last segments
averaged_results = {}
for obj_id, evaluations in analysis_results.items():
    if len(evaluations) > 13:
        segment_length = len(evaluations) // 13
        averaged_results[obj_id] = [
            sum(evaluations[i * segment_length:(i + 1) * segment_length]) / segment_length
            for i in range(13)
        ]
    else:
        averaged_results[obj_id] = [sum(evaluations) / len(evaluations)]

print("--- Averages per segment ---")
for obj_id, averages in averaged_results.items():
   print(f"ID: {obj_id}, Averages: {averages}")

cv2.destroyAllWindows()
print("---end---")

safe_results = {str(obj_id): [float(v) for v in averages] for obj_id, averages in averaged_results.items()}
print(json.dumps({"averaged_results": safe_results}))
