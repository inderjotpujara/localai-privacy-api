# Local LLM API Façade

A privacy-first Node.js (TypeScript) API façade that proxies LocalAI running Llama-3 on Apple Silicon, with streaming chat, RAG capabilities, JWT auth, and full observability stack.

## Features

- 🤖 **Chat Endpoint**: `/chat` with streaming support (SSE) and regular responses
- 🔍 **RAG Query**: `/rag/query` for vector-based semantic search
- 🔐 **JWT Authentication**: Local token verification
- 🏠 **Privacy-First**: All data, embeddings, and logs remain local
- 📊 **Observability**: Loki, Promtail, Grafana stack
- 🐳 **Docker Compose**: Full orchestration
- 🚀 **CI/CD**: Multi-arch Docker builds (arm64/amd64)
- 🍎 **Apple Metal**: Optional native acceleration

## Quick Start

1. **Clone and Setup**
   ```bash
   git clone <repo-url>
   cd local-llm
   cp .env.sample .env
   # Edit .env with your configurations
   ```

2. **Start Services**
   ```bash
   docker-compose up -d
   ```

3. **Test Chat**
   ```bash
   curl -X POST http://localhost:3000/chat \
     -H "Authorization: Bearer your-jwt-token" \
     -H "Content-Type: application/json" \
     -d '{"message": "Hello, world!"}'
   ```

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client App    │ ──▶│   Node.js API   │ ──▶│    LocalAI      │
│                 │    │   (TypeScript)  │    │   (Llama-3)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │ Postgres+pgvector│
                       │   (RAG Store)   │
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │ Loki+Grafana    │
                       │ (Observability) │
                       └─────────────────┘
```

## API Endpoints

### Chat
```bash
# Regular chat
POST /chat
{
  "message": "Your message",
  "stream": false
}

# Streaming chat (SSE)
POST /chat
{
  "message": "Your message", 
  "stream": true
}
```

### RAG Query
```bash
POST /rag/query
{
  "query": "Search query",
  "limit": 5
}
```

## Development

```bash
cd api
npm install
npm run dev
```

## Docker Hub

Multi-arch images are automatically built and pushed:
- `your-username/local-llm:latest`
- `your-username/local-llm:${GITHUB_SHA}`

## Privacy Guarantees

| Component | Data Location | External Calls |
|-----------|---------------|----------------|
| Chat Messages | Local only | None |
| Vector Embeddings | Local pgvector | None |
| Auth Tokens | Local verification | None |
| Logs/Metrics | Local Loki/Grafana | None |
| Model Weights | Local Docker volumes | None |

## Apple Silicon Notes

For optimal performance on Apple Silicon:
1. Use LocalAI with Metal acceleration
2. Set `LOCALAI_BACKEND=metal` in `.env`
3. Ensure Docker Desktop uses Apple Silicon images

## Contributing

1. Make atomic commits with clear messages
2. All data must remain local
3. No external API dependencies
4. Test both streaming and regular endpoints

## License

MIT
