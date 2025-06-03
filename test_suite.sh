#!/bin/bash

echo "🚀 Local LLM API Test Suite"
echo "=========================="
echo ""

# Test 1: Simple greeting
echo "📝 Test 1: Simple greeting"
echo "Request: Hello! Say hi back."
echo "Response:"
curl -s -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "Hello! Say hi back in one sentence."}],
    "max_tokens": 30
  }' | jq -r '.choices[0].message.content' 2>/dev/null || echo "Error parsing response"

echo ""
echo "---"
echo ""

# Test 2: Math question  
echo "🔢 Test 2: Math question"
echo "Request: What is 2+2?"
echo "Response:"
curl -s -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d @test_math.json | jq -r '.choices[0].message.content' 2>/dev/null || echo "Error parsing response"

echo ""
echo "---"
echo ""

# Test 3: Show full response structure
echo "🔍 Test 3: Full API response structure"
echo "Request: Tell me a very short joke."
echo "Response:"
curl -s -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b", 
    "messages": [{"role": "user", "content": "Tell me a very short joke in one sentence."}],
    "max_tokens": 40
  }' | jq '.' 2>/dev/null || echo "Raw response received"

echo ""
echo "✅ Test suite completed!"
echo "If you see responses above, the Local LLM API is working correctly!"
