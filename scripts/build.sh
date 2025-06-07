#!/bin/bash

# Replace with your Docker Hub username
DOCKER_USERNAME="kgp9588"

echo "Building OCR Model Service..."
docker build -f docker/Dockerfile.model -t $DOCKER_USERNAME/ocr-model:latest .

echo "Building OCR Gateway Service..."
docker build -f docker/Dockerfile.gateway -t $DOCKER_USERNAME/ocr-gateway:latest .

echo "Build complete!"
docker images | grep ocr