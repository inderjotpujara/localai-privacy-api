#!/bin/bash

echo "Testing Local LLM API..."
echo "========================"

echo "Sending request to /chat endpoint..."
response=$(curl -s -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d @test_simple.json \
  --max-time 90)

echo "Response received:"
echo "$response" | jq '.' 2>/dev/null || echo "$response"

echo ""
echo "Test completed!"
