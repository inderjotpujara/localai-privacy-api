# local llm (Phase 1)

## Quickstart

### Option 1: Production Deployment (Recommended)

**One-command deployment with pre-built image:**

```bash
curl -s https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml | docker compose -f - up -d
```

**Or step-by-step:**

1. Download the production compose file:
```bash
curl -O https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.prod.yml
```

2. Start the services:
```bash
docker compose -f docker-compose.prod.yml up -d
```

3. Wait for Ollama to download the Llama 3.2 1B model (first run only)

*Uses pre-built Docker image from GitHub Container Registry - no compilation needed!*

### Option 2: Development (Build from Source)

1. Clone this repo
2. `docker compose up --build`
3. Wait for Ollama to download the Llama 3.2 1B model (first run only)

*Builds the API from source code - useful for development and modifications.*

### Test the API:

```bash
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "Hello! Say hi back."}],
    "max_tokens": 50
  }'
```

## What's running?

- Ollama with Llama 3.2 1B model on :11434
- Node.js Express API proxy on :3000

## Architecture

This is a privacy-first microservice that brings up:

- A lightweight Ollama service with Llama 3.2 1B model running locally
- A minimal Node.js TypeScript Express API that exposes a `/chat` endpoint
- Everything runs locally via Docker Compose - no external dependencies

## Features

- **POST /chat**: Proxies requests to Ollama's OpenAI-compatible `/v1/chat/completions` endpoint
- **Multi-arch support**: Compatible with both Apple Silicon (arm64) and x86 architectures
- **TypeScript**: Fully typed API implementation
- **Docker Compose**: Single command deployment
- **Model**: Uses Llama 3.2 1B for fast, efficient local inference
- **Pre-built Images**: Available on GitHub Container Registry for instant deployment

## Docker Images

Pre-built Docker images are automatically built and published to GitHub Container Registry on every push to main:

- **Latest stable**: `ghcr.io/inderjotpujara/localai-privacy-api:latest`
- **Development**: `ghcr.io/inderjotpujara/localai-privacy-api:main`

**Automated builds include:**
- ✅ Multi-architecture support (AMD64 + ARM64)
- ✅ Automatic testing and validation
- ✅ Optimized caching for faster builds
- ✅ Public availability (no authentication required)

### Manual Docker Run

You can also run the API container manually:

```bash
# Start Ollama first
docker run -d --name ollama -p 11434:11434 -v ollama:/root/.ollama ollama/ollama:latest

# Start the API
docker run -d --name local-llm-api \
  -p 3000:3000 \
  -e LLM_BASE_URL=http://host.docker.internal:11434/v1 \
  ghcr.io/inderjotpujara/localai-privacy-api:latest
```

## Development

To run in development mode:

```bash
cd api
npm install
npm run build
npm start
```

Then start Ollama separately or use the full Docker Compose setup.

## Management Script

Use the included management script for easy operations:

```bash
# Check status of containers, models, and API
./scripts/manage.sh status

# Quick API test
./scripts/manage.sh test

# Run comprehensive tests
./scripts/manage.sh tests

# Start/stop/restart services
./scripts/manage.sh start
./scripts/manage.sh stop
./scripts/manage.sh restart

# View logs
./scripts/manage.sh logs
```

## Model Information

The project uses Llama 3.2 1B, which is automatically downloaded on first run. The model provides:

- Fast inference (2-5 seconds per request)
- Small size (~1.3GB)
- Good quality responses for general chat

## Next Steps (Future Phases)

- JWT authentication
- RAG (Retrieval Augmented Generation) capabilities
- Additional model support
- Enhanced error handling and logging

## 🚀 How It Works

This project provides **two ways** to run the Local LLM:

### 1. **Production Mode** (`docker-compose.prod.yml`)
- ✅ **Pulls pre-built image** from GitHub Container Registry
- ✅ **No compilation** - instant deployment
- ✅ **Multi-architecture** support (AMD64 + ARM64)
- ✅ **Health checks** and auto-restart
- ✅ **Perfect for users** who just want to use the API

### 2. **Development Mode** (`docker-compose.yml`)
- 🔧 **Builds from source** code in `./api/` directory
- 🔧 **Good for development** and modifications
- 🔧 **Platform-specific** builds
- 🔧 **Perfect for contributors** who want to modify the code

The **GitHub workflow** automatically builds and publishes the Docker image whenever code is pushed to main, so users can always get the latest stable version without compiling anything!
