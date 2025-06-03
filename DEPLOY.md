# Quick Deployment Guide

Deploy Local LLM in seconds using pre-built Docker images.

## One-Command Deployment

```bash
# Download and start with pre-built image
curl -s https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml | docker compose -f - up -d
```

## Step-by-Step Deployment

1. **Download the production compose file:**
```bash
curl -O https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml
```

2. **Start the services:**
```bash
docker compose -f docker-compose.prod.yml up -d
```

3. **Wait for model download (first run only):**
```bash
# Check logs to see download progress
docker compose -f docker-compose.prod.yml logs -f ollama
```

4. **Test the API:**
```bash
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

## Advanced Options

### Custom Model
To use a different model, modify the Ollama service after startup:

```bash
# Pull a different model
docker exec -it $(docker compose -f docker-compose.prod.yml ps -q ollama) ollama pull llama3.2:3b

# Use it in your API calls
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:3b",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 50
  }'
```

### Environment Variables
Create a `.env` file to customize settings:

```bash
# .env file
LLM_BASE_URL=http://ollama:11434/v1
PORT=3000
OLLAMA_HOST=0.0.0.0
```

### Update to Latest
```bash
# Pull latest images and restart
docker compose -f docker-compose.prod.yml pull
docker compose -f docker-compose.prod.yml up -d
```

## Monitoring

### Health Checks
Both services include health checks:
```bash
docker compose -f docker-compose.prod.yml ps
```

### Resource Usage
```bash
docker stats $(docker compose -f docker-compose.prod.yml ps -q)
```

### Logs
```bash
# All services
docker compose -f docker-compose.prod.yml logs -f

# Specific service
docker compose -f docker-compose.prod.yml logs -f api
docker compose -f docker-compose.prod.yml logs -f ollama
```

## Cleanup

```bash
# Stop and remove containers
docker compose -f docker-compose.prod.yml down

# Remove volumes (this will delete downloaded models)
docker compose -f docker-compose.prod.yml down -v
```
