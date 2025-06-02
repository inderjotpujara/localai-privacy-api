#!/bin/bash

# Docker-only API testing script
# Tests all API endpoints using only Docker containers

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

echo "🧪 LocalAI API - Docker-Only Testing"
echo "===================================="
echo ""

# Check if services are running
if ! docker-compose ps api | grep -q "Up"; then
    print_error "API service is not running. Please start with: docker-compose up -d"
    exit 1
fi

# Test configuration
API_URL="http://localhost:3000"
TEST_CONTAINER="local-llm-api"

# Function to make API calls using docker exec
docker_curl() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local headers="$4"
    
    local cmd="curl -s -X $method"
    
    if [ -n "$headers" ]; then
        cmd="$cmd $headers"
    fi
    
    if [ -n "$data" ]; then
        cmd="$cmd -d '$data'"
    fi
    
    cmd="$cmd $API_URL$endpoint"
    
    docker-compose exec -T api sh -c "$cmd"
}

# Function to test endpoint
test_endpoint() {
    local name="$1"
    local method="$2"
    local endpoint="$3"
    local expected_status="$4"
    local data="$5"
    local headers="$6"
    
    print_status "Testing $name..."
    
    local response
    response=$(docker_curl "$method" "$endpoint" "$data" "$headers" 2>/dev/null || echo "ERROR")
    
    if [ "$response" = "ERROR" ]; then
        print_error "$name failed - connection error"
        return 1
    fi
    
    # Check if response contains expected content
    case "$expected_status" in
        "200")
            if echo "$response" | grep -q "status\|healthy\|ok\|success\|token\|models"; then
                print_success "$name passed"
                return 0
            else
                print_error "$name failed - unexpected response: $response"
                return 1
            fi
            ;;
        "401")
            if echo "$response" | grep -q "unauthorized\|Unauthorized\|token\|authentication"; then
                print_success "$name passed (correctly unauthorized)"
                return 0
            else
                print_error "$name failed - should be unauthorized"
                return 1
            fi
            ;;
        *)
            print_success "$name completed"
            return 0
            ;;
    esac
}

# Test counter
tests_passed=0
tests_failed=0

# Test 1: Health Check
if test_endpoint "Health Check" "GET" "/health" "200"; then
    ((tests_passed++))
else
    ((tests_failed++))
fi

# Test 2: Authentication - Login
print_status "Testing Authentication - Login..."
login_data='{"username": "admin", "password": "admin123"}'
login_headers='-H "Content-Type: application/json"'

login_response=$(docker_curl "POST" "/auth/login" "$login_data" "$login_headers" 2>/dev/null || echo "ERROR")

if echo "$login_response" | grep -q "token"; then
    print_success "Authentication - Login passed"
    # Extract token
    token=$(echo "$login_response" | sed 's/.*"token":"\([^"]*\)".*/\1/' 2>/dev/null || echo "")
    if [ -n "$token" ]; then
        print_success "JWT token extracted successfully"
        auth_header="-H \"Authorization: Bearer $token\""
    else
        print_warning "Could not extract token from response"
        auth_header=""
    fi
    ((tests_passed++))
else
    print_error "Authentication - Login failed: $login_response"
    auth_header=""
    ((tests_failed++))
fi

# Test 3: Protected endpoint without auth
if test_endpoint "Chat without Auth" "POST" "/chat" "401" '{"message": "Hello"}' '-H "Content-Type: application/json"'; then
    ((tests_passed++))
else
    ((tests_failed++))
fi

# Test 4: Chat endpoint with auth (if we have a token)
if [ -n "$token" ]; then
    print_status "Testing Chat endpoint with authentication..."
    chat_data='{"message": "Hello, can you respond with just \"Hi there!\"?", "stream": false}'
    chat_headers='-H "Content-Type: application/json" -H "Authorization: Bearer '$token'"'
    
    chat_response=$(docker_curl "POST" "/chat" "$chat_data" "$chat_headers" 2>/dev/null || echo "ERROR")
    
    if [ "$chat_response" != "ERROR" ] && [ -n "$chat_response" ]; then
        print_success "Chat endpoint with auth passed"
        echo "  Response preview: $(echo "$chat_response" | head -c 100)..."
        ((tests_passed++))
    else
        print_error "Chat endpoint with auth failed: $chat_response"
        ((tests_failed++))
    fi
