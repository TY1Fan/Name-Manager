#!/usr/bin/env bash

################################################################################
# End-to-End Integration Test Runner
# 
# This script automates the execution of end-to-end integration tests for
# the Docker Swarm deployment of the Names Manager application.
#
# Usage:
#   ./ops/test-e2e.sh [OPTIONS]
#
# Options:
#   --help              Show this help message
#   --quick             Skip slow tests (persistence, recovery)
#   --cleanup-only      Only run cleanup test
#   --no-cleanup        Skip final cleanup (leave environment running)
#   --verbose           Show detailed output
#
# Exit Codes:
#   0 - All tests passed
#   1 - Some tests failed
#
################################################################################

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly TEST_LOG_DIR="$PROJECT_ROOT/logs/testing"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Flags
QUICK_MODE=false
CLEANUP_ONLY=false
NO_CLEANUP=false
VERBOSE=false

# Test tracking
declare -a PASSED_TESTS=()
declare -a FAILED_TESTS=()
declare -a SKIPPED_TESTS=()

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

print_test() {
    echo -e "${BLUE}▶ TEST: $1${NC}"
}

print_pass() {
    echo -e "${GREEN}✅ PASS: $1${NC}"
    PASSED_TESTS+=("$1")
}

print_fail() {
    echo -e "${RED}❌ FAIL: $1${NC}"
    FAILED_TESTS+=("$1")
}

print_skip() {
    echo -e "${YELLOW}⏭️  SKIP: $1${NC}"
    SKIPPED_TESTS+=("$1")
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${CYAN}    $1${NC}"
    fi
}

show_help() {
    cat << EOF
End-to-End Integration Test Runner

This script automates the execution of end-to-end integration tests for
the Docker Swarm deployment of the Names Manager application.

Usage:
    ./ops/test-e2e.sh [OPTIONS]

Options:
    --help              Show this help message
    --quick             Skip slow tests (persistence, recovery)
    --cleanup-only      Only run cleanup test
    --no-cleanup        Skip final cleanup (leave environment running)
    --verbose           Show detailed output

Exit Codes:
    0 - All tests passed
    1 - Some tests failed

Test Suite:
    1. Fresh Swarm initialization
    2. Stack deployment
    3. Deployment verification
    4. Web UI functionality
    5. Service restart persistence
    6. Stack redeploy persistence
    7. Database volume on worker
    8. Automatic container restart
    9. Frontend accessibility
    10. Cleanup script

Examples:
    # Run all tests
    ./ops/test-e2e.sh

    # Quick test (skip slow tests)
    ./ops/test-e2e.sh --quick

    # Test only cleanup
    ./ops/test-e2e.sh --cleanup-only

    # Leave environment running after tests
    ./ops/test-e2e.sh --no-cleanup

EOF
}

setup_logging() {
    mkdir -p "$TEST_LOG_DIR"
    exec 1> >(tee "$TEST_LOG_DIR/e2e-test-$TIMESTAMP.log")
    exec 2>&1
}

################################################################################
# Test Functions
################################################################################

