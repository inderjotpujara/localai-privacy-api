#!/bin/bash

# development.sh - Start the development environment

set -e

echo "🚀 Starting Local LLM Development Environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop first."
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp .env.sample .env
    echo "⚠️  Please edit .env file with your configurations before proceeding"
    echo "   - Set JWT_SECRET to a secure random string"
    echo "   - Update database credentials if needed"
    echo "   - Configure LocalAI model settings"
    read -p "Press Enter to continue after editing .env file..."
fi

# Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p models data logs

# Set up models if not already done
if [ ! -f "models/llama3.yaml" ]; then
    echo "🤖 Setting up model configurations..."
    ./scripts/setup-models.sh
fi

# Start services in development mode
echo "🐳 Starting Docker services..."
docker-compose up -d postgres loki promtail grafana

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
docker-compose ps

# Start LocalAI
echo "🤖 Starting LocalAI..."
docker-compose up -d localai

# Wait for LocalAI to be ready
echo "⏳ Waiting for LocalAI to start..."
sleep 30

# Install API dependencies if needed
if [ ! -d "api/node_modules" ]; then
    echo "📦 Installing API dependencies..."
    cd api
    npm install
    cd ..
fi

# Start the API in development mode
echo "🔧 Starting API in development mode..."
cd api
npm run dev &
API_PID=$!
cd ..

echo "✅ Development environment started!"
echo ""
echo "🌐 Services available at:"
echo "   - API: http://localhost:3000"
echo "   - Health Check: http://localhost:3000/health"
echo "   - LocalAI: http://localhost:8080"
echo "   - Grafana: http://localhost:3001 (admin/admin)"
echo "   - Postgres: localhost:5432"
echo ""
echo "📚 API Documentation:"
echo "   POST /chat - Chat with the LLM"
echo "   POST /rag/query - Query the knowledge base"
echo "   POST /rag/documents - Add documents to knowledge base"
echo ""
echo "🧪 Test the API:"
echo "   ./scripts/test-api.sh"
echo ""
echo "📊 View logs in Grafana:"
echo "   1. Open http://localhost:3001"
echo "   2. Login with admin/admin"
echo "   3. Explore Loki logs"
echo ""
echo "🛑 To stop: docker-compose down"

# Keep the script running to show logs
trap "echo 'Stopping development environment...'; docker-compose down; kill $API_PID 2>/dev/null; exit" INT TERM

# Show API logs
echo "📝 API logs (Ctrl+C to stop):"
tail -f api/logs/app.log 2>/dev/null || echo "API logs will appear here when available..."
