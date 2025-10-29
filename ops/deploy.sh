#!/usr/bin/env bash

# deploy.sh - Deploy Application Stack to Docker Swarm
#
# This script deploys the Names Manager application stack to a Docker Swarm cluster.
#
# Usage:
#   ./ops/deploy.sh [OPTIONS]
#
# Options:
#   --help, -h       Show this help message
#   --update, -u     Update existing stack (same as redeploying)
#   --build          Build images before deploying
#
# Prerequisites:
#   - Docker Swarm initialized (run ./ops/init-swarm.sh first)
#   - .env file configured in src/ directory
#   - Docker images built (backend and frontend)
#
# Exit codes:
#   0 = Success
#   1 = Error
#   2 = Timeout waiting for services

set -euo pipefail

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Configuration
readonly STACK_NAME="names-app"
readonly STACK_FILE="src/swarm/stack.yaml"
readonly ENV_FILE="src/.env"
readonly TIMEOUT=120  # 2 minutes timeout for services to be ready
readonly CHECK_INTERVAL=5  # Check every 5 seconds

# Required environment variables
readonly REQUIRED_ENV_VARS=(
    "POSTGRES_USER"
    "POSTGRES_PASSWORD"
    "POSTGRES_DB"
    "DB_URL"
)

# Flags
BUILD_IMAGES=false
UPDATE_MODE=false

#######################################
# Print colored message
# Arguments:
#   $1 - Color code
#   $2 - Message
#######################################
print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}${message}${NC}"
}

#######################################
# Print error message and exit
# Arguments:
#   $1 - Error message
#######################################
error_exit() {
    print_message "$RED" "❌ ERROR: $1"
    exit 1
}

#######################################
# Print success message
# Arguments:
#   $1 - Success message
#######################################
success() {
    print_message "$GREEN" "✅ $1"
}

#######################################
# Print info message
# Arguments:
#   $1 - Info message
#######################################
info() {
    print_message "$BLUE" "ℹ️  $1"
}

#######################################
# Print warning message
# Arguments:
#   $1 - Warning message
#######################################
warning() {
    print_message "$YELLOW" "⚠️  $1"
}

#######################################
# Show usage information
#######################################
show_help() {
    cat << EOF
Docker Swarm Stack Deployment Script

Usage: $0 [OPTIONS]

Deploy the Names Manager application stack to Docker Swarm.

Options:
    -h, --help          Show this help message
    -u, --update        Update existing stack (force redeploy)
    -b, --build         Build Docker images before deploying

Prerequisites:
    - Docker Swarm cluster initialized (./ops/init-swarm.sh)
    - .env file configured in src/ directory
    - Docker images built (or use --build flag)

Stack Configuration:
    Stack Name:  $STACK_NAME
    Stack File:  $STACK_FILE
    Env File:    $ENV_FILE

Services:
    - frontend  (port 80) - Manager node
    - backend   (port 8000) - Manager node
    - db        (port 5432) - Worker node

Examples:
    $0                  # Deploy stack (first time)
    $0 --update         # Update existing stack
    $0 --build          # Build images and deploy

Exit Codes:
    0 = Success
    1 = Error (deployment failed)
    2 = Timeout (services not ready)

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -u|--update)
                UPDATE_MODE=true
                shift
                ;;
            -b|--build)
                BUILD_IMAGES=true
                shift
                ;;
            *)
                error_exit "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done
}

