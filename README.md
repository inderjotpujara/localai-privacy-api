# Local LLM API Façade

A privacy-first Node.js (TypeScript) API façade that proxies LocalAI running Llama-3 on Apple Silicon, with streaming chat, RAG capabilities, JWT auth, and full observability stack.

## ✨ Features

- 🤖 **Chat Endpoint**: `/chat` with streaming support (SSE) and regular responses
- 🔍 **RAG System**: Document upload, vector search, and retrieval-augmented generation
- 📚 **Document Management**: Upload, list, retrieve, and delete documents with metadata
- 🔐 **JWT Authentication**: Secure local token verification
- 🏠 **Privacy-First**: All data, embeddings, and logs remain local - no external dependencies
- 📊 **Full Observability**: Loki + Promtail + Grafana stack with custom dashboards
- 🐳 **Container Orchestration**: Complete Docker Compose setup
- 🚀 **CI/CD Pipeline**: Multi-arch Docker builds (ARM64/AMD64) with GitHub Actions
- 🍎 **Apple Silicon Support**: Optimized for Apple M1/M2 with fallback compatibility
- ⚡ **High Performance**: Connection pooling, caching, and optimized queries
- 🧪 **Comprehensive Testing**: Unit tests, integration tests, and load testing scripts

## 🚀 Quick Start

### Development Environment

1. **Clone and Setup**

   ```bash
   git clone <repo-url>
   cd local-llm
   cp .env.sample .env
   # Edit .env with your configurations
   ```

2. **Start Infrastructure Services**

   ```bash
   # Start database, logging, and monitoring
   docker-compose up -d postgres loki grafana promtail
   ```

3. **Install Dependencies and Start API**

   ```bash
   cd api
   npm install
   npm run dev
   ```

4. **Start LocalAI (separate terminal)**
   ```bash
   docker-compose up -d localai
   ```

### Production Deployment

1. **Configure Production Environment**

   ```bash
   cp .env.prod.sample .env.prod
   # Edit .env.prod with secure passwords and secrets
   ```

2. **Deploy to Production**
   ```bash
   ./scripts/deploy-prod.sh
   ```

## 📡 API Endpoints

### Health Check

```bash
GET /health
# Returns: { status: "ok", timestamp: "...", services: {...} }
```

### Chat (Streaming & Non-Streaming)

```bash
# Regular chat
POST /chat
Headers: Authorization: Bearer <jwt-token>
Body: { "message": "Hello!", "model": "phi-2", "stream": false }

# Streaming chat (SSE)
POST /chat
Headers: Authorization: Bearer <jwt-token>
Body: { "message": "Hello!", "model": "phi-2", "stream": true }
```

### RAG Document Management

```bash
# Upload document
POST /rag/documents
Headers: Authorization: Bearer <jwt-token>
Body: multipart/form-data with file, title, description

# List documents
GET /rag/documents
Headers: Authorization: Bearer <jwt-token>

# Get specific document
GET /rag/documents/:id
Headers: Authorization: Bearer <jwt-token>

# Delete document
DELETE /rag/documents/:id
Headers: Authorization: Bearer <jwt-token>
```

### RAG Query

```bash
POST /rag/query
Headers: Authorization: Bearer <jwt-token>
Body: { "query": "What is Node.js?", "limit": 5 }
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

| Component         | Data Location        | External Calls |
| ----------------- | -------------------- | -------------- |
| Chat Messages     | Local only           | None           |
| Vector Embeddings | Local pgvector       | None           |
| Auth Tokens       | Local verification   | None           |
| Logs/Metrics      | Local Loki/Grafana   | None           |
| Model Weights     | Local Docker volumes | None           |

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

## 🧪 Testing

### Unit Tests

```bash
cd api
npm test
```

### Integration Testing

```bash
# Test all endpoints with mock data
./scripts/test-endpoints.sh
```

### Load Testing

```bash
# Test with 10 concurrent users for 60 seconds
./scripts/load-test.sh http://localhost:3000 10 60
```

## 📊 Monitoring & Observability

### Grafana Dashboard

- URL: http://localhost:3001
- Default credentials: admin/admin
- Dashboards include: API metrics, LocalAI performance, database stats

### Log Aggregation

- Loki: http://localhost:3100
- All logs centralized and searchable
- Structured logging with correlation IDs

### Health Checks

```bash
# API health
curl http://localhost:3000/health

