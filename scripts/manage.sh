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
    
    # Check for containers by service name (ollama, api) or project name (local-llm)
    containers=$(docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(ollama|api|local-llm)")
    
    if [ -n "$containers" ]; then
        echo "$containers" | head -10
        print_success "Containers are running"
        return 0
    else
        print_error "Local LLM containers are not running"
        print_warning "Run one of the following to start the services:"
        echo "  • docker compose up -d (development mode)"
        echo "  • docker compose -f docker-compose.prod.yml up -d (production mode)"
        echo "  • curl -s https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml | docker compose -f - up -d"
        return 1
    fi
}

# Function to check available models
check_models() {
    print_status "🤖 Checking available models..."
    local retries=10
    local count=0
    
    while [ $count -lt $retries ]; do
        if models=$(curl -s http://localhost:11434/api/tags 2>/dev/null); then
            if echo "$models" | jq -e '.models' >/dev/null 2>&1; then
                model_count=$(echo "$models" | jq -r '.models | length')
                if [ "$model_count" -gt 0 ]; then
                    echo "$models" | jq -r '.models[].name' | while read model; do
                        echo "  • $model"
                    done
                    print_success "Models loaded successfully"
                    return 0
                else
                    print_warning "No models found yet, waiting for download to complete..."
                fi
            else
                print_warning "Ollama service not ready, waiting..."
            fi
        else
            print_warning "Could not connect to Ollama service, attempt $((count + 1))/$retries"
        fi
        
        count=$((count + 1))
        sleep 10
    done
    
    print_error "Could not verify models after $retries attempts"
    print_warning "The model might still be downloading. Check container logs with: docker logs <ollama-container>"
    return 1
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

# Function to test summarization endpoints
test_summarize() {
    print_status "📄 Testing /summarize endpoint..."
    
    # First check if the API is reachable
    if ! curl -s http://localhost:3000/chat --max-time 5 >/dev/null 2>&1; then
        print_error "API server is not responding on http://localhost:3000"
        print_warning "Make sure the Local LLM services are running:"
        echo "  • ./scripts/manage.sh start"
        echo "  • ./scripts/manage.sh start-prod"
        echo "  • ./scripts/manage.sh start-curl"
        return 1
    fi
    
    echo ""
    
    local sample_text="Artificial Intelligence (AI) has been one of the most transformative technologies of the 21st century. From its early theoretical foundations laid by pioneers like Alan Turing in the 1950s, AI has evolved from simple rule-based systems to sophisticated machine learning algorithms capable of tasks that were once thought to be exclusively human. Today, AI powers everything from recommendation systems on streaming platforms to autonomous vehicles navigating complex city streets. The field encompasses various subdomains including natural language processing, computer vision, robotics, and deep learning. Machine learning, in particular, has seen explosive growth with the development of neural networks that can learn from vast amounts of data. However, with great power comes great responsibility, and the AI community continues to grapple with ethical considerations around bias, privacy, job displacement, and the potential for artificial general intelligence. As we move forward, the integration of AI into our daily lives will only deepen, making it crucial for society to understand both its potential benefits and risks."
    
    # Test 1: Basic summarization
    print_status "Test 1: Basic summarization"
    echo "------------------------"
    if response=$(curl -s -X POST http://localhost:3000/summarize \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"$sample_text\",
            \"instructions\": \"Provide a concise summary in 2-3 sentences\",
            \"max_tokens\": 100
        }" --max-time 60 2>/dev/null); then
        
        if echo "$response" | jq -e '.summary' >/dev/null 2>&1; then
            echo "$response" | jq -r '.summary'
            print_success "Basic summarization test passed"
        else
            print_error "Basic summarization test failed - invalid response format"
            echo "Response: $response"
        fi
    else
        print_error "Basic summarization test failed - connection error"
    fi
    
    echo ""
    echo ""
    
    # Test 2: Bullet point summary
    print_status "Test 2: Bullet point summary"
    echo "----------------------------"
    if response=$(curl -s -X POST http://localhost:3000/summarize \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"$sample_text\",
            \"instructions\": \"Create a bullet-point summary with key points\",
            \"max_tokens\": 150
        }" --max-time 60 2>/dev/null); then
        
        if echo "$response" | jq -e '.summary' >/dev/null 2>&1; then
            echo "$response" | jq -r '.summary'
            print_success "Bullet point summarization test passed"
        else
            print_error "Bullet point summarization test failed - invalid response format"
        fi
    else
        print_error "Bullet point summarization test failed - connection error"
    fi
    
    echo ""
    echo ""
    
    # Test 3: Technical summary
    print_status "Test 3: Technical summary for experts"
    echo "------------------------------------"
    if response=$(curl -s -X POST http://localhost:3000/summarize \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"$sample_text\",
            \"instructions\": \"Provide a technical summary focusing on AI subdomains and challenges\",
            \"max_tokens\": 120
        }" --max-time 60 2>/dev/null); then
        
        if echo "$response" | jq -e '.summary' >/dev/null 2>&1; then
            echo "$response" | jq -r '.summary'
            print_success "Technical summarization test passed"
        else
            print_error "Technical summarization test failed - invalid response format"
        fi
    else
        print_error "Technical summarization test failed - connection error"
    fi
    
    echo ""
    print_success "Summarization testing complete!"
}

# Function to test custom summarization endpoint
test_custom_summarize() {
    print_status "🎨 Testing /custom-summarize endpoint..."
    echo ""
    
    local sample_text="Artificial Intelligence (AI) has been one of the most transformative technologies of the 21st century. From its early theoretical foundations laid by pioneers like Alan Turing in the 1950s, AI has evolved from simple rule-based systems to sophisticated machine learning algorithms capable of tasks that were once thought to be exclusively human. Today, AI powers everything from recommendation systems on streaming platforms to autonomous vehicles navigating complex city streets. The field encompasses various subdomains including natural language processing, computer vision, robotics, and deep learning. Machine learning, in particular, has seen explosive growth with the development of neural networks that can learn from vast amounts of data. However, with great power comes great responsibility, and the AI community continues to grapple with ethical considerations around bias, privacy, job displacement, and the potential for artificial general intelligence. As we move forward, the integration of AI into our daily lives will only deepen, making it crucial for society to understand both its potential benefits and risks."
    
    # Test 1: Bullet-point style summary
    print_status "Test 1: Bullet-point style summary"
    echo "--------------------------------"
    if response=$(curl -s -X POST http://localhost:3000/custom-summarize \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"$sample_text\",
            \"style\": \"bullet-points\",
            \"tone\": \"neutral\",
            \"length\": \"medium\",
            \"max_tokens\": 200
        }" --max-time 60 2>/dev/null); then
        
        if echo "$response" | jq -e '.summary' >/dev/null 2>&1; then
            echo "$response" | jq -r '.summary'
            print_success "Bullet-point style test passed"
        else
            print_error "Bullet-point style test failed - invalid response format"
            echo "Response: $response"
        fi
    else
        print_error "Bullet-point style test failed - connection error"
    fi
    
    echo ""
    echo ""
    
    # Test 2: Technical summary with formal tone
    print_status "Test 2: Technical summary with formal tone"
    echo "----------------------------------------"
    if response=$(curl -s -X POST http://localhost:3000/custom-summarize \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"$sample_text\",
            \"style\": \"technical\",
            \"tone\": \"formal\",
            \"length\": \"long\",
            \"focus_areas\": [\"machine learning\", \"ethics\", \"applications\"],
            \"max_tokens\": 250
        }" --max-time 60 2>/dev/null); then
        
        if echo "$response" | jq -e '.summary' >/dev/null 2>&1; then
            echo "$response" | jq -r '.summary'
            print_success "Technical formal summary test passed"
        else
            print_error "Technical formal summary test failed - invalid response format"
        fi
    else
        print_error "Technical formal summary test failed - connection error"
    fi
    
    echo ""
    echo ""
    
    # Test 3: Creative summary with casual tone
    print_status "Test 3: Creative summary with casual tone"
    echo "---------------------------------------"
    if response=$(curl -s -X POST http://localhost:3000/custom-summarize \
        -H "Content-Type: application/json" \
        -d "{
            \"text\": \"$sample_text\",
            \"style\": \"creative\",
            \"tone\": \"casual\",
            \"length\": \"short\",
            \"max_tokens\": 150
        }" --max-time 60 2>/dev/null); then
        
        if echo "$response" | jq -e '.summary' >/dev/null 2>&1; then
            echo "$response" | jq -r '.summary'
            print_success "Creative casual summary test passed"
        else
            print_error "Creative casual summary test failed - invalid response format"
        fi
    else
        print_error "Creative casual summary test failed - connection error"
    fi
    
    echo ""
    print_success "Custom summarization testing complete!"
}

# Function to show usage
show_usage() {
    echo "Local LLM Management Script"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status           - Check containers, models, and API status"
    echo "  check-curl       - Specifically check services started with curl method"
    echo "  test             - Run a quick API test"
    echo "  tests            - Run comprehensive API tests"
    echo "  test-summarize   - Test the /summarize endpoint with different scenarios"
    echo "  test-custom-summarize - Test the /custom-summarize endpoint with different styles"
    echo "  start            - Start the Docker containers (development mode)"
    echo "  start-prod       - Start using pre-built image (production mode)"
    echo "  start-curl       - Start using curl method (same as one-liner deployment)"
    echo "  stop             - Stop the Docker containers"
    echo "  restart          - Restart the Docker containers"
    echo "  logs             - Show container logs"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 check-curl    # Check services started with the curl command"
    echo "  $0 test"
    echo "  $0 start         # Build and run from source"
    echo "  $0 start-prod    # Use pre-built image"
    echo "  $0 start-curl    # Same as: curl -s ... | docker compose -f - up -d"
}

# Main logic
case "${1:-status}" in
    "check-curl")
        echo "🔍 Checking services started with curl method"
        echo "============================================="
        echo ""
        print_status "Looking for containers started from remote docker-compose..."
        
        # Check if containers exist with the expected naming pattern
        curl_containers=$(docker ps --format "{{.Names}}" | grep -E "^[a-f0-9]+-.*-(ollama|api)-[0-9]+$")
        
        if [ -n "$curl_containers" ]; then
            print_success "Found containers started from curl method:"
            echo "$curl_containers" | while read container; do
                echo "  • $container"
            done
            echo ""
            check_models && test_api
        else
            print_error "No containers found that match the curl deployment pattern"
            print_warning "Try running the curl command again:"
            echo "  curl -s https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml | docker compose -f - up -d"
        fi
        ;;
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
    "test-summarize")
        test_summarize
        ;;
    "test-custom-summarize")
        test_custom_summarize
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
    "start-curl")
        print_status "Starting Local LLM services using curl method (same as the one-liner)..."
        curl -s https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml | docker compose -f - up -d
        print_success "Services started using curl method"
        ;;
    "stop")
        print_status "Stopping Local LLM services..."
        
        # Try different methods to stop the services
        stopped=false
        
        # Method 1: Try with local docker-compose files
        if [ -f "docker-compose.yml" ]; then
            docker compose down 2>/dev/null && stopped=true
        fi
        
        if [ -f "docker-compose.prod.yml" ]; then
            docker compose -f docker-compose.prod.yml down 2>/dev/null && stopped=true
        fi
        
        # Method 2: Find and stop containers by name pattern
        if ! $stopped; then
            ollama_containers=$(docker ps --format "{{.Names}}" | grep -E "(ollama|local-llm.*ollama)")
            api_containers=$(docker ps --format "{{.Names}}" | grep -E "(api|local-llm.*api)")
            
            if [ -n "$ollama_containers" ] || [ -n "$api_containers" ]; then
                echo "$ollama_containers $api_containers" | xargs -r docker stop
                stopped=true
            fi
        fi
        
        if $stopped; then
            print_success "Services stopped"
        else
            print_warning "No running services found to stop"
        fi
        ;;
    "restart")
        print_status "Restarting Local LLM services..."
        
        # Try different methods to restart the services
        restarted=false
        
        # Method 1: Try with local docker-compose files
        if [ -f "docker-compose.yml" ] && docker compose ps >/dev/null 2>&1; then
            docker compose restart && restarted=true
        elif [ -f "docker-compose.prod.yml" ] && docker compose -f docker-compose.prod.yml ps >/dev/null 2>&1; then
            docker compose -f docker-compose.prod.yml restart && restarted=true
        fi
        
        # Method 2: Find and restart containers by name pattern
        if ! $restarted; then
            ollama_containers=$(docker ps --format "{{.Names}}" | grep -E "(ollama|local-llm.*ollama)")
            api_containers=$(docker ps --format "{{.Names}}" | grep -E "(api|local-llm.*api)")
            
            if [ -n "$ollama_containers" ] || [ -n "$api_containers" ]; then
                echo "$ollama_containers $api_containers" | xargs -r docker restart
                restarted=true
            fi
        fi
        
        if $restarted; then
            print_success "Services restarted"
        else
            print_warning "No running services found to restart"
        fi
        ;;
    "logs")
        print_status "Showing container logs..."
        # Try to find logs from any running containers that might be our services
        ollama_container=$(docker ps --format "{{.Names}}" | grep -E "(ollama|local-llm.*ollama)" | head -1)
        api_container=$(docker ps --format "{{.Names}}" | grep -E "(api|local-llm.*api)" | head -1)
        
        if [ -n "$ollama_container" ] || [ -n "$api_container" ]; then
            if [ -n "$ollama_container" ]; then
                echo "=== Ollama Logs ==="
                docker logs -f --tail 50 "$ollama_container" &
            fi
            if [ -n "$api_container" ]; then
                echo "=== API Logs ==="
                docker logs -f --tail 50 "$api_container" &
            fi
            wait
        else
            print_error "No running services found"
            print_warning "Available containers:"
            docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
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
