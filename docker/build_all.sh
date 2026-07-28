#!/bin/bash
# Build all Docker images for the fine-mapping pipeline
# Usage: ./build_all.sh [REGISTRY_PREFIX]
#
# Example with Docker Hub:
#   ./build_all.sh myusername
# Example with AWS ECR:
#   ./build_all.sh 123456789012.dkr.ecr.us-east-1.amazonaws.com/finemapping

set -e

REGISTRY_PREFIX=${1:-"finemapping"}
VERSION=${2:-"latest"}

echo "================================"
echo "Building Fine-mapping Docker Images"
echo "Registry prefix: ${REGISTRY_PREFIX}"
echo "Version: ${VERSION}"
echo "================================"

# Build base image (optional, not currently used)
echo ""
echo "[1/4] Building base image..."
docker build -t ${REGISTRY_PREFIX}-base:${VERSION} ./base

# Build gwaslab image
echo ""
echo "[2/4] Building gwaslab image..."
docker build -t ${REGISTRY_PREFIX}-gwaslab:${VERSION} ./gwaslab

# Build plink image
echo ""
echo "[3/4] Building plink image..."
docker build -t ${REGISTRY_PREFIX}-plink:${VERSION} ./plink

# Build susie image
echo ""
echo "[4/4] Building susie image..."
docker build -t ${REGISTRY_PREFIX}-susie:${VERSION} ./susie

echo ""
echo "================================"
echo "Build complete!"
echo "================================"
echo ""
echo "Images created:"
echo "  - ${REGISTRY_PREFIX}-base:${VERSION}"
echo "  - ${REGISTRY_PREFIX}-gwaslab:${VERSION}"
echo "  - ${REGISTRY_PREFIX}-plink:${VERSION}"
echo "  - ${REGISTRY_PREFIX}-susie:${VERSION}"
echo ""
echo "To push to registry, run:"
echo "  ./push_all.sh ${REGISTRY_PREFIX} ${VERSION}"
