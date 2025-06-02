#!/bin/bash
set -e

# Load Testing Script for Local LLM API
API_BASE="${1:-http://localhost:3000}"
CONCURRENT_USERS="${2:-10}"
DURATION="${3:-60}"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"

echo "🔥 Starting Load Test for Local LLM API"
echo "   Target: $API_BASE"
echo "   Concurrent Users: $CONCURRENT_USERS"
echo "   Duration: ${DURATION}s"
echo ""

# Check if hey is installed
if ! command -v hey &> /dev/null; then
    echo "📦 Installing 'hey' load testing tool..."
    if command -v brew &> /dev/null; then
        brew install hey
    else
        echo "❌ Please install 'hey' load testing tool:"
        echo "   macOS: brew install hey"
        echo "   Linux: go install github.com/rakyll/hey@latest"
        exit 1
    fi
fi

# Create test data
echo "📝 Preparing test data..."
cat > test_payload.json << EOF
{
    "message": "What is artificial intelligence?",
    "model": "phi-2",
    "stream": false
}
EOF

cat > test_rag_payload.json << EOF
{
    "query": "Tell me about Node.js development",
    "limit": 3
}
EOF

# Generate test JWT token (simplified for testing)
TEST_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXIiLCJpYXQiOjE3MDYwMDAwMDAsImV4cCI6OTk5OTk5OTk5OX0.fake-signature-for-testing"

echo "🏥 Testing API Health..."
hey -n 100 -c 10 -t 5 "$API_BASE/health"

echo ""
echo "🔐 Testing Authenticated Endpoints..."

# Test Chat endpoint (will fail if LocalAI not ready, but tests routing/auth)
echo "💬 Testing Chat Endpoint..."
hey -n 50 -c 5 -t 30 \
    -m POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TEST_TOKEN" \
    -d @test_payload.json \
    "$API_BASE/chat"

echo ""
echo "📚 Testing RAG Query Endpoint..."
hey -n 50 -c 5 -t 30 \
    -m POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TEST_TOKEN" \
    -d @test_rag_payload.json \
    "$API_BASE/rag/query"

echo ""
echo "📄 Testing RAG Documents List..."
hey -n 100 -c 10 -t 10 \
    -H "Authorization: Bearer $TEST_TOKEN" \
    "$API_BASE/rag/documents"

# Stress test
echo ""
echo "🚀 Running Stress Test ($CONCURRENT_USERS concurrent users for ${DURATION}s)..."
hey -z ${DURATION}s -c $CONCURRENT_USERS -t 30 "$API_BASE/health"

# Cleanup
rm -f test_payload.json test_rag_payload.json

echo ""
echo "✅ Load testing complete!"
echo ""
echo "📊 Additional monitoring:"
echo "   System resources: htop or top"
echo "   Docker stats: docker stats"
echo "   Application logs: docker-compose logs -f api"
