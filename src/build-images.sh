#!/bin/bash
# Build script for Names Manager application images
# This script builds both backend and frontend Docker images with consistent tagging

set -e  # Exit on error

echo "========================================="
echo "  Building Names Manager Docker Images  "
echo "========================================="
echo ""

# Change to script directory
cd "$(dirname "$0")"

# Check if Dockerfiles exist
if [ ! -f "backend/Dockerfile" ]; then
    echo "ERROR: backend/Dockerfile not found!"
    exit 1
fi

if [ ! -f "frontend/Dockerfile" ]; then
    echo "ERROR: frontend/Dockerfile not found!"
    exit 1
fi

echo "=== Building Backend Image ==="
echo "Building: localhost/names-backend:latest"
cd backend
docker build -t localhost/names-backend:latest .
if [ $? -eq 0 ]; then
    echo "✓ Backend image built successfully"
else
    echo "✗ Backend image build failed"
    exit 1
fi
cd ..

echo ""
echo "=== Building Frontend Image ==="
echo "Building: localhost/names-frontend:latest"
cd frontend
docker build -t localhost/names-frontend:latest .
if [ $? -eq 0 ]; then
    echo "✓ Frontend image built successfully"
else
    echo "✗ Frontend image build failed"
    exit 1
fi
cd ..

echo ""
echo "=== Build Complete ==="
docker images | grep names

echo ""
echo "Images ready for deployment!"
