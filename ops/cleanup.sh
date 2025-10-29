#!/usr/bin/env bash

################################################################################
# Docker Swarm Stack Cleanup Script
# 
# This script tears down the Docker Swarm deployment for the Names Manager
# application with various cleanup options.
#
# Usage:
#   ./ops/cleanup.sh [OPTIONS]
#
# Options:
#   --help              Show this help message
#   --yes               Skip all confirmations (automatic yes)
#   --keep-swarm        Remove stack but keep Swarm cluster intact
#   --full              Remove stack, volumes, leave Swarm, stop VM (requires confirmation)
#   --stack-only        Remove only the stack (default, safest)
#   --remove-volumes    Remove volumes (data loss warning)
#
# Exit Codes:
#   0 - Cleanup successful
#   1 - Error during cleanup
#   2 - User cancelled operation
#
# Default Behavior:
#   - Removes stack (services and networks)
#   - Keeps volumes (preserves data)
#   - Keeps Swarm cluster (allows redeployment)
#   - Keeps Vagrant VM running
#
################################################################################

set -euo pipefail

# Configuration
STACK_NAME="names-app"
VAGRANT_DIR="vagrant"
TIMEOUT=60  # Seconds to wait for services to stop

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Flags
AUTO_YES=false
KEEP_SWARM=false
FULL_CLEANUP=false
STACK_ONLY=true
REMOVE_VOLUMES=false

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  WARNING: $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  INFO: $1${NC}"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

show_help() {
    cat << EOF
Docker Swarm Stack Cleanup Script

This script tears down the Docker Swarm deployment for the Names Manager
application with various cleanup options.

Usage:
    ./ops/cleanup.sh [OPTIONS]

Options:
    --help              Show this help message
    --yes               Skip all confirmations (automatic yes)
    --keep-swarm        Remove stack but keep Swarm cluster intact (default)
    --full              Remove stack, volumes, leave Swarm, stop VM (requires confirmation)
    --stack-only        Remove only the stack (default, safest)
    --remove-volumes    Remove volumes (data loss warning, requires confirmation)

Exit Codes:
    0 - Cleanup successful
    1 - Error during cleanup
    2 - User cancelled operation

Default Behavior (safest):
    - Removes stack (services and networks)
    - Keeps volumes (preserves database data)
    - Keeps Swarm cluster (allows quick redeployment)
    - Keeps Vagrant VM running

Cleanup Levels:

    1. Stack Only (default - safest):
       ./ops/cleanup.sh
       - Removes services and networks
       - Preserves volumes, Swarm, and VM
       - Quick redeployment possible

    2. Stack + Volumes:
       ./ops/cleanup.sh --remove-volumes
       - Removes services, networks, and volumes
       - ⚠️  DELETES DATABASE DATA
       - Preserves Swarm and VM

    3. Full Cleanup:
       ./ops/cleanup.sh --full
       - Removes everything
       - Leaves Swarm cluster
       - Stops Vagrant VM
       - ⚠️  REQUIRES FULL RE-INITIALIZATION

Examples:
    # Remove stack only (safe, data preserved)
    ./ops/cleanup.sh

    # Remove stack and volumes (data loss)
    ./ops/cleanup.sh --remove-volumes

    # Full cleanup (Swarm + VM)
    ./ops/cleanup.sh --full

    # Remove stack without confirmation
    ./ops/cleanup.sh --yes

    # Keep Swarm, remove stack and volumes
    ./ops/cleanup.sh --remove-volumes --keep-swarm

Restoration:
    After cleanup, redeploy with:
    - Stack only: ./ops/deploy.sh
    - Full cleanup: ./ops/init-swarm.sh && ./ops/deploy.sh

EOF
}

confirm() {
    local prompt="$1"
    local default="${2:-n}"
    
    if [[ "$AUTO_YES" == "true" ]]; then
        echo -e "${YELLOW}$prompt [auto-confirmed]${NC}"
        return 0
    fi
    
    local response
    if [[ "$default" == "y" ]]; then
        read -r -p "$(echo -e ${YELLOW}$prompt [Y/n]: ${NC})" response
        response=${response:-y}
    else
        read -r -p "$(echo -e ${YELLOW}$prompt [y/N]: ${NC})" response
        response=${response:-n}
    fi
    
    case "$response" in
        [yY][eE][sS]|[yY]) 
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

################################################################################
# Cleanup Functions
################################################################################

check_prerequisites() {
    print_step "Checking prerequisites"
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        print_info "Start Docker Desktop or docker daemon"
        return 1
    fi
    
    print_success "Docker daemon is running"
    return 0
}

