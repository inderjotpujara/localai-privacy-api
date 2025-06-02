#!/bin/bash

# LocalAI Privacy-First API - One-Click Deployment Script
# Usage: ./deploy.sh [JWT_SECRET] [OPTIONS]

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_JWT_SECRET=""
DEFAULT_POSTGRES_PASSWORD=""
DEFAULT_MODEL="llama3"
DEFAULT_LOG_LEVEL="info"
DEPLOYMENT_DIR="localai-deployment"
DOCKER_COMPOSE_URL="https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/docker-compose.yml"
ENV_EXAMPLE_URL="https://raw.githubusercontent.com/inderjotpujara/localai-privacy-api/main/.env.example"

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

# Function to generate secure random string
generate_random_string() {
    local length=${1:-32}
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 $length | tr -d "=+/" | cut -c1-$length
    elif command -v python3 >/dev/null 2>&1; then
        python3 -c "import secrets, string; print(''.join(secrets.choice(string.ascii_letters + string.digits) for _ in range($length)))"
    else
        # Fallback for systems without openssl or python3
        date +%s | sha256sum | base64 | head -c $length
    fi
}

# Function to show usage
show_usage() {
    cat << EOF
LocalAI Privacy-First API - One-Click Deployment Script

USAGE:
    ./deploy.sh [JWT_SECRET] [OPTIONS]

ARGUMENTS:
    JWT_SECRET          Custom JWT secret (optional, will generate if not provided)

OPTIONS:
    --postgres-password PASSWORD    Custom PostgreSQL password (optional, will generate if not provided)
    --model MODEL_NAME             LocalAI model to use (default: llama3)
    --log-level LEVEL              Log level (default: info)
    --deployment-dir DIR           Deployment directory (default: localai-deployment)
    --help                         Show this help message
    --status                       Check deployment status
    --stop                         Stop the deployment
    --logs [SERVICE]               Show logs for all services or specific service
    --cleanup                      Stop and remove all containers and volumes

EXAMPLES:
    ./deploy.sh                                           # Quick start with auto-generated secrets
    ./deploy.sh my-super-secure-jwt-secret               # With custom JWT secret
    ./deploy.sh my-jwt --postgres-password my-db-pass    # With custom JWT and DB password
    ./deploy.sh --status                                 # Check if services are running
    ./deploy.sh --logs api                               # Show API service logs
    ./deploy.sh --cleanup                                # Clean up everything

REQUIREMENTS:
    - Docker and Docker Compose installed
    - At least 4GB RAM available
    - 10GB free disk space (for models)

EOF
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker >/dev/null 2>&1; then
        print_error "Docker is not installed. Please install Docker first."
        echo "Visit: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        print_error "Docker Compose is not installed. Please install Docker Compose first."
        echo "Visit: https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        print_error "Docker daemon is not running. Please start Docker first."
        exit 1
    fi
    
    print_success "Prerequisites check passed!"
}

# Function to check deployment status
check_status() {
    if [ ! -d "$DEPLOYMENT_DIR" ]; then
        print_error "Deployment directory '$DEPLOYMENT_DIR' not found. Run deployment first."
        exit 1
    fi
    
    cd "$DEPLOYMENT_DIR"
    
    print_status "Checking deployment status..."
    echo
    
    # Check if services are running
    if docker-compose ps 2>/dev/null | grep -q "Up"; then
        print_success "Services are running:"
        docker-compose ps
        echo
        
        # Test API health
        print_status "Testing API health..."
        if curl -s http://localhost:3000/health >/dev/null 2>&1; then
            print_success "API is healthy and responding!"
            echo "🌐 API: http://localhost:3000"
            echo "📊 Grafana: http://localhost:3001 (admin/admin)"
            echo "🤖 LocalAI: http://localhost:8080"
        else
            print_warning "API is not responding yet (may still be starting up)"
        fi
    else
        print_warning "No services are currently running"
    fi
}

# Function to show logs
show_logs() {
    local service=${1:-""}
    
    if [ ! -d "$DEPLOYMENT_DIR" ]; then
        print_error "Deployment directory '$DEPLOYMENT_DIR' not found."
        exit 1
    fi
    
    cd "$DEPLOYMENT_DIR"
    
    if [ -n "$service" ]; then
        print_status "Showing logs for service: $service"
        docker-compose logs -f "$service"
    else
        print_status "Showing logs for all services (Ctrl+C to exit)"
        docker-compose logs -f
    fi
}

# Function to stop deployment
stop_deployment() {
    if [ ! -d "$DEPLOYMENT_DIR" ]; then
        print_error "Deployment directory '$DEPLOYMENT_DIR' not found."
        exit 1
    fi
    
    cd "$DEPLOYMENT_DIR"
    print_status "Stopping LocalAI deployment..."
    docker-compose down
    print_success "Deployment stopped!"
}

# Function to cleanup deployment
cleanup_deployment() {
    if [ ! -d "$DEPLOYMENT_DIR" ]; then
        print_warning "Deployment directory '$DEPLOYMENT_DIR' not found."
        return
    fi
    
    cd "$DEPLOYMENT_DIR"
    print_status "Cleaning up LocalAI deployment..."
    print_warning "This will remove all containers, networks, and volumes!"
    
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        docker-compose down -v --remove-orphans
        cd ..
        rm -rf "$DEPLOYMENT_DIR"
        print_success "Cleanup completed!"
    else
        print_status "Cleanup cancelled."
    fi
}

