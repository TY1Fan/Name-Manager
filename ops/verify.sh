#!/usr/bin/env bash

################################################################################
# Docker Swarm Stack Verification Script
# 
# This script verifies the health and proper configuration of the deployed
# Docker Swarm stack for the Names Manager application.
#
# Usage:
#   ./ops/verify.sh [OPTIONS]
#
# Options:
#   --help              Show this help message
#   --verbose           Show detailed output for each check
#   --quick             Skip slow checks (service discovery)
#
# Exit Codes:
#   0 - All checks passed
#   1 - Some checks failed
#
# Requirements:
#   - Docker Swarm cluster initialized
#   - Stack 'names-app' deployed
#   - curl command available
#
################################################################################

set -euo pipefail

# Configuration
STACK_NAME="names-app"
EXPECTED_SERVICES=3
MANAGER_IP="192.168.56.1"
WORKER_IP="192.168.56.10"
FRONTEND_PORT=80
BACKEND_PORT=8000

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Flags
VERBOSE=false
QUICK=false

# Check results tracking
declare -a PASSED_CHECKS=()
declare -a FAILED_CHECKS=()
declare -a WARNING_CHECKS=()

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

print_check() {
    echo -e "${BLUE}🔍 Checking:${NC} $1"
}

print_pass() {
    echo -e "${GREEN}✅ PASS:${NC} $1"
    PASSED_CHECKS+=("$1")
}

print_fail() {
    echo -e "${RED}❌ FAIL:${NC} $1"
    FAILED_CHECKS+=("$1")
}

print_warn() {
    echo -e "${YELLOW}⚠️  WARN:${NC} $1"
    WARNING_CHECKS+=("$1")
}

print_info() {
    echo -e "${CYAN}ℹ️  INFO:${NC} $1"
}

print_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}    $1${NC}"
    fi
}

print_troubleshoot() {
    echo -e "${YELLOW}💡 Troubleshooting:${NC} $1"
}

show_help() {
    cat << EOF
Docker Swarm Stack Verification Script

This script verifies the health and proper configuration of the deployed
Docker Swarm stack for the Names Manager application.

Usage:
    ./ops/verify.sh [OPTIONS]

Options:
    --help              Show this help message
    --verbose           Show detailed output for each check
    --quick             Skip slow checks (service discovery)

Exit Codes:
    0 - All checks passed
    1 - Some checks failed

Checks Performed:
    1. Docker Swarm is active
    2. Stack exists and has correct number of services
    3. All services are running (replicas ready)
    4. Services are placed on correct nodes
    5. Database health (pg_isready)
    6. Backend health endpoint (/healthz)
    7. Frontend accessibility (HTTP 200)
    8. Service discovery (backend can reach database)

Examples:
    # Run all checks
    ./ops/verify.sh

    # Run with detailed output
    ./ops/verify.sh --verbose

    # Quick check (skip service discovery test)
    ./ops/verify.sh --quick

EOF
}

################################################################################
# Check Functions
################################################################################

check_docker_running() {
    print_check "Docker daemon is running"
    
    if ! docker info &> /dev/null; then
        print_fail "Docker daemon is not running"
        print_troubleshoot "Start Docker Desktop or docker daemon"
        return 1
    fi
    
    print_pass "Docker daemon is running"
    return 0
}

