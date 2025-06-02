#!/bin/bash

# Docker-based health check script
# This script only uses Docker commands to check service health

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

echo "🔍 LocalAI API - Docker Health Check"
echo "===================================="
echo ""

# Check if Docker is running
if ! docker info &> /dev/null; then
    print_error "Docker is not running"
    exit 1
fi

# Check Docker Compose services
print_status "Checking Docker Compose services..."

services=("postgres" "localai" "api" "loki" "grafana")
all_healthy=true

for service in "${services[@]}"; do
    if docker-compose ps "$service" 2>/dev/null | grep -q "Up"; then
        # Check if service has health check
        health_status=$(docker-compose ps "$service" 2>/dev/null | grep "$service" | awk '{print $4}' || echo "unknown")
        
        case "$health_status" in
            *"healthy"*)
                print_success "$service is running and healthy"
                ;;
            *"unhealthy"*)
                print_error "$service is running but unhealthy"
                all_healthy=false
                ;;
            *"Up"*)
                print_success "$service is running"
                ;;
            *)
                print_warning "$service status: $health_status"
                ;;
        esac
    else
        print_error "$service is not running"
        all_healthy=false
    fi
done

echo ""

# Test services using Docker exec
print_status "Testing service connectivity..."

# Test PostgreSQL
if docker-compose exec -T postgres pg_isready -U llm_user &>/dev/null; then
    print_success "PostgreSQL is accepting connections"
else
    print_error "PostgreSQL connection failed"
    all_healthy=false
fi

# Test LocalAI
if docker-compose exec -T api sh -c "curl -s http://localai:8080/v1/models" &>/dev/null; then
    print_success "LocalAI is responding"
    
    # Get model count
    model_count=$(docker-compose exec -T api sh -c "curl -s http://localai:8080/v1/models | grep -o '\"id\"' | wc -l" 2>/dev/null || echo "0")
    if [ "$model_count" -gt 0 ]; then
        print_success "LocalAI has $model_count models loaded"
    else
        print_warning "LocalAI may still be loading models"
    fi
else
    print_error "LocalAI connection failed"
    all_healthy=false
fi

# Test API
if docker-compose exec -T api sh -c "curl -s http://localhost:3000/health" &>/dev/null; then
    print_success "API health endpoint is responding"
    
    # Test JWT authentication
    jwt_response=$(docker-compose exec -T api sh -c "curl -s -X POST http://localhost:3000/auth/login -H 'Content-Type: application/json' -d '{\"username\": \"admin\", \"password\": \"admin123\"}'" 2>/dev/null || echo "")
    
    if echo "$jwt_response" | grep -q "token"; then
        print_success "JWT authentication is working"
    else
        print_error "JWT authentication failed"
        all_healthy=false
    fi
else
    print_error "API health check failed"
    all_healthy=false
fi

# Test Loki
if docker-compose exec -T api sh -c "curl -s http://loki:3100/ready" &>/dev/null; then
    print_success "Loki is ready"
else
    print_warning "Loki connection failed (may not be critical)"
fi

# Test Grafana
if docker-compose exec -T api sh -c "curl -s http://grafana:3000/api/health" &>/dev/null; then
    print_success "Grafana is responding"
else
    print_warning "Grafana connection failed (may not be critical)"
fi

echo ""

# Show resource usage
print_status "Docker resource usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" $(docker-compose ps -q) 2>/dev/null || echo "Could not get stats"

echo ""

# Show service logs summary
print_status "Recent error logs:"
for service in "${services[@]}"; do
    errors=$(docker-compose logs --tail=10 "$service" 2>/dev/null | grep -i "error\|failed\|exception" | wc -l || echo "0")
    if [ "$errors" -gt 0 ]; then
        print_warning "$service has $errors recent error(s)"
    fi
done

echo ""

# Final status
if [ "$all_healthy" = true ]; then
    print_success "All critical services are healthy!"
    echo ""
    echo "🌐 Service URLs:"
    echo "  - API:     http://localhost:3000"
    echo "  - LocalAI: http://localhost:8080"
    echo "  - Grafana: http://localhost:3001"
    echo ""
    exit 0
else
    print_error "Some services are not healthy. Check the logs above."
    echo ""
    echo "🔧 Troubleshooting commands:"
    echo "  - View logs: docker-compose logs [service]"
    echo "  - Restart:   docker-compose restart [service]"
    echo "  - Rebuild:   docker-compose up --build -d"
    echo ""
    exit 1
fi
