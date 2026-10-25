#!/bin/bash
# Container entrypoint: prepare model assets, then hand over to the ROS launch file.
# Mode logic lives in src/object_detection/launch/object_detection.launch.py.
set -eo pipefail

# Source ROS environments
source /opt/ros/humble/setup.bash
source /opt/ros_ws/install/setup.bash
source "${ISAAC_ROS_WS}/install/setup.bash"

YOLO_MODEL="${YOLO_MODEL:-yolov8n}"     # yolov8n/s/m/l/x or a custom model in isaac_ros_assets/models/yolov8
RUN_MODE="${RUN_MODE:-composite}"       # standalone / composite / bag
VIS_MODE="${VIS_MODE:-sparse}"          # sparse / full / none

echo "=============================================="
echo "  Object Detection Container Startup"
echo "  Mode:  ${RUN_MODE}"
echo "  Model: ${YOLO_MODEL}"
echo "  Vis:   ${VIS_MODE}"
echo "=============================================="

bash "${ISAAC_ROS_WS}/setup_yolo_v8_assets.sh" "${YOLO_MODEL}"

# exec: ros2 launch becomes the main process, so docker stop shuts all nodes down cleanly
exec ros2 launch object_detection object_detection.launch.py \
    run_mode:="${RUN_MODE}" \
    vis_mode:="${VIS_MODE}" \
    model:="${YOLO_MODEL}"