check_stack_exists() {
    if docker stack ls --format '{{.Name}}' 2>/dev/null | grep -q "^${STACK_NAME}$"; then
        return 0
    else
        return 1
    fi
}

remove_stack() {
    print_step "Removing stack '${STACK_NAME}'"
    
    if ! check_stack_exists; then
        print_warn "Stack '${STACK_NAME}' does not exist (already removed)"
        return 0
    fi
    
    # Show what will be removed
    echo ""
    print_info "Services to be removed:"
    docker stack services "${STACK_NAME}" --format "  • {{.Name}} ({{.Replicas}})" 2>/dev/null || true
    echo ""
    
    # Ask for confirmation
    if ! confirm "Remove stack '${STACK_NAME}'?" "y"; then
        print_warn "Stack removal cancelled by user"
        return 2
    fi
    
    # Remove the stack
    if docker stack rm "${STACK_NAME}" 2>/dev/null; then
        print_success "Stack removal initiated"
    else
        print_error "Failed to remove stack"
        return 1
    fi
    
    # Wait for services to stop
    print_info "Waiting for services to stop (timeout: ${TIMEOUT}s)..."
    
    local elapsed=0
    local interval=2
    
    while [[ $elapsed -lt $TIMEOUT ]]; do
        # Check if any services still exist
        local service_count
        service_count=$(docker service ls --filter "label=com.docker.stack.namespace=${STACK_NAME}" --format '{{.Name}}' 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ "$service_count" -eq 0 ]]; then
            print_success "All services stopped"
            break
        fi
        
        echo -n "."
        sleep $interval
        elapsed=$((elapsed + interval))
    done
    echo ""
    
    if [[ $elapsed -ge $TIMEOUT ]]; then
        print_warn "Timeout waiting for services to stop"
        print_info "Some services may still be shutting down"
    fi
    
    # Verify stack is removed
    if check_stack_exists; then
        print_error "Stack still exists after removal"
        return 1
    fi
    
    print_success "Stack '${STACK_NAME}' removed successfully"
    return 0
}

remove_volumes() {
    print_step "Removing volumes"
    
    # List volumes associated with the stack
    local volumes
    volumes=$(docker volume ls --filter "label=com.docker.stack.namespace=${STACK_NAME}" --format '{{.Name}}' 2>/dev/null)
    
    if [[ -z "$volumes" ]]; then
        print_info "No volumes found for stack '${STACK_NAME}'"
        return 0
    fi
    
    echo ""
    print_warn "⚠️  DATA LOSS WARNING ⚠️"
    print_warn "The following volumes will be PERMANENTLY DELETED:"
    echo ""
    echo "$volumes" | while read -r vol; do
        echo -e "  ${RED}• $vol${NC}"
    done
    echo ""
    print_warn "This will delete all database data!"
    print_warn "This operation CANNOT be undone!"
    echo ""
    
    # Ask for confirmation
    if ! confirm "Are you ABSOLUTELY SURE you want to delete these volumes?" "n"; then
        print_warn "Volume removal cancelled by user"
        return 2
    fi
    
    # Double confirmation for safety
    if [[ "$AUTO_YES" != "true" ]]; then
        if ! confirm "Type 'yes' to confirm volume deletion" "n"; then
            print_warn "Volume removal cancelled by user"
            return 2
        fi
    fi
    
    # Remove volumes
    local removed_count=0
    while IFS= read -r vol; do
        if docker volume rm "$vol" 2>/dev/null; then
            print_success "Removed volume: $vol"
            removed_count=$((removed_count + 1))
        else
            print_error "Failed to remove volume: $vol"
        fi
    done <<< "$volumes"
    
    if [[ $removed_count -gt 0 ]]; then
        print_success "Removed $removed_count volume(s)"
    fi
    
    return 0
}

remove_networks() {
    print_step "Checking for orphaned networks"
    
    # List networks associated with the stack
    local networks
    networks=$(docker network ls --filter "label=com.docker.stack.namespace=${STACK_NAME}" --format '{{.Name}}' 2>/dev/null)
    
    if [[ -z "$networks" ]]; then
        print_info "No orphaned networks found"
        return 0
    fi
    
    print_info "Removing orphaned networks..."
    
    while IFS= read -r net; do
        if docker network rm "$net" 2>/dev/null; then
            print_success "Removed network: $net"
        else
            print_warn "Could not remove network: $net (may still be in use)"
        fi
    done <<< "$networks"
    
    return 0
}

