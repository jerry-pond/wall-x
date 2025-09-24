#!/bin/bash
# WALL-X Codespaces Build Script - Handles limited disk space

set -e

echo "🧹 Cleaning up disk space..."
docker system prune -af --volumes
sudo apt-get clean
rm -rf ~/.cache/*

echo "📊 Current disk usage:"
df -h /

echo "🏗️ Building WALL-X Docker image (optimized for Codespaces)..."
DOCKER_BUILDKIT=1 docker build \
  -f Dockerfile.codespaces \
  -t wall-x:codespaces \
  --progress=plain \
  .

echo "🧹 Post-build cleanup..."
docker system prune -f

echo "✅ Build complete! Run: docker run -it --gpus all wall-x:codespaces"