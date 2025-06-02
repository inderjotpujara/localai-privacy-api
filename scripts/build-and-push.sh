#!/bin/bash

# Build and push LocalAI Privacy API Docker image
# This script builds the API image and pushes it to GitHub Container Registry

set -e

# Configuration
IMAGE_NAME="ghcr.io/inderjotpujara/localai-privacy-api"
VERSION="latest"
FULL_IMAGE="$IMAGE_NAME:$VERSION"

echo "🔨 Building LocalAI Privacy API Docker image..."
echo "Image: $FULL_IMAGE"
echo

# Build the Docker image
cd api
docker build -t "$FULL_IMAGE" .

echo
echo "✅ Build completed successfully!"
echo

# Check if we should push
read -p "Push image to GitHub Container Registry? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🚀 Pushing image to registry..."
    
    # Login to GitHub Container Registry (requires GITHUB_TOKEN)
    if [ -z "$GITHUB_TOKEN" ]; then
        echo "❗ GITHUB_TOKEN environment variable is required"
        echo "Create a personal access token with 'write:packages' scope"
        echo "Then run: export GITHUB_TOKEN=your_token"
        exit 1
    fi
    
    echo "$GITHUB_TOKEN" | docker login ghcr.io -u inderjotpujara --password-stdin
    
    # Push the image
    docker push "$FULL_IMAGE"
    
    echo "✅ Successfully pushed $FULL_IMAGE"
    echo
    echo "🎉 Your image is now available for deployment!"
    echo "   docker pull $FULL_IMAGE"
else
    echo "Skipping push. Image built locally as: $FULL_IMAGE"
fi

echo
echo "📋 Next steps:"
echo "1. Test the image: docker run --rm -p 3000:3000 $FULL_IMAGE"
echo "2. Deploy with docker-compose.yml using the published image"
echo "3. Update deployment documentation with the new image"
