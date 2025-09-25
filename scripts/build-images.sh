#!/bin/bash

set -e

echo "Building Docker images for proxy monitoring solution..."

# Build load generator image
echo "Building load-generator image..."
docker build -t crawler-load-gen:latest ./docker/load-generator/

# Build crawler pod image
echo "Building crawler-pod image..."
docker build -t crawler-pod:latest ./docker/crawler-pod/

# Tag images for local registry (minikube)
if command -v minikube &> /dev/null; then
    echo "Tagging images for minikube..."
    eval $(minikube docker-env)
    docker build -t crawler-load-gen:latest ./docker/load-generator/
    docker build -t crawler-pod:latest ./docker/crawler-pod/
fi

echo "Docker images built successfully!"
echo "Images:"
echo "  - crawler-load-gen:latest"
echo "  - crawler-pod:latest"