#!/bin/bash
# Push all Docker images to a registry
# Usage: ./push_all.sh [REGISTRY_PREFIX] [VERSION]
#
# For Docker Hub:
#   docker login
#   ./push_all.sh myusername latest
#
# For AWS ECR:
#   aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com
#   ./push_all.sh 123456789012.dkr.ecr.us-east-1.amazonaws.com/finemapping latest

set -e

REGISTRY_PREFIX=${1:-"finemapping"}
VERSION=${2:-"latest"}

echo "================================"
echo "Pushing Fine-mapping Docker Images"
echo "Registry prefix: ${REGISTRY_PREFIX}"
echo "Version: ${VERSION}"
echo "================================"

# Push all images
for IMG in base gwaslab plink susie; do
    echo ""
    echo "Pushing ${REGISTRY_PREFIX}-${IMG}:${VERSION}..."
    docker push ${REGISTRY_PREFIX}-${IMG}:${VERSION}
done

echo ""
echo "================================"
echo "Push complete!"
echo "================================"