# Function to deploy
deploy() {
    local jwt_secret="$1"
    local postgres_password="$2"
    local model="$3"
    local log_level="$4"
    
    print_status "Starting LocalAI Privacy-First API deployment..."
    
    # Generate secrets if not provided
    if [ -z "$jwt_secret" ]; then
        jwt_secret=$(generate_random_string 64)
        print_status "Generated JWT secret: ${jwt_secret:0:8}... (truncated for security)"
    fi
    
    if [ -z "$postgres_password" ]; then
        postgres_password=$(generate_random_string 32)
        print_status "Generated PostgreSQL password: ${postgres_password:0:8}... (truncated for security)"
    fi
    
    # Create deployment directory
    print_status "Creating deployment directory: $DEPLOYMENT_DIR"
    mkdir -p "$DEPLOYMENT_DIR"
    cd "$DEPLOYMENT_DIR"
    
    # Download deployment files
    print_status "Downloading deployment files..."
    
    if ! curl -fsSL "$DOCKER_COMPOSE_URL" -o docker-compose.yml; then
        print_error "Failed to download docker-compose.yml"
        exit 1
    fi
    
    if ! curl -fsSL "$ENV_EXAMPLE_URL" -o .env.example; then
        print_error "Failed to download .env.example"
        exit 1
    fi
    
    print_success "Downloaded deployment files"
    
    # Create .env file
    print_status "Creating environment configuration..."
    
    cat > .env << EOF
# LocalAI Privacy-First API Configuration
# Generated on $(date)

# Security Settings (CRITICAL - CHANGE IN PRODUCTION)
JWT_SECRET=$jwt_secret
POSTGRES_PASSWORD=$postgres_password

# Application Settings
NODE_ENV=production
LOCALAI_MODEL=$model
LOG_LEVEL=$log_level
PORT=3000

# Database Configuration
DATABASE_URL=postgresql://postgres:$postgres_password@postgres:5432/localllm

# LocalAI Configuration
LOCALAI_URL=http://localai:8080
LOCALAI_BACKEND=auto

# Performance Settings
CONTEXT_SIZE=4096
THREADS=4

# Observability
GRAFANA_ADMIN_PASSWORD=admin
LOKI_URL=http://loki:3100

# Optional: Uncomment and configure for production
# ALLOWED_ORIGINS=https://yourdomain.com
# MAX_TOKENS=2048
# TEMPERATURE=0.7
EOF
    
    print_success "Created .env configuration"
    
    # Start deployment
    print_status "Starting Docker containers..."
    
    # Pull latest images
    docker-compose pull
    
    # Start services
    docker-compose up -d
    
    print_success "Deployment started!"
    
    # Wait for services to be ready
    print_status "Waiting for services to start (this may take a few minutes)..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -s http://localhost:3000/health >/dev/null 2>&1; then
            break
        fi
        sleep 5
        attempt=$((attempt + 1))
        echo -n "."
    done
    
    echo
    
    if [ $attempt -eq $max_attempts ]; then
        print_warning "Services are starting but not fully ready yet. Check logs with: ./deploy.sh --logs"
    else
        print_success "All services are ready!"
    fi
    
    # Show access information
    echo
    print_success "🎉 LocalAI Privacy-First API deployed successfully!"
    echo
    echo "📋 Access Information:"
    echo "   🌐 API Endpoints:    http://localhost:3000"
    echo "   📊 Grafana Dashboard: http://localhost:3001 (admin/admin)"
    echo "   🤖 LocalAI Direct:   http://localhost:8080"
    echo "   🗄️  Database:        PostgreSQL on localhost:5433"
    echo
    echo "🧪 Quick Test:"
    echo "   curl http://localhost:3000/health"
    echo
    echo "📖 View Logs:"
    echo "   ./deploy.sh --logs"
    echo
    echo "🔧 Management:"
    echo "   ./deploy.sh --status     # Check status"
    echo "   ./deploy.sh --stop       # Stop services"
    echo "   ./deploy.sh --cleanup    # Remove everything"
    echo
    print_warning "Important: Save your JWT secret safely: $jwt_secret"
}

# Main script logic
main() {
    local jwt_secret=""
    local postgres_password=""
    local model="$DEFAULT_MODEL"
    local log_level="$DEFAULT_LOG_LEVEL"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --status)
                check_status
                exit 0
                ;;
            --stop)
                stop_deployment
                exit 0
                ;;
            --logs)
                shift
                show_logs "$1"
                exit 0
                ;;
            --cleanup)
                cleanup_deployment
                exit 0
                ;;
            --postgres-password)
                postgres_password="$2"
                shift 2
                ;;
            --model)
                model="$2"
                shift 2
                ;;
            --log-level)
                log_level="$2"
                shift 2
                ;;
            --deployment-dir)
                DEPLOYMENT_DIR="$2"
                shift 2
                ;;
            --*)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$jwt_secret" ]; then
                    jwt_secret="$1"
                else
                    print_error "Unknown argument: $1"
                    show_usage
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check prerequisites before deployment
    check_prerequisites
    
    # Deploy
    deploy "$jwt_secret" "$postgres_password" "$model" "$log_level"
}

# Run main function with all arguments
main "$@"
