FROM nvcr.io/nvidia/isaac/ros:aarch64-ros2_humble_adc428c7077de4984a00b63c55903b0a

# Set up auto-source of workspace for ros user
ENV ISAAC_ROS_WS=/workspaces/object_detection

# Install host setup script
COPY install_realsense.sh /usr/local/bin/install_realsense.sh
RUN bash /usr/local/bin/install_realsense.sh

# Install yolo assets setup script
COPY setup_yolo_v8_assets.sh /usr/local/bin/setup_yolo_v8_assets.sh
RUN chmod +x /usr/local/bin/setup_yolo_v8_assets.sh

RUN mkdir -p /opt/ros_ws/src
WORKDIR /opt/ros_ws/src

# Clone the exact ROS wrapper version
# Clone the repo without checking out HEAD
RUN git clone https://github.com/IntelRealSense/realsense-ros.git /opt/ros_ws/src/realsense-ros && \
    cd /opt/ros_ws/src/realsense-ros && \
    git checkout tags/4.51.1

RUN rm -f /etc/apt/sources.list.d/yarn.list

# Build the workspace, but ignore librealsense2 packages as they are built locally in the correct version
WORKDIR /opt/ros_ws/

RUN /bin/bash -c "source /opt/ros/humble/setup.bash && \
                  apt-get update --allow-releaseinfo-change && \
                  rosdep update && \
                  rosdep install --from-paths src --ignore-src -r -y --skip-keys='librealsense2 librealsense2-dev librealsense2-utils' && \
                  colcon build --symlink-install --executor sequential --cmake-args '-DCMAKE_BUILD_TYPE=RelWithDebInfo' '-DCMAKE_EXPORT_COMPILE_COMMANDS=On' '-DNVBLOX_ENABLE_REALSENSE=ON'"

RUN apt-get update --allow-releaseinfo-change \
    && apt-get install -y \
    ros-humble-isaac-ros-detectnet ros-humble-isaac-ros-yolov8 ros-humble-isaac-ros-tensor-rt \
    ros-humble-isaac-ros-dnn-image-encoder ros-humble-isaac-ros-triton ros-humble-isaac-ros-examples ros-humble-isaac-ros-realsense \
    curl jq tar \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install ultralytics onnx "numpy<2"

RUN echo "source /opt/ros/humble/setup.bash" >> /root/.bashrc
ARG WORKSPACE
RUN echo "source /opt/ros_ws/install/setup.bash" >> ~/.bashrc

# Add fancy colors to bash for root user
SHELL ["/bin/bash", "-c"]
RUN cat <<'EOF' >> /root/.bashrc
# ---- colorful root prompt ----
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi
export PS1="\[\e[1;31m\]\u@\h \[\e[1;34m\]\w \[\e[0m\]# "
EOF
