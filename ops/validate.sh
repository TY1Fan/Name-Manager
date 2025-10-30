#!/bin/bash
# Final End-to-End Validation Script
# Tests all requirements without destroying the current deployment

echo "================================================"
echo "  Names Manager - Final E2E Validation"
echo "================================================"
echo ""

PASSED=0
FAILED=0

check() {
    echo -n "$1... "
    if eval "$2" > /dev/null 2>&1; then
        echo "✅ PASS"
        ((PASSED++))
    else
        echo "❌ FAIL"
        ((FAILED++))
    fi
}

check_output() {
    echo -n "$1... "
    OUTPUT=$(eval "$2" 2>/dev/null)
    if echo "$OUTPUT" | grep -qE "$3"; then
        echo "✅ PASS"
        ((PASSED++))
    else
        echo "❌ FAIL"
        ((FAILED++))
    fi
}

echo "=== Infrastructure Checks ==="
check "VMs running (manager)" "vagrant status manager | grep -q 'running'"
check "VMs running (worker)" "vagrant status worker | grep -q 'running'"
check "Swarm initialized" "vagrant ssh manager -c 'docker node ls' | grep -q swarm-manager"
check "Worker joined swarm" "vagrant ssh manager -c 'docker node ls' | grep -q swarm-worker"
check "Worker labeled role=db" "vagrant ssh manager -c 'docker node inspect swarm-worker --format {{.Spec.Labels}}' | grep -q 'role:db'"
check "Overlay network exists" "vagrant ssh manager -c 'docker network ls' | grep -q 'appnet.*overlay'"
check "Storage directory on worker" "vagrant ssh worker -c 'test -d /var/lib/postgres-data'"

echo ""
echo "=== Deployment Checks ==="
check "Stack deployed" "vagrant ssh manager -c 'docker stack ls' | grep -q names"
check_output "DB on worker node" "vagrant ssh manager -c 'docker service ps names_db --format {{.Node}} | head -1'" "swarm-worker"
check_output "API on manager node" "vagrant ssh manager -c 'docker service ps names_api --format {{.Node}} | head -1'" "swarm-manager"
check_output "Web on manager node" "vagrant ssh manager -c 'docker service ps names_web --format {{.Node}} | head -1'" "swarm-manager"
check "API has 2 replicas" "vagrant ssh manager -c 'docker service ls' | grep names_api | grep -q '2/2'"
check "DB has 1 replica" "vagrant ssh manager -c 'docker service ls' | grep names_db | grep -q '1/1'"
check "Web has 1 replica" "vagrant ssh manager -c 'docker service ls' | grep names_web | grep -q '1/1'"
check "Web publishes port 80" "vagrant ssh manager -c 'docker service inspect names_web --format {{.Endpoint.Ports}}' | grep -q '80'"

echo ""
echo "=== Configuration Checks ==="
check "DATABASE_URL uses service name" "vagrant ssh manager -c 'docker service inspect names_api --format {{.Spec.TaskTemplate.ContainerSpec.Env}}' | grep -q 'DATABASE_URL.*@db:'"
check "Stack file exists" "test -f swarm/stack.yaml"
check "Compose file exists" "test -f src/docker-compose.yml"

echo ""
echo "=== Functionality Checks ==="
check "Application accessible" "curl -sf http://localhost:8081/"
check_output "API health check" "curl -sf http://localhost:8081/api/health" '"status":\s*"ok"'
check_output "DB health check" "curl -sf http://localhost:8081/api/health/db" 'healthy'
check_output "GET /api/names works" "curl -sf http://localhost:8081/api/names" '"names":\s*\['
check "pg_isready works" "vagrant ssh worker -c 'docker exec \$(docker ps -q -f name=names_db) pg_isready -U names_user -d namesdb'"

# Test CRUD operations
echo ""
echo "=== CRUD Operations Test ==="
TEST_NAME="E2E_Validation_$(date +%s)"
echo -n "POST new name... "
POST_RESULT=$(curl -sf -X POST http://localhost:8081/api/names -H "Content-Type: application/json" -d "{\"name\":\"$TEST_NAME\"}")
if echo "$POST_RESULT" | grep -q "$TEST_NAME"; then
    echo "✅ PASS"
    ((PASSED++))
    TEST_ID=$(echo "$POST_RESULT" | python3 -c "import sys, json; print(json.load(sys.stdin)['id'])")
    
    echo -n "GET name with timestamp... "
    GET_RESULT=$(curl -sf http://localhost:8081/api/names)
    if echo "$GET_RESULT" | grep -q "$TEST_NAME" && echo "$GET_RESULT" | grep -q "created_at"; then
        echo "✅ PASS"
        ((PASSED++))
    else
        echo "❌ FAIL"
        ((FAILED++))
    fi
    
    echo -n "DELETE name... "
    DELETE_RESULT=$(curl -sf -X DELETE http://localhost:8081/api/names/$TEST_ID)
    if echo "$DELETE_RESULT" | grep -q "\"deleted\":$TEST_ID"; then
        echo "✅ PASS"
        ((PASSED++))
    else
        echo "❌ FAIL"
        ((FAILED++))
    fi
else
    echo "❌ FAIL"
    ((FAILED++))
fi

echo ""
echo "=== DNS Service Discovery ==="
check "API can resolve DB" "vagrant ssh manager -c 'docker exec \$(docker ps -q -f name=names_api | head -1) python -c \"import socket; socket.gethostbyname(\\\"names_db\\\")\"'"
check "Web can resolve API" "vagrant ssh manager -c 'docker exec \$(docker ps -q -f name=names_web) nslookup api'"

echo ""
echo "=== Operations Scripts ==="
check "init-swarm.sh exists" "test -x ops/init-swarm.sh"
check "deploy.sh exists" "test -x ops/deploy.sh"
check "verify.sh exists" "test -x ops/verify.sh"
check "cleanup.sh exists" "test -x ops/cleanup.sh"

echo ""
echo "=== Documentation ==="
check "README documents compose" "grep -q 'docker compose up' README.md"
check "README documents stack" "grep -q 'swarm/stack.yaml' README.md"
check "README documents ops scripts" "grep -q 'ops/' README.md"
check "Operations guide exists" "test -f docs/OPERATIONS.md"

echo ""
echo "=== Docker Secrets ==="
check "Secrets created" "vagrant ssh manager -c 'docker secret ls' | grep -q postgres_user"
check "DB uses secrets" "vagrant ssh manager -c 'docker service inspect names_db --format \"{{json .Spec.TaskTemplate.ContainerSpec.Secrets}}\"' | grep -q postgres_user"

echo ""
echo "================================================"
echo "  Validation Summary"
echo "================================================"
echo ""
echo "Total Tests: $((PASSED + FAILED))"
echo "Passed:      $PASSED ✅"
echo "Failed:      $FAILED ❌"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 ALL TESTS PASSED! System is production-ready."
    echo ""
    echo "Final State:"
    echo "  - Application: http://localhost:8081"
    echo "  - Services: $(vagrant ssh manager -c 'docker stack services names --format \"{{.Name}}: {{.Replicas}}\"' | tr '\n' ', ' | sed 's/,$//')"
    echo "  - Storage: $(vagrant ssh worker -c 'sudo du -sh /var/lib/postgres-data' | awk '{print $1}')"
    echo ""
    exit 0
else
    echo "⚠️  Some tests failed. Review errors above."
    exit 1
fi