check_swarm_active() {
    print_check "Docker Swarm is active"
    
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        print_fail "Docker Swarm is not active"
        print_troubleshoot "Initialize Swarm: ./ops/init-swarm.sh"
        return 1
    fi
    
    local node_count
    node_count=$(docker node ls --format '{{.Hostname}}' 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$node_count" -lt 2 ]]; then
        print_fail "Swarm has only $node_count node(s), expected at least 2"
        print_troubleshoot "Ensure worker node is joined: ./ops/init-swarm.sh"
        return 1
    fi
    
    print_pass "Docker Swarm is active with $node_count nodes"
    print_verbose "$(docker node ls)"
    return 0
}

check_stack_exists() {
    print_check "Stack '$STACK_NAME' exists"
    
    if ! docker stack ls --format '{{.Name}}' 2>/dev/null | grep -q "^${STACK_NAME}$"; then
        print_fail "Stack '$STACK_NAME' not found"
        print_troubleshoot "Deploy stack: ./ops/deploy.sh"
        return 1
    fi
    
    local service_count
    service_count=$(docker stack services "$STACK_NAME" --format '{{.Name}}' 2>/dev/null | wc -l | tr -d ' ')
    
    if [[ "$service_count" -ne "$EXPECTED_SERVICES" ]]; then
        print_fail "Stack has $service_count services, expected $EXPECTED_SERVICES"
        print_troubleshoot "Redeploy stack: ./ops/deploy.sh --update"
        return 1
    fi
    
    print_pass "Stack '$STACK_NAME' exists with $service_count services"
    print_verbose "$(docker stack services "$STACK_NAME")"
    return 0
}

check_services_running() {
    print_check "All services have ready replicas"
    
    local all_ready=true
    local services
    services=$(docker service ls --filter "label=com.docker.stack.namespace=${STACK_NAME}" --format '{{.Name}}' 2>/dev/null)
    
    if [[ -z "$services" ]]; then
        print_fail "No services found for stack '$STACK_NAME'"
        return 1
    fi
    
    while IFS= read -r service; do
        local replicas
        replicas=$(docker service ls --filter "name=${service}" --format '{{.Replicas}}' 2>/dev/null)
        
        print_verbose "Service: $service - Replicas: $replicas"
        
        if [[ ! "$replicas" =~ ^([0-9]+)/\1 ]]; then
            print_fail "Service '$service' not ready: $replicas"
            all_ready=false
            
            # Show task details for failed service
            print_troubleshoot "Check service logs: docker service logs $service"
            if [[ "$VERBOSE" == "true" ]]; then
                docker service ps "$service" --no-trunc
            fi
        fi
    done <<< "$services"
    
    if [[ "$all_ready" == "true" ]]; then
        print_pass "All services have ready replicas"
        return 0
    else
        return 1
    fi
}

check_service_placement() {
    print_check "Services are placed on correct nodes"
    
    local all_correct=true
    
    # Check database is on worker
    local db_node
    db_node=$(docker service ps "${STACK_NAME}_db" --format '{{.Node}}' 2>/dev/null | head -1)
    
    if [[ -z "$db_node" ]]; then
        print_fail "Cannot find database service placement"
        all_correct=false
    elif [[ "$db_node" != *"worker"* ]] && [[ "$db_node" != "vagrant-worker" ]]; then
        print_fail "Database service is on '$db_node', expected worker node"
        print_troubleshoot "Check stack.yaml placement constraints"
        all_correct=false
    else
        print_verbose "Database service on: $db_node ✓"
    fi
    
    # Check backend is on manager
    local backend_node
    backend_node=$(docker service ps "${STACK_NAME}_backend" --format '{{.Node}}' 2>/dev/null | head -1)
    
    if [[ -z "$backend_node" ]]; then
        print_fail "Cannot find backend service placement"
        all_correct=false
    elif [[ "$backend_node" == *"worker"* ]] || [[ "$backend_node" == "vagrant-worker" ]]; then
        print_fail "Backend service is on '$backend_node', expected manager node"
        print_troubleshoot "Check stack.yaml placement constraints"
        all_correct=false
    else
        print_verbose "Backend service on: $backend_node ✓"
    fi
    
    # Check frontend is on manager
    local frontend_node
    frontend_node=$(docker service ps "${STACK_NAME}_frontend" --format '{{.Node}}' 2>/dev/null | head -1)
    
    if [[ -z "$frontend_node" ]]; then
        print_fail "Cannot find frontend service placement"
        all_correct=false
    elif [[ "$frontend_node" == *"worker"* ]] || [[ "$frontend_node" == "vagrant-worker" ]]; then
        print_fail "Frontend service is on '$frontend_node', expected manager node"
        print_troubleshoot "Check stack.yaml placement constraints"
        all_correct=false
    else
        print_verbose "Frontend service on: $frontend_node ✓"
    fi
    
    if [[ "$all_correct" == "true" ]]; then
        print_pass "All services are placed on correct nodes"
        return 0
    else
        return 1
    fi
}

check_database_health() {
    print_check "Database health (pg_isready)"
    
    # Get database container ID
    local db_container
    db_container=$(docker service ps "${STACK_NAME}_db" --filter "desired-state=running" --format '{{.Name}}.{{.ID}}' 2>/dev/null | head -1)
    
    if [[ -z "$db_container" ]]; then
        print_fail "Cannot find running database container"
        print_troubleshoot "Check database service: docker service logs ${STACK_NAME}_db"
        return 1
    fi
    
    print_verbose "Database container: $db_container"
    
    # Execute pg_isready inside container
    if docker exec "$db_container" pg_isready -U postgres &> /dev/null; then
        print_pass "Database is accepting connections"
        return 0
    else
        print_fail "Database is not accepting connections"
        print_troubleshoot "Check database logs: docker service logs ${STACK_NAME}_db"
        return 1
    fi
}

check_backend_health() {
    print_check "Backend health endpoint (/healthz)"
    
    local healthz_url="http://localhost:${BACKEND_PORT}/healthz"
    
    # Try to reach health endpoint
    local response
    local http_code
    
    if response=$(curl -s -w "\n%{http_code}" --max-time 5 "$healthz_url" 2>/dev/null); then
        http_code=$(echo "$response" | tail -1)
        local body
        body=$(echo "$response" | head -n -1)
        
        print_verbose "HTTP Code: $http_code"
        print_verbose "Response: $body"
        
        if [[ "$http_code" == "200" ]]; then
            if echo "$body" | grep -q '"status".*"ok"'; then
                print_pass "Backend health endpoint returns healthy status"
                return 0
            else
                print_warn "Backend health endpoint returned 200 but unexpected body"
                return 0
            fi
        else
            print_fail "Backend health endpoint returned HTTP $http_code"
            print_troubleshoot "Check backend logs: docker service logs ${STACK_NAME}_backend"
            return 1
        fi
    else
        print_fail "Cannot reach backend health endpoint at $healthz_url"
        print_troubleshoot "Check backend service: docker service logs ${STACK_NAME}_backend"
        print_troubleshoot "Check if backend port is accessible: docker service inspect ${STACK_NAME}_backend"
        return 1
    fi
}

check_frontend_accessible() {
    print_check "Frontend accessibility (HTTP 200 on port $FRONTEND_PORT)"
    
    local frontend_url="http://localhost:${FRONTEND_PORT}"
    
    # Try to reach frontend
    local http_code
    
    if http_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$frontend_url" 2>/dev/null); then
        print_verbose "HTTP Code: $http_code"
        
        if [[ "$http_code" == "200" ]]; then
            print_pass "Frontend is accessible and returns HTTP 200"
            return 0
        else
            print_fail "Frontend returned HTTP $http_code instead of 200"
            print_troubleshoot "Check frontend logs: docker service logs ${STACK_NAME}_frontend"
            return 1
        fi
    else
        print_fail "Cannot reach frontend at $frontend_url"
        print_troubleshoot "Check frontend service: docker service logs ${STACK_NAME}_frontend"
        print_troubleshoot "Verify port 80 is exposed: docker service inspect ${STACK_NAME}_frontend"
        return 1
    fi
}

check_service_discovery() {
    print_check "Cross-node service discovery (backend → database)"
    
    if [[ "$QUICK" == "true" ]]; then
        print_info "Skipping service discovery check (--quick mode)"
        return 0
    fi
    
    # Get backend container ID
    local backend_container
    backend_container=$(docker service ps "${STACK_NAME}_backend" --filter "desired-state=running" --format '{{.Name}}.{{.ID}}' 2>/dev/null | head -1)
    
    if [[ -z "$backend_container" ]]; then
        print_fail "Cannot find running backend container"
        return 1
    fi
    
    print_verbose "Backend container: $backend_container"
    
    # Try to resolve database service name from backend container
    # The database service should be accessible as "db" or "names-app_db"
    local test_result
    
    # Test 1: Can resolve service name
    if docker exec "$backend_container" getent hosts db &> /dev/null; then
        print_verbose "Service name 'db' resolves ✓"
        
        # Test 2: Can connect to database port
        if docker exec "$backend_container" nc -zv db 5432 &> /dev/null || \
           docker exec "$backend_container" timeout 5 sh -c 'cat < /dev/null > /dev/tcp/db/5432' &> /dev/null; then
            print_pass "Backend can reach database via service discovery"
            return 0
        else
            print_fail "Backend can resolve 'db' but cannot connect to port 5432"
            print_troubleshoot "Check database service: docker service logs ${STACK_NAME}_db"
            print_troubleshoot "Check overlay network: docker network inspect ${STACK_NAME}_appnet"
            return 1
        fi
    else
        print_fail "Backend cannot resolve service name 'db'"
        print_troubleshoot "Check overlay network: docker network inspect ${STACK_NAME}_appnet"
        print_troubleshoot "Verify services are on same network: docker service inspect ${STACK_NAME}_backend"
        return 1
    fi
}

################################################################################
# Summary Functions
################################################################################

print_summary() {
    echo ""
    print_header "Verification Summary"
    
    local total_checks=$((${#PASSED_CHECKS[@]} + ${#FAILED_CHECKS[@]} + ${#WARNING_CHECKS[@]}))
    local pass_count=${#PASSED_CHECKS[@]}
    local fail_count=${#FAILED_CHECKS[@]}
    local warn_count=${#WARNING_CHECKS[@]}
    
    echo -e "${BOLD}Total Checks: $total_checks${NC}"
    echo -e "${GREEN}Passed: $pass_count${NC}"
    echo -e "${RED}Failed: $fail_count${NC}"
    echo -e "${YELLOW}Warnings: $warn_count${NC}"
    echo ""
    
    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 All checks passed! Your Swarm deployment is healthy.${NC}"
        echo ""
        echo -e "${CYAN}📍 Application Access:${NC}"
        echo -e "   Frontend:      http://localhost:${FRONTEND_PORT}"
        echo -e "   Frontend:      http://${MANAGER_IP}:${FRONTEND_PORT}"
        echo -e "   API Health:    http://localhost/api/health"
        echo -e "   Swarm Health:  http://localhost/healthz"
        echo ""
        echo -e "${CYAN}📊 Monitoring:${NC}"
        echo -e "   Service Status:  docker stack services ${STACK_NAME}"
        echo -e "   Service Logs:    docker service logs ${STACK_NAME}_<service>"
        echo -e "   Service Details: docker stack ps ${STACK_NAME}"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}❌ Some checks failed. Review the failures above.${NC}"
        echo ""
        echo -e "${YELLOW}Failed Checks:${NC}"
        for check in "${FAILED_CHECKS[@]}"; do
            echo -e "  • $check"
        done
        echo ""
        echo -e "${YELLOW}💡 Common Solutions:${NC}"
        echo -e "  • Re-deploy stack:     ./ops/deploy.sh --update"
        echo -e "  • Check service logs:  docker service logs ${STACK_NAME}_<service>"
        echo -e "  • Restart services:    docker service update --force ${STACK_NAME}_<service>"
        echo -e "  • View stack events:   docker stack ps ${STACK_NAME}"
        echo ""
        return 1
    fi
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
            --verbose)
                VERBOSE=true
                shift
                ;;
            --quick)
                QUICK=true
                shift
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    print_header "🔍 Docker Swarm Stack Verification"
    
    print_info "Stack: $STACK_NAME"
    print_info "Expected Services: $EXPECTED_SERVICES (frontend, backend, db)"
    if [[ "$QUICK" == "true" ]]; then
        print_info "Mode: Quick (skipping slow checks)"
    fi
    echo ""
    
    # Run all checks
    check_docker_running
    check_swarm_active
    check_stack_exists
    check_services_running
    check_service_placement
    check_database_health
    check_backend_health
    check_frontend_accessible
    check_service_discovery
    
    # Print summary and exit with appropriate code
    print_summary
    local exit_code=$?
    
    exit $exit_code
}

# Run main function
main "$@"
