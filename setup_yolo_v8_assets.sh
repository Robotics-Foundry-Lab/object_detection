#!/bin/bash
# Makes sure ${ISAAC_ROS_WS}/isaac_ros_assets/models/yolov8/<model>.onnx and <model>.plan exist.
# Usage: setup_yolo_v8_assets.sh [model]   (default: $YOLO_MODEL or yolov8n)
#
# yolov8n/s/m/l/x are downloaded from ultralytics and exported to ONNX automatically.
# Custom models must be placed manually (at least the .onnx).
# A missing TensorRT .plan is built here with trtexec before launch: letting Isaac ROS build it
# while the pipeline is running runs out of memory on the Jetson.
set -euo pipefail

# sudo apt-get install -y curl jq tar nvidia-l4t-dla-compiler

YOLO_MODEL="${1:-${YOLO_MODEL:-yolov8n}}"
ASSETS_DIR="${ISAAC_ROS_WS}/isaac_ros_assets"
MODEL_DIR="${ASSETS_DIR}/models/yolov8"

build_engine() {
    if [ -f "${MODEL_DIR}/${YOLO_MODEL}.plan" ]; then
        echo "TensorRT engine found: ${MODEL_DIR}/${YOLO_MODEL}.plan"
        return
    fi
    echo "Building TensorRT engine ${YOLO_MODEL}.plan (takes several minutes)..."
    /usr/src/tensorrt/bin/trtexec \
        --onnx="${MODEL_DIR}/${YOLO_MODEL}.onnx" \
        --saveEngine="${MODEL_DIR}/${YOLO_MODEL}.plan" \
        --fp16 --memPoolSize=workspace:1024M --skipInference \
        | grep -E "Engine built|PASSED|FAILED|ERROR"
}

if [ -f "${MODEL_DIR}/${YOLO_MODEL}.onnx" ]; then
    echo "Model assets found: ${MODEL_DIR}/${YOLO_MODEL}.onnx"
    build_engine
    exit 0
fi

if [[ ! "$YOLO_MODEL" =~ ^yolov8[nsmlx]$ ]]; then
    echo "ERROR: Custom model '${YOLO_MODEL}' is missing and cannot be downloaded automatically."
    echo "Place ${YOLO_MODEL}.onnx (and optionally ${YOLO_MODEL}.plan) in:"
    echo "  ${MODEL_DIR}"
    exit 1
fi

# Isaac ROS quickstart assets (rosbag + interface specs, used by RUN_MODE=bag).
# Not needed for live camera modes, so a failed download only warns.
download_quickstart_assets() {
    local NGC_ORG="nvidia"
    local NGC_TEAM="isaac"
    local NGC_RESOURCE="isaac_ros_yolov8_assets"
    local NGC_FILENAME="quickstart.tar.gz"
    local MAJOR_VERSION=3
    local MINOR_VERSION=2
    local VERSION_REQ_URL="https://catalog.ngc.nvidia.com/api/resources/versions?orgName=$NGC_ORG&teamName=$NGC_TEAM&name=$NGC_RESOURCE&isPublic=true&pageNumber=0&pageSize=100&sortOrder=CREATED_DATE_DESC"
    local AVAILABLE_VERSIONS LATEST_VERSION_ID
    AVAILABLE_VERSIONS=$(curl -s -H "Accept: application/json" "$VERSION_REQ_URL")
    LATEST_VERSION_ID=$(echo "$AVAILABLE_VERSIONS" | jq -r "
        .recipeVersions[]
        | .versionId as \$v
        | \$v | select(test(\"^\\\\d+\\\\.\\\\d+\\\\.\\\\d+$\"))
        | split(\".\") | {major: .[0]|tonumber, minor: .[1]|tonumber, patch: .[2]|tonumber}
        | select(.major == $MAJOR_VERSION and .minor <= $MINOR_VERSION)
        | \$v
        " | sort -V | tail -n 1
    )
    if [ -z "$LATEST_VERSION_ID" ]; then
        echo "No corresponding version found for Isaac ROS $MAJOR_VERSION.$MINOR_VERSION"
        return 1
    fi
    local FILE_REQ_URL="https://api.ngc.nvidia.com/v2/resources/$NGC_ORG/$NGC_TEAM/$NGC_RESOURCE/versions/$LATEST_VERSION_ID/files/$NGC_FILENAME"
    mkdir -p "$ASSETS_DIR"
    cd "$ASSETS_DIR"
    curl -LO --request GET "$FILE_REQ_URL"
    tar -xf "$NGC_FILENAME" -C "$ASSETS_DIR"
    rm "$NGC_FILENAME"
}

if [ ! -d "${ASSETS_DIR}/isaac_ros_yolov8" ]; then
    echo "Downloading Isaac ROS YOLOv8 quickstart assets..."
    ( download_quickstart_assets ) || echo "WARNING: Quickstart asset download failed, RUN_MODE=bag will not work."
fi

mkdir -p "$MODEL_DIR"
cd "$MODEL_DIR"
echo "Exporting ${YOLO_MODEL}.pt to ONNX..."
python3 -c "from ultralytics import YOLO; YOLO('${YOLO_MODEL}.pt').export(format='onnx')"
build_engine
