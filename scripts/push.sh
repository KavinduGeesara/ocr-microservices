#!/bin/bash

DOCKER_USERNAME="kgp9588"

echo "Logging into Docker Hub..."
docker login

echo "Pushing OCR Model Service..."
docker push $DOCKER_USERNAME/ocr-model:latest

echo "Pushing OCR Gateway Service..."
docker push $DOCKER_USERNAME/ocr-gateway:latest

echo "Push complete!"