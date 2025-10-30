#!/usr/bin/env bash

################################################################################
# Docker Swarm Cluster Initialization Script
# 
# This script initializes a Docker Swarm cluster with:
#   - Manager Node: Local machine (laptop) at 192.168.56.1
#   - Worker Node: Vagrant VM at 192.168.56.10
#
# Usage:
#   ./ops/init-swarm.sh [OPTIONS]
#
# Options:
#   --help          Show this help message
#   --force         Force re-initialization (leave existing swarm first)
#   --skip-vagrant  Skip Vagrant VM startup (assume it's already running)
#
# Exit Codes:
#   0 - Success (cluster initialized)
#   1 - Error (initialization failed)
#   2 - Already initialized (swarm already exists, use --force to reinitialize)
################################################################################

set -e  # Exit on error
set -o pipefail  # Exit on pipe failure

# Configuration
WORKER_IP="192.168.56.10"
VAGRANT_DIR="vagrant"
SWARM_PORT="2377"

# Detect manager IP based on OS
# On macOS with Docker Desktop, we need to use the main network interface (en0)
# because Docker Desktop doesn't expose Swarm ports on VirtualBox host-only network
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS - use main network interface IP
    MANAGER_IP=$(ifconfig en0 2>/dev/null | grep "inet " | grep -v inet6 | awk '{print $2}')
    if [[ -z "$MANAGER_IP" ]]; then
        # Try other interfaces if en0 fails
        MANAGER_IP=$(ifconfig | grep "inet " | grep -v "127.0.0.1" | grep -v "192.168.56.1" | head -1 | awk '{print $2}')
    fi
    if [[ -z "$MANAGER_IP" ]]; then
        echo "Error: Could not detect network IP. Please check your network connection."
        exit 1
    fi
else
    # Linux - use VirtualBox host-only network
    MANAGER_IP="192.168.56.1"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flags
FORCE_INIT=false
SKIP_VAGRANT=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ Error: $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠ Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_help() {
    grep '^#' "$0" | grep -v '#!/usr/bin/env' | sed 's/^# //' | sed 's/^#//'
    exit 0
}

################################################################################
# Prerequisite Checks
################################################################################

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        missing_tools+=("docker")
    else
        print_success "Docker found: $(docker --version | head -n1)"
    fi
    
    # Check for Vagrant (only if not skipping)
    if [ "$SKIP_VAGRANT" = false ]; then
        if ! command -v vagrant &> /dev/null; then
            missing_tools+=("vagrant")
        else
            print_success "Vagrant found: $(vagrant --version)"
        fi
        
        # Check for VirtualBox
        if ! command -v VBoxManage &> /dev/null; then
            missing_tools+=("virtualbox")
        else
            print_success "VirtualBox found: $(VBoxManage --version)"
        fi
    else
        print_info "Skipping Vagrant/VirtualBox checks (--skip-vagrant flag)"
    fi
    
    # Check if Docker daemon is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker daemon is running"
    
    # Report missing tools
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Installation instructions:"
        for tool in "${missing_tools[@]}"; do
            case $tool in
                docker)
                    echo "  - Docker: https://docs.docker.com/get-docker/"
                    ;;
                vagrant)
                    echo "  - Vagrant: https://www.vagrantup.com/downloads"
                    ;;
                virtualbox)
                    echo "  - VirtualBox: https://www.virtualbox.org/wiki/Downloads"
                    ;;
            esac
        done
        exit 1
    fi
    
    echo ""
}

################################################################################
# Swarm Status Check
################################################################################

check_swarm_status() {
    print_header "Checking Current Swarm Status"
    
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        print_warning "Swarm is already active on this node"
        
        # Check if this is a manager
        if docker info 2>/dev/null | grep -q "Is Manager: true"; then
            print_info "This node is already a Swarm manager"
            
            # Show current nodes
            echo ""
            echo "Current cluster nodes:"
            docker node ls 2>/dev/null || true
            echo ""
            
            if [ "$FORCE_INIT" = false ]; then
                print_error "Swarm already initialized. Use --force to reinitialize."
                exit 2
            else
                print_warning "Force flag detected. Will leave swarm and reinitialize..."
                return 1  # Signal that we need to reinitialize
            fi
        else
            print_error "This node is a worker in another swarm. Please leave that swarm first:"
            echo "  docker swarm leave"
            exit 1
        fi
    else
        print_success "No active swarm found. Ready to initialize."
        return 0
    fi
}

################################################################################
# Vagrant VM Management
################################################################################

