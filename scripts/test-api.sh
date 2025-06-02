#!/bin/bash

# test-api.sh - Test the Local LLM API endpoints

set -e

# Configuration
API_URL="http://localhost:3000"
JWT_TOKEN=""

echo "🧪 Testing Local LLM API..."

# Generate a test JWT token (you'll need to replace this with your actual token generation)
echo "🔐 Generating test JWT token..."
JWT_TOKEN=$(curl -s -X POST "$API_URL/auth/token" \
  -H "Content-Type: application/json" \
  -d '{"user_id": "test-user", "email": "test@example.com"}' | \
  jq -r '.token' || echo "")

if [ -z "$JWT_TOKEN" ]; then
  echo "⚠️  Could not generate JWT token. Using a test token instead."
  # For testing purposes, you can use the generateTestToken function
  JWT_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJ0ZXN0LXVzZXIiLCJpZCI6InRlc3QtdXNlciIsImVtYWlsIjoidGVzdEBleGFtcGxlLmNvbSIsImlhdCI6MTcwMDAwMDAwMCwiZXhwIjoxNzAwMDg2NDAwfQ.example"
fi

echo "🔑 Using JWT token: ${JWT_TOKEN:0:20}..."

# Test health endpoint (no auth required)
echo "🏥 Testing health endpoint..."
curl -s "$API_URL/health" | jq '.' || echo "❌ Health check failed"

# Test chat endpoint (regular)
echo "💬 Testing chat endpoint (regular response)..."
curl -s -X POST "$API_URL/chat" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hello! Can you help me understand what you do?",
    "stream": false,
    "temperature": 0.7,
    "max_tokens": 100
  }' | jq '.' || echo "❌ Chat test failed"

# Test chat endpoint (streaming)
echo "🌊 Testing chat endpoint (streaming response)..."
curl -s -N -X POST "$API_URL/chat" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Count to 5 slowly.",
    "stream": true,
    "temperature": 0.3,
    "max_tokens": 50
  }' | head -20 || echo "❌ Streaming chat test failed"

# Test RAG - add a document
echo "📄 Testing RAG - adding a document..."
DOC_ID=$(curl -s -X POST "$API_URL/rag/documents" \
  -H "Authorization: Bearer $JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "content": "LocalAI is a self-hosted, community-driven, local OpenAI-compatible API. It acts as a drop-in replacement REST API that is compatible with OpenAI API specifications for local inferencing.",
    "metadata": {
      "source": "test",
      "category": "documentation"
    }
  }' | jq -r '.document_id' || echo "")

if [ -n "$DOC_ID" ] && [ "$DOC_ID" != "null" ]; then
  echo "✅ Document added with ID: $DOC_ID"
  
  # Test RAG query
  echo "🔍 Testing RAG query..."
  curl -s -X POST "$API_URL/rag/query" \
    -H "Authorization: Bearer $JWT_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
      "query": "What is LocalAI?",
      "limit": 3,
      "similarity_threshold": 0.5
    }' | jq '.' || echo "❌ RAG query test failed"
else
  echo "⚠️  Could not add document, skipping RAG query test"
fi

# Test models endpoint
echo "🤖 Testing models endpoint..."
curl -s "$API_URL/chat/models" \
  -H "Authorization: Bearer $JWT_TOKEN" | jq '.' || echo "❌ Models test failed"

echo "✅ API testing complete!"
echo ""
echo "📋 Manual testing URLs:"
echo "- Health: $API_URL/health"
echo "- Chat: POST $API_URL/chat"
echo "- RAG Query: POST $API_URL/rag/query"
echo "- Add Document: POST $API_URL/rag/documents"
