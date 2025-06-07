#!/bin/bash

DOCKER_USERNAME="kgp9588"

docker stop ocr-model ocr-gateway 2>/dev/null
docker rm ocr-model ocr-gateway 2>/dev/null

docker network create ocr-network 2>/dev/null || true

docker run -d --name ocr-model -p 8080:8080 --network ocr-network $DOCKER_USERNAME/ocr-model:latest
docker run -d --name ocr-gateway -p 8001:8001 --network ocr-network $DOCKER_USERNAME/ocr-gateway:latest

echo "Services started on ports 8080 and 8001"