start_vagrant_vm() {
    if [ "$SKIP_VAGRANT" = true ]; then
        print_info "Skipping Vagrant VM startup (--skip-vagrant flag)"
        return 0
    fi
    
    print_header "Starting Vagrant Worker VM"
    
    # Check if Vagrantfile exists
    if [ ! -f "$VAGRANT_DIR/Vagrantfile" ]; then
        print_error "Vagrantfile not found in $VAGRANT_DIR/"
        echo "Please ensure you're running this script from the project root directory."
        exit 1
    fi
    
    # Check VM status
    cd "$VAGRANT_DIR"
    local vm_status
    # Look for "default" machine name (Vagrant's default for single-VM setups)
    vm_status=$(vagrant status 2>/dev/null | grep "default" | awk '{print $2}')
    
    case "$vm_status" in
        running)
            print_success "Vagrant VM is already running"
            ;;
        saved|poweroff)
            print_info "Starting Vagrant VM from $vm_status state..."
            vagrant up
            print_success "Vagrant VM started"
            ;;
        *)
            print_info "Starting Vagrant VM..."
            vagrant up
            print_success "Vagrant VM started"
            ;;
    esac
    
    # Wait for VM to be fully ready
    print_info "Waiting for VM to be fully ready..."
    sleep 5
    
    # Test connectivity
    if vagrant ssh -c "echo 'Connection test successful'" &> /dev/null; then
        print_success "VM is accessible via SSH"
    else
        print_error "Cannot connect to VM via SSH"
        exit 1
    fi
    
    # Verify Docker is running in VM
    if vagrant ssh -c "docker info" &> /dev/null; then
        print_success "Docker is running in VM"
    else
        print_error "Docker is not running in VM. Try: cd vagrant && vagrant provision"
        exit 1
    fi
    
    cd - > /dev/null
    echo ""
}

################################################################################
# Swarm Initialization
################################################################################

initialize_swarm() {
    print_header "Initializing Docker Swarm"
    
    # Leave existing swarm if force flag is set
    if [ "$FORCE_INIT" = true ]; then
        print_info "Leaving existing swarm..."
        docker swarm leave --force 2>/dev/null || true
        sleep 2
    fi
    
    # Initialize swarm on manager node
    print_info "Initializing Swarm on manager node (${MANAGER_IP})..."
    
    if docker swarm init --advertise-addr "${MANAGER_IP}:${SWARM_PORT}" &> /dev/null; then
        print_success "Swarm initialized successfully"
    else
        print_error "Failed to initialize Swarm"
        echo "This may happen if:"
        echo "  - The advertise address ${MANAGER_IP} is not accessible"
        echo "  - Port ${SWARM_PORT} is already in use"
        echo "  - You're already part of another swarm"
        exit 1
    fi
    
    # Get manager info
    local manager_id
    manager_id=$(docker info --format '{{.Swarm.NodeID}}')
    print_info "Manager Node ID: ${manager_id}"
    
    echo ""
}

################################################################################
# Worker Join
################################################################################

join_worker_to_swarm() {
    print_header "Adding Worker Node to Swarm"
    
    # Get join token
    print_info "Retrieving worker join token..."
    local join_token
    join_token=$(docker swarm join-token worker -q)
    
    if [ -z "$join_token" ]; then
        print_error "Failed to retrieve join token"
        exit 1
    fi
    print_success "Join token retrieved"
    
    # Build join command
    local join_command="docker swarm join --token ${join_token} ${MANAGER_IP}:${SWARM_PORT}"
    
    # Check if worker is already in swarm
    print_info "Checking worker node status..."
    
    local worker_in_swarm=false
    if [ "$SKIP_VAGRANT" = false ]; then
        if cd "$VAGRANT_DIR" && vagrant ssh -c "docker info 2>/dev/null | grep -q 'Swarm: active'" 2>/dev/null; then
            worker_in_swarm=true
        fi
        cd - > /dev/null
    else
        print_warning "Cannot check worker status with --skip-vagrant flag"
    fi
    
    if [ "$worker_in_swarm" = true ]; then
        print_warning "Worker node is already in a swarm"
        
        if [ "$FORCE_INIT" = true ]; then
            print_info "Force flag set. Removing worker from old swarm..."
            if [ "$SKIP_VAGRANT" = false ]; then
                cd "$VAGRANT_DIR"
                vagrant ssh -c "docker swarm leave --force" 2>/dev/null || true
                cd - > /dev/null
                sleep 2
            fi
        else
            print_error "Worker already in swarm. Use --force to rejoin."
            exit 1
        fi
    fi
    
    # Join worker to swarm
    print_info "Joining worker node to swarm..."
    
    if [ "$SKIP_VAGRANT" = false ]; then
        cd "$VAGRANT_DIR"
        if vagrant ssh -c "${join_command}" &> /dev/null; then
            print_success "Worker node joined successfully"
            
            # Label the worker node for database placement
            cd - > /dev/null
            print_info "Labeling worker node for database placement..."
            
            # Get the worker node ID
            local worker_node_id
            worker_node_id=$(docker node ls --filter "role=worker" --format "{{.ID}}" | head -n 1)
            
            if [ -n "$worker_node_id" ]; then
                if docker node update --label-add role=db "$worker_node_id" &> /dev/null; then
                    print_success "Worker node labeled with role=db"
                else
                    print_warning "Failed to label worker node (may already be labeled)"
                fi
            else
                print_warning "Could not find worker node ID for labeling"
            fi
        else
            print_error "Failed to join worker node"
            echo "Troubleshooting steps:"
            echo "  1. Verify VM network: ping ${WORKER_IP}"
            echo "  2. Check VM can reach manager: vagrant ssh -c 'ping -c 2 ${MANAGER_IP}'"
            echo "  3. Check firewall rules for port ${SWARM_PORT}"
            cd - > /dev/null
            exit 1
        fi
    else
        print_warning "Skipping worker join (--skip-vagrant flag)"
        echo "To join manually from worker node, run:"
        echo "  ${join_command}"
        echo ""
        echo "Then label the worker node with:"
        echo "  docker node update --label-add role=db <worker-node-id>"
    fi
    
    echo ""
}

