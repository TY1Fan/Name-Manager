#!/bin/bash
# ops/deploy.sh - Deploy application to Docker Swarm

set -e

echo "=== Deploying Names Manager to Swarm ==="

# Check if Swarm is initialized
echo "Checking Swarm status..."
vagrant ssh manager -c "docker node ls" > /dev/null || { 
    echo "ERROR: Swarm not initialized. Run 'ops/init-swarm.sh' first."; 
    exit 1; 
}

# Build images directly on manager VM
echo "Step 1: Building Docker images on manager VM..."
echo "Building backend image..."
vagrant ssh manager -c "cd /vagrant/src/backend && docker build -t localhost/names-backend:latest ."

echo "Building frontend image..."
vagrant ssh manager -c "cd /vagrant/src/frontend && docker build -t localhost/names-frontend:latest ."

echo "✅ Images built:"
vagrant ssh manager -c "docker images | grep names"

# Deploy stack
echo "Step 2: Deploying stack..."
vagrant ssh manager -c "docker stack deploy -c /vagrant/swarm/stack.yaml names"

# Wait for database to be ready first
echo "Step 3: Waiting for database to be ready..."
echo -n "Checking DB service"
for i in {1..30}; do
    DB_READY=$(vagrant ssh manager -c "docker service ps names_db --filter 'desired-state=running' --format '{{.CurrentState}}' 2>/dev/null | grep -c 'Running' || echo 0")
    if [ "$DB_READY" -ge 1 ]; then
        echo " ✅"
        break
    fi
    echo -n "."
    sleep 2
done

# Give DB a few more seconds to fully initialize
echo "Waiting for database initialization..."
sleep 10

# Check if API needs to be restarted (race condition fix)
echo "Step 4: Ensuring API is connected to database..."
API_STATUS=$(vagrant ssh manager -c "docker service ps names_api --filter 'desired-state=running' --format '{{.CurrentState}}' 2>/dev/null | grep -c 'Running' || echo 0")
if [ "$API_STATUS" -lt 2 ]; then
    echo "API not ready, forcing restart to connect to DB..."
    vagrant ssh manager -c "docker service update --force names_api" > /dev/null 2>&1
    sleep 15
fi

# Show deployment status
echo "Step 5: Verifying deployment..."
echo ""
echo "Services:"
vagrant ssh manager -c "docker stack services names"
echo ""
echo "Service Tasks (Running):"
vagrant ssh manager -c "docker stack ps names --filter 'desired-state=running' --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"

echo ""
echo "=== Deployment Complete ==="
echo "Application URL: http://localhost:8081"
echo "API Health: http://localhost:8081/api/health"
echo ""
echo "To verify deployment, run: ops/verify.sh"