leave_swarm() {
    print_step "Leaving Docker Swarm"
    
    # Check if Swarm is active
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        print_info "Not in Swarm mode (already left or never joined)"
        return 0
    fi
    
    echo ""
    print_warn "This will remove this node from the Swarm cluster"
    print_warn "You will need to run ./ops/init-swarm.sh to redeploy"
    echo ""
    
    if ! confirm "Leave Docker Swarm cluster?" "n"; then
        print_warn "Swarm leave cancelled by user"
        return 2
    fi
    
    # Get node info
    local is_manager=false
    if docker node ls &> /dev/null; then
        is_manager=true
    fi
    
    # If manager node, need to remove workers first or force leave
    if [[ "$is_manager" == "true" ]]; then
        local node_count
        node_count=$(docker node ls --format '{{.Hostname}}' 2>/dev/null | wc -l | tr -d ' ')
        
        if [[ "$node_count" -gt 1 ]]; then
            print_warn "This is a manager node with $node_count nodes in cluster"
            print_info "Workers should be removed first, or use --force"
            
            if confirm "Force leave Swarm (may strand worker nodes)?" "n"; then
                docker swarm leave --force
                print_success "Left Swarm (forced)"
            else
                print_warn "Swarm leave cancelled"
                return 2
            fi
        else
            docker swarm leave --force
            print_success "Left Swarm"
        fi
    else
        docker swarm leave
        print_success "Left Swarm"
    fi
    
    return 0
}

stop_vagrant_vm() {
    print_step "Stopping Vagrant VM"
    
    # Check if Vagrant is installed
    if ! command -v vagrant &> /dev/null; then
        print_info "Vagrant not installed, skipping VM stop"
        return 0
    fi
    
    # Check if Vagrantfile exists
    if [[ ! -f "${VAGRANT_DIR}/Vagrantfile" ]]; then
        print_info "Vagrantfile not found, skipping VM stop"
        return 0
    fi
    
    # Check VM status
    cd "$VAGRANT_DIR"
    local vm_status
    vm_status=$(vagrant status 2>/dev/null | grep -E "(running|poweroff|saved)" | head -1 || true)
    
    if [[ -z "$vm_status" ]]; then
        print_info "No Vagrant VM found"
        cd - > /dev/null
        return 0
    fi
    
    if echo "$vm_status" | grep -q "running"; then
        echo ""
        print_warn "This will stop the Vagrant worker VM"
        print_info "You will need to run ./ops/init-swarm.sh to restart it"
        echo ""
        
        if ! confirm "Stop Vagrant VM?" "n"; then
            print_warn "VM stop cancelled by user"
            cd - > /dev/null
            return 2
        fi
        
        print_info "Stopping Vagrant VM..."
        if vagrant halt 2>&1 | grep -v "^$"; then
            print_success "Vagrant VM stopped"
        else
            print_error "Failed to stop Vagrant VM"
            cd - > /dev/null
            return 1
        fi
    else
        print_info "Vagrant VM is not running"
    fi
    
    cd - > /dev/null
    return 0
}

