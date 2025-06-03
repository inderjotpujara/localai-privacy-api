#!/bin/bash

echo "🔍 Local LLM Status Check"
echo "======================="
echo ""

echo "📦 Docker Containers:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep local-llm

echo ""
echo "🤖 Available Models:"
curl -s http://localhost:11434/api/tags | jq -r '.models[].name' 2>/dev/null || echo "Could not fetch models"

echo ""
echo "🌐 API Health Check:"
curl -s http://localhost:3000/chat \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"model":"llama3.2:1b","messages":[{"role":"user","content":"Hi"}],"max_tokens":10}' \
  --max-time 30 | jq -r '.choices[0].message.content' 2>/dev/null && echo "✅ API is working!" || echo "❌ API test failed"
