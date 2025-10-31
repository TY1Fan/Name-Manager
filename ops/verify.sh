#!/bin/bash
# ops/verify.sh - Verify Swarm deployment

set -e

echo "=== Verifying Names Manager Deployment ==="
echo ""

FAILED=0

# Check if stack is deployed
echo "1. Checking stack status..."
if vagrant ssh manager -c "docker stack ls | grep -q names"; then
    echo "   ✓ Stack 'names' is deployed"
else
    echo "   ✗ Stack 'names' not found"
    FAILED=1
fi

# Check service replicas
echo ""
echo "2. Checking service replicas..."
vagrant ssh manager -c "docker stack services names --format 'table {{.Name}}\t{{.Replicas}}'"

# Check service placement
echo ""
echo "3. Verifying service placement..."

# DB should be on worker (labeled role=db)
DB_NODE=$(vagrant ssh manager -c "docker service ps names_db --format '{{.Node}}' | grep -v '^$' | head -1" 2>/dev/null | tr -d '\r')
if [ "$DB_NODE" == "swarm-worker" ]; then
    echo "   ✓ DB service on worker node (correct)"
else
    echo "   ✗ DB service on '$DB_NODE' (should be worker)"
    FAILED=1
fi

# API should be on manager
API_NODE=$(vagrant ssh manager -c "docker service ps names_api --format '{{.Node}}' | grep -v '^$' | head -1" 2>/dev/null | tr -d '\r')
if [ "$API_NODE" == "swarm-manager" ]; then
    echo "   ✓ API service on manager node (correct)"
else
    echo "   ✗ API service on '$API_NODE' (should be manager)"
    FAILED=1
fi

# Web should be on manager
WEB_NODE=$(vagrant ssh manager -c "docker service ps names_web --format '{{.Node}}' | grep -v '^$' | head -1" 2>/dev/null | tr -d '\r')
if [ "$WEB_NODE" == "swarm-manager" ]; then
    echo "   ✓ Web service on manager node (correct)"
else
    echo "   ✗ Web service on '$WEB_NODE' (should be manager)"
    FAILED=1
fi

# Check health endpoints
echo ""
echo "4. Testing health endpoints..."

# Wait for services to be fully ready
sleep 3

# Test API health
if curl -sf http://localhost:8081/api/health | grep -q '"status":"ok"'; then
    echo "   ✓ API health check passed"
else
    echo "   ✗ API health check failed"
    FAILED=1
fi

# Test DB health
if curl -sf http://localhost:8081/api/health/db | grep -q 'healthy'; then
    echo "   ✓ Database health check passed"
else
    echo "   ✗ Database health check failed"
    FAILED=1
fi

# Check web access
echo ""
echo "5. Testing web access..."
if curl -sf http://localhost:8081/ | grep -q 'Names Manager'; then
    echo "   ✓ Web interface accessible"
else
    echo "   ✗ Web interface not accessible"
    FAILED=1
fi

# Test API endpoints
echo ""
echo "6. Testing API endpoints..."
if curl -sf http://localhost:8081/api/names | grep -q 'names'; then
    echo "   ✓ API /api/names endpoint working"
else
    echo "   ✗ API /api/names endpoint failed"
    FAILED=1
fi

# Verify overlay network
echo ""
echo "7. Verifying overlay network..."
if vagrant ssh manager -c "docker network ls | grep -q appnet.*overlay"; then
    echo "   ✓ Overlay network 'appnet' exists"
    vagrant ssh manager -c "docker network inspect appnet --format '{{.Driver}} - {{.Scope}}'"
else
    echo "   ✗ Overlay network 'appnet' not found"
    FAILED=1
fi

# Verify storage on worker
echo ""
echo "8. Verifying persistent storage..."
if vagrant ssh worker -c "test -d /var/lib/postgres-data && echo exists" | grep -q exists; then
    echo "   ✓ Storage directory exists on worker"
    STORAGE_SIZE=$(vagrant ssh worker -c "sudo du -sh /var/lib/postgres-data" | awk '{print $1}')
    echo "   Storage size: $STORAGE_SIZE"
else
    echo "   ✗ Storage directory not found on worker"
    FAILED=1
fi

# Verify node labels
echo ""
echo "9. Verifying node labels..."
if vagrant ssh manager -c "docker node inspect swarm-worker --format '{{.Spec.Labels}}'" | grep -q "role:db"; then
    echo "   ✓ Worker node labeled with role=db"
else
    echo "   ✗ Worker node label missing"
    FAILED=1
fi

# Check DNS resolution
echo ""
echo "10. Testing DNS service discovery..."
if vagrant ssh manager -c "docker exec \$(docker ps -q -f name=names_api | head -1) python -c 'import socket; socket.gethostbyname(\"names_db\")'" > /dev/null 2>&1; then
    echo "   ✓ DNS resolution working (API can resolve DB)"
else
    echo "   ✗ DNS resolution failed"
    FAILED=1
fi

# Summary
echo ""
echo "=== Verification Summary ==="
echo ""
if [ $FAILED -eq 0 ]; then
    echo "✅ All checks passed!"
    echo ""
    echo "Application is running correctly:"
    echo "  - Web interface: http://localhost:8081"
    echo "  - API health: http://localhost:8081/api/health"
    echo "  - API endpoints: http://localhost:8081/api/names"
    echo "  - DB on worker node with persistent storage ($STORAGE_SIZE)"
    echo "  - Web and API on manager node"
    echo "  - DNS service discovery working"
    echo ""
    echo "Deployment Status:"
    vagrant ssh manager -c "docker stack ps names --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}' | head -5"
    exit 0
else
    echo "❌ Some checks failed. Review errors above."
    echo ""
    echo "Debug commands:"
    echo "  - View logs: vagrant ssh manager -c 'docker service logs names_<service>'"
    echo "  - Check services: vagrant ssh manager -c 'docker service ps names_<service>'"
    echo "  - Service status: vagrant ssh manager -c 'docker stack services names'"
    exit 1
fi