else
    print_warning "Skipping authenticated chat test (no token)"
fi

# Test 5: RAG endpoints with auth (if we have a token)
if [ -n "$token" ]; then
    # Test RAG document upload
    print_status "Testing RAG document upload..."
    rag_doc_data='{"content": "Docker is a containerization platform that helps developers build, ship, and run applications.", "metadata": {"title": "Docker Info", "type": "documentation"}}'
    rag_headers='-H "Content-Type: application/json" -H "Authorization: Bearer '$token'"'
    
    rag_doc_response=$(docker_curl "POST" "/rag/documents" "$rag_doc_data" "$rag_headers" 2>/dev/null || echo "ERROR")
    
    if echo "$rag_doc_response" | grep -q "success\|id\|created"; then
        print_success "RAG document upload passed"
        ((tests_passed++))
        
        # Test RAG query
        print_status "Testing RAG query..."
        rag_query_data='{"query": "What is Docker?", "limit": 3}'
        
        rag_query_response=$(docker_curl "POST" "/rag/query" "$rag_query_data" "$rag_headers" 2>/dev/null || echo "ERROR")
        
        if [ "$rag_query_response" != "ERROR" ] && [ -n "$rag_query_response" ]; then
            print_success "RAG query passed"
            echo "  Response preview: $(echo "$rag_query_response" | head -c 100)..."
            ((tests_passed++))
        else
            print_error "RAG query failed: $rag_query_response"
            ((tests_failed++))
        fi
    else
        print_error "RAG document upload failed: $rag_doc_response"
        ((tests_failed++))
    fi
else
    print_warning "Skipping RAG tests (no token)"
fi

# Test 6: LocalAI Models endpoint
print_status "Testing LocalAI models endpoint..."
models_response=$(docker-compose exec -T api sh -c "curl -s http://localai:8080/v1/models" 2>/dev/null || echo "ERROR")

if echo "$models_response" | grep -q "data\|models\|id"; then
    print_success "LocalAI models endpoint passed"
    model_count=$(echo "$models_response" | grep -o '"id"' | wc -l 2>/dev/null || echo "0")
    echo "  Available models: $model_count"
    ((tests_passed++))
else
    print_error "LocalAI models endpoint failed: $models_response"
    ((tests_failed++))
fi

# Test 7: Database connectivity
print_status "Testing database connectivity..."
db_test=$(docker-compose exec -T postgres psql -U llm_user -d llm_db -c "SELECT 1;" 2>/dev/null | grep -c "1" || echo "0")

if [ "$db_test" -gt 0 ]; then
    print_success "Database connectivity passed"
    ((tests_passed++))
else
    print_error "Database connectivity failed"
    ((tests_failed++))
fi

# Test 8: Log aggregation (optional)
print_status "Testing log aggregation..."
loki_response=$(docker-compose exec -T api sh -c "curl -s http://loki:3100/ready" 2>/dev/null || echo "ERROR")

if echo "$loki_response" | grep -q "ready"; then
    print_success "Log aggregation (Loki) passed"
    ((tests_passed++))
else
    print_warning "Log aggregation (Loki) not available (non-critical)"
fi

echo ""
echo "📊 Test Results"
echo "==============="
echo "✅ Passed: $tests_passed"
echo "❌ Failed: $tests_failed"
echo "📦 Total:  $((tests_passed + tests_failed))"

if [ $tests_failed -eq 0 ]; then
    print_success "All critical tests passed! 🎉"
    echo ""
    echo "🔗 Available Services:"
    echo "  - API Documentation: http://localhost:3000/health"
    echo "  - LocalAI: http://localhost:8080"
    echo "  - Grafana: http://localhost:3001"
    echo ""
    echo "🔑 Test Credentials Used:"
    echo "  - Username: admin"
    echo "  - Password: admin123"
    echo ""
    exit 0
else
    print_error "Some tests failed. Check service logs:"
    echo "  docker-compose logs api"
    echo "  docker-compose logs localai"
    echo "  docker-compose logs postgres"
    echo ""
    exit 1
fi
