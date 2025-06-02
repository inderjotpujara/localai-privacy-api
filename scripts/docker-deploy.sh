#!/bin/bash

# Docker-only deployment script for LocalAI API
# This script ensures the entire stack runs purely through Docker containers

set -e

echo "🚀 LocalAI API - Docker-Only Deployment"
echo "========================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Setup environment
setup_environment() {
    print_status "Setting up environment..."
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        if [ -f .env.sample ]; then
            cp .env.sample .env
            print_status "Created .env from .env.sample"
        else
            print_error ".env.sample not found. Please ensure you have the sample environment file."
            exit 1
        fi
    fi
    
    # Generate JWT secret if not set
    if ! grep -q "JWT_SECRET=" .env || grep -q "JWT_SECRET=$" .env || grep -q "JWT_SECRET=your-" .env; then
        print_status "Generating secure JWT secret..."
        JWT_SECRET=$(openssl rand -hex 64 2>/dev/null || node -e "console.log(require('crypto').randomBytes(64).toString('hex'))" 2>/dev/null || echo "$(date | sha256sum | head -c 64)")
        
        if grep -q "JWT_SECRET=" .env; then
            # Replace existing JWT_SECRET line
            if [[ "$OSTYPE" == "darwin"* ]]; then
                # macOS
                sed -i '' "s/JWT_SECRET=.*/JWT_SECRET=${JWT_SECRET}/" .env
            else
                # Linux
                sed -i "s/JWT_SECRET=.*/JWT_SECRET=${JWT_SECRET}/" .env
            fi
        else
            # Add JWT_SECRET line
            echo "JWT_SECRET=${JWT_SECRET}" >> .env
        fi
        print_success "JWT secret generated and saved to .env"
    fi
    
    # Create necessary directories
    mkdir -p logs
    mkdir -p data
    mkdir -p localai-data
    
    print_success "Environment setup complete"
}

# Build Docker images
build_images() {
    print_status "Building Docker images..."
    
    # Build API image
    print_status "Building API image..."
    docker-compose build api
    
    print_success "Docker images built successfully"
}

# Deploy services
deploy_services() {
    local env_file="${1:-.env}"
    print_status "Deploying services with environment: $env_file"
    
    # Stop existing services
    print_status "Stopping existing services..."
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Pull latest images
    print_status "Pulling latest images..."
    docker-compose pull
    
    # Start services in correct order
    print_status "Starting infrastructure services..."
    docker-compose up -d postgres loki
    
    # Wait for PostgreSQL to be ready
    print_status "Waiting for PostgreSQL to be ready..."
    for i in {1..30}; do
        if docker-compose exec -T postgres pg_isready -U llm_user &>/dev/null; then
            break
        fi
        sleep 2
        echo -n "."
    done
    echo ""
    
    print_status "Starting LocalAI service..."
    docker-compose up -d localai
    
    # Wait for LocalAI to be ready
    print_status "Waiting for LocalAI to be ready (this may take a few minutes for model downloads)..."
    for i in {1..120}; do
        if curl -s http://localhost:8080/v1/models &>/dev/null; then
            break
        fi
        sleep 5
        echo -n "."
    done
    echo ""
    
    print_status "Starting API and monitoring services..."
    docker-compose up -d api grafana promtail
    
    print_success "All services deployed successfully"
}

# Verify deployment
verify_deployment() {
    print_status "Verifying deployment..."
    
    # Check service health
    services=("postgres" "localai" "api" "loki" "grafana")
    
    for service in "${services[@]}"; do
        if docker-compose ps "$service" | grep -q "Up"; then
            print_success "$service is running"
        else
            print_error "$service is not running"
            return 1
        fi
    done
    
    # Test API endpoints
    print_status "Testing API endpoints..."
    
    # Health check
    if curl -s http://localhost:3000/health &>/dev/null; then
        print_success "API health check passed"
    else
        print_error "API health check failed"
        return 1
    fi
    
    # LocalAI check
    if curl -s http://localhost:8080/v1/models &>/dev/null; then
        print_success "LocalAI is responding"
    else
        print_warning "LocalAI may still be downloading models"
    fi
    
    print_success "Deployment verification complete"
}

# Show service information
show_service_info() {
    print_status "Service Information:"
    echo ""
    echo "🌐 Services:"
    echo "  - API Server:     http://localhost:3000"
    echo "  - LocalAI:        http://localhost:8080"
    echo "  - Grafana:        http://localhost:3001 (admin/admin)"
    echo "  - PostgreSQL:     localhost:5432"
    echo "  - Loki:           http://localhost:3100"
    echo ""
    echo "📚 API Endpoints:"
    echo "  - Health:         GET  http://localhost:3000/health"
    echo "  - Login:          POST http://localhost:3000/auth/login"
    echo "  - Chat:           POST http://localhost:3000/chat"
    echo "  - RAG Query:      POST http://localhost:3000/rag/query"
    echo "  - RAG Document:   POST http://localhost:3000/rag/documents"
    echo ""
    echo "🔑 Default Credentials:"
    echo "  - Username: admin"
    echo "  - Password: admin123"
    echo ""
    echo "📋 Useful Commands:"
    echo "  - View logs:      docker-compose logs -f [service]"
    echo "  - Stop services:  docker-compose down"
    echo "  - Restart:        docker-compose restart [service]"
    echo "  - Status check:   ./scripts/status-check.sh"
    echo ""
}

# Cleanup function
cleanup() {
    if [ "$1" = "full" ]; then
        print_status "Performing full cleanup..."
        docker-compose down --volumes --remove-orphans
        docker system prune -f
        print_success "Full cleanup complete"
    else
        print_status "Stopping services..."
        docker-compose down
        print_success "Services stopped"
    fi
}

# Main deployment function
main() {
    local mode="${1:-dev}"
    local action="${2:-deploy}"
    
    case "$action" in
        "deploy")
            check_prerequisites
            setup_environment
            build_images
            if [ "$mode" = "prod" ]; then
                deploy_services ".env.prod"
            else
                deploy_services ".env"
            fi
            verify_deployment
            show_service_info
            ;;
        "cleanup")
            cleanup "$mode"
            ;;
        "verify")
            verify_deployment
            ;;
        "info")
            show_service_info
            ;;
        *)
            echo "Usage: $0 [dev|prod] [deploy|cleanup|verify|info]"
            echo ""
            echo "Actions:"
            echo "  deploy   - Deploy all services (default)"
            echo "  cleanup  - Stop services (use 'full' as mode for complete cleanup)"
            echo "  verify   - Verify deployment health"
            echo "  info     - Show service information"
            echo ""
            echo "Examples:"
            echo "  $0 dev deploy    - Deploy in development mode"
            echo "  $0 prod deploy   - Deploy in production mode"
            echo "  $0 full cleanup  - Full cleanup with volume removal"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
