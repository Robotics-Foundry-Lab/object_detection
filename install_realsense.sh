#!/usr/bin/env bash
set -euo pipefail

echo "=== Installing/Updating Librealsense from source ==="

# 1️⃣ Clean previous installations
rm -f /usr/local/lib/librealsense*
rm -rf /usr/local/include/librealsense2
rm -rf /usr/local/lib/cmake/realsense2
rm -f /usr/local/lib/pkgconfig/realsense2.pc
rm -f /usr/local/bin/realsense-*
rm -f /usr/local/bin/rs-*
ldconfig

# 2️⃣ Install dependencies (without librealsense2-dev/utils)
apt-get update --allow-releaseinfo-change
apt-get install -y \
  build-essential \
  cmake \
  git \
  pkg-config \
  libusb-1.0-0-dev \
  libglfw3-dev \
  libgtk-3-dev \
  libssl-dev \
  libglu1-mesa-dev \
  libgl1-mesa-dev \
  v4l-utils \
  curl

# 3️⃣ Clone librealsense
WORKDIR="${HOME:-/root}"
rm -rf "$WORKDIR/librealsense"
git clone https://github.com/IntelRealSense/librealsense.git "$WORKDIR/librealsense"
cd "$WORKDIR/librealsense"
git checkout v2.55.1

# 4️⃣ Build librealsense
mkdir -p build && cd build
cmake .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_EXAMPLES=true \
  -DBUILD_GRAPHICAL_EXAMPLES=true \
  -DBUILD_WITH_CUDA=false \
  -DFORCE_RSUSB_BACKEND=true

make -j"$(nproc)"
make install
ldconfig

# 5️⃣ Ensure ros user can access binaries
chmod +x /usr/local/bin/rs-*
chmod +x /usr/local/bin/realsense-*

echo "=== Librealsense installation complete ==="
echo "Test with: rs-enumerate-devices"