# LocalAI health
curl http://localhost:8080/health

# Database health (via API)
curl http://localhost:3000/health | jq .services.database
```

## 🏗️ Project Structure

```
local-llm/
├── api/                    # Node.js TypeScript API
│   ├── src/
│   │   ├── routes/         # API route handlers
│   │   ├── services/       # Business logic services
│   │   ├── middleware/     # Auth, error handling, etc.
│   │   └── types/          # TypeScript type definitions
│   ├── tests/              # Unit and integration tests
│   └── Dockerfile          # Multi-stage Docker build
├── infra/                  # Infrastructure configuration
│   ├── postgres/           # Database init scripts
│   ├── grafana/            # Dashboards and datasources
│   ├── loki/              # Log aggregation config
│   └── promtail/          # Log collection config
├── models/                 # LLM model configurations
├── scripts/               # Development and deployment scripts
├── docker-compose.yml     # Development environment
├── docker-compose.prod.yml # Production environment
└── .github/workflows/     # CI/CD pipelines
```

## 🚀 Deployment

### Development

```bash
# Start all services in development mode
./scripts/development.sh
```

### Production

```bash
# Deploy to production with health checks
./scripts/deploy-prod.sh
```

### Docker Build

```bash
# Build multi-architecture images
docker buildx build --platform linux/amd64,linux/arm64 \
  -t your-registry/local-llm-api:latest \
  --push ./api
```

## 🔧 Configuration

### Environment Variables

| Variable       | Description                  | Default                 |
| -------------- | ---------------------------- | ----------------------- |
| `NODE_ENV`     | Environment mode             | `development`           |
| `PORT`         | API server port              | `3000`                  |
| `DATABASE_URL` | PostgreSQL connection string | `postgres://...`        |
| `JWT_SECRET`   | JWT signing secret           | Required                |
| `LOCALAI_URL`  | LocalAI service URL          | `http://localhost:8080` |
| `LOG_LEVEL`    | Logging level                | `info`                  |

### Model Configuration

Models are configured in YAML files in the `models/` directory:

- `llama3.yaml` - Full Llama-3 model
- `phi-2.yaml` - Lightweight Phi-2 model for testing
- `embeddings.yaml` - Text embedding model for RAG

## 🛠️ Development

### Prerequisites

- Node.js 18+
- Docker & Docker Compose
- Git

### Setup Development Environment

```bash
# Clone repository
git clone <repo-url>
cd local-llm

# Copy environment file
cp .env.sample .env

# Install dependencies
cd api && npm install

# Start infrastructure
docker-compose up -d postgres loki grafana promtail

# Start API in development mode
npm run dev
```

### Adding New Features

1. Create feature branch: `git checkout -b feature/new-feature`
2. Implement changes with tests
3. Run test suite: `npm test`
4. Create pull request

## 🚨 Troubleshooting

### LocalAI Issues

```bash
# Check LocalAI logs
docker-compose logs localai

# Common issues:
# - Model download in progress (wait for completion)
# - Platform architecture mismatch (use correct image)
# - Insufficient memory (adjust Docker memory limits)
```

### Database Connection Issues

```bash
# Check PostgreSQL status
docker-compose ps postgres

# Reset database
docker-compose down postgres
docker volume rm local-llm_postgres_data
docker-compose up -d postgres
```

### API Performance Issues

```bash
# Monitor container resources
docker stats

# Check API logs
docker-compose logs api

# Monitor database connections
docker-compose exec postgres psql -U postgres -c "SELECT * FROM pg_stat_activity;"
```

### Common Error Messages

| Error                      | Solution                                        |
| -------------------------- | ----------------------------------------------- |
| `ECONNREFUSED` to database | Ensure PostgreSQL is running                    |
| `JWT token invalid`        | Check JWT_SECRET configuration                  |
| `LocalAI not responding`   | Wait for model download to complete             |
| `Port already in use`      | Change port in .env or stop conflicting service |

## 📜 License

MIT License - see LICENSE file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📞 Support

- Create an issue for bugs or feature requests
- Check the troubleshooting section above
- Review logs with `docker-compose logs <service-name>`
