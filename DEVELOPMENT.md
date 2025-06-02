# Development Guide

## Prerequisites

- Docker Desktop
- Node.js 18+
- npm or yarn
- PostgreSQL client (optional, for direct DB access)

## Quick Start

1. **Clone and Setup**

   ```bash
   git clone <repository-url>
   cd local-llm
   cp .env.sample .env
   # Edit .env with your configurations
   ```

2. **Start Development Environment**

   ```bash
   ./scripts/development.sh
   ```

3. **Or manually start services**

   ```bash
   # Start infrastructure
   docker-compose up -d postgres loki promtail grafana localai

   # Install API dependencies
   cd api && npm install

   # Start API in development mode
   npm run dev
   ```

## Environment Configuration

### Required Environment Variables

```bash
# API Configuration
PORT=3000
NODE_ENV=development
JWT_SECRET=your-super-secret-jwt-key

# LocalAI Configuration
LOCALAI_URL=http://localai:8080
LOCALAI_MODEL=llama3

# Database Configuration
DATABASE_URL=postgresql://postgres:postgres@postgres:5432/localllm

# Observability
LOKI_URL=http://loki:3100
LOG_LEVEL=info
```

### Apple Silicon Configuration

For optimal performance on Apple Silicon:

```bash
# Enable Metal acceleration (experimental)
LOCALAI_BACKEND=metal
```

## API Development

### Running Tests

```bash
cd api
npm test                 # Run all tests
npm run test:watch      # Run tests in watch mode
npm run test:coverage   # Run tests with coverage
```

### Linting and Formatting

```bash
npm run lint            # Check for linting issues
npm run lint:fix        # Fix linting issues automatically
```

### Building

```bash
npm run build          # Build TypeScript to JavaScript
npm run clean          # Clean build artifacts
```

## Database Development

### Schema Changes

1. Update the migration in `infra/postgres/init.sql`
2. Restart the postgres container:
   ```bash
   docker-compose restart postgres
   ```

### Direct Database Access

```bash
# Connect to the database
docker-compose exec postgres psql -U postgres -d localllm

# View tables
\dt

# Query documents
SELECT id, content, metadata, created_at FROM documents LIMIT 5;

# Check vector index
\d documents_embedding_idx;
```

## Model Management

### Adding New Models

1. Download model files to the `models/` directory
2. Create a YAML configuration file:
   ```yaml
   name: your-model
   backend: llama
   parameters:
     model: your-model-file.gguf
     context_size: 4096
     threads: 4
   ```
3. Update `LOCALAI_MODEL` in `.env`
4. Restart LocalAI: `docker-compose restart localai`

### Supported Model Formats

- GGUF (recommended)
- GGML
- PyTorch
- Safetensors

## Monitoring and Observability

### Grafana Dashboard

1. Open http://localhost:3001
2. Login with `admin`/`admin`
3. Import dashboard from `infra/grafana/dashboards/`

### Log Analysis

```bash
# View API logs
docker-compose logs -f api

# Query logs with Loki
curl -G -s "http://localhost:3100/loki/api/v1/query" \
  --data-urlencode 'query={job="local-llm-api"}' | jq

# View real-time logs in Grafana
# Navigate to Explore > Loki > {job="local-llm-api"}
```

## Testing

### Manual API Testing

```bash
# Test all endpoints
./scripts/test-api.sh

# Generate test JWT token
node -e "
const jwt = require('jsonwebtoken');
console.log(jwt.sign(
  { sub: 'test-user', email: 'test@example.com' },
  process.env.JWT_SECRET || 'test-secret',
  { expiresIn: '24h' }
));
"
```

### Example API Calls

```bash
# Health check
curl http://localhost:3000/health

# Chat (with auth)
curl -X POST http://localhost:3000/chat \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello!", "stream": false}'

# RAG query
curl -X POST http://localhost:3000/rag/query \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "What is LocalAI?", "limit": 3}'
```

## Debugging

### Common Issues

1. **LocalAI not responding**

   - Check if model files exist in `models/` directory
   - Verify model configuration in YAML files
   - Check LocalAI logs: `docker-compose logs localai`

2. **Database connection issues**

   - Ensure PostgreSQL is running: `docker-compose ps postgres`
   - Check database logs: `docker-compose logs postgres`
   - Verify connection string in `.env`

3. **JWT authentication errors**
   - Ensure `JWT_SECRET` is set in `.env`
   - Use the test token generator for development
   - Check token expiration

### Debug Mode

```bash
# Enable debug logging
export LOG_LEVEL=debug
npm run dev

# Debug database queries
export DATABASE_DEBUG=true

# Debug LocalAI requests
export LOCALAI_DEBUG=true
```

## Contributing

### Code Style

- TypeScript with strict mode
- ESLint for code quality
- Prettier for formatting (optional)
- Jest for testing

### Commit Convention

Use conventional commits:

- `feat:` new features
- `fix:` bug fixes
- `docs:` documentation
- `test:` tests
- `refactor:` code improvements
- `ci:` CI/CD changes

### Pull Request Process

1. Create feature branch from `main`
2. Make changes with tests
3. Ensure all tests pass
4. Update documentation
5. Submit PR with clear description

## Deployment

### Docker Production Build

```bash
# Build production image
docker build -t local-llm-api ./api

# Run production stack
docker-compose -f docker-compose.prod.yml up -d
```

### Environment-specific Configurations

- Development: `.env`
- Testing: `.env.test`
- Production: `.env.production`

## Performance Tuning

### LocalAI Optimization

```yaml
# In model YAML configuration
parameters:
  threads: 8 # Increase for better performance
  context_size: 8192 # Increase for longer conversations
  use_mlock: true # Lock model in memory
  use_mmap: true # Memory map model file
  batch_size: 512 # Batch processing size
```

### Database Optimization

```sql
-- Optimize vector search
SET ivfflat.probes = 10;

-- Monitor query performance
EXPLAIN ANALYZE SELECT * FROM documents
WHERE embedding <-> '[...]' < 0.5
ORDER BY embedding <-> '[...]'
LIMIT 5;
```

### API Performance

- Use streaming for long responses
- Implement response caching
- Monitor memory usage
- Use connection pooling

## Security

### Production Checklist

- [ ] Change default JWT secret
- [ ] Use strong database passwords
- [ ] Enable HTTPS
- [ ] Implement rate limiting
- [ ] Add input validation
- [ ] Regular security updates
- [ ] Monitor access logs

### Data Privacy

- All data remains local
- No external API calls
- Encrypted database connections
- Secure JWT tokens
- Local log storage only
