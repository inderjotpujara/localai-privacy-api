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

_Uses pre-built Docker image from GitHub Container Registry - no compilation needed!_

### Option 2: Development (Build from Source)

1. Clone this repo
2. `docker compose up --build`
3. Wait for Ollama to download the Llama 3.2 1B model (first run only)

_Builds the API from source code - useful for development and modifications._

### Test the API:

**Chat endpoint:**

```bash
curl -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role": "user", "content": "Hello! Say hi back."}],
    "max_tokens": 50
  }'
```

**Basic summarize endpoint:**

```bash
curl -X POST http://localhost:3000/summarize \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Your long text to summarize goes here. This can be articles, documents, or any text content that you want to get a concise summary of.",
    "instructions": "Provide a brief summary in 2-3 sentences",
    "max_tokens": 100
  }'
```

**Advanced custom summarize endpoint:**

```bash
curl -X POST http://localhost:3000/custom-summarize \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Your text content here...",
    "style": "bullet-points",
    "tone": "formal",
    "length": "medium",
    "focus_areas": ["key points", "important details"],
    "max_tokens": 200
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
- **POST /summarize**: Intelligent text summarization with customizable instructions and parameters
- **POST /custom-summarize**: Advanced summarization with style, tone, length, and focus area controls
  - **Styles**: concise, detailed, bullet-points, technical, creative
  - **Tones**: neutral, formal, casual, academic
  - **Lengths**: short, medium, long
  - **Focus areas**: Specify particular topics to emphasize
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

# Test summarization endpoints
./scripts/manage.sh test-summarize
./scripts/manage.sh test-custom-summarize

# Start/stop/restart services
./scripts/manage.sh start
./scripts/manage.sh stop
./scripts/manage.sh restart

# View logs
./scripts/manage.sh logs
```

### Testing the Summarization Features

The management script includes comprehensive testing for both summarization endpoints:

- **Basic summarization tests** (`test-summarize`): Tests the `/summarize` endpoint with different instruction types
- **Custom summarization tests** (`test-custom-summarize`): Tests the `/custom-summarize` endpoint with various style, tone, and length combinations

## API Endpoints

### POST /chat

Standard OpenAI-compatible chat completions endpoint.

### POST /summarize

Simple text summarization with customizable instructions.

**Parameters:**

- `text` (required): The text to summarize
- `instructions` (optional): Custom instructions for the summary (default: "Provide a concise summary")
- `max_tokens` (optional): Maximum tokens in response (default: 150)
- `model` (optional): Model to use (default: "llama3.2:1b")

### POST /custom-summarize

Advanced summarization with granular control over style and output.

**Parameters:**

- `text` (required): The text to summarize
- `style` (optional): "concise", "detailed", "bullet-points", "technical", "creative" (default: "concise")
- `tone` (optional): "neutral", "formal", "casual", "academic" (default: "neutral")
- `length` (optional): "short", "medium", "long" (default: "medium")
- `focus_areas` (optional): Array of specific topics to emphasize
- `max_tokens` (optional): Maximum tokens in response (default: 200)
- `model` (optional): Model to use (default: "llama3.2:1b")

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