#######################################
# Check if Docker Swarm is initialized
# Returns:
#   0 if initialized, exits with error if not
#######################################
check_swarm_initialized() {
    info "Checking Docker Swarm status..."
    
    if ! docker info >/dev/null 2>&1; then
        error_exit "Cannot connect to Docker. Is Docker Desktop running?"
    fi
    
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        error_exit "Docker Swarm is not initialized. Run: ./ops/init-swarm.sh"
    fi
    
    # Check for at least 2 nodes (manager + worker)
    local node_count
    node_count=$(docker node ls --format "{{.Hostname}}" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$node_count" -lt 2 ]; then
        error_exit "Expected 2 nodes (manager + worker), found: $node_count. Run: ./ops/init-swarm.sh"
    fi
    
    success "Docker Swarm is active with $node_count nodes"
    echo ""
}

#######################################
# Check if required files exist
#######################################
check_required_files() {
    info "Checking required files..."
    
    # Check stack file
    if [ ! -f "$STACK_FILE" ]; then
        error_exit "Stack file not found: $STACK_FILE"
    fi
    success "Stack file found: $STACK_FILE"
    
    # Check .env file
    if [ ! -f "$ENV_FILE" ]; then
        error_exit ".env file not found: $ENV_FILE. Copy from .env.example and configure."
    fi
    success ".env file found: $ENV_FILE"
    
    echo ""
}

#######################################
# Validate environment variables
#######################################
validate_env_vars() {
    info "Validating environment variables..."
    
    # Source the .env file
    set -a
    source "$ENV_FILE"
    set +a
    
    local missing_vars=()
    
    for var in "${REQUIRED_ENV_VARS[@]}"; do
        if [ -z "${!var:-}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        error_exit "Missing required environment variables: ${missing_vars[*]}"
    fi
    
    success "All required environment variables are set"
    echo ""
}

#######################################
# Build Docker images
#######################################
build_images() {
    info "Building Docker images..."
    echo ""
    
    cd src || error_exit "Cannot change to src directory"
    
    # Build backend image
    print_message "$CYAN" "Building backend image..."
    if ! docker build -t names-manager-backend:latest ./backend; then
        cd - >/dev/null
        error_exit "Failed to build backend image"
    fi
    success "Backend image built successfully"
    echo ""
    
    # Build frontend image
    print_message "$CYAN" "Building frontend image..."
    if ! docker build -t names-manager-frontend:latest ./frontend; then
        cd - >/dev/null
        error_exit "Failed to build frontend image"
    fi
    success "Frontend image built successfully"
    echo ""
    
    cd - >/dev/null
}

#######################################
# Check if images exist
#######################################
check_images() {
    info "Checking Docker images..."
    
    local missing_images=()
    
    if ! docker image inspect names-manager-backend:latest >/dev/null 2>&1; then
        missing_images+=("names-manager-backend:latest")
    fi
    
    if ! docker image inspect names-manager-frontend:latest >/dev/null 2>&1; then
        missing_images+=("names-manager-frontend:latest")
    fi
    
    if [ ${#missing_images[@]} -gt 0 ]; then
        error_exit "Missing Docker images: ${missing_images[*]}. Build them first or use --build flag."
    fi
    
    success "Required Docker images are available"
    echo ""
}

#######################################
# Check if stack already exists
# Returns:
#   0 if exists, 1 if not
#######################################
stack_exists() {
    docker stack ls --format "{{.Name}}" 2>/dev/null | grep -q "^${STACK_NAME}$"
}

#######################################
# Deploy the stack
#######################################
deploy_stack() {
    if stack_exists; then
        if [ "$UPDATE_MODE" = true ]; then
            info "Updating existing stack: $STACK_NAME"
        else
            warning "Stack '$STACK_NAME' already exists. Use --update to redeploy."
            info "Updating stack with new configuration..."
        fi
    else
        info "Deploying new stack: $STACK_NAME"
    fi
    
    echo ""
    
    # Deploy the stack
    cd src || error_exit "Cannot change to src directory"
    
    if ! docker stack deploy -c swarm/stack.yaml "$STACK_NAME"; then
        cd - >/dev/null
        error_exit "Failed to deploy stack"
    fi
    
    cd - >/dev/null
    
    echo ""
    success "Stack deployment command executed successfully"
    echo ""
}

#######################################
# Wait for services to be ready
# Arguments:
#   $1 - Timeout in seconds
# Returns:
#   0 if all ready, 2 if timeout
#######################################
wait_for_services() {
    local timeout="$1"
    local elapsed=0
    
    info "Waiting for services to be ready (timeout: ${timeout}s)..."
    echo ""
    
    while [ $elapsed -lt $timeout ]; do
        local all_ready=true
        local services
        services=$(docker stack services "$STACK_NAME" --format "{{.Name}}" 2>/dev/null)
        
        if [ -z "$services" ]; then
            all_ready=false
        else
            while IFS= read -r service; do
                local replicas
                replicas=$(docker service ls --filter "name=$service" --format "{{.Replicas}}" 2>/dev/null)
                
                # Check if replicas are in format "1/1" or similar
                if [[ ! "$replicas" =~ ^([0-9]+)/\1$ ]]; then
                    all_ready=false
                    print_message "$CYAN" "  Waiting for $service... ($replicas)"
                fi
            done <<< "$services"
        fi
        
        if [ "$all_ready" = true ] && [ -n "$services" ]; then
            echo ""
            success "All services are ready!"
            return 0
        fi
        
        sleep "$CHECK_INTERVAL"
        elapsed=$((elapsed + CHECK_INTERVAL))
    done
    
    echo ""
    error_exit "Timeout waiting for services to be ready after ${timeout}s"
    return 2
}

#######################################
# Show deployment status
#######################################
show_status() {
    info "Deployment Status:"
    echo ""
    
    # Show stack services
    print_message "$CYAN" "Stack Services:"
    docker stack services "$STACK_NAME" 2>/dev/null || error_exit "Cannot get stack services"
    echo ""
    
    # Show service placement
    print_message "$CYAN" "Service Placement:"
    docker stack ps "$STACK_NAME" --no-trunc 2>/dev/null | head -20 || warning "Cannot get service placement"
    echo ""
}

#######################################
# Show access information
#######################################
show_access_info() {
    local manager_ip="192.168.56.1"
    
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$GREEN" "🎉 Deployment Complete!"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    print_message "$GREEN" "📍 Application Access:"
    echo "   Frontend:  http://localhost"
    echo "   Frontend:  http://$manager_ip"
    echo ""
    
    print_message "$GREEN" "🔍 Health Checks:"
    echo "   API Health:   http://localhost/api/health"
    echo "   DB Health:    http://localhost/api/health/db"
    echo "   Swarm Health: http://localhost/healthz"
    echo ""
    
    print_message "$GREEN" "📊 Monitoring Commands:"
    echo "   Service status:   docker stack services $STACK_NAME"
    echo "   Service logs:     docker service logs $STACK_NAME"
    echo "   Service details:  docker stack ps $STACK_NAME"
    echo ""
    
    print_message "$GREEN" "🧪 Next Steps:"
    echo "   1. Verify deployment:"
    echo "      ./ops/verify.sh"
    echo ""
    echo "   2. Test the application:"
    echo "      open http://localhost"
    echo ""
    echo "   3. View logs:"
    echo "      docker service logs ${STACK_NAME}_frontend"
    echo "      docker service logs ${STACK_NAME}_backend"
    echo "      docker service logs ${STACK_NAME}_db"
    echo ""
    
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

#######################################
# Main function
#######################################
main() {
    echo ""
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_message "$GREEN" "🚀 Docker Swarm Stack Deployment"
    print_message "$BLUE" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Parse arguments
    parse_args "$@"
    
    # Pre-deployment checks
    check_swarm_initialized
    check_required_files
    validate_env_vars
    
    # Build images if requested
    if [ "$BUILD_IMAGES" = true ]; then
        build_images
    else
        check_images
    fi
    
    # Deploy the stack
    deploy_stack
    
    # Wait for services to be ready
    wait_for_services "$TIMEOUT"
    
    # Show status
    show_status
    
    # Show access information
    show_access_info
    
    exit 0
}

# Run main function
main "$@"
