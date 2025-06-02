#!/bin/bash
set -e

API_BASE="http://localhost:3000"
JWT_SECRET="your-super-secret-jwt-key-change-this-in-production"

echo "=== Testing Local LLM API ==="
echo ""

# Test 1: Health Check
echo "1. Testing Health Endpoint..."
HEALTH_RESPONSE=$(curl -s "$API_BASE/health")
echo "   Response: $HEALTH_RESPONSE"
echo ""

# Test 2: Generate JWT Token (for authenticated endpoints)
echo "2. Generating test JWT token..."
# Create a simple test token (in production, this would be done through login)
TEST_PAYLOAD='{"sub":"test-user","iat":1706000000,"exp":9999999999}'
# For testing, we'll use a mock token - in real scenario, this would come from login
TEST_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXIiLCJpYXQiOjE3MDYwMDAwMDAsImV4cCI6OTk5OTk5OTk5OX0.fake-signature-for-testing"
echo "   Test token generated (mock)"
echo ""

# Test 3: RAG Document Upload
echo "3. Testing RAG Document Upload..."
cat > test_document.txt << EOF
This is a test document for the RAG system.
It contains information about Node.js and TypeScript development.
The document explains how to build APIs with Express.js.
LocalAI is used for language model inference.
PostgreSQL with pgvector stores document embeddings.
EOF

UPLOAD_RESPONSE=$(curl -s -X POST "$API_BASE/rag/documents" \
  -H "Content-Type: multipart/form-data" \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -F "file=@test_document.txt" \
  -F "title=Test Document" \
  -F "description=A test document for API validation")

echo "   Response: $UPLOAD_RESPONSE"
echo ""

# Test 4: List Documents
echo "4. Testing List Documents..."
LIST_RESPONSE=$(curl -s "$API_BASE/rag/documents" \
  -H "Authorization: Bearer $TEST_TOKEN")
echo "   Response: $LIST_RESPONSE"
echo ""

# Test 5: RAG Query (will fail until LocalAI is ready, but tests routing)
echo "5. Testing RAG Query..."
QUERY_RESPONSE=$(curl -s -X POST "$API_BASE/rag/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -d '{"query":"What is this document about?","limit":3}')
echo "   Response: $QUERY_RESPONSE"
echo ""

# Test 6: Chat Endpoint (will fail until LocalAI is ready, but tests routing)
echo "6. Testing Chat Endpoint..."
CHAT_RESPONSE=$(curl -s -X POST "$API_BASE/chat" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TEST_TOKEN" \
  -d '{"message":"Hello, how are you?","model":"phi-2"}')
echo "   Response: $CHAT_RESPONSE"
echo ""

# Cleanup
rm -f test_document.txt

echo "=== API Test Complete ==="
echo ""
echo "Note: Chat and RAG query endpoints may fail if LocalAI is not ready."
echo "Check LocalAI status with: docker-compose logs localai"
