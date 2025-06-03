#!/bin/bash

# Local LLM Management Script
# Provides status checking and API testing functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

# Function to check if containers are running
check_containers() {
    print_status "📦 Checking Docker containers..."
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "local-llm"; then
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "local-llm"
        print_success "Containers are running"
        return 0
    else
        print_error "Local LLM containers are not running"
        print_warning "Run 'docker compose up' to start the services"
        return 1
    fi
}

# Function to check available models
check_models() {
    print_status "🤖 Checking available models..."
    if models=$(curl -s http://localhost:11434/api/tags 2>/dev/null); then
        if echo "$models" | jq -e '.models' >/dev/null 2>&1; then
            echo "$models" | jq -r '.models[].name' | while read model; do
                echo "  • $model"
            done
            print_success "Models loaded successfully"
        else
            print_error "No models found"
        fi
    else
        print_error "Could not connect to Ollama service"
        return 1
    fi
}

# Function to test the API
test_api() {
    print_status "🌐 Testing API endpoint..."
    
    local test_data='{
        "model": "llama3.2:1b",
        "messages": [{"role": "user", "content": "Hello! Say hi back in one sentence."}],
        "max_tokens": 50
    }'
    
    if response=$(curl -s -X POST http://localhost:3000/chat \
        -H "Content-Type: application/json" \
        -d "$test_data" \
        --max-time 30 2>/dev/null); then
        
        if echo "$response" | jq -e '.choices[0].message.content' >/dev/null 2>&1; then
            content=$(echo "$response" | jq -r '.choices[0].message.content')
            echo "Response: $content"
            print_success "API is working correctly"
        else
            print_error "Invalid API response format"
            echo "Raw response: $response"
            return 1
        fi
    else
        print_error "API test failed - could not connect"
        return 1
    fi
}

# Function to run comprehensive tests
run_tests() {
    print_status "🚀 Running comprehensive API tests..."
    echo ""
    
    # Test 1: Simple greeting
    print_status "Test 1: Simple greeting"
    curl -s -X POST http://localhost:3000/chat \
        -H "Content-Type: application/json" \
        -d '{
            "model": "llama3.2:1b",
            "messages": [{"role": "user", "content": "Hello! Say hi back in one sentence."}],
            "max_tokens": 30
        }' --max-time 30 | jq -r '.choices[0].message.content' 2>/dev/null || print_error "Test 1 failed"
    
    echo ""
    
    # Test 2: Math question
    print_status "Test 2: Math question"
    curl -s -X POST http://localhost:3000/chat \
        -H "Content-Type: application/json" \
        -d '{
            "model": "llama3.2:1b",
            "messages": [{"role": "user", "content": "What is 2+2? Answer in one short sentence."}],
            "max_tokens": 30
        }' --max-time 30 | jq -r '.choices[0].message.content' 2>/dev/null || print_error "Test 2 failed"
    
    echo ""
    print_success "All tests completed"
}

# Function to show usage
show_usage() {
    echo "Local LLM Management Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status    - Check containers, models, and API status"
    echo "  test      - Run a quick API test"
    echo "  tests     - Run comprehensive API tests"
    echo "  start     - Start the Docker containers (development mode)"
    echo "  start-prod - Start using pre-built image (production mode)"
    echo "  stop      - Stop the Docker containers"
    echo "  restart   - Restart the Docker containers"
    echo "  logs      - Show container logs"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 test"
    echo "  $0 start      # Build and run from source"
    echo "  $0 start-prod # Use pre-built image"
}

# Main logic
case "${1:-status}" in
    "status")
        echo "🔍 Local LLM Status Check"
        echo "========================"
        echo ""
        check_containers && check_models && test_api
        ;;
    "test")
        echo "🧪 Quick API Test"
        echo "================"
        echo ""
        test_api
        ;;
    "tests")
        run_tests
        ;;
    "start")
        print_status "Starting Local LLM services (development mode)..."
        docker compose up -d --build
        print_success "Services started"
        ;;
    "start-prod")
        print_status "Starting Local LLM services (production mode with pre-built image)..."
        if [ -f "docker-compose.prod.yml" ]; then
            docker compose -f docker-compose.prod.yml up -d
        else
            print_warning "docker-compose.prod.yml not found, downloading..."
            curl -s -o docker-compose.prod.yml https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml
            docker compose -f docker-compose.prod.yml up -d
        fi
        print_success "Services started with pre-built image"
        ;;
    "stop")
        print_status "Stopping Local LLM services..."
        docker compose down 2>/dev/null || true
        docker compose -f docker-compose.prod.yml down 2>/dev/null || true
        print_success "Services stopped"
        ;;
    "restart")
        print_status "Restarting Local LLM services..."
        docker compose restart 2>/dev/null || docker compose -f docker-compose.prod.yml restart 2>/dev/null
        print_success "Services restarted"
        ;;
    "logs")
        print_status "Showing container logs..."
        if docker compose ps >/dev/null 2>&1; then
            docker compose logs -f
        elif docker compose -f docker-compose.prod.yml ps >/dev/null 2>&1; then
            docker compose -f docker-compose.prod.yml logs -f
        else
            print_error "No running services found"
        fi
        ;;
    "help"|"-h"|"--help")
        show_usage
        ;;
    *)
        print_error "Unknown command: $1"
        echo ""
        show_usage
        exit 1
        ;;
esac
