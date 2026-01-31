#!/bin/bash
set -e

echo "🐳 Building and pushing Claude Mascot to Docker Hub..."
echo ""

# Check if logged in to Docker Hub
if ! docker info | grep -q "Username: lynchz"; then
    echo "⚠️  Not logged in to Docker Hub. Please run: docker login"
    exit 1
fi

# Create buildx builder if not exists
if ! docker buildx inspect claude-builder > /dev/null 2>&1; then
    echo "📦 Creating buildx builder..."
    docker buildx create --name claude-builder --use
fi

# Use existing builder
docker buildx use claude-builder

# Bootstrap builder
docker buildx inspect --bootstrap

# Build and push for multiple architectures
echo ""
echo "🏗️  Building for linux/amd64 and linux/arm64..."
docker buildx build \
    --platform linux/amd64,linux/arm64 \
    --tag lynchz/claude-mascot:latest \
    --tag lynchz/claude-mascot:$(date +%Y%m%d) \
    --push \
    .

echo ""
echo "✅ Successfully built and pushed to Docker Hub!"
echo "📦 Image: lynchz/claude-mascot:latest"
echo "🏷️  Tag: lynchz/claude-mascot:$(date +%Y%m%d)"
echo ""
echo "🚀 To deploy, run: docker-compose up -d"
