# LocalAI Privacy-First API - Simple Deployment Guide

## Quick Start Deployment (Production Ready)

This guide enables simple "pull and run" deployment of the entire LocalAI Privacy-First API stack without requiring source code or complex setup.

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB RAM available
- 10GB free disk space (for models)

### Option 1: Published Image Deployment (Recommended)

1. **Create a new directory for deployment:**

   ```bash
   mkdir localai-deployment && cd localai-deployment
   ```

2. **Download the deployment files:**

   ```bash
   # Download docker-compose.yml (uses published image)
   curl -O https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.yml

   # Download environment template
   curl -O https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/.env.example

   # Verify files downloaded
   ls -la
   ```

3. **Configure environment:**

   ```bash
   cp .env.example .env
   # Edit .env file and set secure passwords
   ```

4. **Deploy the stack:**
   ```bash
   docker-compose up -d
   ```

### Option 2: Local Build Deployment

If the published image is not yet available, you can build from source:

1. **Clone the repository:**

   ```bash
   git clone https://github.com/inderjotpujara/localai-privacy-api.git
   cd localai-privacy-api
   ```

2. **Configure environment:**

   ```bash
   cp .env.example .env
   # Edit .env file and set secure passwords
   ```

3. **Deploy with local build:**
   ```bash
   docker-compose -f docker-compose.test.yml up -d
   ```

## Configuration

### Essential Environment Variables

Edit your `.env` file with these critical settings:

```bash
# Security (CHANGE THESE!)
JWT_SECRET=your-super-secure-jwt-secret-change-this-now
POSTGRES_PASSWORD=secure-database-password

# Application Settings
NODE_ENV=production
LOCALAI_MODEL=llama3
LOG_LEVEL=info

# Database (use Docker service names)
DATABASE_URL=postgresql://postgres:your-password@postgres:5432/localllm
```

### Security Best Practices

1. **Change default passwords** - Never use default passwords in production
2. **Set strong JWT secret** - Use a cryptographically secure random string
3. **Limit network access** - Use reverse proxy/firewall for external access
4. **Regular updates** - Keep images updated with `docker-compose pull`

## Accessing Services

Once deployed, access these services:

- **API Endpoints**: http://localhost:3000
  - Health: `GET /health`
  - Chat: `POST /chat`
  - RAG: `POST /rag`
- **Grafana Dashboard**: http://localhost:3001 (admin/admin)
- **LocalAI**: http://localhost:8080
- **Database**: PostgreSQL on port 5433

## Testing the Deployment

1. **Check service health:**

   ```bash
   curl http://localhost:3000/health
   ```

2. **Test chat endpoint:**

   ```bash
   curl -X POST http://localhost:3000/chat \
     -H "Content-Type: application/json" \
     -d '{"message": "Hello, how are you?", "model": "llama3"}'
   ```

3. **View logs:**
   ```bash
   docker-compose logs -f api
   ```

## Architecture Overview

The deployment includes:

- **API Service**: Node.js/TypeScript REST API
- **LocalAI**: Privacy-first LLM inference engine
- **PostgreSQL + pgvector**: Vector database for RAG
- **Grafana + Loki + Promtail**: Observability stack

## Troubleshooting

### Common Issues

1. **Service not starting:**

   ```bash
   docker-compose logs [service-name]
   ```

2. **Database connection issues:**

   - Verify DATABASE_URL in .env
   - Ensure PostgreSQL is healthy: `docker-compose ps`

3. **LocalAI model loading:**

   - Models download on first start (may take time)
   - Check progress: `docker-compose logs localai`

4. **Memory issues:**
   - Ensure at least 4GB RAM available
   - Monitor with: `docker stats`

### Performance Optimization

1. **For Apple Silicon (M1/M2):**

   ```bash
   # In .env file
   LOCALAI_BACKEND=metal
   ```

2. **For production workloads:**
   - Increase context size: `CONTEXT_SIZE=8192`
   - Adjust thread count: `THREADS=8`
   - Use faster storage (SSD)

## Updating

To update to the latest version:

```bash
docker-compose pull
docker-compose up -d
```

## Backup

Important data is stored in Docker volumes:

- `postgres_data`: Database
- `localai_models`: Downloaded models
- `grafana_data`: Dashboard configurations

To backup:

```bash
docker run --rm -v local-llm_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

## Support

- GitHub Issues: https://github.com/inderjotpujara/localai-privacy-api/issues
- Documentation: See repository README.md
- Model Compatibility: Check LocalAI documentation

---

**Note**: This deployment prioritizes privacy by running everything locally without external API calls or data sharing.
