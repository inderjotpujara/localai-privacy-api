#!/bin/bash
set -e

echo "🔍 Local LLM API Project Status Check"
echo "====================================="
echo ""

# Check Docker services
echo "📦 Docker Services Status:"
if docker-compose ps &> /dev/null; then
    docker-compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
else
    echo "   ⚠️  Docker Compose not running"
fi
echo ""

# Check API endpoint
echo "🏥 API Health Check:"
if curl -f -s http://localhost:3000/health > /dev/null 2>&1; then
    echo "   ✅ API is responding on port 3000"
    curl -s http://localhost:3000/health | jq . || curl -s http://localhost:3000/health
else
    echo "   ❌ API not responding on port 3000"
fi
echo ""

# Check LocalAI endpoint
echo "🤖 LocalAI Status:"
if curl -f -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "   ✅ LocalAI is responding on port 8080"
    echo "   📋 Available models:"
    curl -s http://localhost:8080/v1/models | jq '.data[].id' 2>/dev/null || echo "      (Unable to fetch models list)"
else
    echo "   ⏳ LocalAI not ready on port 8080 (may still be downloading models)"
fi
echo ""

# Check database
echo "🗄️  Database Status:"
if docker-compose exec -T postgres pg_isready -U postgres &> /dev/null; then
    echo "   ✅ PostgreSQL is ready"
    echo "   📊 Database info:"
    docker-compose exec -T postgres psql -U postgres -d localllm -c "SELECT 'Tables: ' || count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null || echo "      (Unable to query database)"
else
    echo "   ❌ PostgreSQL not accessible"
fi
echo ""

# Check Grafana
echo "📊 Monitoring Stack:"
if curl -f -s http://localhost:3001 > /dev/null 2>&1; then
    echo "   ✅ Grafana accessible on port 3001"
else
    echo "   ❌ Grafana not accessible on port 3001"
fi

if curl -f -s http://localhost:3100/ready > /dev/null 2>&1; then
    echo "   ✅ Loki accessible on port 3100"
else
    echo "   ❌ Loki not accessible on port 3100"
fi
echo ""

# Check model files
echo "📚 Model Files:"
if [ -d "models" ]; then
    echo "   📁 Models directory exists"
    echo "   📋 Model files:"
    ls -la models/ | grep -E '\.(gguf|yaml)$' | awk '{print "      " $9 " (" $5 " bytes)"}' || echo "      (No model files found)"
else
    echo "   ❌ Models directory not found"
fi
echo ""

# Check configuration files
echo "⚙️  Configuration Status:"
files=(".env" "docker-compose.yml" "api/package.json" "api/tsconfig.json")
for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "   ✅ $file exists"
    else
        echo "   ❌ $file missing"
    fi
done
echo ""

# Check TypeScript compilation
echo "🔧 Build Status:"
if [ -d "api/dist" ]; then
    echo "   ✅ TypeScript compiled (dist/ directory exists)"
else
    echo "   ⚠️  TypeScript not compiled (run: cd api && npm run build)"
fi
echo ""

# Check Node.js dependencies
echo "📦 Dependencies:"
if [ -f "api/package-lock.json" ]; then
    echo "   ✅ Node.js dependencies installed"
else
    echo "   ⚠️  Node.js dependencies not installed (run: cd api && npm install)"
fi
echo ""

# Project structure overview
echo "📂 Project Structure:"
tree -L 2 -I 'node_modules|dist|*.log' . 2>/dev/null || find . -maxdepth 2 -type d | grep -v -E '\/(node_modules|dist|\.git)' | sort

echo ""
echo "🎯 Quick Actions:"
echo "   Start all services:    docker-compose up -d"
echo "   View logs:             docker-compose logs -f"
echo "   Stop all services:     docker-compose down"
echo "   Test API:              ./scripts/test-endpoints.sh"
echo "   Check LocalAI logs:    docker-compose logs localai"
echo ""
echo "🌐 Service URLs:"
echo "   API:                   http://localhost:3000"
echo "   API Health:            http://localhost:3000/health"
echo "   LocalAI:               http://localhost:8080"
echo "   Grafana:               http://localhost:3001"
echo "   Loki:                  http://localhost:3100"
