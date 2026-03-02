#!/bin/bash
set -e

# Source ROS environments
source /opt/ros/humble/setup.bash
source /opt/ros_ws/install/setup.bash

# Read model + mode from environment
YOLO_MODEL="${YOLO_MODEL:-yolov8s}"      # default model
RUN_MODE="${RUN_MODE:-standalone}"       # default mode (standalone or composite)

ASSETS_BASE="${ISAAC_ROS_WS}/isaac_ros_assets/models/yolov8"
ONNX_FILE="${ASSETS_BASE}/${YOLO_MODEL}.onnx"
ENGINE_FILE="${ASSETS_BASE}/${YOLO_MODEL}.plan"

echo "=============================================="
echo "  Object Detection Container Startup"
echo "  Mode:  ${RUN_MODE}"
echo "  Model: ${YOLO_MODEL}"
echo "=============================================="

# ------------------------- 
# Asset existence logic 
# ------------------------- 

if [ ! -f "$ONNX_FILE" ]; 
    then echo "ONNX model file not found: $ONNX_FILE" 

    if [ "$YOLO_MODEL" = "yolov8s" ]; then 
        echo "Default model selected. Running setup_yolo_v8_assets.sh..." 
        /usr/local/bin/setup_yolo_v8_assets.sh
    else
        echo "ERROR: Non-default model '${YOLO_MODEL}' is missing."
        echo "This model must be manually placed at:"
        echo "  ${ASSETS_BASE}"
        echo "Aborting."
        exit 1
    fi
else
    echo "Model assets found."
fi


# -------------------------
# Standalone Mode
# -------------------------
if [ "$RUN_MODE" = "standalone" ]; then
    echo "Launching in STANDALONE mode..."

    ros2 launch isaac_ros_examples isaac_ros_examples.launch.py \
        launch_fragments:=realsense_mono_rect,yolov8 \
        model_file_path:=${ONNX_FILE} \
        engine_file_path:=${ENGINE_FILE} \
        interface_specs_file:=${ISAAC_ROS_WS}/realsense_specs.json &

    ros2 run isaac_ros_yolov8 isaac_ros_yolov8_visualizer.py &

    ros2 run image_transport republish raw compressed \
        --ros-args \
        --remap in:=/yolov8_processed_image \
        --remap /out/compressed:=/yolov8_processed_image/compressed \
        -p compressed.jpeg_quality:=80

    exit 0
fi

# -------------------------
# Composite Mode
# -------------------------
if [ "$RUN_MODE" = "composite" ]; then
    echo "Launching in COMPOSITE mode..."

    ros2 launch isaac_ros_examples isaac_ros_examples.launch.py \
        launch_fragments:=yolov8 \
        model_file_path:=${ONNX_FILE} \
        engine_file_path:=${ENGINE_FILE} &

    ros2 run isaac_ros_yolov8 isaac_ros_yolov8_visualizer.py &

    ros2 run image_transport republish raw compressed \
        --ros-args \
        -r in:=/yolov8_processed_image \
        -r out:=/yolov8_processed_image \
        -p compressed.jpeg_quality:=80

    exit 0
fi

echo "ERROR: Unknown RUN_MODE '${RUN_MODE}'. Use 'standalone' or 'composite'."
exit 1