################################################################################
# Create Persistent Storage
################################################################################

create_worker_storage() {
    print_header "Setting Up Persistent Storage on Worker"
    
    if [ "$SKIP_VAGRANT" = false ]; then
        print_info "Creating /var/lib/postgres-data directory on worker..."
        
        cd "$VAGRANT_DIR"
        vagrant ssh -c "sudo mkdir -p /var/lib/postgres-data && sudo chown -R 999:999 /var/lib/postgres-data" &> /dev/null
        cd - > /dev/null
        
        print_success "Persistent storage directory created"
    else
        print_warning "Skipping storage setup (--skip-vagrant flag)"
        echo "On worker node, run:"
        echo "  sudo mkdir -p /var/lib/postgres-data"
        echo "  sudo chown -R 999:999 /var/lib/postgres-data"
    fi
    
    echo ""
}

################################################################################
# Verification
################################################################################

verify_cluster() {
    print_header "Verifying Cluster Status"
    
    # Wait a moment for cluster to stabilize
    print_info "Waiting for cluster to stabilize..."
    sleep 3
    
    # List nodes
    echo "Cluster nodes:"
    docker node ls
    echo ""
    
    # Check node count
    local node_count
    node_count=$(docker node ls --format '{{.ID}}' | wc -l | tr -d ' ')
    
    if [ "$node_count" -lt 2 ] && [ "$SKIP_VAGRANT" = false ]; then
        print_warning "Expected 2 nodes, found ${node_count}"
    else
        print_success "Cluster has ${node_count} node(s)"
    fi
    
    # Check if nodes are ready
    local ready_nodes
    ready_nodes=$(docker node ls --filter "role=worker" --format '{{.Status}}' | grep -c "Ready" || true)
    
    if [ "$SKIP_VAGRANT" = false ]; then
        if [ "$ready_nodes" -ge 1 ]; then
            print_success "Worker node is Ready"
        else
            print_error "Worker node is not Ready"
            exit 1
        fi
    fi
    
    # Show manager node
    print_info "Manager node: $(docker node ls --filter 'role=manager' --format '{{.Hostname}}')"
    
    if [ "$SKIP_VAGRANT" = false ]; then
        # Show worker node
        print_info "Worker node: $(docker node ls --filter 'role=worker' --format '{{.Hostname}}')"
    fi
    
    echo ""
}

################################################################################
# Main Script
################################################################################

main() {
    print_header "Docker Swarm Cluster Initialization"
    echo ""
    
    # Show detected configuration
    echo "Configuration:"
    echo "  Manager IP: ${MANAGER_IP}"
    echo "  Worker IP:  ${WORKER_IP}"
    if [[ "$(uname)" == "Darwin" ]]; then
        print_info "Detected macOS - using main network interface IP for Swarm"
    fi
    echo ""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                ;;
            --force)
                FORCE_INIT=true
                shift
                ;;
            --skip-vagrant)
                SKIP_VAGRANT=true
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    # Run initialization steps
    check_prerequisites
    
    if check_swarm_status; then
        # New initialization
        start_vagrant_vm
        initialize_swarm
        join_worker_to_swarm
        create_worker_storage
        verify_cluster
    else
        # Reinitializing with --force
        start_vagrant_vm
        initialize_swarm
        join_worker_to_swarm
        create_worker_storage
        verify_cluster
    fi
    
    # Success message
    print_header "Initialization Complete!"
    echo ""
    print_success "Docker Swarm cluster is ready!"
    echo ""
    echo "Next steps:"
    echo "  1. Build Docker images:"
    echo "     cd src"
    echo "     docker build -t names-manager-backend:latest ./backend"
    echo "     docker build -t names-manager-frontend:latest ./frontend"
    echo ""
    echo "  2. Deploy the application stack:"
    echo "     ./ops/deploy.sh"
    echo ""
    echo "  3. Verify deployment:"
    echo "     ./ops/verify.sh"
    echo ""
    
    exit 0
}

# Run main function
main "$@"