test_fresh_init() {
    print_test "Fresh Swarm Initialization"
    
    local start_time=$(date +%s)
    
    # Ensure clean state
    print_info "Ensuring clean state..."
    "$PROJECT_ROOT/ops/cleanup.sh" --full --yes &>/dev/null || true
    sleep 5
    
    # Run initialization
    print_info "Running init-swarm.sh..."
    if "$PROJECT_ROOT/ops/init-swarm.sh" > "$TEST_LOG_DIR/test1-init.log" 2>&1; then
        # Verify Swarm is active
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
            # Verify 2 nodes
            local node_count=$(docker node ls --format '{{.Hostname}}' 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$node_count" -eq 2 ]]; then
                local duration=$(($(date +%s) - start_time))
                print_pass "Fresh Swarm Initialization (${duration}s)"
                return 0
            fi
        fi
    fi
    
    print_fail "Fresh Swarm Initialization"
    print_info "See log: $TEST_LOG_DIR/test1-init.log"
    return 1
}

test_stack_deployment() {
    print_test "Stack Deployment"
    
    local start_time=$(date +%s)
    
    # Ensure .env exists
    if [[ ! -f "$PROJECT_ROOT/src/.env" ]]; then
        print_info "Creating .env file..."
        cp "$PROJECT_ROOT/src/.env.example" "$PROJECT_ROOT/src/.env"
    fi
    
    # Deploy stack
    print_info "Running deploy.sh..."
    if "$PROJECT_ROOT/ops/deploy.sh" > "$TEST_LOG_DIR/test2-deploy.log" 2>&1; then
        # Verify stack exists
        if docker stack ls --format '{{.Name}}' 2>/dev/null | grep -q "^names-app$"; then
            # Verify 3 services
            local service_count=$(docker stack services names-app --format '{{.Name}}' 2>/dev/null | wc -l | tr -d ' ')
            if [[ "$service_count" -eq 3 ]]; then
                local duration=$(($(date +%s) - start_time))
                print_pass "Stack Deployment (${duration}s)"
                return 0
            fi
        fi
    fi
    
    print_fail "Stack Deployment"
    print_info "See log: $TEST_LOG_DIR/test2-deploy.log"
    return 1
}

test_verification() {
    print_test "Deployment Verification"
    
    local start_time=$(date +%s)
    
    print_info "Running verify.sh..."
    if "$PROJECT_ROOT/ops/verify.sh" > "$TEST_LOG_DIR/test3-verify.log" 2>&1; then
        local duration=$(($(date +%s) - start_time))
        print_pass "Deployment Verification (${duration}s)"
        return 0
    fi
    
    print_fail "Deployment Verification"
    print_info "See log: $TEST_LOG_DIR/test3-verify.log"
    return 1
}

test_web_ui() {
    print_test "Web UI Functionality"
    
    local start_time=$(date +%s)
    
    # Test adding names
    print_info "Adding test names..."
    local name1=$(curl -s -X POST http://localhost/api/names \
        -H "Content-Type: application/json" \
        -d '{"name":"Test User 1"}' 2>/dev/null)
    
    local name2=$(curl -s -X POST http://localhost/api/names \
        -H "Content-Type: application/json" \
        -d '{"name":"Test User 2"}' 2>/dev/null)
    
    # Verify names were added
    print_info "Verifying names..."
    local names=$(curl -s http://localhost/api/names 2>/dev/null)
    
    if echo "$names" | grep -q "Test User 1" && echo "$names" | grep -q "Test User 2"; then
        # Test deletion
        print_info "Testing deletion..."
        local id1=$(echo "$name1" | jq -r '.id' 2>/dev/null)
        curl -s -X DELETE "http://localhost/api/names/$id1" &>/dev/null
        
        # Verify deletion
        local names_after=$(curl -s http://localhost/api/names 2>/dev/null)
        if echo "$names_after" | grep -q "Test User 2" && ! echo "$names_after" | grep -q "Test User 1"; then
            local duration=$(($(date +%s) - start_time))
            print_pass "Web UI Functionality (${duration}s)"
            return 0
        fi
    fi
    
    print_fail "Web UI Functionality"
    return 1
}

test_service_restart_persistence() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        print_skip "Service Restart Persistence (quick mode)"
        return 0
    fi
    
    print_test "Service Restart Persistence"
    
    local start_time=$(date +%s)
    
    # Add test data
    print_info "Adding test data..."
    curl -s -X POST http://localhost/api/names \
        -H "Content-Type: application/json" \
        -d '{"name":"Persistence Test"}' &>/dev/null
    
    local before=$(curl -s http://localhost/api/names 2>/dev/null)
    
    # Restart backend service
    print_info "Restarting backend service..."
    docker service update --force names-app_backend &>/dev/null
    sleep 15
    
    # Verify data persists
    print_info "Verifying data..."
    local after=$(curl -s http://localhost/api/names 2>/dev/null)
    
    if echo "$after" | grep -q "Persistence Test"; then
        local duration=$(($(date +%s) - start_time))
        print_pass "Service Restart Persistence (${duration}s)"
        return 0
    fi
    
    print_fail "Service Restart Persistence"
    return 1
}

test_stack_redeploy_persistence() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        print_skip "Stack Redeploy Persistence (quick mode)"
        return 0
    fi
    
    print_test "Stack Redeploy Persistence"
    
    local start_time=$(date +%s)
    
    # Count names before
    print_info "Counting names before redeploy..."
    local before_count=$(curl -s http://localhost/api/names 2>/dev/null | jq '. | length' 2>/dev/null)
    
    print_verbose "Names before: $before_count"
    
    # Remove stack (keep volumes)
    print_info "Removing stack..."
    "$PROJECT_ROOT/ops/cleanup.sh" --yes &>/dev/null
    sleep 5
    
    # Redeploy
    print_info "Redeploying stack..."
    "$PROJECT_ROOT/ops/deploy.sh" &>/dev/null
    sleep 30
    
    # Count names after
    print_info "Counting names after redeploy..."
    local after_count=$(curl -s http://localhost/api/names 2>/dev/null | jq '. | length' 2>/dev/null)
    
    print_verbose "Names after: $after_count"
    
    if [[ "$before_count" -eq "$after_count" ]] && [[ "$after_count" -gt 0 ]]; then
        local duration=$(($(date +%s) - start_time))
        print_pass "Stack Redeploy Persistence (${duration}s)"
        return 0
    fi
    
    print_fail "Stack Redeploy Persistence (expected: $before_count, got: $after_count)"
    return 1
}

test_volume_on_worker() {
    print_test "Database Volume on Worker Node"
    
    local start_time=$(date +%s)
    
    # Check volume on worker
    print_info "Checking worker node volume..."
    cd "$PROJECT_ROOT/vagrant"
    if vagrant ssh -c "ls -la /var/lib/postgres-data" &>/dev/null; then
        # Check if it has data
        if vagrant ssh -c "du -sh /var/lib/postgres-data" 2>/dev/null | grep -qE '[1-9][0-9]*[KMG]'; then
            cd - > /dev/null
            local duration=$(($(date +%s) - start_time))
            print_pass "Database Volume on Worker Node (${duration}s)"
            return 0
        fi
    fi
    cd - > /dev/null
    
    print_fail "Database Volume on Worker Node"
    return 1
}

test_auto_restart() {
    if [[ "$QUICK_MODE" == "true" ]]; then
        print_skip "Automatic Container Restart (quick mode)"
        return 0
    fi
    
    print_test "Automatic Container Restart"
    
    local start_time=$(date +%s)
    
    # Get backend container
    print_info "Finding backend container..."
    local backend_container=$(docker ps --filter "name=names-app_backend" --format "{{.ID}}" | head -1)
    
    if [[ -z "$backend_container" ]]; then
        print_fail "Automatic Container Restart (no container found)"
        return 1
    fi
    
    print_verbose "Backend container: $backend_container"
    
    # Kill container
    print_info "Killing container..."
    docker kill "$backend_container" &>/dev/null
    
    # Wait for recovery
    print_info "Waiting for recovery..."
    sleep 15
    
    # Check if recovered
    if curl -s http://localhost/healthz 2>/dev/null | grep -q '"status".*"ok"'; then
        local duration=$(($(date +%s) - start_time))
        print_pass "Automatic Container Restart (${duration}s)"
        return 0
    fi
    
    print_fail "Automatic Container Restart"
    return 1
}

test_frontend_access() {
    print_test "Frontend Accessibility"
    
    local start_time=$(date +%s)
    
    # Test localhost
    print_info "Testing http://localhost..."
    local localhost_code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost 2>/dev/null)
    
    # Test manager IP
    print_info "Testing http://192.168.56.1..."
    local manager_code=$(curl -s -o /dev/null -w "%{http_code}" http://192.168.56.1 2>/dev/null)
    
    if [[ "$localhost_code" == "200" ]] && [[ "$manager_code" == "200" ]]; then
        local duration=$(($(date +%s) - start_time))
        print_pass "Frontend Accessibility (${duration}s)"
        return 0
    fi
    
    print_fail "Frontend Accessibility (localhost: $localhost_code, manager: $manager_code)"
    return 1
}

test_cleanup() {
    print_test "Cleanup Script"
    
    local start_time=$(date +%s)
    
    # Test stack-only cleanup
    print_info "Testing stack-only cleanup..."
    if ! "$PROJECT_ROOT/ops/cleanup.sh" --yes > "$TEST_LOG_DIR/test10-cleanup1.log" 2>&1; then
        print_fail "Cleanup Script (stack-only failed)"
        return 1
    fi
    
    # Verify stack removed
    if docker stack ls --format '{{.Name}}' 2>/dev/null | grep -q "^names-app$"; then
        print_fail "Cleanup Script (stack still exists)"
        return 1
    fi
    
    # Verify volumes remain
    if ! docker volume ls 2>/dev/null | grep -q "names-app"; then
        print_fail "Cleanup Script (volumes were deleted)"
        return 1
    fi
    
    # Redeploy for next test
    print_info "Redeploying for volume cleanup test..."
    "$PROJECT_ROOT/ops/deploy.sh" &>/dev/null
    sleep 20
    
    # Test volume cleanup
    print_info "Testing volume cleanup..."
    if ! "$PROJECT_ROOT/ops/cleanup.sh" --remove-volumes --yes > "$TEST_LOG_DIR/test10-cleanup2.log" 2>&1; then
        print_fail "Cleanup Script (volume cleanup failed)"
        return 1
    fi
    
    # Verify volumes removed
    if docker volume ls 2>/dev/null | grep -q "names-app"; then
        print_fail "Cleanup Script (volumes still exist)"
        return 1
    fi
    
    # Redeploy for full cleanup test
    print_info "Redeploying for full cleanup test..."
    "$PROJECT_ROOT/ops/deploy.sh" &>/dev/null
    sleep 20
    
    # Test full cleanup
    print_info "Testing full cleanup..."
    if ! "$PROJECT_ROOT/ops/cleanup.sh" --full --yes > "$TEST_LOG_DIR/test10-cleanup3.log" 2>&1; then
        print_fail "Cleanup Script (full cleanup failed)"
        return 1
    fi
    
    # Verify Swarm left
    if docker info 2>/dev/null | grep -q "Swarm: active"; then
        print_fail "Cleanup Script (still in Swarm)"
        return 1
    fi
    
    local duration=$(($(date +%s) - start_time))
    print_pass "Cleanup Script (${duration}s)"
    return 0
}

################################################################################
# Main Test Execution
################################################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help)
                show_help
                exit 0
                ;;
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --cleanup-only)
                CLEANUP_ONLY=true
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            *)
                echo -e "${RED}ERROR: Unknown option: $1${NC}"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    setup_logging
    
    print_header "🧪 End-to-End Integration Tests"
    
    print_info "Test started: $(date)"
    print_info "Log directory: $TEST_LOG_DIR"
    
    if [[ "$QUICK_MODE" == "true" ]]; then
        print_info "Quick mode: Skipping slow tests"
    fi
    
    echo ""
    
    local start_time=$(date +%s)
    
    # Run tests
    if [[ "$CLEANUP_ONLY" == "true" ]]; then
        test_cleanup
    else
        test_fresh_init
        test_stack_deployment
        test_verification
        test_web_ui
        test_service_restart_persistence
        test_stack_redeploy_persistence
        test_volume_on_worker
        test_auto_restart
        test_frontend_access
        
        if [[ "$NO_CLEANUP" != "true" ]]; then
            test_cleanup
        else
            print_skip "Cleanup (--no-cleanup specified)"
        fi
    fi
    
    local duration=$(($(date +%s) - start_time))
    
    # Print summary
    print_header "Test Summary"
    
    echo -e "${BOLD}Total Tests: $((${#PASSED_TESTS[@]} + ${#FAILED_TESTS[@]} + ${#SKIPPED_TESTS[@]}))${NC}"
    echo -e "${GREEN}Passed: ${#PASSED_TESTS[@]}${NC}"
    echo -e "${RED}Failed: ${#FAILED_TESTS[@]}${NC}"
    echo -e "${YELLOW}Skipped: ${#SKIPPED_TESTS[@]}${NC}"
    echo -e "${BOLD}Duration: ${duration}s${NC}"
    echo ""
    
    if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}Failed Tests:${NC}"
        for test in "${FAILED_TESTS[@]}"; do
            echo -e "  ${RED}• $test${NC}"
        done
        echo ""
        echo -e "${YELLOW}Check logs in: $TEST_LOG_DIR${NC}"
        echo ""
        exit 1
    else
        echo -e "${GREEN}${BOLD}🎉 All tests passed!${NC}"
        echo ""
        exit 0
    fi
}

# Run main function
main "$@"
