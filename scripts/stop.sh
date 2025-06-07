#!/bin/bash

docker stop ocr-model ocr-gateway
docker rm ocr-model ocr-gateway

echo "All OCR Services Stopped"