show_cleanup_summary() {
    print_header "Cleanup Summary"
    
    echo -e "${BOLD}What was cleaned up:${NC}"
    
    # Check stack
    if check_stack_exists; then
        echo -e "  ${YELLOW}○ Stack '${STACK_NAME}' - Still exists${NC}"
    else
        echo -e "  ${GREEN}✓ Stack '${STACK_NAME}' - Removed${NC}"
    fi
    
    # Check volumes
    local vol_count
    vol_count=$(docker volume ls --filter "label=com.docker.stack.namespace=${STACK_NAME}" --format '{{.Name}}' 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$vol_count" -gt 0 ]]; then
        echo -e "  ${YELLOW}○ Volumes - $vol_count remaining (data preserved)${NC}"
    else
        echo -e "  ${GREEN}✓ Volumes - All removed${NC}"
    fi
    
    # Check Swarm
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        local node_count
        node_count=$(docker node ls --format '{{.Hostname}}' 2>/dev/null | wc -l | tr -d ' ')
        echo -e "  ${YELLOW}○ Swarm - Active with $node_count node(s)${NC}"
    else
        echo -e "  ${GREEN}✓ Swarm - Left cluster${NC}"
    fi
    
    # Check Vagrant VM
    if command -v vagrant &> /dev/null && [[ -f "${VAGRANT_DIR}/Vagrantfile" ]]; then
        cd "$VAGRANT_DIR"
        if vagrant status 2>/dev/null | grep -q "running"; then
            echo -e "  ${YELLOW}○ Vagrant VM - Still running${NC}"
        else
            echo -e "  ${GREEN}✓ Vagrant VM - Stopped${NC}"
        fi
        cd - > /dev/null
    fi
    
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    
    if check_stack_exists; then
        echo -e "  ${CYAN}• Stack still exists, cleanup incomplete${NC}"
    elif [[ "$vol_count" -gt 0 ]] && docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo -e "  ${CYAN}• Quick redeploy: ./ops/deploy.sh${NC}"
        echo -e "  ${CYAN}• Remove volumes: ./ops/cleanup.sh --remove-volumes${NC}"
        echo -e "  ${CYAN}• Full cleanup: ./ops/cleanup.sh --full${NC}"
    elif docker info 2>/dev/null | grep -q "Swarm: active"; then
        echo -e "  ${CYAN}• Redeploy: ./ops/deploy.sh${NC}"
        echo -e "  ${CYAN}• Leave Swarm: ./ops/cleanup.sh --full${NC}"
    else
        echo -e "  ${CYAN}• Full re-initialization: ./ops/init-swarm.sh && ./ops/deploy.sh${NC}"
    fi
    
    echo ""
}

################################################################################
# Main Function
################################################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --yes)
                AUTO_YES=true
                shift
                ;;
            --keep-swarm)
                KEEP_SWARM=true
                FULL_CLEANUP=false
                shift
                ;;
            --full)
                FULL_CLEANUP=true
                KEEP_SWARM=false
                STACK_ONLY=false
                REMOVE_VOLUMES=true
                shift
                ;;
            --stack-only)
                STACK_ONLY=true
                REMOVE_VOLUMES=false
                FULL_CLEANUP=false
                shift
                ;;
            --remove-volumes)
                REMOVE_VOLUMES=true
                STACK_ONLY=false
                shift
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    print_header "🧹 Docker Swarm Stack Cleanup"
    
    # Show cleanup plan
    echo -e "${BOLD}Cleanup plan:${NC}"
    echo -e "  • Remove stack: ${GREEN}YES${NC}"
    
    if [[ "$REMOVE_VOLUMES" == "true" ]]; then
        echo -e "  • Remove volumes: ${RED}YES (data loss)${NC}"
    else
        echo -e "  • Remove volumes: ${GREEN}NO (data preserved)${NC}"
    fi
    
    if [[ "$FULL_CLEANUP" == "true" ]]; then
        echo -e "  • Leave Swarm: ${YELLOW}YES${NC}"
        echo -e "  • Stop Vagrant VM: ${YELLOW}YES${NC}"
    else
        echo -e "  • Leave Swarm: ${GREEN}NO (cluster preserved)${NC}"
        echo -e "  • Stop Vagrant VM: ${GREEN}NO (VM preserved)${NC}"
    fi
    
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        exit 1
    fi
    
    echo ""
    
    # Execute cleanup steps
    local exit_code=0
    
    # Step 1: Remove stack
    if ! remove_stack; then
        exit_code=$?
        if [[ $exit_code -eq 2 ]]; then
            print_warn "Cleanup cancelled by user"
            exit 2
        fi
    fi
    
    echo ""
    
    # Step 2: Remove networks (automatic, no confirmation needed)
    remove_networks
    
    echo ""
    
    # Step 3: Remove volumes (if requested)
    if [[ "$REMOVE_VOLUMES" == "true" ]]; then
        if ! remove_volumes; then
            exit_code=$?
            if [[ $exit_code -eq 2 ]]; then
                print_warn "Volume removal cancelled by user"
                # Continue with other cleanup steps
            fi
        fi
        echo ""
    fi
    
    # Step 4: Leave Swarm (if full cleanup)
    if [[ "$FULL_CLEANUP" == "true" ]]; then
        if ! leave_swarm; then
            exit_code=$?
            if [[ $exit_code -eq 2 ]]; then
                print_warn "Swarm leave cancelled by user"
                # Continue with other cleanup steps
            fi
        fi
        echo ""
        
        # Step 5: Stop Vagrant VM (if full cleanup)
        if ! stop_vagrant_vm; then
            exit_code=$?
            if [[ $exit_code -eq 2 ]]; then
                print_warn "VM stop cancelled by user"
            fi
        fi
        echo ""
    fi
    
    # Show summary
    show_cleanup_summary
    
    if [[ $exit_code -eq 0 ]]; then
        print_success "Cleanup completed successfully"
    else
        print_warn "Cleanup completed with warnings"
    fi
    
    exit $exit_code
}

# Run main function
main "$@"
