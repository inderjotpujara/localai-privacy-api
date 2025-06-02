# LocalAI API Setup Guide

This guide will help you set up the privacy-first LocalAI API facade after cloning the repository.

## Prerequisites

- Docker and Docker Compose
- Node.js 18+ (for development)
- Git
- At least 8GB RAM (16GB recommended for larger models)
- Apple Silicon Mac or x86_64 Linux/macOS

## Quick Start

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd local-llm
```

### 2. Docker-Only Deployment (Recommended)

The easiest way to get started is using our Docker-only deployment script:

```bash
# Make scripts executable
chmod +x scripts/docker-deploy.sh scripts/docker-health-check.sh scripts/docker-test.sh

# Deploy in development mode
./scripts/docker-deploy.sh dev deploy

# Or deploy in production mode
./scripts/docker-deploy.sh prod deploy
```

This script will:

- Check prerequisites (Docker, Docker Compose)
- Generate secure JWT secrets automatically
- Build and deploy all services
- Verify deployment health
- Show service information

### 3. Manual Environment Configuration (Optional)

If you prefer manual setup, copy the sample environment file and configure it:

```bash
# For development
cp .env.sample .env

# For production
cp .env.prod.sample .env.prod
```

Edit the `.env` file with your settings:

```bash
# Required: Generate a secure JWT secret
JWT_SECRET=your-super-secure-jwt-secret-here

# Database configuration (default works with Docker Compose)
DATABASE_URL=postgresql://llm_user:llm_password@localhost:5432/llm_db

# LocalAI configuration (default works with Docker Compose)
LOCALAI_URL=http://localhost:8080

# API configuration
PORT=3000
NODE_ENV=development

# Optional: Logging level
LOG_LEVEL=info
```

### 4. Manual Service Startup (Optional)

For development:

```bash
docker-compose up -d
```

For production:

```bash
docker-compose -f docker-compose.prod.yml up -d
```

For development with live reload:

```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

### 5. Verify Installation

Use our Docker-based health check:

```bash
./scripts/docker-health-check.sh
```

Or run comprehensive tests:

```bash
./scripts/docker-test.sh
```

Or manually check endpoints:

```bash
# Health check
curl http://localhost:3000/health

# Get JWT token (use this for authenticated requests)
curl -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'
```

## Directory Structure

```
local-llm/
├── api/                    # TypeScript API server
│   ├── src/
│   │   ├── routes/        # API routes (chat, rag, health)
│   │   ├── services/      # Business logic services
│   │   └── middleware/    # Auth, error handling
├── infra/                 # Infrastructure configuration
│   ├── postgres/         # Database init scripts
│   ├── grafana/          # Monitoring dashboards
│   └── loki/             # Log aggregation config
├── models/               # LocalAI model configurations
├── scripts/              # Utility scripts
├── examples/             # Usage examples
└── localai-data/         # Auto-created: LocalAI models & data (not in git)
```

## Configuration Details

### Environment Variables

| Variable       | Description                  | Default               | Required |
| -------------- | ---------------------------- | --------------------- | -------- |
| `JWT_SECRET`   | Secret for JWT token signing | -                     | ✅       |
| `DATABASE_URL` | PostgreSQL connection string | localhost:5432        | ✅       |
| `LOCALAI_URL`  | LocalAI service URL          | http://localhost:8080 | ✅       |
| `PORT`         | API server port              | 3000                  | ❌       |
| `NODE_ENV`     | Environment mode             | development           | ❌       |
| `LOG_LEVEL`    | Logging level                | info                  | ❌       |

### Service Ports

| Service    | Port | Description          |
| ---------- | ---- | -------------------- |
| API Server | 3000 | Main API endpoints   |
| LocalAI    | 8080 | LLM inference engine |
| PostgreSQL | 5432 | Database             |
| Grafana    | 3001 | Monitoring dashboard |
| Loki       | 3100 | Log aggregation      |

## Model Configuration

The system automatically downloads models on first startup. Default models:

- **Chat**: Llama-3.2-3B (ARM64 optimized)
- **Embeddings**: all-MiniLM-L6-v2
- **Additional**: Phi-2, Whisper, Stable Diffusion

To add custom models, create YAML files in the `models/` directory following the existing patterns.

## Authentication

Default credentials (change in production):

- Username: `admin`
- Password: `admin123`

JWT tokens expire in 24 hours by default.

## Development

### Docker-Only Development

For pure Docker development (recommended):

```bash
# Start development environment with live reload
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Check logs
docker-compose logs -f api

# Run tests
./scripts/docker-test.sh

# Health check
./scripts/docker-health-check.sh
```

### Local Development with Node.js

For local development with Node.js:

```bash
# Install API dependencies
cd api
npm install

# Start infrastructure services only
docker-compose up -d postgres localai loki grafana

# Run API in development mode
npm run dev
```

## Deployment Options

### 1. Docker-Only Deployment (Recommended)

Complete deployment using only Docker:

```bash
# Development
./scripts/docker-deploy.sh dev deploy

# Production
./scripts/docker-deploy.sh prod deploy

# Check status
./scripts/docker-deploy.sh dev info

# Cleanup
./scripts/docker-deploy.sh dev cleanup
# Or full cleanup with volumes
./scripts/docker-deploy.sh full cleanup
```

### 2. Traditional Docker Compose

Manual Docker Compose deployment:

```bash
# Development
docker-compose up -d

# Production
docker-compose -f docker-compose.prod.yml up -d

# Development with live reload
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## Production Deployment

1. Use `docker-compose.prod.yml`
2. Update `.env.prod` with production values
3. Change default credentials
4. Set up proper SSL/TLS termination
5. Configure log rotation
6. Set up backup for PostgreSQL

## Troubleshooting

### Common Issues

1. **Models not downloading**: Check LocalAI logs and ensure sufficient disk space
2. **Database connection failed**: Verify PostgreSQL is running and credentials are correct
3. **JWT authentication failed**: Ensure JWT_SECRET is set and consistent
4. **ARM64 compatibility**: Use the provided Docker images optimized for Apple Silicon

### Checking Logs

```bash
# API logs
docker-compose logs api

# LocalAI logs
docker-compose logs localai

# Database logs
docker-compose logs postgres

# All services
docker-compose logs
```

### Performance Tuning

- Increase `LOCALAI_THREADS` for better CPU utilization
- Adjust `LOCALAI_CONTEXT_SIZE` for longer conversations
- Monitor memory usage with Grafana dashboards

## Security Considerations

1. Change default credentials immediately
2. Use strong JWT secrets (64+ characters)
3. Run behind a reverse proxy with SSL/TLS
4. Regularly update Docker images
5. Monitor access logs in Grafana
6. Keep all data local (no external API calls)

## Testing

Run the test suite:

```bash
# Endpoint tests
./scripts/test-endpoints.sh

# Load testing
./scripts/load-test.sh

# Status check
./scripts/status-check.sh
```

## Support

For issues and questions:

1. Check the logs using the commands above
2. Review the troubleshooting section in README.md
3. Verify all environment variables are set correctly
4. Ensure Docker services are healthy
