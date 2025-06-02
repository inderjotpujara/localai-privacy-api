#!/bin/bash
set -e

# Production deployment script for Local LLM API
echo "🚀 Starting Local LLM API Production Deployment..."

# Load environment variables
if [ -f .env.prod ]; then
    export $(cat .env.prod | grep -v '#' | awk '/=/ {print $1}')
else
    echo "⚠️  Warning: .env.prod file not found. Using default values."
fi

# Check required environment variables
if [ -z "$JWT_SECRET" ]; then
    echo "❌ Error: JWT_SECRET must be set in .env.prod"
    exit 1
fi

# Create necessary directories
mkdir -p logs models localai-data

# Pull latest images
echo "📦 Pulling latest Docker images..."
docker-compose -f docker-compose.prod.yml pull

# Start services
echo "🔧 Starting production services..."
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be ready..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker-compose -f docker-compose.prod.yml ps --filter "health=healthy" | grep -q "postgres-prod.*healthy"; then
        echo "✅ PostgreSQL is healthy"
        break
    fi
    attempt=$((attempt + 1))
    echo "   Waiting for PostgreSQL... ($attempt/$max_attempts)"
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ PostgreSQL failed to start within expected time"
    exit 1
fi

# Check API health
echo "🔍 Testing API health..."
max_attempts=20
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if curl -f -s http://localhost:3000/health > /dev/null; then
        echo "✅ API is healthy"
        break
    fi
    attempt=$((attempt + 1))
    echo "   Waiting for API... ($attempt/$max_attempts)"
    sleep 5
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ API failed to start within expected time"
    echo "📋 Check logs with: docker-compose -f docker-compose.prod.yml logs api"
    exit 1
fi

# Show service status
echo ""
echo "📊 Service Status:"
docker-compose -f docker-compose.prod.yml ps

echo ""
echo "🎉 Production deployment complete!"
echo ""
echo "📍 Service URLs:"
echo "   API:      http://localhost:3000"
echo "   Health:   http://localhost:3000/health"
echo "   LocalAI:  http://localhost:8080"
echo "   Grafana:  http://localhost:3001"
echo ""
echo "📋 Useful commands:"
echo "   Logs:     docker-compose -f docker-compose.prod.yml logs"
echo "   Stop:     docker-compose -f docker-compose.prod.yml down"
echo "   Restart:  docker-compose -f docker-compose.prod.yml restart"
